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
#
# check-trackers.sh -- keep the static "0 trackers" README badge honest.
#
# WHAT IT DOES
#   Fetches the published Exodus Privacy report for de.godisch.potillus and
#   confirms it still lists zero trackers. Exodus statically audits the shipped
#   APK for known third-party trackers. The README carries a static
#   "εxodus 0 trackers" badge, and a static badge can silently rot if some
#   future dependency ever introduces a tracker. This check is the guard: if the
#   report is no longer zero, the badge -- and the app -- need attention.
#
# WHY IT IS A SEPARATE, MANUAL CHECK (not in check-static / the release gate)
#   It makes a live HTTP request to a third-party server, so it is neither
#   offline nor deterministic -- the same reasons check-reuse is kept out of
#   check-static. Run it locally before a release: `make check-trackers`.
#
# THREE DISTINCT OUTCOMES (never conflated)
#   exit 0  zero trackers                    -> prints OK
#   exit 1  one or more trackers reported    -> prints the count
#   exit 2  report unreachable / HTML changed -> asks for a manual check
#   Outcome 2 is the important one: a network hiccup or a redesigned Exodus page
#   must never be mistaken for a clean result, nor for a tracker regression.
#
# MAINTENANCE
#   The parser keys off Exodus' current markup (the count beside the "#trackers"
#   section link). If Exodus redesigns the page, this yields outcome 2 rather
#   than passing by accident -- update the grep below when that happens.
#
# =============================================================================

set -euo pipefail

readonly URL='https://reports.exodus-privacy.eu.org/en/reports/de.godisch.potillus/latest/'

# 1. Fetch the report. `-f` fails on HTTP errors, `-S` surfaces the reason, `-L`
#    follows redirects, `-m` bounds the wait. Any failure is outcome 2, so a
#    transport problem is never read as "zero trackers".
if ! html=$(curl -sSfL -m 30 -A 'potillus-check-trackers' "$URL"); then
    echo "check-trackers: could not fetch the Exodus report." >&2
    echo "check-trackers:   $URL" >&2
    echo "check-trackers: network problem or report unavailable -- verify manually." >&2
    exit 2
fi

# 2. Read the tracker count shown beside the report's "#trackers" section link.
#    The badge colour class varies (success when zero, danger otherwise), so we
#    match any colour and extract the number itself -- that way a non-zero count
#    is reported as its real value instead of looking like "not found".
count=$(printf '%s\n' "$html" \
    | grep -A1 '<a href="#trackers" class="section-link">' \
    | grep -oE '<span class="badge badge-pill badge-[a-z]+ reports">[0-9]+</span>' \
    | grep -oE '[0-9]+' \
    | head -n1 || true)

# 3. No number found means the page structure changed: outcome 2, not a pass.
if [[ -z "$count" ]]; then
    echo "check-trackers: could not locate the tracker count in the report." >&2
    echo "check-trackers: Exodus may have changed its HTML -- update this check." >&2
    exit 2
fi

# 4. Verdict.
if [[ "$count" -eq 0 ]]; then
    echo "check-trackers: OK -- Exodus reports 0 trackers."
else
    echo "check-trackers: FAIL -- Exodus reports ${count} tracker(s)." >&2
    echo "check-trackers: remove the tracker or correct the README badge." >&2
    exit 1
fi
