#!/usr/bin/env bash
# vim: set et ts=4:
# =============================================================================
# Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
# =============================================================================

# =============================================================================
#  release-check.sh – Potillus release readiness checker
# =============================================================================
#
# PURPOSE
#   Verifies all invariants that must hold before a new Potillus release is
#   tagged. Run this script after completing all code changes and before
#   calling `git tag`. It is a pure read-only check: it never modifies any
#   file.
#
# USAGE
#   chmod +x tools/release-check.sh      # once
#   tools/release-check.sh               # run from the android/ directory
#   tools/release-check.sh --Werror      # treat warnings as errors
#
#   The script self-anchors to android/ (it lives in android/tools/), so it can
#   also be invoked from anywhere, e.g. `bash android/tools/release-check.sh`.
#   It additionally runs automatically on every build: the android/Makefile
#   `prereq` target invokes it (with --Werror) via the `release-check` target,
#   so a failing invariant — or, under --Werror, any warning — aborts the build.
#
# OPTIONS
#   --Werror   Treat warnings as errors: exit non-zero if any warning is
#              emitted, even when no hard FAIL occurred.
#
# EXIT CODES
#   0  All checks passed (warnings allowed unless --Werror is given).
#   1  At least one FAIL (or, under --Werror, at least one warning); NOT safe to
#      tag.
#   2  Invalid command-line option.
#
# CHECKS PERFORMED
#   The script is organised into eight sections that mirror the project's
#   known release-time error categories (documented in CONTRIBUTING.md §6):
#
#   1. VERSION CONSISTENCY
#      The versionName in build.gradle.kts, the top CHANGELOG.md entry, the
#      README.md title line, and the proguard-rules.pro header comment must
#      all carry the same version string.  versionCode must be ≥ 1 and must
#      be a plain integer (no alphabetic suffix).
#
#   2. CHANGELOG
#      The top-most ## vX.Y.Z entry must match versionName and must have at
#      least one non-empty body line below it (not just a heading with nothing
#      after it).
#
#   3. ROOM DATABASE MIGRATIONS
#      When the @Database version constant in AppDatabase.kt is N, there must
#      be a MIGRATION_(N-1)_N object declared in the same file, and both the
#      schemas/(N-1).json and schemas/N.json files must exist on disk.
#
#   4. LOCALE CONSISTENCY (three-way sync)
#      a. Every values-<qualifier>/strings.xml directory must correspond to an
#         entry in SupportedLocales.ALL (and vice-versa, except "en").
#      b. Every tag in SupportedLocales.ALL must appear in locale_config.xml
#         (and vice-versa).
#      c. Every translated strings.xml must contain exactly as many <string>
#         elements as the base locale (values/strings.xml).  A mismatch means
#         the LocaleSyncTest would also fail.
#
#   5. SOURCE CODE DOCUMENTATION
#      a. Every Kotlin source file must start with the GPL-3.0 file header
#         (the "vim: set et ts=4" block).
#      b. Every public or internal top-level function and every @Composable
#         function must have a KDoc block immediately preceding it.  Private
#         functions are excluded.
#
#   6. LOG CALL GUARDS
#      All android.util.Log.* calls in the main source set must be wrapped in
#      an if (BuildConfig.DEBUG) { … } block. Log calls in the test source set
#      are exempt.
#
#   7. GERMAN LANGUAGE IN SOURCE CODE
#      Source code comments and KDoc must be written in English (CONTRIBUTING.md
#      §3).  This check scans for a curated list of common German words that
#      would not normally appear in English code.  False positives from German
#      *strings* inside translation files are excluded automatically because
#      translation files live under res/values-*/strings.xml, not under
#      src/main/kotlin/.
#
#   8. BACKUP FORMAT VERSION CONSISTENCY
#      When BackupManager.BACKUP_VERSION is incremented, the version-1 →
#      version-N migration notes in the KDoc comment above it must be updated.
#      This check is heuristic: it verifies that the version constant matches
#      the highest version number mentioned in the adjacent KDoc block.
#
# HOW TO ADD A NEW CHECK
#   1. Write a bash function named check_<topic>().
#   2. Call fail "description" for hard failures (blocks the release).
#   3. Call warn "description" for advisory failures (documented issue, safe
#      to override).
#   4. Call pass "description" when the check succeeds.
#   5. Add the function call in the main() section at the bottom.
#
# TEACHING NOTES
#   The script is written as a teaching artefact.  Each section header
#   explains *why* that invariant matters (not just *what* is checked).
#   Bash idioms are commented inline where they might be unfamiliar.
# =============================================================================

# ── Strict mode ───────────────────────────────────────────────────────────────
# -e  : exit on first error
# -u  : treat unset variables as errors
# -o pipefail : propagate errors through pipes (e.g. grep | wc fails if grep fails)
set -euo pipefail

# ── Colour and output helpers (identical to the Makefile for visual consistency) ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# Counters for the final summary
FAILS=0
WARNS=0
PASSES=0

# ── Options ───────────────────────────────────────────────────────────────────
# --Werror : treat warnings as errors. Without it, warnings are advisory and the
#            script exits 0 as long as there are no hard failures. With it, ANY
#            warning flips the final exit code to non-zero, so a warning can never
#            slip silently into a build. The Makefile `release-check` target
#            passes --Werror, making the on-every-build gate reject warnings too.
WERROR=0
for arg in "$@"; do
    case "$arg" in
        --Werror|-Werror|--werror) WERROR=1 ;;
        -h|--help)
            echo "Usage: tools/release-check.sh [--Werror]"
            echo "  --Werror   treat warnings as errors (non-zero exit on any warning)"
            exit 0
            ;;
        *)
            echo "release-check.sh: unknown option '$arg' (try --help)" >&2
            exit 2
            ;;
    esac
done

# Output helpers – each increments the relevant counter and prints a
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

# ── Locate the repo root ──────────────────────────────────────────────────────
# $BASH_SOURCE[0] is the path to this script.
# cd + pwd -P resolves symlinks to give the canonical physical path.
# The script now lives in android/tools/, so anchor ONE level up to android/
# (SCRIPT_DIR/..). Every path below stays relative to android/ exactly as
# before the move (app/... for build files, ../ for repo-root files), so the
# relocation needs no other path edits.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR/.."

# ── File paths (all relative to repo root) ────────────────────────────────────
BUILD_GRADLE="app/build.gradle.kts"
# CHANGELOG.md and README.md live at the repository root, one level above this
# script's directory (android/). The script cd's into its own dir (SCRIPT_DIR)
# above, so reference them with `../`. build.gradle.kts and proguard-rules.pro
# remain relative to android/ (i.e. under app/).
CHANGELOG="../CHANGELOG.md"
README="../README.md"
PROGUARD="app/proguard-rules.pro"
APPDB_KT="app/src/main/kotlin/de/godisch/potillus/data/db/AppDatabase.kt"
BACKUP_MANAGER_KT="app/src/main/kotlin/de/godisch/potillus/util/BackupManager.kt"
SUPPORTED_LOCALES_KT="app/src/main/kotlin/de/godisch/potillus/l10n/SupportedLocales.kt"
LOCALE_CONFIG_XML="app/src/main/res/xml/locale_config.xml"
BASE_STRINGS_XML="app/src/main/res/values/strings.xml"
SOURCE_ROOT="app/src/main/kotlin"
SCHEMAS_DIR="app/schemas/de.godisch.potillus.data.db.AppDatabase"
# Fastlane store-metadata tree (used by both F-Droid and `fastlane supply`).
# Per-locale release notes are named after the integer versionCode, e.g.
# fastlane/metadata/android/en-US/changelogs/65.txt — see SECTION 1.
FASTLANE_DIR="fastlane/metadata/android"

# ── Pre-flight: verify all required files exist ───────────────────────────────
# Without these files the rest of the checks cannot run.
for f in "$BUILD_GRADLE" "$CHANGELOG" "$README" "$PROGUARD" \
          "$APPDB_KT" "$BACKUP_MANAGER_KT" "$SUPPORTED_LOCALES_KT" \
          "$LOCALE_CONFIG_XML" "$BASE_STRINGS_XML"; do
    if [[ ! -f "$f" ]]; then
        echo -e "${RED}FATAL: Required file not found: $f${NC}"
        echo "The script self-anchors to android/; ensure the tree is intact."
        exit 1
    fi
done

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

# =============================================================================
# SECTION 1 – VERSION CONSISTENCY
#
# WHY THIS MATTERS:
#   Four places must carry the same version string to avoid user confusion:
#     • versionName (shown in Android Settings → Apps)
#     • CHANGELOG.md top entry (release documentation)
#     • README.md title line (first thing visitors see)
#     • proguard-rules.pro header comment (for APK archaeology)
#   A mismatch here is a real hazard: an APK built with a versionName that
#   disagrees with the CHANGELOG, README or proguard header misleads users and
#   makes later APK archaeology impossible.
#
#   versionCode must be a plain integer ≥ 1.  It is checked separately from
#   versionName because it obeys different rules (monotonically increasing
#   integer vs. human-readable string).
#
#   FASTLANE COUPLING:
#     The store listings (F-Droid and Google Play via `fastlane supply`) carry
#     a per-locale "what's new" note named after the integer versionCode, i.e.
#     fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt. That file
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
    section "1 / 8 — VERSION CONSISTENCY"

    local vname vcode changelog_top readme_version proguard_version

    # Extract values from each source
    vname=$(extract_version_name)
    vcode=$(extract_version_code)
    # Top-most "## vX.Y" line in CHANGELOG (strip the "## v" prefix)
    changelog_top=$(grep '^## v' "$CHANGELOG" | head -1 | sed 's/^## v//')
    # "vX.Y" in the README title line
    readme_version=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$README" | head -1 | tr -d 'v')
    # Version in proguard-rules.pro header comment
    proguard_version=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$PROGUARD" | head -1 | tr -d 'v')

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

    # Cross-check: versionName must match README title
    if [[ -z "$readme_version" ]]; then
        warn "Could not parse a version number from the README.md title line"
    elif [[ "$vname" != "$readme_version" ]]; then
        fail "versionName '$vname' ≠ README.md version '$readme_version' — update README.md header"
    else
        pass "versionName matches README.md title (v$vname)"
    fi

    # Cross-check: versionName must match proguard-rules.pro header
    if [[ -z "$proguard_version" ]]; then
        warn "Could not parse a version number from $PROGUARD header — add or update the version comment"
    elif [[ "$vname" != "$proguard_version" ]]; then
        fail "versionName '$vname' ≠ proguard-rules.pro header version '$proguard_version'"
    else
        pass "versionName matches proguard-rules.pro header (v$vname)"
    fi

    # Cross-check: fastlane release notes are coupled to versionCode by filename.
    # If no fastlane tree exists yet this is only advisory (the project may not
    # publish to a store); once a locale directory exists it MUST carry the note
    # for the current versionCode.
    if [[ ! -d "$FASTLANE_DIR" ]]; then
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

        # Cross-check 2: LOCALE PARITY. Every locale's changelogs/ directory must
        # carry the SAME set of <versionCode>.txt notes. The check above only
        # inspects the current versionCode; this catches a note that was added to
        # one locale but forgotten in another (or left behind in only one). The
        # reference is the union of all locales' changelog file names; any locale
        # missing one of them is a desync.
        local all_files f desync=0
        all_files=$(for locale_dir in "$FASTLANE_DIR"/*/; do
            [[ -d "${locale_dir}changelogs" ]] || continue
            ls "${locale_dir}changelogs" 2>/dev/null | grep -E '^[0-9]+\.txt$' || true
        done | sort -u)
        for locale_dir in "$FASTLANE_DIR"/*/; do
            [[ -d "$locale_dir" ]] || continue
            locale=$(basename "$locale_dir")
            for f in $all_files; do
                if [[ ! -f "${locale_dir}changelogs/${f}" ]]; then
                    fail "fastlane: locale '$locale' is missing changelog $f that another locale has (changelogs out of sync)"
                    desync=1
                fi
            done
        done

        if [[ "$checked" -eq 0 ]]; then
            warn "fastlane tree present but contains no locale directories"
        elif [[ "$missing" -eq 0 && "$desync" -eq 0 ]]; then
            pass "fastlane changelogs present for versionCode $vcode and in sync across all $checked locale(s)"
        fi
    fi
}

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
    section "2 / 8 — CHANGELOG ENTRY"

    local vname top_entry body_line_count

    vname=$(extract_version_name)
    top_entry=$(grep '^## v' "$CHANGELOG" | head -1 | sed 's/^## v//')

    # The version in the top entry must match versionName (also checked in §1,
    # but we repeat it here for a self-contained section).
    if [[ "$vname" != "$top_entry" ]]; then
        fail "Top CHANGELOG entry is 'v$top_entry' but versionName is '$vname'"
        return
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

# =============================================================================
# SECTION 3 – ROOM DATABASE MIGRATIONS
#
# WHY THIS MATTERS:
#   When the Room @Database version is bumped from N-1 to N without a
#   Migration object, Room will throw an IllegalStateException on the user's
#   device because it cannot transform the existing schema.  The exported
#   schema JSON files in app/schemas/ serve as a paper trail; if the file for
#   the new version is missing the build is in an inconsistent state.
#
#   If the schema did NOT change (e.g. only logic changes, no new columns),
#   the version should NOT be bumped.  This check flags a bump without the
#   accompanying migration artefacts as a hard failure.
# =============================================================================
check_room_migrations() {
    section "3 / 8 — ROOM DATABASE MIGRATIONS"

    local db_version

    db_version=$(extract_db_version)

    if [[ -z "$db_version" ]]; then
        fail "Could not parse the Room @Database version from $APPDB_KT"
        return
    fi

    pass "Room @Database version = $db_version"

    # For version 1 there is no migration needed; start checking from v2 upwards.
    if [[ "$db_version" -ge 2 ]]; then
        local prev=$(( db_version - 1 ))
        local migration_name="MIGRATION_${prev}_${db_version}"

        # Check that the Migration object is declared
        if grep -q "val ${migration_name}" "$APPDB_KT"; then
            pass "Migration object $migration_name found in AppDatabase.kt"
        else
            fail "$migration_name not declared in AppDatabase.kt — add the migration or revert the version bump"
        fi

        # Check that the migration is registered with addMigrations()
        if grep -q "addMigrations.*${migration_name}" "$APPDB_KT"; then
            pass "$migration_name is registered with addMigrations()"
        else
            fail "$migration_name is declared but NOT passed to addMigrations() — the migration will never run"
        fi
    fi

    # Check that both the previous and current schema JSON files exist.
    # The previous file must exist to prove continuity; the current file
    # is generated by `./gradlew build` (with exportSchema = true).
    local schema_file="$SCHEMAS_DIR/${db_version}.json"
    if [[ -f "$schema_file" ]]; then
        pass "Schema file $schema_file exists"
    else
        warn "Schema file $schema_file not found — run ./gradlew build to generate it, then commit"
    fi

    if [[ "$db_version" -ge 2 ]]; then
        local prev_schema="$SCHEMAS_DIR/$(( db_version - 1 )).json"
        if [[ -f "$prev_schema" ]]; then
            pass "Previous schema file $prev_schema exists"
        else
            warn "Previous schema file $prev_schema is missing — should be committed as reference"
        fi
    fi
}

# =============================================================================
# SECTION 4 – LOCALE CONSISTENCY (three-way sync)
#
# WHY THIS MATTERS:
#   Adding a new language requires three simultaneous changes (§ "How to add a
#   new language" in SupportedLocales.kt):
#     1. Create values-<qualifier>/strings.xml
#     2. Add a Locale(tag, autonym) entry to SupportedLocales.ALL
#     3. Add <locale android:name="…"/> to locale_config.xml
#   Missing any one of these three steps causes the language to be invisible
#   either in the system picker, in the in-app dropdown, or both.  This was
#   exactly the class of bug this check is designed to prevent.
#
#   Additionally, every translated strings.xml must contain exactly as many
#   <string> elements as the base file (values/strings.xml).  A lower count
#   means untranslated strings fall back to the wrong language at runtime.
# =============================================================================
check_locale_consistency() {
    section "4 / 8 — LOCALE CONSISTENCY"

    # ── Build the three reference sets ───────────────────────────────────────

    # Set A: BCP-47 tags derived from values-<qualifier>/ directories.
    # Android encodes region with a lowercase "r" prefix: values-pt-rBR → pt-BR.
    # We strip "values-" and replace "-rX" → "-X" to get a plain BCP-47 tag.
    local dirs_tags
    dirs_tags=$(find "app/src/main/res" -maxdepth 1 -type d -name 'values-*' \
                    ! -name 'values-night' \
                | sed 's|.*/values-||' \
                | sed 's/-r\([A-Z]\)/-\1/' \
                | sort)

    # Set B: tags from SupportedLocales.ALL in SupportedLocales.kt.
    # We grab lines like: Locale("pt-BR", "Português (Brasil)"),
    # extract the first quoted string, and strip quotes/comma.
    local kt_tags
    kt_tags=$(grep 'Locale("' "$SUPPORTED_LOCALES_KT" \
                  | grep -oE '"[a-z][a-zA-Z-]*",' \
                  | tr -d '",' \
                  | sort)

    # Set C: android:name values from locale_config.xml.
    local config_tags
    config_tags=$(grep 'android:name=' "$LOCALE_CONFIG_XML" \
                      | grep -o '"[^"]*"' \
                      | tr -d '"' \
                      | sort)

    # ── Check A vs B (dirs ↔ SupportedLocales) ────────────────────────────────
    # "en" is a deliberate exception: it lives in values/ (the base locale),
    # not in values-en/, but it IS in SupportedLocales.ALL.

    local missing_from_kt extra_in_kt
    missing_from_kt=$(comm -23 <(echo "$dirs_tags") <(echo "$kt_tags") || true)
    extra_in_kt=$(comm -13 <(echo "$dirs_tags") <(echo "$kt_tags") \
                      | grep -v '^en$' || true)  # exclude the "en" exception

    if [[ -n "$missing_from_kt" ]]; then
        while IFS= read -r tag; do
            [[ -n "$tag" ]] && fail "values-${tag}/ exists but '$tag' is NOT in SupportedLocales.ALL"
        done <<< "$missing_from_kt"
    fi
    if [[ -n "$extra_in_kt" ]]; then
        while IFS= read -r tag; do
            [[ -n "$tag" ]] && fail "SupportedLocales.ALL contains '$tag' but there is no values-${tag}/ directory"
        done <<< "$extra_in_kt"
    fi
    if [[ -z "$missing_from_kt" && -z "$extra_in_kt" ]]; then
        local dir_count
        dir_count=$(echo "$dirs_tags" | grep -c . || true)
        pass "values-XX/ directories and SupportedLocales.ALL are in sync ($dir_count locales)"
    fi

    # ── Check B vs C (SupportedLocales ↔ locale_config.xml) ──────────────────

    local missing_from_config extra_in_config
    missing_from_config=$(comm -23 <(echo "$kt_tags") <(echo "$config_tags") || true)
    extra_in_config=$(comm -13 <(echo "$kt_tags") <(echo "$config_tags") || true)

    if [[ -n "$missing_from_config" ]]; then
        while IFS= read -r tag; do
            [[ -n "$tag" ]] && fail "SupportedLocales.ALL has '$tag' but locale_config.xml is missing it — language invisible in system picker"
        done <<< "$missing_from_config"
    fi
    if [[ -n "$extra_in_config" ]]; then
        while IFS= read -r tag; do
            [[ -n "$tag" ]] && fail "locale_config.xml has '$tag' but it is NOT in SupportedLocales.ALL"
        done <<< "$extra_in_config"
    fi
    if [[ -z "$missing_from_config" && -z "$extra_in_config" ]]; then
        pass "SupportedLocales.ALL and locale_config.xml are in sync"
    fi

    # ── Check string key count parity ────────────────────────────────────────
    # The base file is values/strings.xml (English / fallback).
    # Every other strings.xml must have exactly the same number of <string> elements.
    local base_count offenders
    base_count=$(grep -c '<string name=' "$BASE_STRINGS_XML")
    offenders=""

    while IFS= read -r strings_file; do
        local actual_count locale_dir
        actual_count=$(grep -c '<string name=' "$strings_file" || true)
        locale_dir=$(basename "$(dirname "$strings_file")")

        if [[ "$actual_count" -ne "$base_count" ]]; then
            offenders+="    ${locale_dir}/strings.xml: $actual_count strings (expected $base_count)\n"
        fi
    done < <(find "app/src/main/res" -path '*/values-*/strings.xml' ! -path '*/values-night/*' | sort)

    if [[ -n "$offenders" ]]; then
        fail "String count mismatch (base has $base_count; see below):"
        # Print the offender list without leading newlines
        echo -e "$offenders" | grep -v '^$' | while IFS= read -r line; do
            echo -e "    ${RED}$line${NC}"
        done
    else
        pass "All translation files have $base_count string keys (matches base)"
    fi
}

# =============================================================================
# SECTION 5 – SOURCE CODE DOCUMENTATION
#
# WHY THIS MATTERS:
#   This project doubles as a teaching app.  Every source file must carry the
#   GPL-3.0 header (copyright notice, license notice) and every public function
#   must be documented with KDoc so readers can understand the code without
#   needing to trace call sites.
#
# 5a. FILE HEADERS
#   The canonical header starts with the vim modeline comment.
#   We check for the presence of "GNU General Public License" as the unique
#   identifier rather than the exact vim modeline, which makes the check
#   robust against minor formatting variations.
#
# 5b. FUNCTION KDOC (heuristic)
#   We scan for public/internal/top-level function declarations and verify each
#   is preceded by a KDoc block (a line ending in "*/"). The look-behind skips
#   blank lines, single-line annotations, AND multi-line annotation arguments
#   such as @Query("""…""") so that KDoc placed above the annotation is still
#   found. Excluded from the requirement (documented with inline comments, not
#   KDoc): private functions, trivial set/clear/dismiss one-liners, and LOCAL
#   (nested) functions — detected as declarations indented more than 8 spaces,
#   i.e. deeper than any top-level, class-member or companion-object member.
# =============================================================================
check_documentation() {
    section "5 / 8 — SOURCE CODE DOCUMENTATION"

    # ── 5a: GPL file headers ──────────────────────────────────────────────────
    local missing_headers=0 total_kt=0

    while IFS= read -r kt_file; do
        total_kt=$(( total_kt + 1 ))
        if ! grep -q "GNU General Public License" "$kt_file"; then
            fail "Missing GPL header: $kt_file"
            missing_headers=$(( missing_headers + 1 ))
        fi
    done < <(find "$SOURCE_ROOT" "app/src/test" -name '*.kt' 2>/dev/null | sort)

    if [[ "$missing_headers" -eq 0 ]]; then
        pass "All $total_kt Kotlin files have GPL-3.0 file headers"
    fi

    # ── 5b: KDoc on public/internal functions (heuristic) ────────────────────
    # Strategy:
    #   For every line that starts a public or internal fun (not private, not
    #   override-only-private, not a lambda), look at the non-empty line
    #   immediately above it.  If that line ends with "*/" it is the closing
    #   line of a KDoc block → documented.  Otherwise → report as missing.
    #
    # We use Python for the multi-line context scan because bash is awkward
    # for look-behind parsing of text files.
    local missing_kdoc
    missing_kdoc=$(python3 - "$SOURCE_ROOT" <<'PYEOF'
import sys, os, re

source_root = sys.argv[1]

# Patterns: match public/internal function lines.
# We exclude:  private, override (typically inherits doc from interface),
#              lambda shorthand (fun () = ...), and @JvmStatic boilerplate.
fun_re   = re.compile(r'^\s*((?:internal\s+)?(?:suspend\s+)?fun\s+\w)')
skip_re  = re.compile(r'^\s*(private|override|//)')
anno_re  = re.compile(r'^\s*@')   # annotation line — not a doc line
kdoc_re  = re.compile(r'\*/')     # end of a KDoc block

results = []

for dirpath, _, filenames in os.walk(source_root):
    for fname in sorted(filenames):
        if not fname.endswith('.kt'):
            continue
        fpath = os.path.join(dirpath, fname)
        with open(fpath, encoding='utf-8', errors='replace') as fh:
            lines = fh.readlines()

        for i, line in enumerate(lines):
            if not fun_re.match(line):
                continue
            if skip_re.match(line):
                continue
            # Skip trivial one-liner setter/delegate functions:
            # these are boilerplate that forward to a repository or preference
            # method, and their purpose is self-evident from the function name.
            # Pattern: the entire function body is on the same line (contains
            # "= " or "{ " and ends without a separate closing brace).
            # Examples: fun setTheme(m) = launch { prefs.setTheme(m) }
            #           fun toggleViewMode() { _mode.value = … }
            stripped = line.rstrip()
            is_one_liner = (
                re.search(r"fun\s+set[A-Z]", stripped) or
                re.search(r"fun\s+clear[A-Z]", stripped) or
                re.search(r"fun\s+dismiss[A-Z]", stripped)
            ) and (stripped.endswith("}") or stripped.endswith(")"))
            if is_one_liner:
                continue

            # Skip LOCAL (nested) functions. Like private functions, local
            # helpers declared inside another function's body are documented
            # with inline comments, not KDoc. Under the project's 4-space
            # indentation, every API-level function is a top-level (0 spaces),
            # class-member (4) or companion/object-member (8) declaration, so a
            # leading indent of MORE than 8 spaces reliably marks a local helper
            # (e.g. `fun svg(...)` defined inside a `run { … }` block).
            indent = len(line) - len(line.lstrip(' '))
            if indent > 8:
                continue

            # Walk upwards over blank lines and annotation lines to find the most
            # recent non-trivial preceding line.
            j = i - 1
            while j >= 0:
                prev = lines[j]
                if prev.strip() == '' or anno_re.match(prev):
                    j -= 1
                    continue
                # A MULTI-LINE annotation argument — e.g.
                #     @Query("""
                #         SELECT …
                #     """)
                # — ends on a line such as `    """)` or `    )`. Those body
                # lines are neither blank nor start with '@', so without this
                # they would stop the look-behind before reaching the KDoc that
                # sits above the annotation, producing a false positive (e.g.
                # EntryDao.getDailySummaries). When the preceding line closes
                # such an argument, rewind past the matching `@Name(` opener
                # (bounded to 30 lines) and keep scanning above it.
                if prev.rstrip().endswith(')'):
                    k, limit = j, max(0, j - 30)
                    while k >= limit and not re.match(r'^\s*@\w+\s*\(', lines[k]):
                        k -= 1
                    if k >= limit and re.match(r'^\s*@\w+\s*\(', lines[k]):
                        j = k - 1
                        continue
                break

            if j < 0 or not kdoc_re.search(lines[j]):
                # No KDoc found above this function.
                rel = os.path.relpath(fpath, source_root)
                func_snippet = line.strip()[:80]
                results.append(f"  {rel}:{i+1}: {func_snippet}")

for r in results[:20]:   # cap at 20 to avoid flooding output
    print(r)
if len(results) > 20:
    print(f"  … and {len(results)-20} more (run with --verbose to see all)")
PYEOF
)

    if [[ -n "$missing_kdoc" ]]; then
        warn "Public/internal functions without KDoc (heuristic — review manually):"
        echo "$missing_kdoc" | while IFS= read -r line; do
            echo -e "    ${YELLOW}$line${NC}"
        done
    else
        pass "All detected public/internal functions appear to have KDoc"
    fi
}

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
    section "6 / 8 — LOG CALL GUARDS"

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

# =============================================================================
# SECTION 7 – NO GERMAN IN SOURCE CODE
#
# WHY THIS MATTERS:
#   The project documentation standard (CONTRIBUTING.md §3) requires all
#   source code comments and KDoc to be written in English.  German prose in
#   code comments is confusing for international contributors.  Translation
#   strings in values-de/strings.xml are explicitly excluded.
#
# NOTE ON FALSE POSITIVES:
#   The word list was calibrated against the current source tree.  Short or
#   ambiguous words are deliberately excluded:
#     "falls" → English "falls back";  "und" → "android", "found";
#     "nicht" → too short;  "kann/soll/wird" → borderline identifiers.
#   Only unambiguous German nouns/verb-forms that never appear in English
#   technical prose are included.
# =============================================================================
check_no_german_comments() {
    section "7 / 8 — NO GERMAN IN SOURCE CODE COMMENTS"

    # German words calibrated to produce zero false positives on the current tree.
    # Each entry uses whole-word matching (\b anchors in the grep pattern).
    # Words are case-sensitive: capitalised entries match German nouns (which
    # are always capitalised), lowercase entries match verb/modal forms.
    local german_words=(
        # Unambiguous German nouns / technical terms (capitalised)
        "Methode" "Klasse" "Funktion" "Eigenschaft" "Rückgabe"
        "Beschreibung" "Hinweis" "Ausnahme"
        "Beispiel" "Verwendung" "Erstellt" "Geändert" "Gelöscht" "Gespeichert"
        "Bildschirm" "Einstellung" "Benutzer" "Datenbank"
        "Konfiguration" "Verarbeitung" "Berechnung" "Überprüfung"
        # Unambiguous German verb/modal forms (lowercase)
        "wurde" "wurden" "werden" "können" "müssen" "müsste"
        "bitte" "setzt" "liefert"
        # German adjectives / determiners that never appear in English prose
        "keine" "keinen" "keiner" "jedes" "dieses" "solche"
        "immer" "niemals" "bereits" "entsprechend" "folgende" "folgendes"
    )

    local pattern
    # Build a single alternation regex from the word list so grep runs once.
    # printf '%s\n' "${arr[@]}" prints each element on its own line;
    # paste -sd'|' joins them with | into "word1|word2|…"
    pattern=$(printf '%s\n' "${german_words[@]}" | paste -sd'|')

    local matches
    # Search only Kotlin source files; exclude blank lines and pure-code lines
    # (i.e. lines that contain // or * indicating a comment).
    # We pipe through grep -E twice: first to find comment lines, then to find German.
    matches=$(grep -rn --include='*.kt' "//\|^\s*\*" "$SOURCE_ROOT" \
                  | grep -iE "\b(${pattern})\b" \
                  | head -15 || true)

    if [[ -n "$matches" ]]; then
        warn "Possible German text in source comments (review manually):"
        echo "$matches" | while IFS= read -r line; do
            # Strip the repo root prefix for readability
            echo -e "    ${YELLOW}${line//$SCRIPT_DIR\//}${NC}"
        done
    else
        pass "No German words detected in source code comments"
    fi
}

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
    section "8 / 8 — BACKUP FORMAT VERSION CONSISTENCY"

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

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Potillus – Release Readiness Check             ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    info "Working directory: $(pwd)"
    info "Checking release candidate…"

    check_version_consistency
    check_changelog
    check_room_migrations
    check_locale_consistency
    check_documentation
    check_log_guards
    check_no_german_comments
    check_backup_version

    # ── Final summary ─────────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}━━━  SUMMARY  ━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✓  Passed :${NC}  $PASSES"
    echo -e "  ${YELLOW}⚠  Warnings:${NC} $WARNS"
    echo -e "  ${RED}✗  Failed :${NC}  $FAILS"
    echo ""

    if [[ "$FAILS" -gt 0 ]]; then
        echo -e "${RED}${BOLD}  ✗ Release NOT ready — $FAILS check(s) failed.${NC}"
        echo -e "  Fix the issues above before tagging the release."
        echo ""
        exit 1
    elif [[ "$WARNS" -gt 0 ]]; then
        if [[ "$WERROR" -eq 1 ]]; then
            echo -e "${RED}${BOLD}  ✗ Release NOT ready — $WARNS warning(s) treated as errors (--Werror).${NC}"
            echo -e "  Resolve the warnings above, or invoke without --Werror to treat them as advisory."
            echo ""
            exit 1
        fi
        echo -e "${YELLOW}${BOLD}  ⚠ Release CONDITIONALLY ready — $WARNS warning(s).${NC}"
        echo -e "  Review the warnings above. Warnings are advisory;"
        echo -e "  they do not block the release but should be resolved."
        echo ""
        exit 0
    else
        echo -e "${GREEN}${BOLD}  ✓ Release ready — all checks passed.${NC}"
        echo ""
        exit 0
    fi
}

main "$@"
