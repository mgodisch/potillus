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
"""check-fixture-parity.py — the two demo fixtures hold the same demo data.

WHY TWO FILES
    fastlane/demo-backup.json is a format-2 backup and stays one: BackupTests
    asserts that this app still reads a real export written before the settings
    block existed, and reading THAT file rather than a hand-written sample is
    what makes the interoperability claim a demonstration.

    fastlane/screenshot-fixture.json is a format-3 export of the same data. It
    exists for its settings block: the screenshot runs read the limits out of the
    store they seed, and a fixture without settings left an emulator reporting
    whatever a previous session had stored.

    Two roles, two files, and one set of demo data that must stay one set. Two
    copies of 85 entries drift, and when they do, the file that proves the app
    reads old backups no longer holds the data the screenshots show.

WHAT IS COMPARED
    Drinks by (name, volume, percent, category); entries by (timestamp, grams,
    drink name, note). By CONTENT, not by id or position: the format-3 export was
    taken from a device that had renumbered both, so an element-wise comparison
    would fail on a pair of files that agree about every drink and every entry.

    The settings block is deliberately NOT compared. It is the whole reason the
    second file exists, and a format-2 file cannot carry one.
"""

import json
import sys
from collections import Counter

from potillus_repo import repo_root

ROOT = repo_root()
V2 = ROOT / "fastlane/demo-backup.json"
V3 = ROOT / "fastlane/screenshot-fixture.json"


def drink_key(drink):
    return (drink["name"], drink["volumeMl"], drink["alcoholPercent"], drink["category"])


def entry_keys(backup):
    """Entries with the drink NAME in place of its id, which differs per export."""
    names = {d["id"]: d["name"] for d in backup["drinks"]}
    return Counter(
        (
            entry["timestampMillis"],
            round(entry["gramsAlcohol"], 4),
            names.get(entry["drinkId"]),
            entry.get("note", ""),
        )
        for entry in backup["entries"]
    )


def describe(counter, limit=3):
    return ", ".join(repr(item) for item in list(counter.elements())[:limit])


def main():
    problems = []
    for path in (V2, V3):
        if not path.exists():
            problems.append(f"missing {path.relative_to(ROOT)}")
    if problems:
        for line in problems:
            print(f"check-fixture-parity: {line}", file=sys.stderr)
        return 1

    v2 = json.loads(V2.read_text(encoding="utf-8"))
    v3 = json.loads(V3.read_text(encoding="utf-8"))

    if v2.get("version") != 2:
        problems.append(
            f"{V2.name} is version {v2.get('version')}; it is the pre-v3 fixture and stays format 2"
        )
    if v3.get("version") != 3:
        problems.append(
            f"{V3.name} is version {v3.get('version')}; it carries the settings block and stays format 3"
        )
    if "settings" in v2:
        problems.append(f"{V2.name} carries a settings block; a format-2 file has none")
    if "settings" not in v3:
        problems.append(f"{V3.name} carries no settings block, which is the reason it exists")

    a, b = Counter(map(drink_key, v2["drinks"])), Counter(map(drink_key, v3["drinks"]))
    if a != b:
        problems.append(
            f"drinks differ: only in {V2.name}: {describe(a - b)}; only in {V3.name}: {describe(b - a)}"
        )
    a, b = entry_keys(v2), entry_keys(v3)
    if a != b:
        problems.append(
            f"entries differ ({len(list((a - b).elements()))} only in {V2.name}, "
            f"{len(list((b - a).elements()))} only in {V3.name}): {describe(a - b, 2)}"
        )

    for line in problems:
        print(f"check-fixture-parity: {line}", file=sys.stderr)
    if problems:
        print(
            f"check-fixture-parity: {len(problems)} problem(s); the two demo fixtures "
            f"have drifted apart.",
            file=sys.stderr,
        )
        return 1

    print(
        f"check-fixture-parity: OK ({len(v2['drinks'])} drinks, {len(v2['entries'])} entries, "
        f"same content in both fixtures)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
