#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
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
# =============================================================================

"""
check-ios-a11y.py -- icon-only buttons must say what they do.

WHY THIS EXISTS
    release-check.sh Section 13 has enforced this on Android since its own
    review rounds: an interactive `IconButton` whose icon carries
    `contentDescription = null` is a control TalkBack announces as nothing at
    all.  The iOS side had no counterpart -- the convention held only because
    somebody remembered it (0.83.0 QA round: all eleven icon-only buttons were
    in fact labelled; nothing was watching).  A rule enforced on one platform
    and merely remembered on the other is exactly how the two drift.

    This is that counterpart.  Same rule, native spelling: a `Button` whose
    label is only an `Image` needs an `.accessibilityLabel(...)`, because
    VoiceOver has nothing else to read.  A `Button` containing a `Text` or a
    `Label` needs none -- SwiftUI speaks the text.

WHAT IT CHECKS
    Every `Button` in the app's views.  The scan is brace-aware, like Android's:
    it isolates each button -- its optional argument list, its action closure,
    its `label:` closure, and the modifier chain that follows -- and reports one
    only when ALL of these hold:

      * its label contains `Image(` or `Image(systemName:`,
      * its label contains no `Text(` and no `Label(`,
      * neither the button nor its modifier chain calls `.accessibilityLabel(`.

    The modifier chain is part of the span on purpose: the label is virtually
    always attached AFTER the closing brace, as `.accessibilityLabel(...)`
    beneath a `.buttonStyle(.plain)`.

WHAT IT DELIBERATELY DOES NOT CHECK
    Decorative images outside a Button (the lock glyph on the privacy cover, the
    warning triangle on the startup-failure view).  They are not controls;
    labelling them would make VoiceOver read furniture.  Android's gate draws
    the same line by scanning only inside `IconButton` lambdas.

    `.accessibilityLabel` inherited from an ENCLOSING view is not seen, so such a
    button would be reported.  That is the safe direction: the finding is a
    sentence to read, and if it is ever a false positive the fix is to move the
    label onto the control itself, where a reader of the code expects it.

USAGE
    tools/check-ios-a11y.py [PATH ...]

    With no PATH, checks every *.swift under ios/Potillus/ (the app's views;
    PotillusKit imports no SwiftUI and has no controls).  Skips gracefully with
    an info message when that directory is absent, so it is safe in any checkout.
    Exit status: 0 = clean or nothing to scan, 1 = unlabelled buttons found.
"""

import os
import re
import sys

# `Button` as a word, so `AppButtonStyle` or a comment's "Button" do not match.
BUTTON = re.compile(r"\bButton\b")

IMAGE = re.compile(r"\bImage\s*\(")
TEXT = re.compile(r"\bText\s*\(")
LABEL_VIEW = re.compile(r"\bLabel\s*\(")
A11Y = re.compile(r"\.accessibilityLabel\s*\(")


def repository_root():
    """The directory above tools/, i.e. the repository root."""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def match_delim(text, start, open_ch, close_ch):
    """Index of the delimiter closing the one at text[start], or -1.

    String literals are not tracked: a brace or paren inside a Swift string
    would confuse the count.  In practice the app's button labels hold no such
    literal, and the failure mode is a span that ends too early -- which can
    only produce a report, never silence one.
    """
    depth = 0
    for i in range(start, len(text)):
        if text[i] == open_ch:
            depth += 1
        elif text[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return -1


def skip_space(text, i):
    """The next index at or after `i` that is not whitespace."""
    while i < len(text) and text[i].isspace():
        i += 1
    return i


def button_span(text, start):
    """The end index of the `Button` construct beginning at `start`, or -1.

    Consumes, in order: an optional argument list `(...)`, then any number of
    trailing closures, hopping over the `label:` keyword between them.  That
    covers every shape the app uses -- `Button { } label: { }`,
    `Button(role:) { } label: { }`, and `Button(action:) { }`.
    """
    i = skip_space(text, start + len("Button"))
    if i < len(text) and text[i] == "(":
        i = match_delim(text, i, "(", ")")
        if i == -1:
            return -1
        i = skip_space(text, i + 1)
    saw_closure = False
    while i < len(text) and text[i] == "{":
        end = match_delim(text, i, "{", "}")
        if end == -1:
            return -1
        saw_closure = True
        i = skip_space(text, end + 1)
        if text.startswith("label:", i):
            i = skip_space(text, i + len("label:"))
    return i if saw_closure else -1


def modifier_span(text, start):
    """The end index of the `.modifier(...)` chain beginning at `start`."""
    i = skip_space(text, start)
    while i < len(text) and text[i] == ".":
        j = i + 1
        while j < len(text) and (text[j].isalnum() or text[j] == "_"):
            j += 1
        if j == i + 1:
            break
        j = skip_space(text, j)
        if j < len(text) and text[j] == "(":
            j = match_delim(text, j, "(", ")")
            if j == -1:
                break
            j += 1
        j = skip_space(text, j)
        if j < len(text) and text[j] == "{":
            j = match_delim(text, j, "{", "}")
            if j == -1:
                break
            j += 1
        i = skip_space(text, j)
    return i


def offenders(path):
    """Every icon-only, unlabelled button in `path`, as message strings."""
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return []

    found = []
    for match in BUTTON.finditer(text):
        end = button_span(text, match.start())
        if end == -1:
            continue
        whole = text[match.start():modifier_span(text, end)]
        if not IMAGE.search(whole):
            continue
        if TEXT.search(whole) or LABEL_VIEW.search(whole):
            continue
        if A11Y.search(whole):
            continue
        line = text.count("\n", 0, match.start()) + 1
        found.append(f"{path}:{line}: icon-only Button without .accessibilityLabel")
    return found


def main(argv):
    root = repository_root()
    paths = argv[1:]
    if not paths:
        views = os.path.join(root, "ios", "Potillus")
        if not os.path.isdir(views):
            print("check-ios-a11y: ios/Potillus not present — nothing to check")
            return 0
        paths = sorted(
            os.path.join(views, name)
            for name in os.listdir(views)
            if name.endswith(".swift")
        )

    problems = []
    for path in paths:
        problems.extend(offenders(path))

    if problems:
        for line in problems:
            print(f"check-ios-a11y: {os.path.relpath(line, root)}"
                  if line.startswith(root) else f"check-ios-a11y: {line}")
        print(
            f"check-ios-a11y: {len(problems)} icon-only button(s) VoiceOver "
            "cannot announce; add .accessibilityLabel(Loc.string(...)) to each.",
            file=sys.stderr,
        )
        return 1

    print(f"check-ios-a11y: OK ({len(paths)} view file(s) scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
