"""Tests for ft_py.ops.sys — daily-driver maintenance + core workflow.

Subprocess-backed steps are exercised via the fake_streamed_command /
fake_run_capture fixtures from conftest.py, scripted with the same argv
shapes sys.py actually issues. test_proc.py already covers the real
subprocess plumbing those fakes stand in for.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from ft_py.errors import CommandFailedError, MissingRequirementsError, UncommittedChangesError
from ft_py.ops import sys as sys_ops


@pytest.fixture
def no_missing_requirements(monkeypatch):
    """Pretends nh/nvd/delta are all present on PATH, for tests of the steps
    after that check that don't care about missing_requirements() itself."""
    monkeypatch.setattr(sys_ops, "missing_requirements", lambda: [])


# --- pure helpers ---


def test_generation_number_parses_system_link_name():
    assert sys_ops.generation_number("system-123-link") == 123


def test_last_two_generations_returns_two_newest_by_number(tmp_path: Path):
    for n in (1, 10, 2):
        (tmp_path / f"system-{n}-link").touch()
    result = sys_ops.last_two_generations(tmp_path)
    assert [p.name for p in result] == ["system-2-link", "system-10-link"]


def test_last_two_generations_returns_fewer_than_two_when_absent(tmp_path: Path):
    (tmp_path / "system-1-link").touch()
    assert [p.name for p in sys_ops.last_two_generations(tmp_path)] == ["system-1-link"]
    assert sys_ops.last_two_generations(tmp_path / "nonexistent") == []


def test_find_nix_files_recurses_and_sorts(tmp_path: Path):
    (tmp_path / "a.nix").touch()
    nested = tmp_path / "nested"
    nested.mkdir()
    (nested / "b.nix").touch()
    (tmp_path / "c.txt").touch()
    found = sys_ops.find_nix_files(tmp_path)
    assert found == sorted(found)
    assert {p.name for p in found} == {"a.nix", "b.nix"}


def test_missing_requirements_reports_absent_commands():
    resolver = {"nh": "/bin/nh", "nvd": None, "delta": None}.get
    assert sys_ops.missing_requirements(resolver) == ["nvd", "delta"]


# --- fmt / check / clean ---


async def test_fmt_skips_nixfmt_when_no_nix_files(
    tmp_path, fake_streamed_command, streamed_calls, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())

    lines = [line.text async for line in sys_ops.fmt(tmp_path)]
    assert lines == [":: Formatting ::"]
    assert streamed_calls == []


async def test_fmt_runs_nixfmt_over_every_nix_file(tmp_path, fake_streamed_command, monkeypatch):
    (tmp_path / "a.nix").touch()
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())

    lines = [line.text async for line in sys_ops.fmt(tmp_path)]
    assert lines[0] == ":: Formatting ::"


async def test_check_runs_fmt_then_trufflehog(tmp_path, fake_streamed_command, streamed_calls, monkeypatch):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())

    lines = [line.text async for line in sys_ops.check(tmp_path)]
    assert lines == [":: Formatting ::", ":: Scanning for leaked secrets ::"]
    assert streamed_calls == [
        ["trufflehog", "git", "file://.", "--since-commit", "HEAD", "--fail"]
    ]


async def test_clean_runs_nh_clean_with_keep_five(tmp_path, fake_streamed_command, streamed_calls, monkeypatch):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())

    lines = [line.text async for line in sys_ops.clean(tmp_path)]
    assert lines == [":: Cleaning Nix Store ::"]
    assert streamed_calls == [["nh", "clean", "all", "--keep", "5"]]


# --- test_() ---


async def test_test_raises_when_requirements_missing(tmp_path, fake_streamed_command, monkeypatch):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(sys_ops, "missing_requirements", lambda: ["nh"])

    with pytest.raises(MissingRequirementsError) as excinfo:
        async for _ in sys_ops.test_(tmp_path):
            pass
    assert excinfo.value.missing == ["nh"]


async def test_test_happy_path_streams_every_phase(
    tmp_path, fake_streamed_command, fake_run_piped, monkeypatch, no_missing_requirements
):
    monkeypatch.setattr(
        sys_ops,
        "StreamedCommand",
        fake_streamed_command({("nh", "os", "test"): (["build ok"], 0)}),
    )
    monkeypatch.setattr(sys_ops, "run_piped", fake_run_piped())

    lines = [line.text async for line in sys_ops.test_(tmp_path)]
    assert ":: Staging & Diffs ::" in lines
    assert ":: Running Test ::" in lines
    assert "build ok" in lines
    assert ":: Test complete. Reboot to revert. ::" in lines


async def test_test_raises_command_failed_but_still_prints_completion_line(
    tmp_path, fake_streamed_command, fake_run_piped, monkeypatch, no_missing_requirements
):
    monkeypatch.setattr(
        sys_ops,
        "StreamedCommand",
        fake_streamed_command({("nh", "os", "test"): ([], 1)}),
    )
    monkeypatch.setattr(sys_ops, "run_piped", fake_run_piped())

    collected = []
    with pytest.raises(CommandFailedError):
        async for line in sys_ops.test_(tmp_path):
            collected.append(line.text)
    assert ":: Test complete. Reboot to revert. ::" in collected


# --- switch_preview() ---


async def test_switch_preview_raises_when_requirements_missing(
    tmp_path, fake_streamed_command, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(sys_ops, "missing_requirements", lambda: ["delta"])

    with pytest.raises(MissingRequirementsError):
        async for _ in sys_ops.switch_preview(tmp_path):
            pass


async def test_switch_preview_streams_dry_run_and_diff_headers(
    tmp_path, fake_streamed_command, fake_run_piped, monkeypatch, no_missing_requirements
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(sys_ops, "run_piped", fake_run_piped())

    lines = [line.text async for line in sys_ops.switch_preview(tmp_path)]
    assert ":: Previewing Build ::" in lines
    assert ":: Source Code Changes ::" in lines


# --- switch_apply() ---


async def test_switch_apply_commits_when_staged_changes_present(
    tmp_path, fake_streamed_command, fake_run_capture, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(
        sys_ops,
        "run_capture",
        fake_run_capture(
            {
                ("readlink",): ("system-2-link", "", 0),
                ("git", "diff", "--cached", "--quiet"): ("", "", 1),  # staged changes exist
                ("git", "commit"): ("", "", 0),
            }
        ),
    )
    monkeypatch.setattr(sys_ops, "last_two_generations", lambda: [])

    result = None
    async for item in sys_ops.switch_apply(tmp_path, "my message"):
        if isinstance(item, sys_ops.SwitchResult):
            result = item
    assert result is not None
    assert result.committed is True
    assert result.old_generation == 2
    assert result.new_generation == 2


async def test_switch_apply_skips_commit_when_tree_clean(
    tmp_path, fake_streamed_command, fake_run_capture, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(
        sys_ops,
        "run_capture",
        fake_run_capture(
            {
                ("readlink",): ("system-2-link", "", 0),
                ("git", "diff", "--cached", "--quiet"): ("", "", 0),  # no staged changes
            }
        ),
    )
    monkeypatch.setattr(sys_ops, "last_two_generations", lambda: [])

    lines = []
    result = None
    async for item in sys_ops.switch_apply(tmp_path, None):
        if isinstance(item, sys_ops.SwitchResult):
            result = item
        else:
            lines.append(item.text)
    assert result is not None
    assert result.committed is False
    assert ":: No source changes detected. Skipping git commit. ::" in lines


async def test_switch_apply_cleans_only_when_generation_advanced(
    tmp_path, fake_streamed_command, fake_run_capture, monkeypatch, streamed_calls
):
    gens = iter(["system-1-link", "system-2-link"])

    async def fake_current_generation(cwd=None):
        return sys_ops.generation_number(next(gens))

    monkeypatch.setattr(sys_ops, "current_generation", fake_current_generation)
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(
        sys_ops,
        "run_capture",
        fake_run_capture({("git", "diff", "--cached", "--quiet"): ("", "", 0)}),
    )
    monkeypatch.setattr(sys_ops, "last_two_generations", lambda: [])

    async for _ in sys_ops.switch_apply(tmp_path, None):
        pass

    assert ["nh", "clean", "all", "--keep", "5"] in streamed_calls


async def test_switch_apply_skips_clean_when_generation_unchanged(
    tmp_path, fake_streamed_command, fake_run_capture, monkeypatch, streamed_calls
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(
        sys_ops,
        "run_capture",
        fake_run_capture(
            {
                ("readlink",): ("system-1-link", "", 0),
                ("git", "diff", "--cached", "--quiet"): ("", "", 0),
            }
        ),
    )
    monkeypatch.setattr(sys_ops, "last_two_generations", lambda: [])

    lines = []
    async for item in sys_ops.switch_apply(tmp_path, None):
        if not isinstance(item, sys_ops.SwitchResult):
            lines.append(item.text)

    assert ["nh", "clean", "all", "--keep", "5"] not in streamed_calls
    assert ":: System generation did not change. Skipping cleanup. ::" in lines


async def test_run_switch_raises_command_failed_on_nonzero_exit(
    tmp_path, fake_streamed_command, monkeypatch
):
    monkeypatch.setattr(
        sys_ops, "StreamedCommand", fake_streamed_command({("nh", "os", "switch"): ([], 1)})
    )
    with pytest.raises(CommandFailedError):
        async for _ in sys_ops._run_switch(tmp_path):
            pass


# --- home_switch() ---


async def test_home_switch_uses_explicit_user_and_arch(
    tmp_path, fake_streamed_command, streamed_calls, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    async for _ in sys_ops.home_switch(tmp_path, user="alice", arch="x86_64-linux"):
        pass
    assert streamed_calls == [
        ["home-manager", "switch", "--flake", ".#alice@x86_64-linux"]
    ]


async def test_home_switch_defaults_to_env_user_and_uname_arch(
    tmp_path, fake_streamed_command, streamed_calls, monkeypatch
):
    monkeypatch.setenv("USER", "bob")
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(sys_ops.platform, "machine", lambda: "aarch64")

    async for _ in sys_ops.home_switch(tmp_path):
        pass
    assert streamed_calls == [["home-manager", "switch", "--flake", ".#bob@aarch64-linux"]]


# --- pull() / push() / sync() ---


async def test_pull_streams_every_phase_header(
    tmp_path, fake_streamed_command, fake_run_piped, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(sys_ops, "run_piped", fake_run_piped())
    monkeypatch.setattr(sys_ops, "last_two_generations", lambda: [])

    lines = [line.text async for line in sys_ops.pull(tmp_path)]
    assert lines[0] == ":: Pulling Updates ::"
    assert ":: Incoming Source Changes ::" in lines
    assert ":: Building and Switching ::" in lines
    assert ":: System Package Changes ::" in lines
    assert "(no previous generation to diff)" in lines


async def test_push_raises_when_tree_dirty(tmp_path, fake_run_capture, monkeypatch):
    monkeypatch.setattr(
        sys_ops,
        "run_capture",
        fake_run_capture({("git", "status"): (" M flake.nix\n", "", 0)}),
    )
    with pytest.raises(UncommittedChangesError):
        async for _ in sys_ops.push(tmp_path):
            pass


async def test_push_runs_git_push_when_tree_clean(
    tmp_path, fake_streamed_command, fake_run_capture, streamed_calls, monkeypatch
):
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())
    monkeypatch.setattr(
        sys_ops, "run_capture", fake_run_capture({("git", "status"): ("", "", 0)})
    )
    lines = [line.text async for line in sys_ops.push(tmp_path)]
    assert lines == [":: Pushing to Remote ::"]
    assert streamed_calls == [["git", "push"]]


async def test_sync_runs_pull_then_push_in_order(tmp_path, monkeypatch):
    calls = []

    async def fake_pull(repo_path):
        calls.append("pull")
        return
        yield  # pragma: no cover

    async def fake_push(repo_path):
        calls.append("push")
        return
        yield  # pragma: no cover

    monkeypatch.setattr(sys_ops, "pull", fake_pull)
    monkeypatch.setattr(sys_ops, "push", fake_push)

    async for _ in sys_ops.sync(tmp_path):
        pass
    assert calls == ["pull", "push"]


# --- rollback() ---


async def test_rollback_happy_path_prints_generation_and_completion(
    tmp_path, fake_streamed_command, fake_run_capture, monkeypatch
):
    monkeypatch.setattr(
        sys_ops, "run_capture", fake_run_capture({("readlink",): ("system-9-link", "", 0)})
    )
    monkeypatch.setattr(sys_ops, "StreamedCommand", fake_streamed_command())

    lines = [line.text async for line in sys_ops.rollback(tmp_path)]
    assert ":: Current Generation ::" in lines
    assert "9" in lines
    assert ":: Rollback Complete! ::" in lines


async def test_rollback_raises_command_failed_when_rollback_command_fails(
    tmp_path, fake_streamed_command, fake_run_capture, monkeypatch
):
    monkeypatch.setattr(
        sys_ops, "run_capture", fake_run_capture({("readlink",): ("system-9-link", "", 0)})
    )
    monkeypatch.setattr(
        sys_ops,
        "StreamedCommand",
        fake_streamed_command({("sudo", "nix-env"): ([], 1)}),
    )

    with pytest.raises(CommandFailedError):
        async for _ in sys_ops.rollback(tmp_path):
            pass
