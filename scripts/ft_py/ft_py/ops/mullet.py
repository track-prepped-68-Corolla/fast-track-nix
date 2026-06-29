"""Async port of scripts/mullet.just — the imperative-package escape hatch.

The Mullet is a flat file, one nixpkgs attribute path per line. These ops
take the resolved mullet_file Path as a parameter (the CLI layer computes it
from `users/<user>/var/mullet.txt`, mirroring MULLET_FILE's `env_var("USER")`
default) — ops never read environment variables themselves.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import AsyncIterator

from ft_py.errors import PackageNotFoundError, PackageNotPresentError
from ft_py.proc import OutputLine, run_capture

_SEARCH_FALLBACK_LINES = 15
_ADD_FALLBACK_LINES = 10


def _line_pattern(pkg: str) -> re.Pattern[str]:
    # Mirrors lib/mullet.sh's grep/sed pattern, but escapes pkg so package
    # names containing regex metacharacters (e.g. "python3Packages.foo")
    # match only themselves rather than being interpreted as a pattern.
    return re.compile(rf"^[ \t]*{re.escape(pkg)}[ \t]*$")


def mullet_contains(mullet_file: Path, pkg: str) -> bool:
    """Mirrors mullet_contains() in lib/mullet.sh."""
    if not mullet_file.exists():
        return False
    pattern = _line_pattern(pkg)
    return any(pattern.match(line) for line in mullet_file.read_text().splitlines())


def mullet_add_line(mullet_file: Path, pkg: str) -> None:
    """Mirrors mullet_add_line() in lib/mullet.sh. Caller is responsible for
    validation/dedup, same as the bash helper."""
    with mullet_file.open("a") as f:
        f.write(f"{pkg}\n")


def mullet_rm_line(mullet_file: Path, pkg: str) -> None:
    """Mirrors mullet_rm_line() in lib/mullet.sh."""
    pattern = _line_pattern(pkg)
    lines = mullet_file.read_text().splitlines()
    kept = [line for line in lines if not pattern.match(line)]
    mullet_file.write_text("".join(f"{line}\n" for line in kept))


async def _nix_locate(query: str, cwd: Path | None = None) -> str:
    result = await run_capture(
        ["nix-locate", "--top-level", "--minimal", "--at-root", f"/bin/{query}"], cwd=cwd
    )
    return result.stdout


async def _nix_search_head(query: str, n: int, cwd: Path | None = None) -> str:
    result = await run_capture(["nix", "search", "nixpkgs", query], cwd=cwd)
    return "\n".join(result.stdout.splitlines()[:n])


async def search(query: str, cwd: Path | None = None) -> AsyncIterator[OutputLine]:
    """Mirrors the `search` recipe."""
    yield OutputLine("stdout", f":: Searching Nix-Index for binary '{query}' ::")
    results = await _nix_locate(query, cwd=cwd)
    if results:
        for text in results.splitlines():
            yield OutputLine("stdout", text)
        return
    yield OutputLine("stdout", ":: No exact binary match in Nix-Index. ::")
    yield OutputLine("stdout", ":: Searching Nixpkgs descriptions... ::")
    fallback = await _nix_search_head(query, _SEARCH_FALLBACK_LINES, cwd=cwd)
    for text in fallback.splitlines():
        yield OutputLine("stdout", text)


async def add(pkg: str, mullet_file: Path, cwd: Path | None = None) -> AsyncIterator[OutputLine]:
    """Mirrors the `add` recipe. Raises PackageNotFoundError (after
    streaming the same nix-locate/nix-search suggestions the just recipe
    prints) when pkg does not evaluate in nixpkgs."""
    if mullet_contains(mullet_file, pkg):
        yield OutputLine("stdout", f":: '{pkg}' is already in The Mullet. ::")
        return

    yield OutputLine("stdout", f":: Verifying '{pkg}' exists... ::")
    eval_result = await run_capture(
        ["nix", "eval", f"nixpkgs#{pkg}", "--apply", "p: p.outPath or p.pname or p.name"],
        cwd=cwd,
    )
    if not eval_result.ok:
        yield OutputLine("stdout", f":: Error: '{pkg}' is not a valid package path. ::")
        yield OutputLine(
            "stdout", f":: Did you mean one of these? (Searching Nix-Index for '{pkg}') ::"
        )
        yield OutputLine("stdout", "")
        for text in (await _nix_locate(pkg, cwd=cwd)).splitlines():
            yield OutputLine("stdout", text)
        yield OutputLine("stdout", "")
        yield OutputLine("stdout", ":: (Fallback) Searching Nixpkgs descriptions... ::")
        for text in (await _nix_search_head(pkg, _ADD_FALLBACK_LINES, cwd=cwd)).splitlines():
            yield OutputLine("stdout", text)
        raise PackageNotFoundError(pkg)

    mullet_add_line(mullet_file, pkg)
    yield OutputLine("stdout", f":: Added {pkg}. Run 'ft switch' to apply. ::")


async def rm(pkg: str, mullet_file: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `rm` recipe. Raises PackageNotPresentError if pkg is not
    listed."""
    if not mullet_contains(mullet_file, pkg):
        raise PackageNotPresentError(pkg)
    mullet_rm_line(mullet_file, pkg)
    yield OutputLine("stdout", f":: Removed {pkg}. Run 'ft switch' to apply. ::")


def lst(mullet_file: Path) -> str:
    """Mirrors the `lst` recipe: file contents, or "(Empty)" if the file
    doesn't exist (matching `cat file || echo "(Empty)"` — a merely-empty
    existing file prints nothing, same as `cat` on an empty file)."""
    try:
        return mullet_file.read_text()
    except FileNotFoundError:
        return "  (Empty)"


def haircut(mullet_file: Path) -> None:
    """Mirrors the `haircut` recipe's effect: truncate the Mullet file. The
    CLI layer owns the "Continue?" confirmation prompt; this performs the
    truncation unconditionally once called."""
    mullet_file.write_text("")
