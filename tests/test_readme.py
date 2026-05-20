"""
Tests for README.md

Validates the documentation added in this PR. The README went from a single
placeholder line to a comprehensive 174-line reference document covering:
- Project overview
- Consumer flake.nix wiring
- Repo layout
- Feature enabling
- Available NixOS and Home Manager modules
- Machine provisioning
- Development commands
- Branch workflow
"""

import re
import unittest
from pathlib import Path

README_PATH = Path(__file__).parent.parent / "README.md"


def _read_readme() -> str:
    return README_PATH.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _extract_sections(content: str) -> list[str]:
    """Return all level-2 (##) heading names in document order."""
    return re.findall(r"^##\s+(.+)$", content, re.MULTILINE)


def _fenced_code_blocks(content: str) -> list[tuple[str, str]]:
    """Return list of (language, body) for each fenced code block."""
    pattern = re.compile(r"```(\w*)\n(.*?)```", re.DOTALL)
    return pattern.findall(content)


# ---------------------------------------------------------------------------
# Basic presence and size
# ---------------------------------------------------------------------------

class TestReadmeExists(unittest.TestCase):
    def test_file_exists(self):
        self.assertTrue(README_PATH.exists(), "README.md must exist")

    def test_file_is_not_placeholder(self):
        content = _read_readme()
        # Old content was a single line; new content is substantial.
        self.assertGreater(
            len(content.splitlines()),
            50,
            "README must contain more than 50 lines (was replaced with full docs)",
        )

    def test_old_placeholder_line_upgraded(self):
        content = _read_readme()
        # Original single-line placeholder is now a bold tagline inside the doc,
        # not the only content.
        self.assertGreater(
            len(content),
            500,
            "README must be a full document, not the single placeholder line",
        )


# ---------------------------------------------------------------------------
# Title and tagline
# ---------------------------------------------------------------------------

class TestReadmeTitleAndTagline(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_h1_title_ft_home(self):
        self.assertRegex(
            self.content,
            r"^# ft-home",
            "README must start with '# ft-home' as H1 title",
        )

    def test_tagline_present(self):
        self.assertIn(
            "Building the onramp I wish I had",
            self.content,
            "Tagline must be preserved in the new README",
        )

    def test_tagline_is_bold(self):
        self.assertIn(
            "**Building the onramp I wish I had.**",
            self.content,
            "Tagline must be bold",
        )

    def test_project_description_present(self):
        self.assertIn(
            "NixOS + Home Manager framework flake",
            self.content,
            "Project description must mention NixOS + Home Manager framework flake",
        )


# ---------------------------------------------------------------------------
# Required top-level sections
# ---------------------------------------------------------------------------

REQUIRED_SECTIONS = [
    "How it works",
    "Consumer repo layout",
    "Enabling features",
    "Available modules",
    "Provisioning a new machine",
    "Development",
    "Branch workflow",
]


class TestReadmeSections(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()
        self.sections = _extract_sections(self.content)

    def test_all_required_sections_present(self):
        for section in REQUIRED_SECTIONS:
            with self.subTest(section=section):
                self.assertIn(
                    section,
                    self.sections,
                    f"Section '## {section}' must be present in README",
                )

    def test_section_count(self):
        self.assertGreaterEqual(
            len(self.sections),
            len(REQUIRED_SECTIONS),
            "README must have at least as many sections as required",
        )


# ---------------------------------------------------------------------------
# How it works section
# ---------------------------------------------------------------------------

class TestHowItWorksSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_consumed_not_forked_phrase(self):
        self.assertIn(
            "consumed, not forked",
            self.content,
            "How it works must state ft-home is consumed, not forked",
        )

    def test_lib_mkflake_documented(self):
        self.assertIn(
            "lib.mkFlake",
            self.content,
            "lib.mkFlake must be documented",
        )

    def test_flake_nix_code_block_present(self):
        blocks = _fenced_code_blocks(self.content)
        nix_blocks = [body for lang, body in blocks if lang == "nix"]
        self.assertTrue(
            any("lib.mkFlake" in b for b in nix_blocks),
            "A nix code block containing lib.mkFlake must be present",
        )

    def test_github_url_in_code_block(self):
        self.assertIn(
            "github:track-prepped-68-corolla/ft-home",
            self.content,
            "Consumer flake must reference the ft-home GitHub URL",
        )

    def test_inputs_nixpkgs_follows(self):
        self.assertIn(
            "ft-home.inputs.nixpkgs.follows",
            self.content,
            "Consumer wiring must show how to follow nixpkgs",
        )

    def test_outputs_table_nixos_configurations(self):
        self.assertIn(
            "nixosConfigurations.<name>",
            self.content,
            "Outputs table must document nixosConfigurations",
        )

    def test_outputs_table_darwin_configurations(self):
        self.assertIn(
            "darwinConfigurations.<name>",
            self.content,
            "Outputs table must document darwinConfigurations",
        )

    def test_outputs_table_home_configurations(self):
        self.assertIn(
            "homeConfigurations.<user>@<arch>",
            self.content,
            "Outputs table must document homeConfigurations",
        )


# ---------------------------------------------------------------------------
# Consumer repo layout section
# ---------------------------------------------------------------------------

class TestConsumerRepoLayoutSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_machines_directory_documented(self):
        self.assertIn("machines/", self.content)

    def test_users_directory_documented(self):
        self.assertIn("users/", self.content)

    def test_var_directory_documented(self):
        self.assertIn("var/", self.content)

    def test_facter_json_documented(self):
        self.assertIn(
            "facter.json",
            self.content,
            "facter.json must be mentioned in the layout",
        )

    def test_default_arch_fallback_documented(self):
        self.assertIn(
            "x86_64-linux",
            self.content,
            "Default architecture fallback must be documented",
        )

    def test_facter_system_key_documented(self):
        self.assertIn(
            "facter.system",
            self.content,
            "facter.system JSON key must be documented",
        )

    def test_secrets_yaml_documented(self):
        self.assertIn(
            "secrets.yaml",
            self.content,
            "secrets.yaml must be documented in layout",
        )


# ---------------------------------------------------------------------------
# Enabling features section
# ---------------------------------------------------------------------------

class TestEnablingFeaturesSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_ft_options_pattern_introduced(self):
        self.assertIn(
            "ft.*",
            self.content,
            "ft.* option pattern must be introduced",
        )

    def test_nothing_on_by_default_note(self):
        self.assertIn(
            "Nothing is on by default",
            self.content,
            "Doc must clarify nothing is on by default",
        )

    def test_example_machine_file_code_block(self):
        blocks = _fenced_code_blocks(self.content)
        nix_blocks = [body for lang, body in blocks if lang == "nix"]
        self.assertTrue(
            any("machines/my-desktop/default.nix" in b for b in nix_blocks),
            "Example machine file code block must be present",
        )

    def test_example_user_file_code_block(self):
        blocks = _fenced_code_blocks(self.content)
        nix_blocks = [body for lang, body in blocks if lang == "nix"]
        self.assertTrue(
            any("users/alice/default.nix" in b for b in nix_blocks),
            "Example user file code block must be present",
        )

    def test_example_machine_options_present(self):
        self.assertIn("ft.boot.limine.enable", self.content)
        self.assertIn("ft.desktop.cosmic.enable", self.content)
        self.assertIn("ft.security.sops.enable", self.content)
        self.assertIn("ft.services.tailscale.enable", self.content)

    def test_example_user_options_present(self):
        self.assertIn("ft.terminal.enable", self.content)
        self.assertIn("ft.lazyvim.enable", self.content)
        self.assertIn("ft.dotfiles.enable", self.content)

    def test_home_username_in_user_example(self):
        self.assertIn(
            'home.username = "alice"',
            self.content,
            "User example must set home.username",
        )


# ---------------------------------------------------------------------------
# Available modules section
# ---------------------------------------------------------------------------

REQUIRED_NIXOS_OPTIONS = [
    "ft.users.enable",
    "ft.boot.limine.enable",
    "ft.kernel.cachyos.enable",
    "ft.desktop.cosmic.enable",
    "ft.desktop.plasma.enable",
    "ft.profiles.gaming.enable",
    "ft.security.sops.enable",
    "ft.hardware.yubikey.enable",
    "ft.keepass.enable",
    "ft.services.printing.enable",
    "ft.services.nfs.enable",
    "ft.services.tailscale.enable",
    "ft.programs.nixIndex.enable",
    "ft.cli.enable",
    "ft.system.virt.*",
]

REQUIRED_HOME_MANAGER_OPTIONS = [
    "ft.terminal.enable",
    "ft.lazyvim.enable",
    "ft.dotfiles.enable",
    "ft.home.sops.enable",
    "ft.stylix.enable",
]


class TestAvailableModulesSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_nixos_modules_subsection_present(self):
        self.assertIn("### NixOS modules", self.content)

    def test_home_manager_modules_subsection_present(self):
        self.assertIn("### Home Manager modules", self.content)

    def test_all_nixos_options_documented(self):
        for option in REQUIRED_NIXOS_OPTIONS:
            with self.subTest(option=option):
                self.assertIn(
                    option,
                    self.content,
                    f"NixOS option '{option}' must be documented",
                )

    def test_all_home_manager_options_documented(self):
        for option in REQUIRED_HOME_MANAGER_OPTIONS:
            with self.subTest(option=option):
                self.assertIn(
                    option,
                    self.content,
                    f"Home Manager option '{option}' must be documented",
                )

    def test_nixos_modules_table_has_option_column(self):
        self.assertIn("| Option |", self.content)

    def test_nixos_modules_table_has_description_column(self):
        self.assertIn("| What it does |", self.content)

    def test_cosmic_description_mentions_desktop(self):
        self.assertIn(
            "COSMIC desktop",
            self.content,
            "COSMIC module description must mention desktop environment",
        )

    def test_gaming_profile_mentions_steam(self):
        self.assertIn(
            "Steam",
            self.content,
            "Gaming profile description must mention Steam",
        )

    def test_sops_description_mentions_age(self):
        # sops module uses SSH host key / age key
        self.assertIn(
            "sops",
            self.content.lower(),
            "sops module must be mentioned",
        )

    def test_terminal_module_mentions_kitty(self):
        self.assertIn(
            "Kitty",
            self.content,
            "ft.terminal.enable description must mention Kitty",
        )


# ---------------------------------------------------------------------------
# Provisioning section
# ---------------------------------------------------------------------------

class TestProvisioningSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_nixos_anywhere_mentioned(self):
        self.assertIn(
            "nixos-anywhere",
            self.content,
            "Provisioning section must mention nixos-anywhere",
        )

    def test_disko_mentioned(self):
        self.assertIn("disko", self.content)

    def test_nixos_facter_mentioned(self):
        self.assertIn("nixos-facter", self.content)

    def test_nixos_anywhere_command_in_code_block(self):
        blocks = _fenced_code_blocks(self.content)
        bash_blocks = [body for lang, body in blocks if lang == "bash"]
        self.assertTrue(
            any("nixos-anywhere" in b for b in bash_blocks),
            "nixos-anywhere deploy command must appear in a bash code block",
        )

    def test_facter_json_generation_step_documented(self):
        self.assertIn(
            "nixos-facter",
            self.content,
            "Step to generate facter.json must be documented",
        )

    def test_nixos_live_iso_mentioned(self):
        self.assertIn(
            "NixOS live ISO",
            self.content,
            "Provisioning must reference booting from NixOS live ISO",
        )


# ---------------------------------------------------------------------------
# Development section
# ---------------------------------------------------------------------------

class TestDevelopmentSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_nix_develop_command_documented(self):
        self.assertIn(
            "nix develop",
            self.content,
            "nix develop command must be documented",
        )

    def test_nix_fmt_command_documented(self):
        self.assertIn(
            "nix fmt",
            self.content,
            "nix fmt command must be documented in Development section",
        )

    def test_statix_check_command_documented(self):
        self.assertIn(
            "statix check",
            self.content,
            "statix check command must be documented",
        )

    def test_nix_flake_check_command_documented(self):
        self.assertIn(
            "nix flake check",
            self.content,
            "nix flake check command must be documented",
        )

    def test_ci_runs_nix_flake_check_note(self):
        self.assertIn(
            "CI runs",
            self.content,
            "Development section must note that CI runs checks",
        )

    def test_dev_shell_tools_mentioned(self):
        # nix develop drops into a shell with nixfmt, deadnix, statix
        self.assertIn("nixfmt", self.content)
        self.assertIn("deadnix", self.content)
        self.assertIn("statix", self.content)

    def test_bash_code_block_with_dev_commands(self):
        blocks = _fenced_code_blocks(self.content)
        bash_blocks = [body for lang, body in blocks if lang == "bash"]
        self.assertTrue(
            any("nix develop" in b for b in bash_blocks),
            "Development bash code block must include nix develop",
        )


# ---------------------------------------------------------------------------
# Branch workflow section
# ---------------------------------------------------------------------------

class TestBranchWorkflowSection(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_feature_testing_main_flow_documented(self):
        # Must show: feature → testing → main
        self.assertIn("feature", self.content)
        self.assertIn("testing", self.content)
        self.assertIn("main", self.content)

    def test_arrow_flow_present(self):
        self.assertIn(
            "feature → testing → main",
            self.content,
            "Branch workflow must show the three-stage arrow flow",
        )

    def test_prs_target_testing(self):
        self.assertIn(
            "All pull requests target",
            self.content,
            "Branch workflow must document that PRs target testing",
        )

    def test_main_requires_ci_on_testing(self):
        self.assertIn(
            "passing CI on `testing`",
            self.content,
            "Branch workflow must state main requires CI to pass on testing",
        )


# ---------------------------------------------------------------------------
# Code block integrity
# ---------------------------------------------------------------------------

class TestCodeBlockIntegrity(unittest.TestCase):
    def setUp(self):
        self.content = _read_readme()

    def test_all_fenced_blocks_closed(self):
        # Every opening ``` must have a closing ```.
        # Count triple-backtick occurrences; must be even.
        fence_count = len(re.findall(r"^```", self.content, re.MULTILINE))
        self.assertEqual(
            fence_count % 2,
            0,
            f"All fenced code blocks must be closed (found {fence_count} fences, expected even count)",
        )

    def test_nix_code_blocks_present(self):
        blocks = _fenced_code_blocks(self.content)
        nix_blocks = [b for lang, b in blocks if lang == "nix"]
        self.assertGreaterEqual(
            len(nix_blocks),
            2,
            "README must have at least 2 nix code blocks (consumer flake + examples)",
        )

    def test_bash_code_blocks_present(self):
        blocks = _fenced_code_blocks(self.content)
        bash_blocks = [b for lang, b in blocks if lang == "bash"]
        self.assertGreaterEqual(
            len(bash_blocks),
            2,
            "README must have at least 2 bash code blocks (nixos-anywhere + dev commands)",
        )

    def test_no_truncated_nix_block(self):
        # All nix blocks must contain balanced braces at minimum.
        blocks = _fenced_code_blocks(self.content)
        for lang, body in blocks:
            if lang == "nix":
                open_braces = body.count("{")
                close_braces = body.count("}")
                self.assertEqual(
                    open_braces,
                    close_braces,
                    f"Nix code block must have balanced braces: {body[:60]!r}",
                )

    def test_horizontal_rules_used_as_section_dividers(self):
        # The new README uses --- as dividers between sections.
        hr_count = len(re.findall(r"^---$", self.content, re.MULTILINE))
        self.assertGreaterEqual(
            hr_count,
            5,
            "README must use at least 5 horizontal rules as section dividers",
        )

    def test_tables_have_header_separator(self):
        # Every markdown table must have a |---|---| separator line.
        table_headers = re.findall(r"^\|.+\|$", self.content, re.MULTILINE)
        separator_lines = re.findall(r"^\|[-| :]+\|$", self.content, re.MULTILINE)
        # There should be at least as many separator lines as distinct tables.
        self.assertGreaterEqual(
            len(separator_lines),
            3,
            "README must contain at least 3 table separator lines (outputs table + 2 module tables)",
        )


if __name__ == "__main__":
    unittest.main()
