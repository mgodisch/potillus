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
#  release-checks/backup-version.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 8 – BACKUP FORMAT VERSION CONSISTENCY
#
# WHY THIS MATTERS:
#   BackupManager.BACKUP_VERSION controls which backup files are accepted.
#   When the JSON schema changes (e.g. a new field is added that older apps
#   cannot read), BACKUP_VERSION must be incremented.  The KDoc comment above
#   the constant documents the version history; if the constant is bumped but
#   the history comment is not updated, future developers cannot tell what
#   changed between versions.
#
#   This check is heuristic: it verifies that BACKUP_VERSION (e.g. 3) appears
#   in the migration history comment immediately above the constant.  It does
#   not verify that the history is accurate, only that it was edited at all.
# =============================================================================
check_backup_version() {
    section "8 / 15 — BACKUP FORMAT VERSION CONSISTENCY"

    local backup_version
    backup_version=$(grep 'private const val BACKUP_VERSION\s*=' "$BACKUP_MANAGER_KT" \
                         | grep -oE '[0-9]+' | head -1)

    if [[ -z "$backup_version" ]]; then
        fail "Could not parse BACKUP_VERSION from $BACKUP_MANAGER_KT"
        return
    fi

    pass "BACKUP_VERSION = $backup_version"

    # Extract the 30 lines above the BACKUP_VERSION constant and check that
    # the version number appears in a migration history comment.
    local line_number history_block
    line_number=$(grep -n 'private const val BACKUP_VERSION' "$BACKUP_MANAGER_KT" | head -1 | cut -d: -f1)

    if [[ -z "$line_number" ]]; then
        warn "Cannot locate BACKUP_VERSION line — skip history doc check"
        return
    fi

    local start=$(( line_number > 30 ? line_number - 30 : 1 ))
    history_block=$(sed -n "${start},${line_number}p" "$BACKUP_MANAGER_KT")

    # The history comment should mention version N with an arrow (→) or a number
    # in a pattern like "2 → added …" or "version 2" or "v2".
    if echo "$history_block" | grep -qE "(^|\s)${backup_version}(\s|→|:)"; then
        pass "BACKUP_VERSION $backup_version is mentioned in the history KDoc above the constant"
    else
        warn "BACKUP_VERSION = $backup_version but version $backup_version does not appear in the history comment above — update the migration notes"
    fi
}
