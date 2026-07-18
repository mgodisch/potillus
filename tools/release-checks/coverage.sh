#!/usr/bin/env bash
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
#  release-checks/coverage.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


check_coverage() {
    section "COVERAGE — Kover verification (opt-in: --coverage)"

    if [[ "$COVERAGE" -ne 1 ]]; then
        info "Skipped (run with --coverage to enforce :app:koverVerify)"
        return
    fi

    if [[ ! -x ./gradlew ]]; then
        fail "gradlew not found or not executable in $(pwd) — cannot run the coverage gate"
        return
    fi

    info "Running ./gradlew :app:koverXmlReport :app:koverVerify (this runs the unit-test suite)…"
    if ./gradlew --console=plain --quiet :app:koverXmlReport :app:koverVerify; then
        # Report the actual figures alongside the enforced floors. The values are
        # read from the XML report koverXmlReport just produced; if it cannot be
        # located or parsed, fall back to naming the floors only.
        local report figures
        report="$(find app/build/reports/kover -maxdepth 2 -name '*.xml' 2>/dev/null | head -1)"
        figures=""
        if [[ -n "$report" ]]; then
            figures="$(python3 - "$report" <<'PYEND' 2>/dev/null
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    sys.exit(0)
def pct(unit):
    for c in root.findall("counter"):
        if c.get("type") == unit:
            missed, covered = int(c.get("missed")), int(c.get("covered"))
            total = missed + covered
            return f"{100.0 * covered / total:.1f}%" if total else "n/a"
    return "n/a"
print(f"LINE = {pct('LINE')} >= 90, BRANCH = {pct('BRANCH')} >= 75")
PYEND
)"
        fi
        if [[ -n "$figures" ]]; then
            pass "Coverage floors met ($figures; see app/build.gradle.kts)"
        else
            pass "Coverage floors met (LINE >= 90, BRANCH >= 75; see app/build.gradle.kts)"
        fi
    else
        fail "koverVerify failed — coverage dropped below the enforced floor (LINE 90 / BRANCH 75)"
    fi
}
