"""Tests for the Typer CLI layer: prompts, confirmations, error formatting.

The ops layer is fully faked here — these tests verify cli.py's own
responsibilities (env resolution, confirm/prompt flow, exit codes, print
fidelity), not ops behaviour, which test_ops_sys.py / test_ops_mullet.py
already cover.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from typer.testing import CliRunner

from ft_py import errors
from ft_py.cli import app
from ft_py.ops import mullet as mullet_ops
from ft_py.ops import sys as sys_ops
from ft_py.proc import OutputLine

runner = CliRunner()


@pytest.fixture(autouse=True)
def _env(tmp_path: Path, monkeypatch):
    monkeypatch.setenv("FT_REPO", str(tmp_path))
    monkeypatch.setenv("USER", "tester")
    return tmp_path


async def _lines(*texts: str):
    for text in texts:
        yield OutputLine("stdout", text)


# --- fmt ---


def test_fmt_streams_ops_output(monkeypatch):
    monkeypatch.setattr(sys_ops, "fmt", lambda repo_path: _lines(":: Formatting ::"))
    result = runner.invoke(app, ["fmt"])
    assert result.exit_code == 0
    assert ":: Formatting ::" in result.output


# --- switch ---


def test_switch_cancelled_on_declined_confirmation(monkeypatch):
    monkeypatch.setattr(sys_ops, "switch_preview", lambda repo_path: _lines(":: Previewing Build ::"))
    result = runner.invoke(app, ["switch"], input="n\n")
    assert result.exit_code == 1
    assert "Cancelled." in result.output


def test_switch_missing_requirements_fails_before_prompting(monkeypatch):
    async def preview(repo_path):
        raise errors.MissingRequirementsError(["nh"])
        yield  # pragma: no cover

    monkeypatch.setattr(sys_ops, "switch_preview", preview)
    result = runner.invoke(app, ["switch"], input="y\n")
    assert result.exit_code == 1
    assert "Error: nh is not installed." in result.output


def test_switch_applies_and_reports_new_generation(monkeypatch):
    monkeypatch.setattr(sys_ops, "switch_preview", lambda repo_path: _lines(":: Previewing Build ::"))

    async def apply(repo_path, commit_message):
        assert commit_message == "my commit"
        yield OutputLine("stdout", ":: applying ::")
        yield sys_ops.SwitchResult(
            old_generation=1, new_generation=2, nvd_diff="", committed=True
        )

    monkeypatch.setattr(sys_ops, "switch_apply", apply)
    result = runner.invoke(app, ["switch"], input="y\nmy commit\n")
    assert result.exit_code == 0
    assert ":: Update Complete! Now running Generation 2 ::" in result.output


def test_switch_apply_command_failed_exits_with_returncode(monkeypatch):
    monkeypatch.setattr(sys_ops, "switch_preview", lambda repo_path: _lines())

    async def apply(repo_path, commit_message):
        raise errors.CommandFailedError(["nh", "os", "switch"], 5)
        yield  # pragma: no cover

    monkeypatch.setattr(sys_ops, "switch_apply", apply)
    result = runner.invoke(app, ["switch"], input="y\nmy commit\n")
    assert result.exit_code == 5


# --- home-switch ---


def test_home_switch_passes_positional_args_through(monkeypatch):
    captured = {}

    def fake_home_switch(repo_path, user=None, arch=None):
        captured["user"] = user
        captured["arch"] = arch
        return _lines(":: ok ::")

    monkeypatch.setattr(sys_ops, "home_switch", fake_home_switch)
    result = runner.invoke(app, ["home-switch", "alice", "x86_64-linux"])
    assert result.exit_code == 0
    assert captured == {"user": "alice", "arch": "x86_64-linux"}


# --- push / sync ---


def test_push_uncommitted_changes_fails(monkeypatch):
    async def push(repo_path):
        raise errors.UncommittedChangesError("Uncommitted changes. Run 'ft switch' first.")
        yield  # pragma: no cover

    monkeypatch.setattr(sys_ops, "push", push)
    result = runner.invoke(app, ["push"])
    assert result.exit_code == 1
    assert "Uncommitted changes" in result.output


def test_push_streams_on_clean_tree(monkeypatch):
    monkeypatch.setattr(sys_ops, "push", lambda repo_path: _lines(":: Pushing to Remote ::"))
    result = runner.invoke(app, ["push"])
    assert result.exit_code == 0
    assert ":: Pushing to Remote ::" in result.output


# --- rollback ---


def test_rollback_command_failed_exits_with_returncode(monkeypatch):
    async def rollback(repo_path):
        raise errors.CommandFailedError(["sudo", "nix-env"], 9)
        yield  # pragma: no cover

    monkeypatch.setattr(sys_ops, "rollback", rollback)
    result = runner.invoke(app, ["rollback"])
    assert result.exit_code == 9


# --- search / add / rm ---


def test_search_streams_results(monkeypatch):
    monkeypatch.setattr(mullet_ops, "search", lambda query, cwd=None: _lines("bin/rg"))
    result = runner.invoke(app, ["search", "rg"])
    assert result.exit_code == 0
    assert "bin/rg" in result.output


def test_add_success(monkeypatch):
    monkeypatch.setattr(
        mullet_ops,
        "add",
        lambda pkg, mullet_file, cwd=None: _lines(f":: Added {pkg}. Run 'ft switch' to apply. ::"),
    )
    result = runner.invoke(app, ["add", "ripgrep"])
    assert result.exit_code == 0
    assert "Added ripgrep" in result.output


def test_add_package_not_found_exits_nonzero(monkeypatch):
    async def add(pkg, mullet_file, cwd=None):
        yield OutputLine("stdout", ":: Error: not a valid package path. ::")
        raise errors.PackageNotFoundError(pkg)

    monkeypatch.setattr(mullet_ops, "add", add)
    result = runner.invoke(app, ["add", "not-a-pkg"])
    assert result.exit_code == 1


def test_rm_not_present_fails(monkeypatch):
    async def rm(pkg, mullet_file):
        raise errors.PackageNotPresentError(pkg)
        yield  # pragma: no cover

    monkeypatch.setattr(mullet_ops, "rm", rm)
    result = runner.invoke(app, ["rm", "ripgrep"])
    assert result.exit_code == 1
    assert "not found in The Mullet" in result.output


def test_rm_success(monkeypatch):
    monkeypatch.setattr(
        mullet_ops,
        "rm",
        lambda pkg, mullet_file: _lines(f":: Removed {pkg}. Run 'ft switch' to apply. ::"),
    )
    result = runner.invoke(app, ["rm", "ripgrep"])
    assert result.exit_code == 0
    assert "Removed ripgrep" in result.output


# --- lst: print-fidelity around trailing newlines / emptiness ---


def test_lst_prints_only_header_when_file_truly_empty(monkeypatch):
    monkeypatch.setattr(mullet_ops, "lst", lambda mullet_file: "")
    result = runner.invoke(app, ["lst"])
    assert result.exit_code == 0
    assert result.output == ":: Imperative Packages (The Mullet) ::\n"


def test_lst_prints_placeholder_when_file_missing(monkeypatch):
    monkeypatch.setattr(mullet_ops, "lst", lambda mullet_file: "  (Empty)")
    result = runner.invoke(app, ["lst"])
    assert result.output == ":: Imperative Packages (The Mullet) ::\n  (Empty)\n"


def test_lst_does_not_double_newline_content_already_ending_in_newline(monkeypatch):
    monkeypatch.setattr(mullet_ops, "lst", lambda mullet_file: "fd\nripgrep\n")
    result = runner.invoke(app, ["lst"])
    assert result.output == ":: Imperative Packages (The Mullet) ::\nfd\nripgrep\n"


def test_lst_adds_newline_when_content_lacks_trailing_newline(monkeypatch):
    monkeypatch.setattr(mullet_ops, "lst", lambda mullet_file: "fd\nripgrep")
    result = runner.invoke(app, ["lst"])
    assert result.output == ":: Imperative Packages (The Mullet) ::\nfd\nripgrep\n"


# --- haircut ---


def test_haircut_cancelled_does_not_call_ops(monkeypatch):
    called = False

    def fake_haircut(mullet_file):
        nonlocal called
        called = True

    monkeypatch.setattr(mullet_ops, "haircut", fake_haircut)
    result = runner.invoke(app, ["haircut"], input="n\n")
    assert "Cancelled." in result.output
    assert called is False


def test_haircut_confirmed_calls_ops_and_prints_completion(monkeypatch):
    called = False

    def fake_haircut(mullet_file):
        nonlocal called
        called = True

    monkeypatch.setattr(mullet_ops, "haircut", fake_haircut)
    result = runner.invoke(app, ["haircut"], input="y\n")
    assert called is True
    assert "Haircut complete." in result.output
