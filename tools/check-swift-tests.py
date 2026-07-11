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
check-swift-tests.py -- catches Swift test mistakes the compiler only reports
after a full build, and that a human reviewer reliably re-introduces.

WHY THIS EXISTS
    `XCTAssertEqual` and its siblings take their arguments as AUTOCLOSURES, so
    the expression can be printed back when an assertion fails.  Autoclosures are
    synchronous.  Writing

        XCTAssertEqual(await store.load(), AppSettings())

    therefore fails to compile with "'async' call in an autoclosure that does not
    support concurrency".  The fix is always the same: bind the awaited value to
    a `let` first, which also makes the failure message name the value.

    This mistake was made, fixed, and then made again two patches later.  A grep
    is cheaper than a memory, and cheaper than a five-minute compile on a Mac
    when the author is working without one.

WHAT IT CHECKS
    Any line where an `XCTAssert*` or `XCTUnwrap` call contains `await`.

    The check is textual on purpose: it needs no toolchain, so it runs in the
    same second on any machine, and a false positive costs one hoisted `let`.

USAGE
    tools/check-swift-tests.py [PATH ...]

    With no PATH, checks every tracked *.swift file under ios/.
    Exit status: 0 = clean, 1 = problems found.
"""

import os
import re
import sys

# `XCTAssertEqual(await x, y)` and `XCTUnwrap(await x)`, but not a line that
# merely mentions await in a trailing comment.
OFFENDER = re.compile(r"\b(XCTAssert\w*|XCTUnwrap)\s*\(.*\bawait\b")

# A comment on the line would be a false positive; strip it first. Crude, but a
# `//` inside a Swift string literal in a test assertion is vanishingly rare.
COMMENT = re.compile(r"//.*$")


def repository_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# Build products and dependencies. Everything else under ios/ is ours.
SKIPPED_DIRECTORIES = {".build", ".swiftpm", "DerivedData", "Potillus.xcodeproj"}


def default_paths(root):
    """Every Swift file under ios/, tracked or not.

    This used to ask `git ls-files`, and therefore skipped files that had been
    written but not yet added to the index -- which is precisely the state a file
    is in while it is being reviewed. A linter that silently passes over the file
    under scrutiny is worse than no linter: it reports green for work it never
    looked at. Patch -39 shipped uncompilable tests through exactly that gap.
    """
    paths = []
    for directory, subdirectories, names in os.walk(os.path.join(root, "ios")):
        subdirectories[:] = [d for d in subdirectories if d not in SKIPPED_DIRECTORIES]
        for name in names:
            if name.endswith(".swift"):
                paths.append(os.path.join(directory, name))
    return sorted(paths)


def check_file(path, root):
    """Returns a list of complaint strings for one file."""
    problems = []
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
    except OSError:
        return problems

    relative = os.path.relpath(path, root)
    for number, line in enumerate(lines, start=1):
        if OFFENDER.search(COMMENT.sub("", line)):
            problems.append(
                f"{relative}:{number}: await inside an XCTAssert autoclosure; "
                "bind it to a `let` first"
            )
    return problems


def main(argv):
    root = repository_root()
    paths = argv or default_paths(root)

    problems = []
    for path in paths:
        problems.extend(check_file(path, root))

    for message in problems:
        print(f"check-swift-tests: {message}")

    if problems:
        print(f"check-swift-tests: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
