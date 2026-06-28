"""Integration tests for proc.py against real (trivial) subprocesses.

These exercise the actual asyncio.create_subprocess_exec plumbing rather
than a fake, since proc.py is the one module where that plumbing itself is
the thing worth verifying (line splitting, stream tagging, returncode
propagation, piping).
"""

from __future__ import annotations

from ft_py.proc import StreamedCommand, run_capture, run_piped


async def test_run_capture_collects_stdout_and_stderr_on_separate_streams():
    result = await run_capture(
        [
            "python3",
            "-c",
            "import sys; print('out1'); print('out2'); sys.stderr.write('err1\\n')",
        ]
    )
    assert result.ok
    assert result.returncode == 0
    assert result.stdout == "out1\nout2"
    assert result.stderr == "err1"


async def test_run_capture_reports_nonzero_exit():
    result = await run_capture(["python3", "-c", "import sys; sys.exit(3)"])
    assert not result.ok
    assert result.returncode == 3


async def test_streamed_command_yields_combined_stdout_and_stderr_in_order():
    cmd = StreamedCommand(
        ["python3", "-c", "import sys; print('a'); sys.stderr.write('b\\n'); print('c')"]
    )
    lines = [line.text async for line in cmd]
    assert lines == ["a", "b", "c"]
    assert cmd.returncode == 0


async def test_streamed_command_returncode_reflects_failure():
    cmd = StreamedCommand(["python3", "-c", "import sys; sys.exit(7)"])
    async for _ in cmd:
        pass
    assert cmd.returncode == 7


async def test_streamed_command_returncode_is_none_before_iteration():
    cmd = StreamedCommand(["python3", "-c", "pass"])
    assert cmd.returncode is None


async def test_run_piped_feeds_first_commands_stdout_into_second():
    lines = [
        line.text
        async for line in run_piped(
            ["python3", "-c", "print('x'); print('y')"],
            [
                "python3",
                "-c",
                "import sys\nfor l in sys.stdin:\n    print(l.strip().upper())",
            ],
        )
    ]
    assert lines == ["X", "Y"]
