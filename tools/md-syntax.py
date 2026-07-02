#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
# =============================================================================
"""
md-syntax.py -- a small, dependency-free Markdown well-formedness checker for
the documents shipped with the app.

WHY THIS EXISTS
    The in-app guide/licence viewer renders Markdown with a small, permissive
    in-house renderer. A stray emphasis marker -- an asterisk or underscore
    meant literally but sitting OUTSIDE an inline-code span -- quietly turns
    into italics/bold there, even where a strict CommonMark parser would leave
    it alone. Off-the-shelf tools do not catch this: renderers merely convert
    (the accidental emphasis is "valid" Markdown), and style linters check
    layout, not intent. So this is a tiny guard, written against the Python
    standard library only, tuned to the one failure mode we actually hit:
    code-looking tokens that were never wrapped in backticks.

WHAT IT CHECKS, per file
    1. Inline code spans are closed (balanced backtick runs) on their line, and
       fenced ``` blocks are balanced across the file.
    2. Code-looking tokens must live INSIDE backticks, not in running prose:
         - snake_case          e.g.  pdf_days_suffix, SOURCE_DATE_EPOCH
         - glob / wildcard '*' e.g.  pdf_*, category_*, *.png, a*b
       Genuine emphasis -- *italic*, _italic_, **bold** with natural-language
       content -- is deliberately left untouched, as are URLs and link targets.
    3. Asterisk emphasis is balanced (an even number of '*' once code, escapes,
       URLs and flagged globs are removed), catching a dangling '*' that would
       italicise the remainder of a line.

    For CHANGELOG.md additionally (structural):
    4. Every "## ..." heading is exactly "## vMAJOR.MINOR.PATCH", and the
       versions run strictly newest-to-oldest from top to bottom.

WHAT IT INTENTIONALLY DOES NOT DO
    It is not a full CommonMark parser and makes no attempt to validate every
    construct. It favours a near-zero false-positive rate over completeness:
    every rule above was chosen because, in these specific documents, a match
    is overwhelmingly a real mistake rather than legitimate prose.

USAGE
    python3 md-syntax.py FILE [FILE ...]
    Exit status 0 = clean, 1 = at least one problem (printed as "path:line: msg").
    Missing files are reported on stderr and skipped (callers may pass build
    artefacts that only exist after an earlier build step).
"""

import os
import re
import sys

# An asterisk glued to one of these is a glob/path wildcard, never emphasis.
# '.' is handled separately (only "*." followed by an alphanumeric, e.g. *.png)
# so that a bold run ending in a full stop -- "**... done.**" -- is not flagged.
_GLOB_NEIGHBOUR = set("_/")

# A snake_case identifier: an alphanumeric word with at least one INTERNAL
# underscore joining two word characters (foo_bar, A_B_C). This never matches a
# simple "_italic_" run, whose underscores sit at the word's edges, not inside.
_SNAKE = re.compile(
    r"(?<![A-Za-z0-9_])[A-Za-z0-9]+(?:_[A-Za-z0-9]+)+(?![A-Za-z0-9_])"
)

# URLs and inline-link destinations, blanked before the token rules so that an
# underscore inside a link target (a Wikipedia anchor, say) is not mistaken for
# an un-backticked identifier.
_URL = re.compile(r"(?:https?://|www\.)\S+")
_AUTOLINK = re.compile(r"<(?:https?://|mailto:|[^>\s]+@)[^>\s]*>")
_LINK_DEST = re.compile(r"\]\([^)]*\)")

# A thematic break: a line of three or more *, _ or - (optionally spaced).
_THEMATIC = re.compile(r"^\s*([*_-])(?:\s*\1){2,}\s*$")

# A CHANGELOG version heading.
_VERSION_HEADING = re.compile(r"^## v(\d+)\.(\d+)\.(\d+)\s*$")


def _blank(text, span_len):
    """Length-preserving blank string (keeps later column math honest)."""
    return " " * span_len


def strip_inline_code(line):
    """Replace every closed `...` inline-code span on *line* with spaces.

    Returns (clean_line, ok). `ok` is False when a backtick run is opened but
    never closed on the same line, which is itself a reportable error. Spans are
    matched per CommonMark: a run of N backticks is closed by the next run of
    exactly N backticks.
    """
    out = []
    i, n = 0, len(line)
    while i < n:
        if line[i] != "`":
            out.append(line[i])
            i += 1
            continue
        # Measure the opening backtick run.
        j = i
        while j < n and line[j] == "`":
            j += 1
        run = j - i
        # Look for a closing run of the SAME length.
        k, close = j, -1
        while k < n:
            if line[k] == "`":
                m = k
                while m < n and line[m] == "`":
                    m += 1
                if m - k == run:
                    close = m
                    break
                k = m
            else:
                k += 1
        if close == -1:
            out.append(_blank(line[i:], n - i))
            return "".join(out), False
        out.append(_blank(line[i:close], close - i))
        i = close
    return "".join(out), True


def neutralise(line):
    """Blank out spans that must not be scanned for emphasis/identifier markers:
    backslash escapes, URLs, autolinks and inline-link destinations."""
    line = re.sub(r"\\[\\*_`]", "  ", line)            # \*  \_  \`  \\
    line = _LINK_DEST.sub(lambda m: _blank(m.group(), len(m.group())), line)
    line = _AUTOLINK.sub(lambda m: _blank(m.group(), len(m.group())), line)
    line = _URL.sub(lambda m: _blank(m.group(), len(m.group())), line)
    return line


def _strip_leading_marker(line):
    """Blank a leading list marker ("- ", "* ", "+ ") so a bullet '*' is never
    mistaken for an emphasis/glob marker."""
    return re.sub(r"^(\s*)[*+-](\s)", lambda m: m.group(1) + " " + m.group(2), line)


def _is_glob_star(s, idx):
    """True if the '*' at s[idx] looks like a path/glob wildcard rather than an
    emphasis delimiter. Stars inside a ** / *** run are never globs."""
    left = s[idx - 1] if idx > 0 else " "
    right = s[idx + 1] if idx + 1 < len(s) else " "
    if left == "*" or right == "*":
        return False
    nxt2 = s[idx + 2] if idx + 2 < len(s) else " "
    return (
        left in _GLOB_NEIGHBOUR
        or right in _GLOB_NEIGHBOUR
        or (right == "." and nxt2.isalnum())      # *.png, *.md
        or (left.isalnum() and right.isalnum())   # interior a*b
    )


def scan_tokens(line, lineno, errors):
    """Per-line rules: a code-looking token (snake_case or glob '*') outside an
    inline-code span must be wrapped in backticks. Identifiers never wrap across
    a line break, so scanning per line is exact here."""
    clean, _ = strip_inline_code(line)          # balance is checked per block
    s = _strip_leading_marker(neutralise(clean))

    for m in _SNAKE.finditer(s):
        errors.append(
            (lineno, f"code identifier '{m.group()}' should be wrapped in backticks")
        )
    s = _SNAKE.sub(lambda m: _blank(m.group(), len(m.group())), s)

    for idx, ch in enumerate(s):
        if ch == "*" and _is_glob_star(s, idx):
            a, b = idx, idx
            while a > 0 and not s[a - 1].isspace():
                a -= 1
            while b < len(s) and not s[b].isspace():
                b += 1
            errors.append(
                (lineno, f"wildcard '*' in '{s[a:b]}' should be wrapped in backticks")
            )


def scan_balance(block, errors):
    """Per-block rules: inline code spans and '*' emphasis must balance. Working
    on the whole block (a run of non-blank lines joined back together) is what
    lets a span legitimately wrap across a soft line break without tripping."""
    start = block[0][0]
    joined = " ".join(_strip_leading_marker(text) for _, text in block)

    s, closed = strip_inline_code(joined)
    if not closed:
        errors.append((start, "unterminated inline code (unbalanced backtick)"))

    s = _SNAKE.sub(lambda m: _blank(m.group(), len(m.group())), neutralise(s))
    chars = list(s)
    for idx, ch in enumerate(chars):
        if ch == "*" and _is_glob_star(s, idx):
            chars[idx] = " "                    # already reported by scan_tokens
    if "".join(chars).count("*") % 2 == 1:
        errors.append((start, "unbalanced '*' emphasis marker"))


def check_file(path):
    """Return a list of (lineno, message) problems for one Markdown file."""
    errors = []
    is_changelog = os.path.basename(path) == "CHANGELOG.md"
    versions = []  # (lineno, (major, minor, patch))

    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    # Group the file into blocks: maximal runs of non-blank lines. A blank line,
    # a fenced-code boundary, a thematic break and an ATX heading all close the
    # current block; a heading also forms a block of its own. Emphasis and inline
    # code may wrap across a soft line break but never across a block boundary,
    # so per-block balance checking avoids false positives on wrapped spans.
    blocks, cur, in_fence = [], [], False

    def flush():
        if cur:
            blocks.append(cur[:])
            cur.clear()

    for lineno, line in enumerate(lines, start=1):
        if line.strip().startswith("```"):
            in_fence = not in_fence
            flush()
            continue
        if in_fence:
            continue
        if not line.strip() or _THEMATIC.match(line):
            flush()
            continue
        if re.match(r"#{1,6}\s", line):
            flush()
            blocks.append([(lineno, line)])
            if is_changelog and line.startswith("## "):
                m = _VERSION_HEADING.match(line)
                if not m:
                    errors.append(
                        (lineno, f"CHANGELOG heading must be '## vMAJOR.MINOR.PATCH': {line!r}")
                    )
                else:
                    versions.append((lineno, tuple(int(g) for g in m.groups())))
            continue
        cur.append((lineno, line))
    flush()

    if in_fence:
        errors.append((len(lines), "unterminated fenced code block (```)"))

    for block in blocks:
        for lineno, line in block:
            scan_tokens(line, lineno, errors)
        scan_balance(block, errors)

    if is_changelog:
        for (_, prev), (ln, cur_v) in zip(versions, versions[1:]):
            if cur_v >= prev:
                errors.append(
                    (ln, "CHANGELOG versions not strictly descending: "
                         f"v{'.'.join(map(str, cur_v))} follows v{'.'.join(map(str, prev))}")
                )

    return sorted(errors)


def main(argv):
    total = 0
    for path in argv:
        if not os.path.isfile(path):
            print(f"md-syntax: skipped (not found): {path}", file=sys.stderr)
            continue
        for lineno, msg in check_file(path):
            print(f"{path}:{lineno}: {msg}")
            total += 1
    if total:
        print(f"md-syntax: {total} problem(s) found", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
