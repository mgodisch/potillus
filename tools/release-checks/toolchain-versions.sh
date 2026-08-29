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
#  release-checks/toolchain-versions.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 16 – TOOLCHAIN VERSIONS (install guides ↔ build files)
# =============================================================================
# WHY THIS MATTERS:
#   docs/INSTALL-ANDROID.md and docs/INSTALL-IOS.md open with a table telling a
#   newcomer which tools to install and at which version. Those numbers are
#   NOT authoritative anywhere in the guide: the build reads them from
#   android/Makefile, gradle-wrapper.properties, libs.versions.toml,
#   app/build.gradle.kts, make/release.mk, ios/Makefile, ios/project.yml and
#   Package.resolved. A version raised in one of those files leaves the guide
#   behind, and the failure lands on the one reader least able to diagnose it —
#   someone following a first-build walkthrough on a machine with nothing on it.
#
#   The number cannot simply be dropped from the guide and replaced by a
#   pointer: a reader who must be told to install a JDK is not helped by being
#   sent to a Gradle version catalogue. So the duplication stays and this check
#   guards it, the same shape as SECTION 14 for the OpenPGP fingerprint.
#
# HOW IT WORKS:
#   For each tool the check reads the value from its source file, finds the
#   tool's ROW in the guide's table, and asserts the value appears there. The
#   row is matched by its bold label, not the whole file: a bare grep for "21"
#   would pass on any page that happens to contain the number, which is exactly
#   the false pass a version check must not have.
#
#   Every lookup is guarded. A source file the check cannot read, or a value it
#   cannot extract, is reported as SKIPPED rather than failed — the check is
#   only ever as good as its inputs, and a wrong verdict is worse than none.
# =============================================================================

# Extract a value from a source file with a sed expression, or print nothing.
#
# $1 file, $2 sed script yielding the value on its own line.
_toolchain_value() {
    local file="$1" script="$2"
    [[ -f "$file" ]] || return 0
    sed -nE "$script" "$file" | head -1
}

# Assert that the guide's row for a tool carries the value the build uses.
#
# $1 guide file, $2 the row's bold label (e.g. "JDK"), $3 the expected value,
# $4 the source file, named in the failure message so the fix is obvious.
_toolchain_row_states() {
    local guide="$1" label="$2" value="$3" source_file="$4"
    if [[ -z "$value" ]]; then
        skip "$label: no version found in $source_file — guide not checked against it"
        return
    fi
    if [[ ! -f "$guide" ]]; then
        skip "$label: $guide not found"
        return
    fi
    local row
    row=$(grep -F "**$label**" "$guide" | head -1 || true)
    if [[ -z "$row" ]]; then
        fail "$guide has no table row for **$label** — the guide and $source_file can no longer be compared"
    elif [[ "$row" == *"$value"* ]]; then
        pass "$label $value in $(basename "$guide") matches $source_file"
    else
        fail "$label is $value in $source_file, and $(basename "$guide") says otherwise — a first-time reader would install the wrong version"
    fi
}

# Assert that a sentence of prose carries the value the build uses.
#
# The counterpart of _toolchain_row_states for a file with no table. The
# sentence is found by an anchor phrase rather than a bold label, which is
# looser: prose can be reworded, and a rewording that drops the anchor is
# reported as a missing sentence rather than as a stale value. That is the right
# way round -- it asks for a look instead of passing quietly.
#
# $1 file, $2 anchor phrase identifying the sentence, $3 the string the sentence
# must contain, $4 the source file, named in the failure message.
_toolchain_prose_states() {
    local doc="$1" anchor="$2" needle="$3" source_file="$4"
    if [[ -z "$needle" ]]; then
        skip "$anchor: no version found in $source_file — $(basename "$doc") not checked against it"
        return
    fi
    if [[ ! -f "$doc" ]]; then
        skip "$anchor: $doc not found"
        return
    fi
    local line
    line=$(grep -F "$anchor" "$doc" | head -1 || true)
    if [[ -z "$line" ]]; then
        fail "$(basename "$doc") no longer carries the sentence starting \"$anchor\" — the platform floor it states cannot be compared with $source_file"
    elif [[ "$line" == *"$needle"* ]]; then
        pass "\"$needle\" in $(basename "$doc") matches $source_file"
    else
        fail "$source_file gives \"$needle\", and $(basename "$doc") states a different platform floor — the first page a reader sees would be wrong"
    fi
}

check_toolchain_versions() {
    section "16 / 16 — TOOLCHAIN VERSIONS"
    # ── Android ──────────────────────────────────────────────────────────────
    _toolchain_row_states "$INSTALL_ANDROID" "JDK" \
        "$(_toolchain_value "Makefile" 's/^JAVA_VERSION[[:space:]]*:=[[:space:]]*([0-9]+).*/\1/p')" \
        "android/Makefile"

    # The wrapper pins Gradle inside a distribution URL, so the version is the
    # substring between "gradle-" and "-bin.zip" rather than a field of its own.
    _toolchain_row_states "$INSTALL_ANDROID" "Gradle" \
        "$(_toolchain_value "gradle/wrapper/gradle-wrapper.properties" \
            's|.*/gradle-([0-9]+(\.[0-9]+)*)-bin\.zip.*|\1|p')" \
        "gradle/wrapper/gradle-wrapper.properties"

    # AGP and Kotlin share one table row ("Android Gradle Plugin / Kotlin"), so
    # both values are asserted against the same label.
    _toolchain_row_states "$INSTALL_ANDROID" "Android Gradle Plugin / Kotlin" \
        "$(_toolchain_value "gradle/libs.versions.toml" 's/^agp[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p')" \
        "gradle/libs.versions.toml (agp)"
    _toolchain_row_states "$INSTALL_ANDROID" "Android Gradle Plugin / Kotlin" \
        "$(_toolchain_value "gradle/libs.versions.toml" 's/^kotlin[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p')" \
        "gradle/libs.versions.toml (kotlin)"

    # compileSdk appears in the SDK row as "platforms;android-<N>".
    _toolchain_row_states "$INSTALL_ANDROID" "Android SDK" \
        "$(_toolchain_value "$BUILD_GRADLE" 's/^[[:space:]]*compileSdk[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p')" \
        "$BUILD_GRADLE (compileSdk)"

    _toolchain_row_states "$INSTALL_ANDROID" "osv-scanner" \
        "$(_toolchain_value "../make/release.mk" 's/^OSV_SCANNER_VERSION[[:space:]]*:=[[:space:]]*([0-9][^[:space:]]*).*/\1/p')" \
        "make/release.mk"

    # ── iOS ──────────────────────────────────────────────────────────────────
    _toolchain_row_states "$INSTALL_IOS" "Xcode" \
        "$(_toolchain_value "../make/release.mk" 's/^XCODE_VERSION[[:space:]]*:=[[:space:]]*([0-9]+).*/\1/p')" \
        "make/release.mk"

    _toolchain_row_states "$INSTALL_IOS" "SwiftLint" \
        "$(_toolchain_value "../ios/Makefile" 's/^SWIFTLINT_VERSION[[:space:]]*:=[[:space:]]*([0-9][^[:space:]]*).*/\1/p')" \
        "ios/Makefile"

    _toolchain_row_states "$INSTALL_IOS" "GRDB.swift" \
        "$(_toolchain_value "../ios/PotillusKit/Package.resolved" 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')" \
        "ios/PotillusKit/Package.resolved"

    _toolchain_row_states "$INSTALL_IOS" "osv-scanner" \
        "$(_toolchain_value "../make/release.mk" 's/^OSV_SCANNER_VERSION[[:space:]]*:=[[:space:]]*([0-9][^[:space:]]*).*/\1/p')" \
        "make/release.mk"

    # ── README: the platform floor the landing page advertises ───────────────
    #
    # Unlike the guides, the README states the floor in a sentence, so the
    # anchor is that sentence's opening rather than a table label. The anchor
    # runs as far as "Android" on purpose: "The app runs on" alone also matches
    # the earlier "The app runs on both Android and iOS, and is available on",
    # and the check would then read the wrong sentence and fail on a correct
    # document.
    #
    # ONE THING THIS CANNOT CHECK, stated so it is not mistaken for covered: the
    # README also names the Android RELEASE ("Android 11") beside the API level,
    # and no file in this repository maps 30 to 11. Raising minSdk therefore
    # fails this check on the API level and leaves the marketing name to a human.
    _toolchain_prose_states "$README" "The app runs on Android" \
        "API $(_toolchain_value "$BUILD_GRADLE" 's/^[[:space:]]*minSdk[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p')" \
        "$BUILD_GRADLE (minSdk)"

    # project.yml states the deployment target as "17.0"; the README says
    # "iOS 17", which is what a reader needs. Compare the major version.
    _toolchain_prose_states "$README" "The app runs on Android" \
        "iOS $(_toolchain_value "../ios/project.yml" 's/^[[:space:]]*iOS:[[:space:]]*"?([0-9]+).*/\1/p')" \
        "ios/project.yml (deploymentTarget)"
}
