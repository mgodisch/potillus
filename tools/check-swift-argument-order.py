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
check-swift-argument-order.py -- labelled arguments in declaration order.

WHY
    Swift requires the labelled arguments of a call to appear in the order the
    initializer declares them; Kotlin does not care. Porting a change across the
    two therefore has a failure mode with no Kotlin counterpart: reorder a
    parameter on both sides, update the Kotlin call sites (where order is free),
    and every Swift call site that names the moved parameter stops compiling.

    That is how `entries.utcOffsetSeconds` broke the build once already: the
    field moved to the end of `ConsumptionEntry` and `Entry` so a freshly created
    table and a migrated one would carry their columns in the same order, and
    four call sites kept naming it where it used to be. The compiler catches
    this, but only on a Mac -- and on Linux this file is the only thing that can.

WHAT IT CHECKS
    For each type in TYPES: the labels of every call to it, in every .swift file
    under ios/, against the order of its `public init`. Only labels the
    initializer knows are considered, and only those at the call's top
    parenthesis level -- a nested call's own labels (`AlcoholCalculator
    .calculateGrams(volumeMl:alcoholPercent:)` inside a `ConsumptionEntry(...)`)
    belong to that call, not this one, and counting them reported two phantom
    violations before this was fixed.

WHAT IT DOES NOT CHECK
    Every type in the package. The list is the two record types that cross the
    platform boundary and therefore change whenever the schema does; a general
    check would need a Swift parser rather than a regex. Add a type here when it
    grows the same property: a shared shape that both platforms edit in step.

USAGE
    tools/check-swift-argument-order.py
    Exit status: 0 when every call matches its declaration, 1 otherwise.
"""

import re
import sys
from potillus_repo import repo_root

ROOT = repo_root()
IOS = ROOT / "ios"

# The project's own Swift, and only that. `ios/` also holds
# PotillusKit/.build/, where SwiftPM checks out GRDB: scanning it would read a
# dependency's source as if it were ours, and it contains a DIRECTORY named
# `GRDB.swift`, which a bare rglob("*.swift") hands to read_text(). These are the
# same roots ios/.swiftlint.yml lists under `included`.
SOURCE_ROOTS = (
    IOS / "Potillus",
    IOS / "PotillusKit/Sources",
    IOS / "PotillusKit/Tests",
    IOS / "PotillusTests",
    IOS / "PotillusUITests",
)

# type name -> file declaring it. Both are the record shapes the shared schema
# contract covers; see the module docstring for why the list is short.
TYPES = {
    "ConsumptionEntry": IOS / "PotillusKit/Sources/PotillusKit/Domain/Models.swift",
    "Entry": IOS / "PotillusKit/Sources/PotillusKit/Data/Records.swift",
}


def swift_files():
    """Every .swift FILE under the project's own roots, sorted, deduplicated.

    `is_file()` is not paranoia: a directory may end in `.swift` (GRDB's
    checkout is one), and rglob matches on the name alone.
    """
    seen = {}
    for root in SOURCE_ROOTS:
        if not root.is_dir():
            continue
        for path in root.rglob("*.swift"):
            if path.is_file():
                seen[path.resolve()] = path
    return [seen[key] for key in sorted(seen)]


def declared_labels(path, type_name):
    """The parameter labels of `type_name`'s `public init`, in order."""
    source = path.read_text(encoding="utf-8")
    start = source.index(f"struct {type_name}:")
    init = source.index("public init(", start)
    end = source.index(") {", init)
    body = source[init + len("public init(") : end]
    return [m.group(1) for m in re.finditer(r"^\s+(\w+):", body, re.M)]


def top_level_labels(call):
    """Labels at the call's own parenthesis level, ignoring nested calls."""
    labels, depth, i = [], 0, 0
    while i < len(call):
        char = call[i]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif depth == 0:
            match = re.match(r"(\w+):", call[i:])
            if match and (i == 0 or call[i - 1] in ",\n \t"):
                labels.append(match.group(1))
                i += match.end()
                continue
        i += 1
    return labels


def call_arguments(source, open_paren):
    """The text between `open_paren` and its matching close paren."""
    depth, i = 1, open_paren
    while i < len(source) and depth:
        if source[i] == "(":
            depth += 1
        elif source[i] == ")":
            depth -= 1
        i += 1
    return source[open_paren:i - 1]


def main():
    order = {name: declared_labels(path, name) for name, path in TYPES.items()}

    files = swift_files()
    violations = []
    for path in files:
        source = path.read_text(encoding="utf-8")
        for name, declaration in order.items():
            for match in re.finditer(r"\b" + re.escape(name) + r"\(", source):
                arguments = call_arguments(source, match.end())
                labels = [l for l in top_level_labels(arguments) if l in declaration]
                positions = [declaration.index(l) for l in labels]
                if positions != sorted(positions):
                    line = source[: match.start()].count("\n") + 1
                    relative = path.relative_to(ROOT)
                    violations.append(
                        f"{relative}:{line}: {name}({', '.join(labels)}) — "
                        f"declared: {', '.join(declaration)}"
                    )

    if violations:
        print(
            f"check-swift-argument-order: {len(violations)} call(s) name their "
            "arguments out of declaration order:",
            file=sys.stderr,
        )
        for line in violations:
            print(f"  {line}", file=sys.stderr)
        return 1

    print(
        f"check-swift-argument-order: OK ({len(order)} type(s) checked across "
        f"{len(files)} file(s))"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
