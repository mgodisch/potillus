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
#  release-checks/version-consistency.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================



# =============================================================================
# SECTION 1 – VERSION CONSISTENCY
#
# WHY THIS MATTERS:
#   Three places must carry the same version string to avoid user confusion:
#     • versionName (shown in Android Settings → Apps)
#     • CHANGELOG.md top entry (release documentation)
#     • README.md title line (first thing visitors see)
#   A mismatch here is a real hazard: an APK built with a versionName that
#   disagrees with the CHANGELOG or README misleads users.
#
#   versionCode must be a plain integer ≥ 1.  It is checked separately from
#   versionName because it obeys different rules (monotonically increasing
#   integer vs. human-readable string).
#
#   FASTLANE COUPLING:
#     The store listings (F-Droid and Google Play via `fastlane supply`) carry
#     a per-locale "what's new" note named after the integer versionCode, i.e.
#     ../fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt. That file
#     name is the ONLY place a version number is embedded in the fastlane tree
#     (titles and descriptions deliberately omit the version to avoid churn), so
#     it must track versionCode. Every locale present in the tree must ship the
#     note for the current versionCode, or the store would advertise stale or
#     missing release notes for the APK actually being shipped. In addition, all
#     locale directories must carry the SAME set of <versionCode>.txt notes
#     (locale parity), so a note added to one language but forgotten in another
#     is caught before release.
# =============================================================================
check_version_consistency() {
    section "1 / 15 — VERSION CONSISTENCY"

    local vname vcode changelog_top readme_version

    # Extract values from each source
    vname=$(extract_version_name)
    vcode=$(extract_version_code)
    # Top-most "## vX.Y" line in CHANGELOG (strip the "## v" prefix)
    changelog_top=$(grep '^## v' "$CHANGELOG" | head -1 | sed 's/^## v//')
    # "vX.Y" in the README title line
    readme_version=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$README" | head -1 | tr -d 'v')

    # versionName: must be present and in "major.minor" format
    if [[ -z "$vname" ]]; then
        fail "versionName is empty in $BUILD_GRADLE"
    elif [[ ! "$vname" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        fail "versionName '$vname' does not match the expected 'major.minor.patch' format"
    else
        pass "versionName = $vname"
    fi

    # versionCode: must be a non-zero integer
    if [[ -z "$vcode" ]]; then
        fail "versionCode is missing in $BUILD_GRADLE"
    elif [[ ! "$vcode" =~ ^[0-9]+$ ]] || [[ "$vcode" -lt 1 ]]; then
        fail "versionCode '$vcode' is not a positive integer"
    else
        pass "versionCode = $vcode"
    fi

    # Cross-check: versionName must match the top CHANGELOG entry
    if [[ "$vname" != "$changelog_top" ]]; then
        fail "versionName '$vname' ≠ top CHANGELOG entry 'v$changelog_top' — update one or the other"
    else
        pass "versionName matches top CHANGELOG entry (v$vname)"
    fi

    # ── Cross-check: ONE versionCode INCREMENT PER RELEASE ────────────────────
    # RULE (since the anchor below): every "## vX.Y.Z" heading added to
    # CHANGELOG.md must be accompanied by EXACTLY ONE increment of versionCode.
    # Equivalently, with the anchor as a fixed reference point:
    #
    #     expected versionCode = ANCHOR_VERSION_CODE
    #                          + (count of "## vX.Y.Z" entries strictly ABOVE
    #                             the anchored version in CHANGELOG.md)
    #
    # The anchor (android/version-anchor) freezes the pre-rule history, during
    # which some doc-only releases deliberately shared a versionCode. Only
    # entries above the anchored version are subject to the strict 1:1 rule.
    #
    # WHEN YOU ADD A NEW "## vX.Y.Z" TO CHANGELOG.md:
    #   1. bump versionCode in build.gradle.kts by exactly 1, AND
    #   2. add ../fastlane/metadata/android/<locale>/changelogs/<newCode>.txt
    #      for every locale (enforced by the fastlane check further below).
    if [[ ! -f "$ANCHOR_FILE" ]]; then
        warn "No $ANCHOR_FILE — skipping one-increment-per-release check"
    elif [[ -z "$vcode" || ! "$vcode" =~ ^[0-9]+$ ]]; then
        warn "versionCode unusable — skipping one-increment-per-release check"
    else
        local anchor_name anchor_code
        anchor_name=$(grep -E '^ANCHOR_VERSION_NAME=' "$ANCHOR_FILE" | head -1 | cut -d= -f2 | tr -d '[:space:]')
        anchor_code=$(grep -E '^ANCHOR_VERSION_CODE=' "$ANCHOR_FILE" | head -1 | cut -d= -f2 | tr -d '[:space:]')

        if [[ -z "$anchor_name" || -z "$anchor_code" || ! "$anchor_code" =~ ^[0-9]+$ ]]; then
            fail "$ANCHOR_FILE is malformed (need ANCHOR_VERSION_NAME and integer ANCHOR_VERSION_CODE)"
        else
            # Ordered list of all release headings, top (newest) first.
            local headings releases_above anchor_seen=0 line v
            mapfile -t headings < <(grep -E '^## v[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" | sed 's/^## v//')

            # Confirm the anchor version actually appears, and count entries above it.
            releases_above=0
            for v in "${headings[@]}"; do
                if [[ "$v" == "$anchor_name" ]]; then
                    anchor_seen=1
                    break                 # everything before this was "above" (newer)
                fi
                releases_above=$((releases_above + 1))
            done

            if [[ "$anchor_seen" -ne 1 ]]; then
                fail "anchor version 'v$anchor_name' from $ANCHOR_FILE not found in $CHANGELOG — re-anchor or fix the changelog"
            else
                local expected_code=$((anchor_code + releases_above))
                if [[ "$vcode" -ne "$expected_code" ]]; then
                    fail "versionCode $vcode ≠ expected $expected_code \
(anchor v$anchor_name=$anchor_code + $releases_above release(s) since): each new \
CHANGELOG version must bump versionCode by exactly 1"
                else
                    pass "versionCode $vcode matches one-increment-per-release rule (anchor v$anchor_name=$anchor_code + $releases_above)"
                fi
            fi
        fi
    fi

    # Cross-check: versionName must match README title
    if [[ -z "$readme_version" ]]; then
        warn "Could not parse a version number from the README.md title line"
    elif [[ "$vname" != "$readme_version" ]]; then
        fail "versionName '$vname' ≠ README.md version '$readme_version' — update README.md header"
    else
        pass "versionName matches README.md title (v$vname)"
    fi

    # Cross-check: fastlane release notes are coupled to versionCode by filename.
    # If no fastlane tree exists yet this is only advisory (the project may not
    # publish to a store); once a locale directory exists it MUST carry the note
    # for the current versionCode. These translated store changelogs are only
    # needed when actually cutting a release, so they are enforced under --release
    # (which `make release-android` passes) and deferred on the every-build path so
    # `make android` does not demand them. The note keeps the line green rather
    # than warning, so it survives --Werror.
    if [[ "$RELEASE" -ne 1 ]]; then
        pass "fastlane: per-locale store changelogs deferred to 'make release-android' (run with --release to enforce)"
    elif [[ ! -d "$FASTLANE_DIR" ]]; then
        warn "No fastlane metadata tree at $FASTLANE_DIR — skipping store-changelog check"
    elif [[ -z "$vcode" ]]; then
        warn "versionCode unknown — skipping fastlane changelog check"
    else
        local locale_dir locale changelog_file missing=0 checked=0
        for locale_dir in "$FASTLANE_DIR"/*/; do
            [[ -d "$locale_dir" ]] || continue
            locale=$(basename "$locale_dir")
            changelog_file="${locale_dir}changelogs/${vcode}.txt"
            checked=$((checked + 1))
            if [[ ! -f "$changelog_file" ]]; then
                fail "fastlane: missing $changelog_file for versionCode $vcode (locale '$locale')"
                missing=$((missing + 1))
            fi
        done

        # Cross-check 2: LOCALE PARITY (history locales only). The locales in
        # HISTORY_LOCALES (en-US, de-DE) maintain the FULL per-versionCode
        # changelog history, so they must all carry the SAME set of <code>.txt
        # notes — this catches a note added to one but forgotten in the other.
        # Every OTHER listing locale is intentionally listing-only: it ships just
        # the CURRENT versionCode note (already required by cross-check 1 above)
        # and reuses the en-US screenshots, so it is EXEMPT from full-history
        # parity. Without this exemption, adding a new listing locale would demand
        # a back-dated changelog file for every historical versionCode it never
        # actually shipped under. The reference set is therefore the union over
        # history locales only.
        local all_files f desync=0 hl
        all_files=$(for hl in $HISTORY_LOCALES; do
            [[ -d "$FASTLANE_DIR/$hl/changelogs" ]] || continue
            ls "$FASTLANE_DIR/$hl/changelogs" 2>/dev/null | grep -E '^[0-9]+\.txt$' || true
        done | sort -u)
        for hl in $HISTORY_LOCALES; do
            [[ -d "$FASTLANE_DIR/$hl" ]] || continue
            for f in $all_files; do
                if [[ ! -f "$FASTLANE_DIR/$hl/changelogs/${f}" ]]; then
                    fail "fastlane: history locale '$hl' is missing changelog $f that another history locale has (changelogs out of sync)"
                    desync=1
                fi
            done
        done

        if [[ "$checked" -eq 0 ]]; then
            warn "fastlane tree present but contains no locale directories"
        elif [[ "$missing" -eq 0 && "$desync" -eq 0 ]]; then
            pass "fastlane: versionCode $vcode note present in all $checked locale(s); full history in sync across history locales ($HISTORY_LOCALES)"
        fi
    fi
}
