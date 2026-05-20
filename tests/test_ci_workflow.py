"""
Tests for .github/workflows/ci.yml

Validates structural changes introduced in this PR:
- DeterminateSystems/nix-installer-action@v14 replaces cachix/install-nix-action
- DeterminateSystems/magic-nix-cache-action@v8 added for GitHub-native caching
- Auto-format step uses `nix fmt` instead of manual nixfmt+deadnix shell commands
- format/lint comment added to nix flake check step
"""

import re
import unittest
from pathlib import Path

CI_WORKFLOW_PATH = Path(__file__).parent.parent / ".github" / "workflows" / "ci.yml"


def _read_workflow() -> str:
    return CI_WORKFLOW_PATH.read_text(encoding="utf-8")


class TestCIWorkflowExists(unittest.TestCase):
    def test_file_exists(self):
        self.assertTrue(CI_WORKFLOW_PATH.exists(), "ci.yml must exist")

    def test_file_is_not_empty(self):
        self.assertGreater(CI_WORKFLOW_PATH.stat().st_size, 0, "ci.yml must not be empty")


class TestNixInstallerAction(unittest.TestCase):
    """DeterminateSystems/nix-installer-action@v14 replaces cachix/install-nix-action."""

    def setUp(self):
        self.content = _read_workflow()

    def test_determinate_nix_installer_action_present(self):
        self.assertIn(
            "DeterminateSystems/nix-installer-action@v14",
            self.content,
            "nix-installer-action@v14 must be present",
        )

    def test_cachix_install_nix_action_removed(self):
        self.assertNotIn(
            "cachix/install-nix-action",
            self.content,
            "cachix/install-nix-action must be removed (replaced by DeterminateSystems)",
        )

    def test_no_extra_nix_config_block(self):
        # The old cachix action used extra_nix_config with experimental-features;
        # this block should no longer exist.
        self.assertNotIn(
            "extra_nix_config",
            self.content,
            "extra_nix_config key must be absent after removing cachix action",
        )

    def test_no_experimental_features_config(self):
        self.assertNotIn(
            "experimental-features = nix-command flakes",
            self.content,
            "experimental-features config must be absent after removing cachix action",
        )

    def test_nix_installer_action_used_as_step(self):
        # Confirm it appears as a `uses:` directive, not just a comment.
        self.assertRegex(
            self.content,
            r"uses:\s+DeterminateSystems/nix-installer-action@v14",
            "nix-installer-action must appear as a 'uses:' step",
        )


class TestMagicNixCacheAction(unittest.TestCase):
    """DeterminateSystems/magic-nix-cache-action@v8 is a new step in this PR."""

    def setUp(self):
        self.content = _read_workflow()

    def test_magic_nix_cache_action_present(self):
        self.assertIn(
            "DeterminateSystems/magic-nix-cache-action@v8",
            self.content,
            "magic-nix-cache-action@v8 must be present",
        )

    def test_magic_nix_cache_action_used_as_step(self):
        self.assertRegex(
            self.content,
            r"uses:\s+DeterminateSystems/magic-nix-cache-action@v8",
            "magic-nix-cache-action must appear as a 'uses:' step",
        )

    def test_magic_nix_cache_comes_after_nix_installer(self):
        installer_pos = self.content.find("DeterminateSystems/nix-installer-action@v14")
        cache_pos = self.content.find("DeterminateSystems/magic-nix-cache-action@v8")
        self.assertGreater(
            cache_pos,
            installer_pos,
            "magic-nix-cache-action must come after nix-installer-action",
        )

    def test_no_cachix_token_required(self):
        # The new GitHub-native cache needs no Cachix token secret.
        self.assertNotIn(
            "CACHIX_AUTH_TOKEN",
            self.content,
            "CACHIX_AUTH_TOKEN must not be present (not needed with magic-nix-cache)",
        )


class TestAutoFormatStep(unittest.TestCase):
    """Auto-format step now uses `nix fmt` instead of a manual nixfmt+deadnix shell invocation."""

    def setUp(self):
        self.content = _read_workflow()

    def test_nix_fmt_command_present(self):
        self.assertIn(
            "nix fmt",
            self.content,
            "Auto-format step must invoke `nix fmt`",
        )

    def test_old_manual_nixfmt_command_removed(self):
        # Old: xargs -r nixfmt
        self.assertNotIn(
            "xargs -r nixfmt",
            self.content,
            "Manual `xargs -r nixfmt` invocation must be removed",
        )

    def test_old_manual_deadnix_command_removed(self):
        # Old: xargs -r deadnix --edit
        self.assertNotIn(
            "xargs -r deadnix",
            self.content,
            "Manual `xargs -r deadnix` invocation must be removed",
        )

    def test_old_nix_shell_with_nixfmt_deadnix_removed(self):
        # Old: nix shell .#nixfmt .#deadnix --command sh -c '...'
        self.assertNotIn(
            "nix shell .#nixfmt .#deadnix",
            self.content,
            "Old `nix shell .#nixfmt .#deadnix` invocation must be removed",
        )

    def test_auto_format_step_name_updated(self):
        self.assertIn(
            "Auto-format (treefmt)",
            self.content,
            "Step name must be 'Auto-format (treefmt)'",
        )

    def test_old_auto_format_step_name_removed(self):
        self.assertNotIn(
            "Auto-format (nixfmt + deadnix)",
            self.content,
            "Old step name 'Auto-format (nixfmt + deadnix)' must be removed",
        )

    def test_auto_format_commits_on_diff(self):
        # The conditional commit logic must still be present.
        self.assertIn(
            "git diff --quiet",
            self.content,
            "Conditional commit check `git diff --quiet` must be present",
        )

    def test_auto_format_commit_message(self):
        self.assertIn(
            'git commit -am "style: auto-format"',
            self.content,
            "Auto-commit with message 'style: auto-format' must be present",
        )

    def test_bot_email_configured(self):
        self.assertIn(
            "github-actions[bot]@users.noreply.github.com",
            self.content,
            "Bot email must be configured for git commits",
        )

    def test_bot_name_configured(self):
        self.assertIn(
            "github-actions[bot]",
            self.content,
            "Bot username must be configured for git commits",
        )


class TestNixFlakeCheckStep(unittest.TestCase):
    """nix flake check step retains -L flag and gains a format/lint comment."""

    def setUp(self):
        self.content = _read_workflow()

    def test_nix_flake_check_command_present(self):
        self.assertIn(
            "nix flake check -L",
            self.content,
            "nix flake check -L must be present",
        )

    def test_format_lint_comment_present(self):
        # New comment added in this PR: format: nixfmt + deadnix diff    lint: statix
        self.assertIn(
            "format: nixfmt + deadnix diff",
            self.content,
            "format/lint comment must document what the checks run",
        )

    def test_lint_statix_comment_present(self):
        self.assertIn(
            "lint: statix",
            self.content,
            "Comment must mention statix as the lint tool",
        )


class TestWorkflowStructure(unittest.TestCase):
    """Sanity-check the overall workflow structure is intact after changes."""

    def setUp(self):
        self.content = _read_workflow()

    def test_workflow_has_name(self):
        self.assertRegex(self.content, r"^name:\s+CI", "Workflow must have name: CI")

    def test_workflow_triggers_on_push(self):
        self.assertIn("push:", self.content)

    def test_workflow_triggers_on_pull_request(self):
        self.assertIn("pull_request:", self.content)

    def test_workflow_targets_testing_branch(self):
        self.assertIn("testing", self.content, "Workflow must target the testing branch")

    def test_workflow_targets_main_branch(self):
        self.assertIn("main", self.content, "Workflow must target the main branch")

    def test_checkout_step_present(self):
        self.assertIn("actions/checkout@v4", self.content, "Checkout step must be present")

    def test_checkout_full_history(self):
        self.assertIn("fetch-depth: 0", self.content, "Full git history fetch must be configured")

    def test_resolve_flake_inputs_step_present(self):
        self.assertIn("nix flake lock", self.content, "Resolve flake inputs step must be present")

    def test_secret_scan_step_present(self):
        self.assertIn("trufflehog", self.content, "Secret scan step must be present")

    def test_contents_write_permission(self):
        # Needed for auto-format commits
        self.assertIn("contents: write", self.content, "contents: write permission must be set")

    def test_github_token_used(self):
        self.assertIn("secrets.GITHUB_TOKEN", self.content, "GITHUB_TOKEN must be referenced")

    def test_step_ordering_installer_before_lock(self):
        installer_pos = self.content.find("DeterminateSystems/nix-installer-action@v14")
        lock_pos = self.content.find("nix flake lock")
        self.assertGreater(
            lock_pos,
            installer_pos,
            "nix flake lock must come after nix installer",
        )

    def test_step_ordering_lock_before_format(self):
        lock_pos = self.content.find("nix flake lock")
        fmt_pos = self.content.find("nix fmt")
        self.assertGreater(
            fmt_pos,
            lock_pos,
            "nix fmt must come after nix flake lock",
        )

    def test_step_ordering_format_before_check(self):
        fmt_pos = self.content.find("nix fmt")
        # Search for the `run:` line to avoid matching comment references
        # to "nix flake check" that appear in the auto-format step's comment block.
        check_pos = self.content.find("run: nix flake check")
        self.assertGreater(
            check_pos,
            fmt_pos,
            "nix flake check run step must come after nix fmt",
        )

    def test_no_flake_lock_committed(self):
        # The workflow comment says the lock is materialised but not committed.
        self.assertIn(
            "without committing it",
            self.content,
            "Comment must clarify flake.lock is not committed",
        )

    def test_no_push_after_format_commit(self):
        # The auto-format commit is local-only — no git push should follow it.
        # Verify no unconditional push command is present in the format step.
        # We look for `git push` anywhere in the file as a regression guard.
        self.assertNotIn(
            "git push",
            self.content,
            "git push must not appear — format commits are local-only",
        )


if __name__ == "__main__":
    unittest.main()