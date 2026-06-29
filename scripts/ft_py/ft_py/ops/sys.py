"""Async port of scripts/sys.just — daily-driver maintenance + core workflow.

Ops functions stream OutputLine events and raise ft_py.errors.FtOpsError
subclasses on failure; they never prompt. Interactive decisions ("Apply and
commit?", the commit message itself) are parameters the CLI layer collects
and passes in — see switch_preview()/switch_apply() below.
"""

from __future__ import annotations

import os
import platform
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import AsyncIterator, Callable

from ft_py.errors import (
    CommandFailedError,
    MissingRequirementsError,
    UncommittedChangesError,
)
from ft_py.proc import OutputLine, StreamedCommand, run_capture, run_piped

REQUIRED_COMMANDS: tuple[str, ...] = ("nh", "nvd", "delta")

_SYSTEM_PROFILE = Path("/nix/var/nix/profiles/system")


def missing_requirements(
    which: Callable[[str], str | None] | None = None,
) -> list[str]:
    """Which REQUIRED_COMMANDS are absent from PATH. `which` is injectable
    for tests; defaults to shutil.which. Mirrors the private `_check-reqs`
    recipe."""
    resolver = which or shutil.which
    return [cmd for cmd in REQUIRED_COMMANDS if resolver(cmd) is None]


def find_nix_files(repo_path: Path) -> list[Path]:
    """Every *.nix file under repo_path, recursively. Mirrors
    `find . -name "*.nix"`."""
    return sorted(repo_path.rglob("*.nix"))


def generation_number(system_link: str) -> int:
    """Parse the generation number out of a system profile link name, e.g.
    "system-123-link" -> 123. Mirrors `cut -d'-' -f2`."""
    return int(system_link.split("-")[1])


def last_two_generations(profile_dir: Path | None = None) -> list[Path]:
    """The two oldest-to-newest `system-*-link` entries. Mirrors
    `ls -d1v system-*-link | tail -n 2`. Mirrors the private
    `_last-two-gens` recipe."""
    profile_dir = profile_dir or _SYSTEM_PROFILE.parent
    links = sorted(profile_dir.glob("system-*-link"), key=lambda p: generation_number(p.name))
    return links[-2:]


async def current_generation(cwd: Path | str | None = None) -> int:
    """Mirrors the private `_current-gen` recipe:
    `readlink /nix/var/nix/profiles/system | cut -d'-' -f2`."""
    result = await run_capture(["readlink", str(_SYSTEM_PROFILE)], cwd=cwd)
    return generation_number(result.stdout.strip())


async def fmt(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `fmt` recipe: nixfmt every *.nix file in the repo."""
    yield OutputLine("stdout", ":: Formatting ::")
    files = find_nix_files(repo_path)
    if not files:
        return
    async for line in StreamedCommand(["nixfmt", *map(str, files)], cwd=repo_path):
        yield line


async def check(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `check` recipe: fmt, then scan for leaked secrets."""
    async for line in fmt(repo_path):
        yield line
    yield OutputLine("stdout", ":: Scanning for leaked secrets ::")
    async for line in StreamedCommand(
        ["trufflehog", "git", "file://.", "--since-commit", "HEAD", "--fail"],
        cwd=repo_path,
    ):
        yield line


async def clean(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `clean` recipe: nh clean all --keep 5."""
    yield OutputLine("stdout", ":: Cleaning Nix Store ::")
    async for line in StreamedCommand(["nh", "clean", "all", "--keep", "5"], cwd=repo_path):
        yield line


async def stage(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the private `_stage` recipe: git add ."""
    async for line in StreamedCommand(["git", "add", "."], cwd=repo_path):
        yield line


async def diff_src(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the private `_diff-src` recipe: git diff --cached | delta."""
    async for line in run_piped(
        ["git", "diff", "--cached"],
        ["delta", "--side-by-side"],
        cwd=repo_path,
    ):
        yield line


async def test_(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `test` recipe: check, _check-reqs, _stage, _diff-src,
    then `nh os test . --ask`."""
    async for line in check(repo_path):
        yield line
    missing = missing_requirements()
    if missing:
        raise MissingRequirementsError(missing)
    yield OutputLine("stdout", ":: Staging & Diffs ::")
    async for line in stage(repo_path):
        yield line
    async for line in diff_src(repo_path):
        yield line
    yield OutputLine("stdout", ":: Running Test ::")
    cmd = StreamedCommand(["nh", "os", "test", ".", "--ask"], cwd=repo_path)
    async for line in cmd:
        yield line
    yield OutputLine("stdout", ":: Test complete. Reboot to revert. ::")
    if cmd.returncode:
        raise CommandFailedError(cmd.argv, cmd.returncode)


async def switch_preview(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `switch` recipe up to (not including) its "Apply and
    commit?" prompt: check, _check-reqs, _stage, `nh os test . --dry`,
    _diff-src. The CLI layer shows this output, prompts the user, then —
    only on confirmation — calls switch_apply()."""
    async for line in check(repo_path):
        yield line
    missing = missing_requirements()
    if missing:
        raise MissingRequirementsError(missing)
    yield OutputLine("stdout", ":: Previewing Build ::")
    async for line in stage(repo_path):
        yield line
    cmd = StreamedCommand(["nh", "os", "test", ".", "--dry"], cwd=repo_path)
    async for line in cmd:
        yield line
    if cmd.returncode:
        raise CommandFailedError(cmd.argv, cmd.returncode)
    yield OutputLine("stdout", ":: Source Code Changes ::")
    async for line in diff_src(repo_path):
        yield line


@dataclass
class SwitchResult:
    old_generation: int
    new_generation: int
    nvd_diff: str
    committed: bool


async def _run_switch(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `failover-switch` recipe's happy path: `nh os switch .`.

    The stable-overrides retry/pin logic in scripts/failover.just is not
    ported here — out of scope for this pass (sys.just + mullet.just only).
    This runs the underlying build/switch directly, correct as long as the
    build succeeds on the first attempt; the retry behaviour is deferred to
    whichever future pass ports failover.just.
    """
    cmd = StreamedCommand(["nh", "os", "switch", "."], cwd=repo_path)
    async for line in cmd:
        yield line
    if cmd.returncode:
        raise CommandFailedError(cmd.argv, cmd.returncode)


async def switch_apply(
    repo_path: Path, commit_message: str | None
) -> AsyncIterator[OutputLine | SwitchResult]:
    """Mirrors the post-confirmation half of the `switch` recipe.

    `commit_message` is collected by the CLI layer (e.g. via prompt) before
    calling this — ops functions never prompt themselves. A commit only
    happens when there are staged changes, regardless of message content,
    matching the just recipe. Yields OutputLine events as it runs, then a
    final SwitchResult.
    """
    old_gen = await current_generation(cwd=repo_path)

    async for line in _run_switch(repo_path):
        yield line

    new_gen = await current_generation(cwd=repo_path)

    gens = last_two_generations()
    if len(gens) == 2:
        nvd = await run_capture(
            ["nvd", "--color", "never", "diff", str(gens[0]), str(gens[1])],
            cwd=repo_path,
        )
        nvd_diff = nvd.stdout if nvd.ok else "(no previous generation to diff)"
    else:
        nvd_diff = "(no previous generation to diff)"

    staged = await run_capture(["git", "diff", "--cached", "--quiet"], cwd=repo_path)
    committed = False
    if not staged.ok:  # non-zero exit means there ARE staged changes
        commit_result = await run_capture(
            [
                "git",
                "commit",
                "-m",
                commit_message or "",
                "-m",
                f"Generation: {new_gen}",
                "-m",
                nvd_diff,
            ],
            cwd=repo_path,
        )
        if not commit_result.ok:
            raise CommandFailedError(["git", "commit"], commit_result.returncode)
        committed = True
    else:
        yield OutputLine("stdout", ":: No source changes detected. Skipping git commit. ::")

    if new_gen > old_gen:
        async for line in clean(repo_path):
            yield line
    else:
        yield OutputLine("stdout", ":: System generation did not change. Skipping cleanup. ::")

    yield SwitchResult(
        old_generation=old_gen,
        new_generation=new_gen,
        nvd_diff=nvd_diff,
        committed=committed,
    )


async def home_switch(
    repo_path: Path, user: str | None = None, arch: str | None = None
) -> AsyncIterator[OutputLine]:
    """Mirrors the `home-switch` recipe. Defaults mirror the bash recipe's
    `${USER}` / `$(uname -m)-linux` fallbacks."""
    resolved_user = user or os.environ.get("USER", "")
    resolved_arch = arch or f"{platform.machine()}-linux"
    async for line in StreamedCommand(
        ["home-manager", "switch", "--flake", f".#{resolved_user}@{resolved_arch}"],
        cwd=repo_path,
    ):
        yield line


async def pull(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `pull` recipe: rebase pull, show incoming diff, switch,
    show the resulting package diff."""
    yield OutputLine("stdout", ":: Pulling Updates ::")
    async for line in StreamedCommand(["git", "pull", "--rebase", "--autostash"], cwd=repo_path):
        yield line
    yield OutputLine("stdout", ":: Incoming Source Changes ::")
    async for line in run_piped(
        ["git", "diff", "HEAD@{1}..HEAD"], ["delta", "--side-by-side"], cwd=repo_path
    ):
        yield line
    yield OutputLine("stdout", ":: Building and Switching ::")
    async for line in StreamedCommand(["nh", "os", "switch", ".", "--ask"], cwd=repo_path):
        yield line
    yield OutputLine("stdout", ":: System Package Changes ::")
    gens = last_two_generations()
    if len(gens) == 2:
        async for line in StreamedCommand(
            ["nvd", "diff", str(gens[0]), str(gens[1])], cwd=repo_path
        ):
            yield line
    else:
        yield OutputLine("stdout", "(no previous generation to diff)")


async def push(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `push` recipe: refuse if the tree is dirty, else
    git push."""
    status = await run_capture(["git", "status", "--porcelain"], cwd=repo_path)
    if status.stdout.strip():
        raise UncommittedChangesError(
            "Uncommitted changes. Run 'ft switch' or commit manually first."
        )
    yield OutputLine("stdout", ":: Pushing to Remote ::")
    async for line in StreamedCommand(["git", "push"], cwd=repo_path):
        yield line


async def sync(repo_path: Path) -> AsyncIterator[OutputLine]:
    """Mirrors the `sync` recipe: pull then push."""
    async for line in pull(repo_path):
        yield line
    async for line in push(repo_path):
        yield line


async def rollback(repo_path: Path | str | None = None) -> AsyncIterator[OutputLine]:
    """Mirrors the `rollback` recipe: roll back the system profile and
    activate it. Operates on /nix/var/nix/profiles/system, independent of
    the consumer repo, but accepts cwd for consistency with the other ops."""
    gen = await current_generation(cwd=repo_path)
    yield OutputLine("stdout", ":: Current Generation ::")
    yield OutputLine("stdout", str(gen))

    yield OutputLine("stdout", ":: Rolling back to previous generation ::")
    cmd = StreamedCommand(
        ["sudo", "nix-env", "--profile", str(_SYSTEM_PROFILE), "--rollback"], cwd=repo_path
    )
    async for line in cmd:
        yield line
    if cmd.returncode:
        raise CommandFailedError(cmd.argv, cmd.returncode)

    yield OutputLine("stdout", ":: Activating rolled-back system ::")
    cmd = StreamedCommand(
        ["sudo", f"{_SYSTEM_PROFILE}/bin/switch-to-configuration", "switch"], cwd=repo_path
    )
    async for line in cmd:
        yield line
    if cmd.returncode:
        raise CommandFailedError(cmd.argv, cmd.returncode)

    yield OutputLine("stdout", ":: Rollback Complete! ::")
    yield OutputLine(
        "stdout",
        ":: Note: Your Git repo is still ahead. You may want to 'git reset' or fix the code. ::",
    )
