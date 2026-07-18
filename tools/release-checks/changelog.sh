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
#  release-checks/changelog.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 2 – CHANGELOG ENTRY
#
# WHY THIS MATTERS:
#   The CHANGELOG is the user-facing record of what changed.  A release without
#   a CHANGELOG entry violates the project's documentation contract and makes
#   it impossible to track what was introduced when.  Additionally, a heading
#   with no body (a "## " heading with the next "## " heading right below it) means
#   someone created the heading but forgot to write the actual content.
# =============================================================================
check_changelog() {
    section "2 / 15 — CHANGELOG ENTRY"

    local vname top_entry body_line_count

    vname=$(extract_version_name)
    top_entry=$(grep '^## v' "$CHANGELOG" | head -1 | sed 's/^## v//')

    # The version in the top entry must match versionName (also checked in §1,
    # but we repeat it here for a self-contained section).
    if [[ "$vname" != "$top_entry" ]]; then
        fail "Top CHANGELOG entry is 'v$top_entry' but versionName is '$vname'"
        return
    fi

    # Rule 6: the first non-empty line of the top entry is the git subject line
    # and must be ≤ 50 characters — git's own subject-length convention, so the
    # CHANGELOG heading can be reused verbatim as the release commit subject.
    # Subjects are ASCII English imperatives, so bash's byte-based ${#var} equals
    # the character count here.
    local subject subj_len
    subject=$(awk '/^## v/{seen=1; next} seen && NF {print; exit}' "$CHANGELOG")
    subj_len=${#subject}
    if (( subj_len > 50 )); then
        fail "CHANGELOG subject line is $subj_len chars (> 50): \"$subject\""
    else
        pass "CHANGELOG subject line ≤ 50 chars ($subj_len): \"$subject\""
    fi

    # Count non-empty, non-heading body lines between the top ## entry and the next ## entry.
    # awk prints lines that are between the first and second "^## " markers,
    # then we filter out blank lines and count what remains.
    body_line_count=$(awk '/^## /{count++; if (count==2) exit} count==1 && !/^## /' \
                         "$CHANGELOG" \
                     | grep -cv '^[[:space:]]*$' || true)

    if [[ "$body_line_count" -lt 1 ]]; then
        fail "CHANGELOG entry for v$vname exists but has no body text — add release notes"
    else
        pass "CHANGELOG v$vname has $body_line_count lines of release notes"
    fi
}
