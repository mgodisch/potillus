#!/usr/bin/env python3
# vim: set et ts=4:
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
#
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
#
# =============================================================================
#  check-swift-symbols.py -- catch invented names and missing imports
# =============================================================================
#
#  WHY THIS EXISTS
#    Two classes of error reached the repository because nobody could compile
#    Swift at the time the code was written:
#
#      1. An INVENTED TYPE. `BackupExporter` called `Backup.parse`. There is no
#         `Backup`; the file is named Backup.swift and declares `BackupReader`
#         and `BackupWriter`. Nine call sites, written from memory of a file read
#         weeks earlier.
#
#      2. A MISSING IMPORT. `SettingsScreen` used the `UTType` value `.json`
#         without importing UniformTypeIdentifiers.
#
#    Both are mechanical. Both are found in milliseconds. Neither needs a Mac,
#    which is the point: the check runs wherever the code is written, not only
#    where it is built.
#
#  WHAT IT CHECKS, AND WHY ONLY THAT
#    A first attempt verified that `Type.member` named a member the project
#    declares. It was worthless twice over. It MISSED the very bug it was written
#    for -- `Backup.makeJSON` was skipped because `Backup` is not a declared type,
#    and undeclared types were the case it silently ignored -- and it produced
#    twenty false alarms, because `Drink.filter` and `Entry.order` come from
#    GRDB's protocols, `allCases` from CaseIterable, and `.self` is not a member
#    at all. A linter that misses the real fault and cries wolf about the rest
#    gets switched off, and then finds nothing ever again.
#
#    So it checks two things it can be RIGHT about:
#
#      A. A NEAR-MISS TYPE. `Backup.parse` where no `Backup` exists but
#         `BackupReader`, `BackupWriter` and `BackupFile` do. Shortening a real
#         family of types into one that never existed is what memory does to a
#         name. Apple's own types CAN collide with this rule -- `Calendar` is a
#         prefix of `CalendarModel` -- so they are listed in EXTERNAL_TYPES, and a
#         name missing from that list costs a false alarm, never a missed bug.
#
#      B. A MISSING IMPORT. `UTType` without UniformTypeIdentifiers, `BarMark`
#         without Charts, `@Observable` without Observation.
#
#    It is not a Swift parser. Overload resolution, generics, inference and
#    protocol conformance are the compiler's business, and this tool does not
#    pretend otherwise. It reports only what it is sure of, and stays quiet
#    otherwise.
# =============================================================================

import os
import re
import sys

# ── Which files to read ──────────────────────────────────────────────────────

# Build products and checked-out dependencies. Everything else under ios/ is ours.
SKIPPED_DIRECTORIES = {".build", ".swiftpm", "DerivedData", "Potillus.xcodeproj"}

# The package whose public surface the app is checked against.
KIT_SOURCES = os.path.join("ios", "PotillusKit", "Sources")

# ── Missing imports ──────────────────────────────────────────────────────────
#
# A token that can only come from one module. Each entry is (regex, module).
# Deliberately short: every rule here has cost someone a broken build, and a rule
# that fires on a name two modules could provide would be a false positive.
IMPORT_RULES = [
    (re.compile(r"\bUTType\b|\ballowedContentTypes\b|\bcontentType:"), "UniformTypeIdentifiers"),
    (re.compile(r"\bBarMark\b|\bLineMark\b|\bAxisMarks\b|\bChart\("), "Charts"),
    (re.compile(r"@Observable\b|@ObservationIgnored\b"), "Observation"),
    (re.compile(r"\bXCTAssert|\bXCTestCase\b|\bXCTUnwrap\b"), "XCTest"),
    (re.compile(r"\bCryptoKit\b|\bAES\.GCM\b|\bSymmetricKey\b"), "CryptoKit"),
]

# Modules some files import transitively and legitimately do not name.
# `SwiftUI` re-exports much of Foundation; Charts and UTType it does not.
IMPORT_EXEMPT = {
    # A file that only *documents* a symbol in a comment is not using it, but the
    # comment stripper handles that. Nothing is exempt today; the set exists so a
    # future exception is a listed decision rather than a weakened rule.
}

# ── Declaration parsing ──────────────────────────────────────────────────────

TYPE_DECLARATION = re.compile(
    r"^(?P<indent>\s*)"
    r"(?:public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?"
    r"(?:final\s+)?"
    r"(?:enum|struct|class|actor|protocol)\s+"
    r"(?P<name>\w+)"
)

EXTENSION = re.compile(r"^(?P<indent>\s*)extension\s+(?P<name>\w+)")

MEMBER_DECLARATION = re.compile(
    r"^(?P<indent>\s+)"
    r"(?P<access>public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?"
    r"(?:static\s+|class\s+)?"
    r"(?:final\s+)?"
    r"(?:func|let|var|case)\s+"
    r"(?P<name>\w+)"
)

# `SomeType.someMember`, with or without a call. The member must start lowercase,
# so `Foo.Bar` (a nested type) and `.beer` (an enum case) do not match.
USE_SITE = re.compile(r"\b(?P<type>[A-Z]\w+)\.(?P<member>[a-z]\w*)")

# Below this length a shared prefix means nothing: `App`, `Day`, `Set`.
MINIMUM_PREFIX = 4

# Types the compiler owns. The near-miss rule assumed no Apple type could be a
# prefix of one of ours; `Calendar` and `CalendarModel` disproved that within a
# minute of the rule existing. Rather than weaken the rule, name the exceptions.
#
# A missing entry here is a false alarm, not a missed bug -- the failure mode
# points the right way, and adding a name is a one-line fix.
EXTERNAL_TYPES = {
    # Foundation and the standard library
    "Array", "Bool", "Bundle", "Calendar", "CocoaError", "Data", "Date",
    "DateComponents", "DateFormatter", "Dictionary", "Double", "FileManager",
    "FileWrapper", "Float", "ISO8601DateFormatter", "Int", "Int64",
    "JSONSerialization", "Locale", "Notification", "NumberFormatter", "Optional",
    "Result", "Set", "String", "Task", "TimeInterval", "TimeZone", "URL",
    "UserDefaults", "UUID",
    # SwiftUI, Charts, UniformTypeIdentifiers
    "AxisMarks", "BarMark", "Binding", "Button", "Chart", "Circle", "Color",
    "EdgeInsets", "GridItem", "Image", "Label", "LineMark", "Picker",
    "ProgressView", "Rectangle", "RoundedRectangle", "Section", "State",
    "Stepper", "Text", "Toggle", "UTType", "View",
    # GRDB
    "Column", "Database", "DatabaseQueue", "DatabaseMigrator", "Row",
    # XCTest
    "XCTestCase",
}

COMMENT_OR_STRING = re.compile(
    r'"""(?:.|\n)*?"""'      # multi-line strings
    r'|"(?:\\.|[^"\\\n])*"'  # single-line strings
    r"|//[^\n]*"             # line comments
    r"|/\*(?:.|\n)*?\*/",    # block comments
    re.MULTILINE,
)


def strip_noise(text):
    """Blanks out comments and string literals, preserving line numbers.

    A prose mention of `Backup.parse` in a doc comment must not be read as a call
    site, and an interpolated string must not hide one. Newlines are kept so that
    the line numbers in complaints stay true.
    """
    def blank(match):
        return re.sub(r"[^\n]", " ", match.group(0))

    return COMMENT_OR_STRING.sub(blank, text)


def swift_files(root, subdirectory="ios"):
    paths = []
    for directory, subdirectories, names in os.walk(os.path.join(root, subdirectory)):
        subdirectories[:] = [d for d in subdirectories if d not in SKIPPED_DIRECTORIES]
        for name in names:
            if name.endswith(".swift"):
                paths.append(os.path.join(directory, name))
    return sorted(paths)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def collect_declarations(paths):
    """Maps each declared type to the members declared inside it.

    Members are attributed to the innermost enclosing type by INDENTATION, which
    is exact for this codebase (four spaces, enforced by the file headers' vim
    modeline) and would be wrong for arbitrary Swift. Extensions contribute to
    the type they extend, which is what a caller sees.

    Access levels are recorded but not enforced: a test file with `@testable`
    reaches internal members, and distinguishing the two per call site is more
    machinery than the payoff justifies. The check is for names that do not exist
    at all.
    """
    members = {}
    for path in paths:
        text = strip_noise(read(path))
        stack = []  # (indent, type name)
        for line in text.split("\n"):
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip())

            while stack and indent <= stack[-1][0]:
                stack.pop()

            declaration = TYPE_DECLARATION.match(line) or EXTENSION.match(line)
            if declaration and "(" not in line.split(declaration.group("name"))[0]:
                name = declaration.group("name")
                members.setdefault(name, set())
                stack.append((indent, name))
                continue

            member = MEMBER_DECLARATION.match(line)
            if member and stack:
                members[stack[-1][1]].add(member.group("name"))
    return members


# ── The checks ───────────────────────────────────────────────────────────────

def check_symbols(path, declarations):
    """Flags `X.member` where X does not exist but is a prefix of types that do.

    The signature of a remembered name. `Backup.parse` is written by someone who
    read Backup.swift weeks ago and recalls the file, not the two enums inside it.
    A type from Foundation or SwiftUI is never a prefix of one of ours, so the
    rule fires on inventions and on nothing else.
    """
    problems = []
    text = strip_noise(read(path))
    for number, line in enumerate(text.split("\n"), start=1):
        for match in USE_SITE.finditer(line):
            type_name = match.group("type")
            if (
                type_name in declarations
                or type_name in EXTERNAL_TYPES
                or len(type_name) < MINIMUM_PREFIX
            ):
                continue

            # Types that extend this name. `Backup` -> BackupReader, BackupWriter.
            relatives = sorted(
                name for name in declarations
                if name.startswith(type_name) and len(name) > len(type_name)
                and name[len(type_name)].isupper()
            )
            if not relatives:
                continue  # an external type; not ours to judge

            problems.append(
                f"{path}:{number}: no type '{type_name}' exists; "
                f"did you mean {', '.join(relatives)}?"
            )
    return problems


def check_imports(path):
    """Flags a token whose module the file never imports."""
    problems = []
    raw = read(path)
    text = strip_noise(raw)
    imported = set(re.findall(r"^\s*(?:@testable\s+)?import\s+(\w+)", raw, re.MULTILINE))

    for pattern, module in IMPORT_RULES:
        if module in imported or (path, module) in IMPORT_EXEMPT:
            continue
        match = pattern.search(text)
        if match:
            number = text[: match.start()].count("\n") + 1
            problems.append(
                f"{path}:{number}: uses '{match.group(0)}' but does not import {module}"
            )
    return problems


def repository_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(argv):
    root = repository_root()
    paths = argv or swift_files(root)
    if not paths:
        return 0

    # Declarations come from the WHOLE project, not only the kit: the app declares
    # types too, and a screen calling its own model must be checked as well.
    declarations = collect_declarations(swift_files(root))

    problems = []
    for path in paths:
        problems.extend(check_symbols(path, declarations))
        problems.extend(check_imports(path))

    for message in problems:
        print(f"check-swift-symbols: {os.path.relpath(message.split(':')[0], root)}"
              f":{':'.join(message.split(':')[1:])}")

    if problems:
        print(f"check-swift-symbols: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
