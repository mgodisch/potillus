#!/usr/bin/env python3
# vim: set et ts=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
# =============================================================================
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
#
# =============================================================================
# check-swift-length.py -- SwiftLint's length rules, where SwiftLint cannot run.
# =============================================================================
#
# SwiftLint is a macOS binary; the Linux gate (`make check-ios-static`) cannot
# invoke it. Its LENGTH rules, though, are simple line counts, and they are the
# ones a diff trips silently: a type that grows two lines past the limit compiles
# and tests green, and only the Mac's `--strict` SwiftLint pass rejects it — one
# round-trip too late. This checker reproduces those counts in the container so
# the overrun is caught with the other static gates.
#
# WHAT IS AND ISN'T CHECKED
#   Covered: type_body_length, file_length, line_length. These are structural —
#   they decide how a file is split — and are exactly the ones that have bitten.
#   NOT covered: function_body_length, cyclomatic_complexity, nesting and the
#   rest. SwiftLint on the Mac remains the authority for every rule; this is an
#   early-warning subset, not a replacement. It never green-lights a build on its
#   own (it runs beside `check-swiftlint`, not instead of it).
#
# FAITHFULNESS
#   The counts mirror SwiftLint 0.65.0's documented behaviour:
#     - type_body_length: lines strictly between a type's braces, excluding
#       comment-only and blank lines. (SwiftLint's message: "excluding comments
#       and whitespace".) The limit is SwiftLint's DEFAULT, 250 — .swiftlint.yml
#       does not override it, so neither does this. Applies to class/struct/enum/
#       actor, NOT extension (SwiftLint's extension_body_length is not enabled)
#       and NOT protocol.
#     - file_length: total lines minus comment-only lines (the yml sets
#       ignore_comment_only_lines: true). Blank lines count, as in SwiftLint.
#     - line_length: character count per line; comment-only lines and lines
#       containing a URL are exempt (the yml sets ignores_comments/ignores_urls).
#   Limits and the included/excluded roots are read from ios/.swiftlint.yml, so
#   the two stay in step. If SwiftLint and this ever disagree, SwiftLint is right
#   and this file has the bug — the calibration below (it must pass on the whole
#   committed tree, which SwiftLint accepts) is what keeps them honest.
# =============================================================================

import re
import sys
from pathlib import Path

# SwiftLint's built-in default for type_body_length's warning threshold. Not in
# .swiftlint.yml, so it is named here; read from the yml if ever added there.
DEFAULT_TYPE_BODY_LIMIT = 250

ROOT = Path(__file__).resolve().parent.parent
IOS = ROOT / "ios"
CONFIG = IOS / ".swiftlint.yml"


def yaml_block(text, key):
    """The lines under a top-level `key:` mapping, up to the next top-level key.

    A deliberately small reader for the flat, two-space-indented blocks this
    project's .swiftlint.yml uses — not a YAML parser, and not trying to be."""
    lines = text.split("\n")
    out = []
    collecting = False
    for line in lines:
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            collecting = True
            continue
        if collecting:
            if line and not line[0].isspace():
                break  # next top-level key
            out.append(line)
    return out


def yaml_list(text, key):
    """`- item` entries under a top-level key, comments and blanks dropped."""
    items = []
    for line in yaml_block(text, key):
        m = re.match(r"\s*-\s*(\S.*?)\s*$", line)
        if m and not m.group(1).startswith("#"):
            items.append(m.group(1))
    return items


def yaml_scalar(text, key, subkey, default):
    """A `subkey: value` under a top-level `key:` block, or `default`."""
    for line in yaml_block(text, key):
        m = re.match(rf"\s*{re.escape(subkey)}:\s*(\S+)", line)
        if m:
            value = m.group(1)
            if value in ("true", "false"):
                return value == "true"
            return int(value) if value.isdigit() else value
    return default


def classify(lines):
    """For each raw line, whether it is CODE (not blank, not comment-only), plus
    a brace-safe copy with comments and string contents removed."""
    is_code = []
    stripped = []
    in_block = False
    for raw in lines:
        s = raw.strip()
        code = True
        text = raw
        if in_block:
            code = False
            if "*/" in text:
                text = text.split("*/", 1)[1]
                in_block = False
            else:
                text = ""
        elif s == "":
            code = False
        elif s.startswith("//"):
            code = False
        elif s.startswith("/*"):
            code = False
            if "*/" not in s:
                in_block = True
        if not in_block and code:
            # Remove line comments and collapse string literals so a `{` or `}`
            # inside them is never mistaken for structure.
            text = re.sub(r"//.*", "", text)
            text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
            if "/*" in text:
                if "*/" in text:
                    text = re.sub(r"/\*.*?\*/", "", text)
                else:
                    text = text.split("/*", 1)[0]
                    in_block = True
        is_code.append(code)
        stripped.append(text)
    return is_code, stripped


TYPE_DECL = re.compile(
    r"\b(?:final\s+|public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)*"
    r"(?:class|struct|enum|actor)\s+[A-Za-z_]\w*"
)


def type_body_violations(path, limit):
    lines = path.read_text(encoding="utf-8").split("\n")
    is_code, stripped = classify(lines)
    problems = []
    i = 0
    while i < len(lines):
        # `extension` also contains `class`/`struct` words only as substrings of
        # other identifiers, never as a leading keyword, so the decl regex plus
        # this guard keeps extensions (unbounded here) out.
        if TYPE_DECL.search(stripped[i]) and not re.match(r"\s*extension\b", stripped[i]):
            depth = 0
            started = False
            open_line = None
            j = i
            found = False
            while j < len(lines) and not found:
                for ch in stripped[j]:
                    if ch == "{":
                        depth += 1
                        if not started:
                            started = True
                            open_line = j
                    elif ch == "}":
                        depth -= 1
                        if started and depth == 0:
                            body = sum(1 for k in range(open_line + 1, j) if is_code[k])
                            name = TYPE_DECL.search(stripped[i]).group(0).split()[-1]
                            if body > limit:
                                problems.append(
                                    f"{path.relative_to(ROOT)}:{i + 1}: type_body_length: "
                                    f"'{name}' body spans {body} lines (limit {limit})"
                                )
                            i = j
                            found = True
                            break
                j += 1
        i += 1
    return problems


def file_length_violation(path, limit, ignore_comment_only):
    lines = path.read_text(encoding="utf-8").split("\n")
    # A file's text ends in a trailing newline, so the split yields one empty
    # tail element that is not a real line; drop it, as SwiftLint counts lines.
    if lines and lines[-1] == "":
        lines = lines[:-1]
    is_code, _ = classify(lines)
    count = len(lines)
    if ignore_comment_only:
        # Only comment-only lines are removed; blank lines still count.
        count -= sum(
            1
            for k, raw in enumerate(lines)
            if not is_code[k] and raw.strip() != ""
        )
    if count > limit:
        return [
            f"{path.relative_to(ROOT)}: file_length: {count} lines (limit {limit})"
        ]
    return []


URL = re.compile(r"https?://")


def line_length_violations(path, limit, ignores_comments, ignores_urls):
    lines = path.read_text(encoding="utf-8").split("\n")
    is_code, _ = classify(lines)
    problems = []
    for k, raw in enumerate(lines):
        if ignores_comments and not is_code[k] and raw.strip() != "":
            continue  # a comment-only line
        if ignores_urls and URL.search(raw):
            continue
        if len(raw) > limit:
            problems.append(
                f"{path.relative_to(ROOT)}:{k + 1}: line_length: "
                f"{len(raw)} characters (limit {limit})"
            )
    return problems


def swift_files(text):
    included = yaml_list(text, "included") or ["."]
    excluded = yaml_list(text, "excluded")
    excluded_paths = [(IOS / e).resolve() for e in excluded]
    files = []
    for root in included:
        base = (IOS / root).resolve()
        if base.is_file() and base.suffix == ".swift":
            candidates = [base]
        else:
            candidates = sorted(base.rglob("*.swift"))
        for f in candidates:
            rf = f.resolve()
            if any(rf == e or e in rf.parents for e in excluded_paths):
                continue
            files.append(f)
    return files


def main():
    if not CONFIG.exists():
        # No iOS project in this checkout: nothing to guard, like the other
        # sub-checks that skip gracefully on an absent input.
        return 0
    text = CONFIG.read_text(encoding="utf-8")

    type_limit = yaml_scalar(text, "type_body_length", "warning", DEFAULT_TYPE_BODY_LIMIT)
    file_limit = yaml_scalar(text, "file_length", "warning", 400)
    file_ignore_comments = yaml_scalar(text, "file_length", "ignore_comment_only_lines", False)
    line_limit = yaml_scalar(text, "line_length", "warning", 120)
    line_ignore_comments = yaml_scalar(text, "line_length", "ignores_comments", False)
    line_ignore_urls = yaml_scalar(text, "line_length", "ignores_urls", False)

    problems = []
    for path in swift_files(text):
        problems += type_body_violations(path, type_limit)
        problems += file_length_violation(path, file_limit, file_ignore_comments)
        problems += line_length_violations(path, line_limit, line_ignore_comments, line_ignore_urls)

    if problems:
        print("check-swift-length: SwiftLint length limits would be exceeded:", file=sys.stderr)
        for p in sorted(problems):
            print(f"  {p}", file=sys.stderr)
        print(
            "\nThese fail the Mac's `--strict` SwiftLint pass. Move members into an "
            "extension\n(not counted by type_body_length) or split the file.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
