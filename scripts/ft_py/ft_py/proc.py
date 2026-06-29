"""Async subprocess primitives shared by every ops module.

Every helper here uses asyncio.create_subprocess_exec (never subprocess.run
or shell=True) so that, per the project's UI roadmap, the same ops functions
can later drive a Textual TUI without blocking it on long-running commands
like `nh os switch`.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from pathlib import Path
from typing import AsyncIterator, Mapping, Sequence

from ft_py.errors import CommandFailedError

Stream = str  # "stdout" | "stderr"


@dataclass(frozen=True)
class OutputLine:
    """One line of subprocess output, tagged with its origin stream."""

    stream: Stream
    text: str


@dataclass
class CommandResult:
    """Fully-captured result of a non-streamed command (run_capture)."""

    argv: Sequence[str]
    returncode: int
    lines: list[OutputLine] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return self.returncode == 0

    @property
    def stdout(self) -> str:
        return "\n".join(line.text for line in self.lines if line.stream == "stdout")

    @property
    def stderr(self) -> str:
        return "\n".join(line.text for line in self.lines if line.stream == "stderr")


async def run_capture(
    argv: Sequence[str],
    *,
    cwd: Path | str | None = None,
    env: Mapping[str, str] | None = None,
) -> CommandResult:
    """Run argv to completion, capturing stdout/stderr. For short commands
    whose output is parsed rather than streamed to a user."""
    process = await asyncio.create_subprocess_exec(
        *argv,
        cwd=cwd,
        env=dict(env) if env is not None else None,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate()
    lines = [OutputLine("stdout", text) for text in stdout.decode(errors="replace").splitlines()]
    lines += [OutputLine("stderr", text) for text in stderr.decode(errors="replace").splitlines()]
    assert process.returncode is not None
    return CommandResult(argv=argv, returncode=process.returncode, lines=lines)


class StreamedCommand:
    """A subprocess whose combined stdout+stderr can be consumed line-by-line
    as it runs. `returncode` is populated once iteration completes.

    Usage:
        cmd = StreamedCommand(["nh", "os", "switch", "."], cwd=repo_path)
        async for line in cmd:
            print(line.text)
        assert cmd.returncode == 0
    """

    def __init__(
        self,
        argv: Sequence[str],
        *,
        cwd: Path | str | None = None,
        env: Mapping[str, str] | None = None,
    ) -> None:
        self.argv = list(argv)
        self._cwd = cwd
        self._env = dict(env) if env is not None else None
        self._process: asyncio.subprocess.Process | None = None

    @property
    def returncode(self) -> int | None:
        return None if self._process is None else self._process.returncode

    async def __aiter__(self) -> AsyncIterator[OutputLine]:
        self._process = await asyncio.create_subprocess_exec(
            *self.argv,
            cwd=self._cwd,
            env=self._env,
            stdin=None,  # inherit — lets e.g. `nh os test . --ask` prompt directly
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        assert self._process.stdout is not None
        while True:
            raw = await self._process.stdout.readline()
            if not raw:
                break
            yield OutputLine("stdout", raw.decode(errors="replace").rstrip("\n"))
        await self._process.wait()


async def run_piped(
    argv1: Sequence[str],
    argv2: Sequence[str],
    *,
    cwd: Path | str | None = None,
) -> AsyncIterator[OutputLine]:
    """Run argv1 | argv2 (argv1's stdout feeds argv2's stdin), yielding
    argv2's stdout line-by-line. Used for `git diff ... | delta --side-by-side`
    style pipelines, without spawning a shell.
    """
    proc1 = await asyncio.create_subprocess_exec(
        *argv1,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE,
    )
    proc2 = await asyncio.create_subprocess_exec(
        *argv2,
        cwd=cwd,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    assert proc1.stdout is not None
    assert proc2.stdin is not None
    assert proc2.stdout is not None

    async def relay() -> None:
        assert proc1.stdout is not None
        assert proc2.stdin is not None
        while True:
            chunk = await proc1.stdout.read(65536)
            if not chunk:
                break
            proc2.stdin.write(chunk)
            await proc2.stdin.drain()
        proc2.stdin.close()

    relay_task = asyncio.create_task(relay())
    while True:
        raw = await proc2.stdout.readline()
        if not raw:
            break
        yield OutputLine("stdout", raw.decode(errors="replace").rstrip("\n"))

    await relay_task
    rc1 = await proc1.wait()
    rc2 = await proc2.wait()
    if rc1:
        raise CommandFailedError(list(argv1), rc1)
    if rc2:
        raise CommandFailedError(list(argv2), rc2)
