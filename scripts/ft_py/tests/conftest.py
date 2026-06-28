"""Shared pytest fixtures for the ft_py test suite.

Ops modules talk to the outside world exclusively through proc.py's
StreamedCommand/run_capture. Tests that exercise control flow (rather than
real subprocess behaviour, which test_proc.py covers directly) monkeypatch
those two call points with the fakes below, scripted per test via an argv
prefix -> canned-result mapping.
"""

from __future__ import annotations

from typing import Sequence

import pytest

from ft_py.proc import CommandResult, OutputLine


class FakeStreamedCommand:
    """Drop-in stand-in for proc.StreamedCommand, scripted per test."""

    def __init__(
        self,
        argv: Sequence[str],
        *,
        cwd=None,
        env=None,
        lines: list[str] | None = None,
        returncode: int = 0,
    ) -> None:
        self.argv = list(argv)
        self.cwd = cwd
        self.env = env
        self._lines = lines or []
        self._returncode = returncode
        self.returncode: int | None = None

    async def __aiter__(self):
        for text in self._lines:
            yield OutputLine("stdout", text)
        self.returncode = self._returncode


@pytest.fixture
def streamed_calls() -> list[list[str]]:
    """Every argv passed to a faked StreamedCommand, in call order."""
    return []


@pytest.fixture
def fake_streamed_command(streamed_calls):
    """Factory returning a StreamedCommand-compatible callable.

    `script` maps an argv prefix (tuple of str) to (lines, returncode);
    an argv not matching any prefix gets (no lines, returncode 0).
    """

    def make(script: dict[tuple[str, ...], tuple[list[str], int]] | None = None):
        script = script or {}

        def factory(argv: Sequence[str], *, cwd=None, env=None) -> FakeStreamedCommand:
            streamed_calls.append(list(argv))
            for prefix, (lines, returncode) in script.items():
                if tuple(argv[: len(prefix)]) == prefix:
                    return FakeStreamedCommand(
                        argv, cwd=cwd, env=env, lines=lines, returncode=returncode
                    )
            return FakeStreamedCommand(argv, cwd=cwd, env=env)

        return factory

    return make


@pytest.fixture
def capture_calls() -> list[list[str]]:
    """Every argv passed to a faked run_capture, in call order."""
    return []


@pytest.fixture
def fake_run_capture(capture_calls):
    """Factory returning a run_capture-compatible async callable.

    `script` maps an argv prefix to (stdout_text, stderr_text, returncode);
    an argv not matching any prefix gets ("", "", 0).
    """

    def make(script: dict[tuple[str, ...], tuple[str, str, int]] | None = None):
        script = script or {}

        async def fake(argv: Sequence[str], *, cwd=None, env=None) -> CommandResult:
            capture_calls.append(list(argv))
            for prefix, (stdout_text, stderr_text, returncode) in script.items():
                if tuple(argv[: len(prefix)]) == prefix:
                    lines = [OutputLine("stdout", t) for t in stdout_text.splitlines()]
                    lines += [OutputLine("stderr", t) for t in stderr_text.splitlines()]
                    return CommandResult(argv=argv, returncode=returncode, lines=lines)
            return CommandResult(argv=argv, returncode=0, lines=[])

        return fake

    return make


@pytest.fixture
def fake_run_piped():
    """Factory returning a run_piped-compatible async generator callable
    that yields canned lines regardless of the argv pair it's given —
    stands in for the real `git diff ... | delta` pipeline, which depends
    on `delta` being installed."""

    def make(lines: list[str] | None = None):
        lines = lines or []

        async def fake(argv1, argv2, *, cwd=None):
            for text in lines:
                yield OutputLine("stdout", text)

        return fake

    return make
