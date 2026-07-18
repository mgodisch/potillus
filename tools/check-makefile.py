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
#  check-makefile.py -- a bare `cd` under .ONESHELL leaks
# =============================================================================
#
#  THE TRAP
#    Without .ONESHELL, make runs every recipe line in its own shell, so a `cd`
#    affects that line alone. WITH .ONESHELL -- which this project sets, to get
#    `set -euo pipefail` across a whole recipe -- the entire recipe is one shell,
#    and a `cd` on line one changes the working directory of every line after it.
#
#    The `ios` target read:
#
#        cd ios/PotillusKit && swift test
#        xcodebuild -project ios/Potillus.xcodeproj ...
#
#    The tests passed. Then xcodebuild looked for the project underneath
#    ios/PotillusKit/ and reported that it does not exist -- a path error
#    disguised as a missing file, after a green test run.
#
#    The fix is a subshell: `( cd ios/PotillusKit && swift test )`. The
#    `screenshots` target already knew this and says so in a comment. The
#    knowledge was in the file; only the discipline was missing. Hence a check.
#
#  THE RULE
#    A `cd` is a problem only if a later line in the SAME recipe depends on the
#    original directory. That is undecidable in general, so the rule is
#    conservative and syntactic: a recipe line beginning with `cd ` must be the
#    LAST line of its recipe, or be wrapped in parentheses. Recipes end at target
#    boundaries -- make starts a fresh shell for each target -- so a trailing `cd`
#    cannot leak anywhere.
#
#  THE SCOPE
#    With no arguments the check covers every makefile this project ships: the
#    root, android/ and ios/ Makefiles and each make/*.mk fragment. A fragment is
#    `include`d by a Makefile that sets .ONESHELL, so it is checked under that
#    setting even though it declares none itself. Pass explicit paths to override.
# =============================================================================

import glob
import os
import re
import sys

# `@` suppresses echo, `-` ignores errors; neither changes what the line does.
PREFIXES = "@-+"

BARE_CD = re.compile(r"^cd\s")


def repository_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def default_makefiles():
    """Every makefile this project ships: the three per-context Makefiles plus each
    fragment under make/. Globbing make/*.mk keeps new fragments (e.g. a future
    publish.mk) covered automatically, so the check never silently misses one."""
    root = repository_root()
    named = [
        os.path.join(root, "Makefile"),
        os.path.join(root, "android", "Makefile"),
        os.path.join(root, "ios", "Makefile"),
    ]
    fragments = sorted(glob.glob(os.path.join(root, "make", "*.mk")))
    return [path for path in named + fragments if os.path.isfile(path)]


def is_fragment(path):
    """A make/*.mk fragment is `include`d by a Makefile that declares .ONESHELL, so
    its recipes run under that setting even though the fragment does not declare it
    itself. The bare-cd check must therefore apply to it too -- see check()."""
    parent = os.path.basename(os.path.dirname(os.path.abspath(path)))
    return parent == "make" and path.endswith(".mk")


def check(path, assume_oneshell=False):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")

    # Without .ONESHELL each recipe line runs in its own shell, so a `cd` cannot
    # leak into the next one. A make/*.mk fragment inherits .ONESHELL from the
    # Makefile that `include`s it (assume_oneshell), so it is still checked even
    # though it declares none of its own.
    if not assume_oneshell and not any(line.startswith(".ONESHELL") for line in lines):
        return []  # each line gets its own shell; a `cd` cannot leak

    problems = []
    recipe = []

    def close_recipe():
        # Comments inside a recipe are passed to the shell but do nothing, so a
        # `cd` followed only by comments still leaks nothing. Ignore them when
        # deciding which line is last.
        code = [
            (number, text) for number, text in recipe
            if not text.lstrip("\t").lstrip(PREFIXES).startswith("#")
        ]
        for index, (number, text) in enumerate(code):
            command = text.lstrip("\t").lstrip(PREFIXES)
            if BARE_CD.match(command) and index != len(code) - 1:
                problems.append(
                    f"{path}:{number}: bare 'cd' under .ONESHELL changes the directory "
                    f"for the rest of the recipe; wrap it as `( cd ... && ... )`"
                )

    for number, line in enumerate(lines, start=1):
        if line.startswith("\t"):
            recipe.append((number, line))
        elif recipe:
            close_recipe()
            recipe = []
    if recipe:
        close_recipe()

    return problems


def main(argv):
    paths = argv or default_makefiles()
    problems = []
    for path in paths:
        problems.extend(check(path, assume_oneshell=is_fragment(path)))

    for message in problems:
        print(f"check-makefile: {message}")

    if problems:
        print(f"check-makefile: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
