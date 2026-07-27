#!/usr/bin/env python3
"""Render ft.* nixosOptionsDoc optionsJSON into a grouped Markdown README.

Reads nixosOptionsDoc's options.json (already filtered to the "ft" subtree by
the caller) and emits Markdown grouped by feature (the first path segment
under "ft"), with a table of contents and a one-line feature summary sourced
from that feature's `enable` option description.

Usage: render-module-docs.py <options.json> <declarations-root-marker>
  <declarations-root-marker> is the single path segment nixosOptionsDoc's
  "declarations" entries carry right after the store hash (e.g. "source"),
  used to strip /nix/store/<hash>-<marker>/ down to a repo-relative path.
"""

import json
import re
import sys

DECL_RE = re.compile(r"^/nix/store/[0-9a-z]{32}-[^/]+/(.*)$")


def anchor(heading: str) -> str:
    # Mirrors GitHub's heading-to-anchor algorithm closely enough for our
    # headings (ASCII, dots, no duplicates): lowercase, drop anything that
    # isn't alnum/space/hyphen/underscore, then turn spaces into hyphens.
    slug = heading.lower()
    slug = re.sub(r"[^a-z0-9 _-]", "", slug)
    return slug.replace(" ", "-")


def fmt_literal(value) -> str:
    if value is None:
        return "*(none)*"
    if isinstance(value, dict):
        text = value.get("text")
        if text is not None:
            return f"`{text}`"
        return f"`{value}`"
    return f"`{value}`"


def declared_by(declarations, readme_root) -> str:
    lines = []
    for decl in declarations or []:
        m = DECL_RE.match(decl)
        rel = m.group(1) if m else decl
        # rel is repo-root-relative (e.g. "modules/nixos/services/foo.nix");
        # the link target must be relative to the README's own directory.
        prefix = readme_root.rstrip("/") + "/"
        link = rel[len(prefix):] if rel.startswith(prefix) else rel
        lines.append(f"- [{rel}]({link})")
    return "\n".join(lines) if lines else "*(none)*"


def main() -> None:
    options_json_path, readme_root = sys.argv[1], sys.argv[2]
    with open(options_json_path, encoding="utf-8") as f:
        raw = json.load(f)

    entries = []
    for name, opt in raw.items():
        loc = opt.get("loc") or name.split(".")
        if not loc or loc[0] != "ft":
            continue
        entries.append(
            {
                "name": name,
                "loc": loc,
                "description": (opt.get("description") or "").strip(),
                "type": opt.get("type", ""),
                "default": opt.get("default"),
                "example": opt.get("example"),
                "declarations": opt.get("declarations", []),
                "readOnly": opt.get("readOnly", False),
            }
        )
    entries.sort(key=lambda e: e["name"])

    groups: dict[str, list] = {}
    for e in entries:
        feature = e["loc"][1] if len(e["loc"]) > 1 else e["name"]
        groups.setdefault(feature, []).append(e)

    out = []
    out.append("# Module Options\n")
    out.append("## Table of Contents\n")
    for feature in sorted(groups):
        members = groups[feature]
        summary = feature_summary(feature, members)
        heading = f"ft.{feature}"
        out.append(f"- [{heading}](#{anchor(heading)})" + (f" — {summary}" if summary else ""))
    out.append("")
    out.append("---\n")

    for feature in sorted(groups):
        members = groups[feature]
        heading = f"ft.{feature}"
        summary = feature_summary(feature, members)
        out.append(f"## {heading}\n")
        if summary:
            out.append(f"{summary}\n")

        # A bare top-level option (e.g. ft.repoPath, loc == ["ft", "repoPath"])
        # is its own single member with nothing to sub-group; render its
        # detail directly under the feature heading instead of a redundant
        # identical "###" subsection.
        is_bare = len(members) == 1 and members[0]["loc"] == ["ft", feature]

        for e in members:
            if not is_bare:
                out.append(f"### {e['name']}\n")
                if e["description"]:
                    out.append(f"{e['description']}\n")
            render_detail(out, e, readme_root)

    sys.stdout.write("\n".join(out) + "\n")


def feature_summary(feature: str, members: list) -> str:
    for e in members:
        if e["loc"] == ["ft", feature, "enable"]:
            return first_line(e["description"])
    if len(members) == 1 and members[0]["loc"] == ["ft", feature]:
        return first_line(members[0]["description"])
    return ""


def first_line(text: str) -> str:
    return text.strip().splitlines()[0] if text.strip() else ""


def render_detail(out: list, e: dict, readme_root: str) -> None:
    out.append("*Type:*")
    out.append(f"{e['type']}\n")
    if e["default"] is not None:
        out.append("*Default:*")
        out.append(f"{fmt_literal(e['default'])}\n")
    if e["example"] is not None:
        out.append("*Example:*")
        out.append(f"{fmt_literal(e['example'])}\n")
    out.append("*Declared by:*")
    out.append(f"{declared_by(e['declarations'], readme_root)}\n")


if __name__ == "__main__":
    main()
