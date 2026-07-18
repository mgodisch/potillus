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
# version.  See <https://www.gnu.org/licenses/> and the accompanying COPYING.md.
#
# =============================================================================
#  release-checks/lib.sh -- shared library for tools/release-check.sh
# =============================================================================
#
#  SOURCED (never executed) by tools/release-check.sh and by the individual
#  per-check scripts. It provides everything the checks share: the colour codes
#  and pass/fail/warn counters, the pass/fail/warn/info/section output helpers,
#  the file-path constants (relative to android/, into which the runner cd's
#  before sourcing this), and the extract_version_* helpers. It defines no check
#  and runs nothing on its own.
# =============================================================================

# ── Colour and output helpers (identical to the Makefile for visual consistency) ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# Counters for the final summary
FAILS=0
WARNS=0

# coloured, prefixed message.
pass() { echo -e "  ${GREEN}✓${NC} $*";          PASSES=$(( PASSES + 1 )); }
fail() { echo -e "  ${RED}✗ FAIL:${NC} $*";      FAILS=$(( FAILS  + 1 )); }
warn() { echo -e "  ${YELLOW}⚠ WARN:${NC} $*";   WARNS=$(( WARNS  + 1 )); }
info() { echo -e "  ${BLUE}▶${NC} $*"; }

# Section header – printed before each group of related checks
section() {
    echo ""
    echo -e "${BOLD}━━━  $*  ━━━${NC}"
}

# ── File paths (all relative to repo root) ────────────────────────────────────
BUILD_GRADLE="app/build.gradle.kts"
# CHANGELOG.md and README.md live at the repository root, one level above the
# android/ directory the script cd'd into above, so reference them with `../`.
# build.gradle.kts remains relative to android/ (i.e. under app/).
CHANGELOG="../CHANGELOG.md"
README="../README.md"
CONTRIBUTING="../CONTRIBUTING.md"
PRIVACY="../PRIVACY.md"
APPDB_KT="app/src/main/kotlin/de/godisch/potillus/data/db/AppDatabase.kt"
BACKUP_MANAGER_KT="app/src/main/kotlin/de/godisch/potillus/util/BackupManager.kt"
SUPPORTED_LOCALES_KT="app/src/main/kotlin/de/godisch/potillus/l10n/SupportedLocales.kt"
LOCALE_CONFIG_XML="app/src/main/res/xml/locale_config.xml"
BASE_STRINGS_XML="app/src/main/res/values/strings.xml"
SOURCE_ROOT="app/src/main/kotlin"
SCHEMAS_DIR="app/schemas/de.godisch.potillus.data.db.AppDatabase"
# Fastlane store-metadata tree (used by both F-Droid and `fastlane supply`).
# Per-locale release notes are named after the integer versionCode, e.g.
# ../fastlane/metadata/android/en-US/changelogs/65.txt — see SECTION 1.
FASTLANE_DIR="../fastlane/metadata/android"
# Listing locales that maintain the FULL per-versionCode changelog history. All
# OTHER fastlane locales are listing-only: they ship the current versionCode note
# and reuse en-US screenshots, and are exempt from full-history parity. See the
# locale-parity cross-check in SECTION 1.
HISTORY_LOCALES="en-US de-DE"
# Baseline coupling versionName ↔ versionCode for the one-increment-per-release
# rule. See the file's own header and SECTION 1 for the derivation.
ANCHOR_FILE="version-anchor"

# =============================================================================
# HELPER: extract_version_name
#   Reads versionName from build.gradle.kts.
#   Strips surrounding quotes so callers get a plain string like "0.56.0".
# =============================================================================
extract_version_name() {
    # grep for the line that sets versionName (not versionNameSuffix),
    # then extract the quoted value, then strip the quotes.
    grep 'versionName\s*=' "$BUILD_GRADLE" \
        | grep -v 'Suffix' \
        | grep -o '"[^"]*"' \
        | tr -d '"' \
        | head -1
}

# =============================================================================
# HELPER: extract_version_code
#   Reads versionCode (plain integer) from build.gradle.kts.
# =============================================================================
extract_version_code() {
    grep 'versionCode\s*=' "$BUILD_GRADLE" \
        | grep -v '//' \
        | grep -oE '[0-9]+' \
        | head -1
}

# =============================================================================
# HELPER: extract_db_version
#   Reads the Room @Database(version = N) constant from AppDatabase.kt.
# =============================================================================
extract_db_version() {
    grep 'version\s*=' "$APPDB_KT" \
        | grep -v '//' \
        | grep -oE '[0-9]+' \
        | head -1
}
