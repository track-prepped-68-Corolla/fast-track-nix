"""Typer entry point for `ft-py` — the Phase 1 (sys + mullet) parity CLI.

Owns every interactive decision (confirmations, prompts) and every bit of
environment resolution (FT_REPO, USER). The ops/ layer never prompts or
reads the environment itself — see ops/sys.py and ops/mullet.py.
"""

from __future__ import annotations

import asyncio
import os
from pathlib import Path
from typing import Any, AsyncIterator, Coroutine, NoReturn, Optional

import typer

from ft_py import errors
from ft_py.ops import mullet as mullet_ops
from ft_py.ops import sys as sys_ops
from ft_py.proc import OutputLine

app = typer.Typer(add_completion=False, no_args_is_help=True)


def _repo_path() -> Path:
    """Mirrors the FT_REPO convention: the `ft.cli` wrapper exports it
    pointing at `ft.repoPath`; the standalone flake package defaults it to
    `$(pwd)`. We mirror both: env var first, cwd fallback."""
    return Path(os.environ.get("FT_REPO") or Path.cwd())


def _mullet_file(repo_path: Path) -> Path:
    """Mirrors mullet.just's `MULLET_FILE := "users/" + env_var("USER") +
    "/var/mullet.txt"` — env_var() fails fast if USER is unset."""
    user = os.environ.get("USER")
    if not user:
        _fail("Error: USER environment variable is not set.")
    return repo_path / "users" / user / "var" / "mullet.txt"


def _print(line: OutputLine) -> None:
    typer.echo(line.text, err=(line.stream == "stderr"))


async def _stream(lines: AsyncIterator[OutputLine]) -> None:
    async for line in lines:
        _print(line)


def _fail(message: str) -> NoReturn:
    typer.echo(message, err=True)
    raise typer.Exit(code=1)


def _run(coro: Coroutine[Any, Any, None]) -> None:
    asyncio.run(coro)


def _missing_requirements_message(exc: errors.MissingRequirementsError) -> str:
    return "\n".join(f"Error: {cmd} is not installed." for cmd in exc.missing)


# --- 1. Maintenance & Checks ---


@app.command()
def fmt() -> None:
    """Format every *.nix file in the repo."""
    _run(_stream(sys_ops.fmt(_repo_path())))


@app.command()
def check() -> None:
    """fmt, then scan for leaked secrets."""
    _run(_stream(sys_ops.check(_repo_path())))


@app.command()
def clean() -> None:
    """nh clean all --keep 5."""
    _run(_stream(sys_ops.clean(_repo_path())))


# --- 2. Testing ---


@app.command(name="test")
def test_cmd() -> None:
    """check, then a disposable `nh os test . --ask` build."""

    async def run() -> None:
        try:
            await _stream(sys_ops.test_(_repo_path()))
        except errors.MissingRequirementsError as exc:
            _fail(_missing_requirements_message(exc))
        except errors.CommandFailedError as exc:
            raise typer.Exit(code=exc.returncode)

    _run(run())


# --- 3. Core Workflow ---


@app.command()
def switch() -> None:
    """Preview the build, confirm, then apply + commit + clean up."""

    async def run() -> None:
        repo_path = _repo_path()
        try:
            await _stream(sys_ops.switch_preview(repo_path))
        except errors.MissingRequirementsError as exc:
            _fail(_missing_requirements_message(exc))

        if not typer.confirm("Apply and commit?", default=False):
            typer.echo("Cancelled.")
            raise typer.Exit(code=1)

        typer.echo("")
        commit_message = typer.prompt("Commit message")

        try:
            result: Optional[sys_ops.SwitchResult] = None
            async for item in sys_ops.switch_apply(repo_path, commit_message):
                if isinstance(item, sys_ops.SwitchResult):
                    result = item
                else:
                    _print(item)
        except errors.CommandFailedError as exc:
            raise typer.Exit(code=exc.returncode)

        assert result is not None
        typer.echo(f":: Update Complete! Now running Generation {result.new_generation} ::")

    _run(run())


@app.command(name="home-switch")
def home_switch(
    user: Optional[str] = typer.Argument(None),
    arch: Optional[str] = typer.Argument(None),
) -> None:
    """home-manager switch --flake .#<user>@<arch>."""
    _run(_stream(sys_ops.home_switch(_repo_path(), user=user, arch=arch)))


# --- 4. Remote Syncing ---


@app.command()
def pull() -> None:
    """Rebase pull, show incoming diff, switch, show the package diff."""
    _run(_stream(sys_ops.pull(_repo_path())))


@app.command()
def push() -> None:
    """Refuse if the tree is dirty, else git push."""

    async def run() -> None:
        try:
            await _stream(sys_ops.push(_repo_path()))
        except errors.UncommittedChangesError as exc:
            _fail(f":: Error: {exc} ::")

    _run(run())


@app.command()
def sync() -> None:
    """pull, then push."""

    async def run() -> None:
        try:
            await _stream(sys_ops.sync(_repo_path()))
        except errors.UncommittedChangesError as exc:
            _fail(f":: Error: {exc} ::")

    _run(run())


# --- 5. Emergency Recovery ---


@app.command()
def rollback() -> None:
    """Roll back the system profile and activate it."""

    async def run() -> None:
        try:
            await _stream(sys_ops.rollback(_repo_path()))
        except errors.CommandFailedError as exc:
            raise typer.Exit(code=exc.returncode)

    _run(run())


# --- Mullet: imperative package escape hatch ---


@app.command()
def search(query: str) -> None:
    """Search Nix-Index (then Nixpkgs descriptions) for a binary/package."""
    _run(_stream(mullet_ops.search(query, cwd=_repo_path())))


@app.command()
def add(pkg: str) -> None:
    """Add a nixpkgs attribute path to The Mullet."""
    repo_path = _repo_path()

    async def run() -> None:
        try:
            await _stream(mullet_ops.add(pkg, _mullet_file(repo_path), cwd=repo_path))
        except errors.PackageNotFoundError as exc:
            raise typer.Exit(code=1) from exc

    _run(run())


@app.command()
def rm(pkg: str) -> None:
    """Remove a package from The Mullet."""
    repo_path = _repo_path()

    async def run() -> None:
        try:
            await _stream(mullet_ops.rm(pkg, _mullet_file(repo_path)))
        except errors.PackageNotPresentError as exc:
            _fail(f":: Error: {exc}. ::")

    _run(run())


@app.command()
def lst() -> None:
    """List every package currently in The Mullet."""
    typer.echo(":: Imperative Packages (The Mullet) ::")
    content = mullet_ops.lst(_mullet_file(_repo_path()))
    # Mirrors `cat file || echo "(Empty)"`: an existing-but-empty file
    # prints nothing extra (cat's own 0-byte output), unlike the "(Empty)"
    # fallback string, which gets the newline `echo` would add.
    if content:
        typer.echo(content, nl=not content.endswith("\n"))


@app.command()
def haircut() -> None:
    """Remove every package from The Mullet, after confirmation."""
    if not typer.confirm("This removes all imperative packages. Continue?", default=False):
        typer.echo("Cancelled.")
        return
    mullet_ops.haircut(_mullet_file(_repo_path()))
    typer.echo(":: Haircut complete. Run 'ft switch' to apply the clean slate. ::")


if __name__ == "__main__":
    app()
