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
#  release-checks/bestpractices-complete.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
#  OPT-IN — CODE COVERAGE (Kover)
# =============================================================================
#   Runs the build-breaking Kover verification (:app:koverVerify), whose bounds
#   are declared in app/build.gradle.kts (LINE >= 90, BRANCH >= 75 over the
#   JVM-unit-testable scope), and :app:koverXmlReport so the actual measured
#   figures can be shown next to the enforced floors. Skipped unless --coverage
#   is given, because it launches Gradle and executes the unit-test suite — far
#   slower than the static checks above, so the on-every-build Makefile `prereq`
#   path leaves it off. Release and CI runs pass --coverage to enforce the floor.
# =============================================================================
# SECTION 15 – BEST-PRACTICES BADGE COMPLETENESS
# =============================================================================
# WHY THIS MATTERS:
#   .bestpractices.json is the committed snapshot of the project's answers to
#   the OpenSSF Best Practices Badge (metal series: passing/silver/gold) and the
#   OSPS Baseline (level 1/2/3). `make bestpractices-json` now mirrors the FULL
#   upstream criteria set — every tracked criterion is present even when it is
#   unanswered — so the file doubles as a checklist. This gate makes the
#   checklist binding: it FAILS while any criterion is still unanswered, where
#   "unanswered" means (per the project decision recorded in this section):
#     * a status that is not one of Met / Unmet / N/A  (e.g. "?", "0",
#       "Unknown", empty), OR
#     * an EMPTY justification — except for the handful of criteria the badge
#       form gives no rationale field at all, listed under "no_justification"
#       in tools/bestpractices-levels.json, which are checked for status only.
#
# HOW IT WORKS:
#   The set of tracked criteria and the justification-exempt list both come from
#   tools/bestpractices-levels.json (the same map that annotates the .jsonc), so
#   this gate, the renderer and check-bestpractices-levels.py all agree on what
#   a criterion is. It skips gracefully (info + pass) when either the answers
#   file or the map is absent, per the project's gate-design rule.
# =============================================================================
check_bestpractices_complete() {
    section "15 / 15 — BEST-PRACTICES BADGE COMPLETENESS"

    local answers="../.bestpractices.json"
    local levels="../tools/bestpractices-levels.json"
    if [[ ! -f "$answers" ]]; then
        info ".bestpractices.json not present — badge completeness check skipped"
        pass "Badge completeness is answers-file-gated (nothing to verify without it)"
        return
    fi
    if [[ ! -f "$levels" ]]; then
        info "tools/bestpractices-levels.json not present — check skipped"
        pass "Badge completeness needs the level map (nothing to verify without it)"
        return
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping badge completeness check"
        return
    fi

    # One "criterion<TAB>reason" line per outstanding criterion; empty on a clean
    # pass. Guarded by `if` so the python exit status 1 on findings does not abort
    # under `set -e` (the SECTION 9 pattern).
    local findings
    if ! findings=$(python3 - "$answers" "$levels" <<'PYEND'
import json, sys

answers = json.load(open(sys.argv[1], encoding="utf-8"))
levels = json.load(open(sys.argv[2], encoding="utf-8"))

tracked = set(levels["metal"]) | set(levels["baseline"])
no_just = set(levels.get("no_justification", []))
ANSWERED = {"Met", "Unmet", "N/A"}

out = []
for criterion in sorted(tracked):
    status = str(answers.get(f"{criterion}_status", "")).strip()
    if status not in ANSWERED:
        out.append(f"{criterion}\tstatus is '{status or '(missing)'}' (need Met/Unmet/N/A)")
        continue
    if criterion not in no_just:
        justification = str(answers.get(f"{criterion}_justification", "")).strip()
        if not justification:
            out.append(f"{criterion}\tjustification is empty")

for line in out:
    print(line)
sys.exit(1 if out else 0)
PYEND
    ); then
        while IFS=$'\t' read -r criterion reason; do
            [[ -n "$criterion" ]] || continue
            fail "Badge criterion $criterion unanswered: $reason"
        done <<< "$findings"
    else
        pass "All tracked badge criteria are answered (status + justification)"
    fi
}
