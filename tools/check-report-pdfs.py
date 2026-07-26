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
"""check-report-pdfs.py — every committed sample report is two pages.

WHY THIS EXISTS
    The report is designed as two sheets and the store screenshots rasterize page
    one and page two of it. Nothing checked that a rendered report actually came
    out at two pages, and in the 0.84.0 round it did not: on iOS a label wrapped,
    sheet one grew past the page, the printer drew only the pages the renderer had
    counted, and the exported file lost its second sheet. Nine locales shipped a
    blank screenshot 08 to the App Store.

    ReportPdfPrinter now refuses to hand out a truncated document, which catches
    it at export time on one platform. This catches it in the repository, on the
    artefacts that are actually committed, for both.

WHAT IT CHECKS AND WHAT IT DOES NOT
    The page count, and only that. Whether the right things are ON those pages
    needs a text layer, and reading one means a PDF library this project does not
    otherwise require. A wrong page count is the failure that shipped; a wrong
    page one would have been visible in the screenshot.

WHY IT PARSES THE BYTES ITSELF
    `.gitlab-ci.yml` runs the static checks on a pip-free image, so a gate in
    `check-static` may not import pypdf. The page count sits in the document's
    page-tree node as `/Count`, which is plain text in every file this project
    produces. Verified against pypdf over all 21 committed reports and over
    iOS-produced ones, whose writer is a different program entirely: same number
    every time.

    If a future PDF hides its page tree in an object stream, this reports that it
    could not read the count rather than guessing — an unreadable file is a
    finding, not a pass.
"""

import re
import sys

from potillus_repo import repo_root

ROOT = repo_root()
REPORT_DIR = ROOT / "fastlane/report-pdf/android"
EXPECTED_PAGES = 2

# `/Type /Pages` is the page-tree root; its `/Count` is the document's page count.
# Written in either order by different producers, so both are tried.
COUNT_PATTERNS = (
    re.compile(rb"/Type\s*/Pages\b[^>]*?/Count\s+(\d+)", re.S),
    re.compile(rb"/Count\s+(\d+)[^>]*?/Type\s*/Pages\b", re.S),
)


def page_count(path):
    """The document's page count, or None when the page tree is not readable."""
    raw = path.read_bytes()
    for pattern in COUNT_PATTERNS:
        found = pattern.findall(raw)
        if found:
            # A document may nest page-tree nodes; the root carries the largest.
            return max(int(value) for value in found)
    return None


def main():
    if not REPORT_DIR.is_dir():
        print(
            f"check-report-pdfs: {REPORT_DIR.relative_to(ROOT)} is missing; "
            f"the sample reports are a committed store asset.",
            file=sys.stderr,
        )
        return 1

    reports = sorted(REPORT_DIR.glob("*.pdf"))
    if not reports:
        print(
            f"check-report-pdfs: no reports in {REPORT_DIR.relative_to(ROOT)}; "
            f"a check over nothing is not a check.",
            file=sys.stderr,
        )
        return 1

    problems = []
    for report in reports:
        pages = page_count(report)
        if pages is None:
            problems.append(f"{report.name}: page tree not readable")
        elif pages != EXPECTED_PAGES:
            problems.append(f"{report.name}: {pages} pages, expected {EXPECTED_PAGES}")

    for line in problems:
        print(f"check-report-pdfs: {line}", file=sys.stderr)
    if problems:
        print(
            f"check-report-pdfs: {len(problems)} of {len(reports)} sample report(s) "
            f"are not {EXPECTED_PAGES} pages; regenerate them or fix what made the "
            f"report longer.",
            file=sys.stderr,
        )
        return 1

    print(f"check-report-pdfs: OK ({len(reports)} reports, {EXPECTED_PAGES} pages each)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
