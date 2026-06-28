"""Exceptions raised by ops/ functions.

Ops functions never prompt or print directly on failure — they raise one of
these, and the CLI (or, eventually, the TUI) layer decides how to present it.
"""

from __future__ import annotations


class FtOpsError(Exception):
    """Base class for all ops-layer failures."""


class MissingRequirementsError(FtOpsError):
    """One or more required external commands are not on PATH."""

    def __init__(self, missing: list[str]) -> None:
        self.missing = missing
        super().__init__(f"missing required commands: {', '.join(missing)}")


class CommandFailedError(FtOpsError):
    """A subprocess exited non-zero."""

    def __init__(self, argv: list[str], returncode: int) -> None:
        self.argv = argv
        self.returncode = returncode
        super().__init__(f"command failed ({returncode}): {' '.join(argv)}")


class PackageNotFoundError(FtOpsError):
    """The requested nixpkgs attribute path does not evaluate."""

    def __init__(self, pkg: str) -> None:
        self.pkg = pkg
        super().__init__(f"'{pkg}' is not a valid package path")


class PackageNotPresentError(FtOpsError):
    """The requested package is not in the Mullet file."""

    def __init__(self, pkg: str) -> None:
        self.pkg = pkg
        super().__init__(f"'{pkg}' not found in The Mullet")


class UncommittedChangesError(FtOpsError):
    """git push was attempted with a dirty working tree."""
