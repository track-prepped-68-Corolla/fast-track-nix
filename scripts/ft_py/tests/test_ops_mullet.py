"""Tests for ft_py.ops.mullet — the imperative-package escape hatch."""

from __future__ import annotations

from pathlib import Path

import pytest

from ft_py.errors import PackageNotFoundError, PackageNotPresentError
from ft_py.ops import mullet as mullet_ops


@pytest.fixture
def mullet_file(tmp_path: Path) -> Path:
    return tmp_path / "mullet.txt"


# --- pure helpers ---


def test_mullet_contains_false_when_file_missing(mullet_file: Path):
    assert mullet_ops.mullet_contains(mullet_file, "ripgrep") is False


def test_mullet_contains_matches_exact_line(mullet_file: Path):
    mullet_file.write_text("ripgrep\nfd\n")
    assert mullet_ops.mullet_contains(mullet_file, "ripgrep") is True
    assert mullet_ops.mullet_contains(mullet_file, "fd") is True
    assert mullet_ops.mullet_contains(mullet_file, "bat") is False


def test_mullet_contains_ignores_surrounding_whitespace(mullet_file: Path):
    mullet_file.write_text("  ripgrep  \n")
    assert mullet_ops.mullet_contains(mullet_file, "ripgrep") is True


def test_mullet_add_line_appends_and_creates_parent_content(mullet_file: Path):
    mullet_file.write_text("fd\n")
    mullet_ops.mullet_add_line(mullet_file, "ripgrep")
    assert mullet_file.read_text() == "fd\nripgrep\n"


def test_mullet_rm_line_removes_only_matching_line(mullet_file: Path):
    mullet_file.write_text("fd\nripgrep\nbat\n")
    mullet_ops.mullet_rm_line(mullet_file, "ripgrep")
    assert mullet_file.read_text() == "fd\nbat\n"


def test_lst_returns_placeholder_when_file_missing(mullet_file: Path):
    assert mullet_ops.lst(mullet_file) == "  (Empty)"


def test_lst_returns_raw_contents_when_file_exists(mullet_file: Path):
    mullet_file.write_text("fd\nripgrep\n")
    assert mullet_ops.lst(mullet_file) == "fd\nripgrep\n"


def test_lst_returns_empty_string_for_existing_but_empty_file(mullet_file: Path):
    mullet_file.write_text("")
    assert mullet_ops.lst(mullet_file) == ""


def test_haircut_truncates_existing_file(mullet_file: Path):
    mullet_file.write_text("fd\nripgrep\n")
    mullet_ops.haircut(mullet_file)
    assert mullet_file.read_text() == ""


def test_haircut_creates_file_if_absent(mullet_file: Path):
    mullet_ops.haircut(mullet_file)
    assert mullet_file.read_text() == ""


# --- search() ---


async def test_search_returns_nix_locate_hits_without_falling_back(monkeypatch):
    async def fake_nix_locate(query, cwd=None):
        return "pkg.out  bin/rg\n"

    async def fake_nix_search_head(query, n, cwd=None):
        raise AssertionError("should not fall back when nix-locate has a hit")

    monkeypatch.setattr(mullet_ops, "_nix_locate", fake_nix_locate)
    monkeypatch.setattr(mullet_ops, "_nix_search_head", fake_nix_search_head)

    lines = [line.text async for line in mullet_ops.search("rg")]
    assert lines[0] == ":: Searching Nix-Index for binary 'rg' ::"
    assert lines[1:] == ["pkg.out  bin/rg"]


async def test_search_falls_back_to_nixpkgs_descriptions_when_no_hit(monkeypatch):
    async def fake_nix_locate(query, cwd=None):
        return ""

    async def fake_nix_search_head(query, n, cwd=None):
        assert n == mullet_ops._SEARCH_FALLBACK_LINES
        return "ripgrep\n  A fast grep"

    monkeypatch.setattr(mullet_ops, "_nix_locate", fake_nix_locate)
    monkeypatch.setattr(mullet_ops, "_nix_search_head", fake_nix_search_head)

    lines = [line.text async for line in mullet_ops.search("rg")]
    assert ":: No exact binary match in Nix-Index. ::" in lines
    assert ":: Searching Nixpkgs descriptions... ::" in lines
    assert "ripgrep" in lines
    assert "  A fast grep" in lines


# --- add() ---


async def test_add_short_circuits_when_already_present(mullet_file: Path, monkeypatch):
    mullet_file.write_text("ripgrep\n")

    async def fail_run_capture(*args, **kwargs):
        raise AssertionError("nix eval should not run when pkg is already present")

    monkeypatch.setattr(mullet_ops, "run_capture", fail_run_capture)

    lines = [line.text async for line in mullet_ops.add("ripgrep", mullet_file)]
    assert lines == [":: 'ripgrep' is already in The Mullet. ::"]
    assert mullet_file.read_text() == "ripgrep\n"


async def test_add_appends_pkg_when_eval_succeeds(mullet_file, fake_run_capture, monkeypatch):
    monkeypatch.setattr(
        mullet_ops,
        "run_capture",
        fake_run_capture({("nix", "eval"): ("/nix/store/...-ripgrep", "", 0)}),
    )

    lines = [line.text async for line in mullet_ops.add("ripgrep", mullet_file)]
    assert lines[-1] == ":: Added ripgrep. Run 'ft switch' to apply. ::"
    assert mullet_ops.mullet_contains(mullet_file, "ripgrep")


async def test_add_raises_package_not_found_and_streams_suggestions(
    mullet_file: Path, monkeypatch
):
    async def fake_run_capture(argv, *, cwd=None, env=None):
        from ft_py.proc import CommandResult

        return CommandResult(argv=argv, returncode=1, lines=[])

    async def fake_nix_locate(query, cwd=None):
        return "suggestion-one"

    async def fake_nix_search_head(query, n, cwd=None):
        assert n == mullet_ops._ADD_FALLBACK_LINES
        return "suggestion-two"

    monkeypatch.setattr(mullet_ops, "run_capture", fake_run_capture)
    monkeypatch.setattr(mullet_ops, "_nix_locate", fake_nix_locate)
    monkeypatch.setattr(mullet_ops, "_nix_search_head", fake_nix_search_head)

    collected = []
    with pytest.raises(PackageNotFoundError) as excinfo:
        async for line in mullet_ops.add("not-a-pkg", mullet_file):
            collected.append(line.text)

    assert excinfo.value.pkg == "not-a-pkg"
    assert ":: Error: 'not-a-pkg' is not a valid package path. ::" in collected
    assert "suggestion-one" in collected
    assert "suggestion-two" in collected
    assert not mullet_ops.mullet_contains(mullet_file, "not-a-pkg")


# --- rm() ---


async def test_rm_raises_when_pkg_not_present(mullet_file: Path):
    mullet_file.write_text("fd\n")
    with pytest.raises(PackageNotPresentError) as excinfo:
        async for _ in mullet_ops.rm("ripgrep", mullet_file):
            pass
    assert excinfo.value.pkg == "ripgrep"
    assert mullet_file.read_text() == "fd\n"


async def test_rm_removes_pkg_and_yields_confirmation(mullet_file: Path):
    mullet_file.write_text("fd\nripgrep\n")
    lines = [line.text async for line in mullet_ops.rm("ripgrep", mullet_file)]
    assert lines == [":: Removed ripgrep. Run 'ft switch' to apply. ::"]
    assert mullet_file.read_text() == "fd\n"
