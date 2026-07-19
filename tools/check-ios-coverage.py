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
check-ios-coverage.py -- enforce a line-coverage floor on PotillusKit.

WHY THIS EXISTS
---------------
This is the iOS counterpart of Android's `:app:koverVerify`. Android's Kover
verifies the JVM unit tests reach a LINE floor over the app's unit-testable
code; this tool verifies `swift test --enable-code-coverage` reaches a LINE
floor over PotillusKit's OWN sources -- the iOS business logic, exercised by the
same command-line suite, with no simulator.

It reads the LLVM coverage-export JSON that SwiftPM writes (the file
`swift test --show-codecov-path` prints) and re-computes the line percentage
over just the files under `--path-filter` (default `/Sources/PotillusKit/`).
That filter is deliberate and mirrors Kover's class filter: the raw total in the
JSON also counts the test target and vendored dependencies (GRDB), which are not
what the project's own coverage floor is about.

LINE ONLY, ON PURPOSE
---------------------
The floor is line (statement) coverage only. That is what the OpenSSF silver
badge asks for (`test_statement_coverage80`); branch coverage is a gold-tier
criterion and is not obtainable from this `swift test` / llvm-cov path anyway
(the branch column comes back empty), so it stays a roadmap goal on both
platforms. See docs/ROADMAP.md.

USAGE
-----
    swift test --enable-code-coverage                       # in ios/PotillusKit
    check-ios-coverage.py "$(swift test --enable-code-coverage --show-codecov-path)" \
        --min-line 80

Exit status is 0 when the floor is met, 1 when it is not (or the report is
unusable), so it drops straight into `make cover-check` / `release-ios`.
"""

import argparse
import json
import sys


def filtered_line_coverage(report, path_filter):
    """Return (covered, count) summed over files whose name contains path_filter.

    The LLVM export JSON is {"data": [{"files": [{"filename", "summary": {
    "lines": {"count", "covered", ...}}}], "totals": {...}}]}. We sum the
    per-file line tallies rather than trusting a single total so the path filter
    can exclude the test target and dependencies.
    """
    covered = count = 0
    matched = 0
    for datum in report.get("data", []):
        for entry in datum.get("files", []):
            name = entry.get("filename", "")
            if path_filter in name:
                lines = entry.get("summary", {}).get("lines", {})
                covered += lines.get("covered", 0)
                count += lines.get("count", 0)
                matched += 1
    return covered, count, matched


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Enforce a line-coverage floor on PotillusKit from swift "
        "test's codecov JSON."
    )
    parser.add_argument(
        "report",
        help="path to the LLVM coverage-export JSON "
        "(swift test --enable-code-coverage --show-codecov-path)",
    )
    parser.add_argument(
        "--min-line",
        type=float,
        required=True,
        help="minimum line-coverage percent required (e.g. 80)",
    )
    parser.add_argument(
        "--path-filter",
        default="/Sources/PotillusKit/",
        help="only count files whose path contains this (default "
        "/Sources/PotillusKit/)",
    )
    args = parser.parse_args(argv)

    try:
        with open(args.report, encoding="utf-8") as handle:
            report = json.load(handle)
    except (OSError, json.JSONDecodeError) as err:
        print(f"check-ios-coverage: cannot read coverage report "
              f"'{args.report}': {err}", file=sys.stderr)
        return 1

    covered, count, matched = filtered_line_coverage(report, args.path_filter)
    if matched == 0 or count == 0:
        print(f"check-ios-coverage: no lines matched '{args.path_filter}' in "
              f"{args.report} -- was 'swift test --enable-code-coverage' run "
              f"first?", file=sys.stderr)
        return 1

    percent = 100.0 * covered / count
    label = args.path_filter.strip("/")
    if percent + 1e-9 < args.min_line:
        print(f"check-ios-coverage: {label} line coverage {percent:.2f}% "
              f"({covered}/{count}) is below the required {args.min_line:.0f}%.",
              file=sys.stderr)
        return 1

    print(f"check-ios-coverage: OK -- {label} line coverage {percent:.2f}% "
          f"({covered}/{count}) >= {args.min_line:.0f}%.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
