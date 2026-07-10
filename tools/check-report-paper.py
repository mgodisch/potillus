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
#
# check-report-paper.py -- the report template and the iOS printer must agree
# about the size of a sheet of paper.
#
# WHY THIS EXISTS
#   The template is meant to be edited by hand. Its page geometry lives in two
#   CSS rules:
#
#       @page  { size: A4; margin: 14mm 12mm 16mm 12mm; }
#       .sheet { min-height: 267mm; }
#
#   Android's print framework reads both. `UIViewPrintFormatter` reads neither:
#   it prints into the rectangle it is given. So `ReportPdfPrinter` restates the
#   margins in Swift, and two truths about one thing will drift apart the first
#   time someone widens a margin to fit a table.
#
#   Drift here does not crash and does not warn. It silently prints a two-page
#   report on four pages, which is how patch -59 shipped.
#
#   This script has no opinion about which value is right. It only insists that
#   the template's `@page` margins are the printer's `pageMarginsMm`, and that
#   `.sheet`'s min-height is what those margins leave of an A4 sheet.
# =============================================================================

import os
import re
import sys

TEMPLATE = "report/report_template.html"
PRINTER = "ios/Potillus/ReportPdfPrinter.swift"

A4_HEIGHT_MM = 297


def repository_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def template_margins(css):
    """The four `@page` margins, in the CSS order: top, right, bottom, left."""
    match = re.search(
        r"@page\s*\{[^}]*margin:\s*"
        r"([\d.]+)mm\s+([\d.]+)mm\s+([\d.]+)mm\s+([\d.]+)mm",
        css,
    )
    if not match:
        return None
    return tuple(float(value) for value in match.groups())


def template_sheet_height(css):
    match = re.search(r"\.sheet\s*\{[^}]*min-height:\s*([\d.]+)mm", css, re.S)
    return float(match.group(1)) if match else None


def printer_margins(swift):
    """`pageMarginsMm = (top: 14.0, right: 12.0, bottom: 16.0, left: 12.0)`."""
    match = re.search(
        r"pageMarginsMm\s*=\s*\(\s*top:\s*([\d.]+)\s*,\s*right:\s*([\d.]+)\s*,"
        r"\s*bottom:\s*([\d.]+)\s*,\s*left:\s*([\d.]+)\s*\)",
        swift,
    )
    if not match:
        return None
    return tuple(float(value) for value in match.groups())


def main():
    root = repository_root()
    problems = []

    css = read(os.path.join(root, TEMPLATE))
    swift = read(os.path.join(root, PRINTER))

    in_css = template_margins(css)
    in_swift = printer_margins(swift)
    sheet = template_sheet_height(css)

    if in_css is None:
        problems.append(f"{TEMPLATE}: no `@page` margin rule of four millimetre values")
    if in_swift is None:
        problems.append(f"{PRINTER}: no `pageMarginsMm` tuple of four values")
    if sheet is None:
        problems.append(f"{TEMPLATE}: `.sheet` has no `min-height` in millimetres")

    if in_css and in_swift and in_css != in_swift:
        problems.append(
            f"the page margins disagree: {TEMPLATE} says "
            f"top {in_css[0]}, right {in_css[1]}, bottom {in_css[2]}, left {in_css[3]} mm, "
            f"while {PRINTER} says "
            f"top {in_swift[0]}, right {in_swift[1]}, bottom {in_swift[2]}, left {in_swift[3]} mm"
        )

    if in_css and sheet is not None:
        expected = A4_HEIGHT_MM - in_css[0] - in_css[2]
        if abs(sheet - expected) > 1e-9:
            problems.append(
                f"{TEMPLATE}: `.sheet` min-height is {sheet}mm, but the `@page` margins "
                f"leave {expected}mm of an A4 sheet. A sheet taller than its page "
                f"prints on two."
            )

    for problem in problems:
        print(f"check-report-paper: {problem}", file=sys.stderr)

    if problems:
        print(f"check-report-paper: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
