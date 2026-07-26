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
"""check-report-labels.py — every KPI label fits its tile on one line.

WHY THIS EXISTS
    The report's KPI grid puts four tiles in a row and lets each label wrap. A
    label that needs two lines makes its whole row taller, and four rows of that
    grew sheet one by 35pt in Greek, Russian and Italian — enough to push the
    page footer onto a page of its own and, because the printer drew only the
    pages the renderer had counted, to drop the second sheet from the exported
    file entirely. The reader lost the drink categories, the time-of-day pattern
    and the weekday profile, and nothing said so.

    The cure was to shorten the four longest labels in sixteen languages and to
    give the tile more room. Neither survives on its own: the next translation,
    or a padding tweak made for looks, puts a label over the edge again. This is
    the check that notices.

WHAT IT MEASURES
    The three template values that decide how much room a label has -- the grid
    gap, the tile's horizontal padding and the label font size -- are read from
    report/report_template.html rather than restated here, so a change there is
    a change to this check. The usable width follows from them:

        tile   = (type area - 3 * gap) / 4
        usable = tile - 2 * padding

    Every label is then measured with a per-script average character width,
    calibrated against real exported PDFs (Latin 4.81pt, Cyrillic 5.13pt, Greek
    5.00pt, CJK 9.6pt at 7.5pt type, scaled linearly with the font size).

WHAT IT IS NOT
    Not a text shaper. The estimate is an average, not a glyph-by-glyph advance,
    so it is right to a few points and no better. The margin it demands is set
    accordingly: a label is reported at the usable width, and the values chosen
    in the template leave the widest label about 5pt of room. A label that lands
    within a point or two of the limit deserves a rendered PDF, not an argument
    with this script.
"""

import re
import sys

from potillus_repo import repo_root

ROOT = repo_root()
TEMPLATE = ROOT / "report/report_template.html"
CATALOG = ROOT / "ios/PotillusKit/Sources/PotillusKit/Domain/ReportLabelsCatalog.swift"
DEFAULTS = ROOT / "ios/PotillusKit/Sources/PotillusKit/Domain/ReportLabels.swift"

# A4 width minus the @page left and right margins (12mm each), in points.
TYPE_AREA_PT = 595.0 - 2 * 34.0

# Average advance per character at 7.5pt, measured off exported reports.
WIDTH_AT_7_5 = {"latin": 4.81, "cyrillic": 5.13, "greek": 5.00, "cjk": 9.6}


def script_of(ch):
    o = ord(ch)
    if 0x0400 <= o <= 0x04FF:
        return "cyrillic"
    if 0x0370 <= o <= 0x03FF:
        return "greek"
    if o > 0x2E7F:
        return "cjk"
    return "latin"


def text_width(text, font_pt):
    scale = font_pt / 7.5
    return sum(WIDTH_AT_7_5[script_of(ch)] for ch in text) * scale


def geometry():
    """Reads gap, horizontal padding and label size out of the template."""
    css = TEMPLATE.read_text(encoding="utf-8")
    gap = re.search(r"\.kpis\s*\{[^}]*gap:\s*([\d.]+)pt", css)
    pad = re.search(r"\.kpi\s*\{[^}]*padding:\s*[\d.]+pt\s+([\d.]+)pt", css, re.S)
    font = re.search(r"\.kpi\s+\.lab\s*\{[^}]*font-size:\s*([\d.]+)pt", css)
    missing = [n for n, m in (("gap", gap), ("padding", pad), ("font-size", font)) if not m]
    if missing:
        raise SystemExit(
            f"check-report-labels: could not read {', '.join(missing)} from "
            f"{TEMPLATE.relative_to(ROOT)}; the KPI rules were renamed or reshaped."
        )
    return float(gap.group(1)), float(pad.group(1)), float(font.group(1))


def labels():
    """Every KPI label, as (language, field, text)."""
    out = []
    text = DEFAULTS.read_text(encoding="utf-8")
    for field, value in re.findall(r'public var (kpi[A-Za-z0-9]*)\s*=\s*"((?:[^"\\]|\\.)*)"', text):
        out.append(("en", field, value))
    text = CATALOG.read_text(encoding="utf-8")
    for lang, body in re.findall(
        r"private mutating func apply([a-zA-Z\-]+)\(\)\s*\{(.*?)\n    \}", text, re.S
    ):
        for field, value in re.findall(r'self\.(kpi[A-Za-z0-9]*)\s*=\s*"((?:[^"\\]|\\.)*)"', body):
            out.append((lang, field, value))
    return out


def main():
    gap, padding, font = geometry()
    tile = (TYPE_AREA_PT - 3 * gap) / 4
    usable = tile - 2 * padding

    found = labels()
    if not found:
        print("check-report-labels: no KPI labels found; the catalogue moved.", file=sys.stderr)
        return 1

    over = [
        (text_width(value, font), lang, field, value)
        for lang, field, value in found
        if text_width(value, font) > usable
    ]
    for width, lang, field, value in sorted(over, reverse=True):
        print(
            f"check-report-labels: [{lang}] {field} needs {width:.0f}pt of "
            f"{usable:.0f}pt and would wrap: {value!r}",
            file=sys.stderr,
        )
    if over:
        print(
            f"check-report-labels: {len(over)} label(s) too wide for a "
            f"{usable:.0f}pt tile; shorten them or widen the tile.",
            file=sys.stderr,
        )
        return 1

    widest = max(text_width(v, font) for _, _, v in found)
    print(
        f"check-report-labels: OK ({len(found)} labels, widest {widest:.0f}pt, "
        f"tile {usable:.0f}pt)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
