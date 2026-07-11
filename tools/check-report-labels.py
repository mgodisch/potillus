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
#
# Guards ReportLabelsCatalog.swift, which is generated and therefore excluded from
# SwiftLint. Two things must hold:
#
#   1. The committed file matches what the generator produces now. If Android's
#      report strings changed, or someone hand-edited the file, this catches the
#      drift — the whole point of generating it is that it cannot silently disagree
#      with Android.
#   2. Every language's `\\($0)` interpolation count matches English, so a harvested
#      closure with a dropped placeholder cannot crash the report at print time.
# =============================================================================

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "ios/PotillusKit/Sources/PotillusKit/Domain/ReportLabelsCatalog.swift"
GENERATOR = ROOT / "tools/build-report-labels.py"


def regeneration_matches():
    """Runs the generator to a temp path and compares byte for byte."""
    committed = CATALOG.read_text(encoding="utf-8")
    backup = committed
    try:
        subprocess.run([sys.executable, str(GENERATOR)], check=True,
                       capture_output=True, cwd=str(ROOT))
        regenerated = CATALOG.read_text(encoding="utf-8")
    finally:
        CATALOG.write_text(backup, encoding="utf-8")
    return committed == regenerated


def closure_placeholder_problems():
    """Each language's closures must carry the same `\\($0)` count as English."""
    text = CATALOG.read_text(encoding="utf-8")
    problems = []
    # closures look like:  self.kpiBinge = { "... \($0) ..." }
    pattern = re.compile(r'self\.(\w+) = \{ "((?:[^"\\]|\\.)*)" \}')
    per_lang = {}
    for name, body in pattern.findall(text):
        count = len(re.findall(r"\\\(\$0\)", body))
        per_lang.setdefault(name, []).append(count)
    for name, counts in per_lang.items():
        if len(set(counts)) != 1:
            problems.append(f"closure {name!r} has inconsistent \\($0) counts: {counts}")
    return problems


def main():
    problems = []
    if not regeneration_matches():
        problems.append(
            "ReportLabelsCatalog.swift is stale — run tools/build-report-labels.py "
            "and commit the result"
        )
    problems.extend(closure_placeholder_problems())
    for line in problems:
        print(f"check-report-labels: {line}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
