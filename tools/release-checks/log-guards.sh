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
#  release-checks/log-guards.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 6 – LOG CALL GUARDS
#
# WHY THIS MATTERS:
#   android.util.Log.* calls in release builds leak internal state into device
#   logcat.  Health-sensitive apps such as this one must never write consumption
#   data to logcat in production.  Every Log call in the main source set must
#   be wrapped in if (BuildConfig.DEBUG) so R8 compiles them away completely
#   in release builds.  Log calls in test source sets are exempt.
# =============================================================================
check_log_guards() {
    section "6 / 15 — LOG CALL GUARDS"

    # Find all Log.* calls in the main source set
    local unguarded=""

    while IFS= read -r match; do
        # Extract file and line number
        local file line
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)

        # Read a window of lines around the Log call to check for a
        # BuildConfig.DEBUG guard on the same or preceding line(s).
        # We look back up to 3 lines to handle multi-line if blocks.
        local window
        window=$(sed -n "$((line > 3 ? line-3 : 1)),${line}p" "$file" 2>/dev/null)

        if ! echo "$window" | grep -q "BuildConfig\.DEBUG"; then
            unguarded+="    ${file}:${line}\n"
        fi
    done < <(grep -rn "Log\.\(v\|d\|i\|w\|e\|wtf\)" "$SOURCE_ROOT" \
                 | grep -v '^.*//.*Log\.' \
                 | grep -oE '^[^:]+:[0-9]+' || true)

    if [[ -n "$unguarded" ]]; then
        fail "Log calls without BuildConfig.DEBUG guard in main source:"
        echo -e "$unguarded" | grep -v '^$' | while IFS= read -r line; do
            echo -e "  ${RED}$line${NC}"
        done
    else
        pass "All Log calls in main source are guarded with BuildConfig.DEBUG"
    fi
}
