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

# =============================================================================
#  release-check.sh – Potillus release readiness checker
# =============================================================================
#
# PURPOSE
#   Verifies all invariants that must hold before a new Potillus release is
#   tagged. Run this script after completing all code changes and before
#   calling `git tag`. The static checks are pure and read-only: they never
#   modify any file. The opt-in coverage gate (--coverage) additionally runs
#   `./gradlew :app:koverVerify`, which executes the unit-test suite and writes
#   Gradle build outputs (never source files).
#
# USAGE
#   chmod +x tools/release-check.sh      # once
#   tools/release-check.sh               # run from the repo root (self-anchors)
#   tools/release-check.sh --Werror      # treat warnings as errors
#   tools/release-check.sh --coverage    # also enforce the Kover coverage floor
#
#   The script self-anchors to android/ (it lives in tools/ at the repo root and
#   cd's into the sibling android/ directory), so it can also be invoked from
#   anywhere, e.g. `bash tools/release-check.sh`.
#   It additionally runs automatically on every build: the android/Makefile
#   `prereq` target invokes it (with --Werror) via the `release-check` target,
#   so a failing invariant — or, under --Werror, any warning — aborts the build.
#
# OPTIONS
#   --Werror   Treat warnings as errors: exit non-zero if any warning is
#              emitted, even when no hard FAIL occurred.
#   --coverage Additionally run the Kover coverage gate (:app:koverVerify),
#              which hard-fails if LINE < 90 or BRANCH < 75 over the
#              JVM-unit-testable scope. Opt-in because it runs Gradle and the
#              unit-test suite (slow); the on-every-build Makefile prereq path
#              leaves it off, release/CI runs enable it.
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
#      README.md title line must all carry the same version string.
#      versionCode must be ≥ 1 and must
#      be a plain integer (no alphabetic suffix).  Fastlane store changelogs are coupled
#      to versionCode by filename; every listing locale must carry the CURRENT
#      versionCode note, while the FULL per-versionCode history need only stay in
#      sync across the history-bearing locales (HISTORY_LOCALES: en-US, de-DE).
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
#   9. MARKDOWN SYNTAX
#      The authored Markdown docs (CHANGELOG.md, README.md, CONTRIBUTING.md,
#      PRIVACY.md) and
#      the per-language guides rendered from *.md.in into res/raw*/ must be well
#      formed: inline-code backticks and '*' emphasis balanced, and code-looking
#      tokens (snake_case, glob '*') wrapped in backticks so a stray marker does
#      not turn into accidental emphasis in the in-app renderer.  CHANGELOG.md
#      headings must additionally read "## vMAJOR.MINOR.PATCH" in descending
#      order.  The check lives in tools/md-syntax.py.  The verbatim license
#      texts (LICENSE.md, LICENSE.Apache-2.0.md, LICENSE.GPL-2.0.md, COPYING.md)
#      are not in the checked set at all.
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

PASSES=0

# ── Options ───────────────────────────────────────────────────────────────────
# --Werror : treat warnings as errors. Without it, warnings are advisory and the
#            script exits 0 as long as there are no hard failures. With it, ANY
#            warning flips the final exit code to non-zero, so a warning can never
#            slip silently into a build. The Makefile `release-check` target
#            passes --Werror, making the on-every-build gate reject warnings too.
WERROR=0
# --coverage : additionally run the Kover coverage gate (./gradlew :app:koverVerify).
#            Opt-in because it launches Gradle and runs the unit-test suite, which
#            is far slower than the static checks; the on-every-build Makefile
#            `prereq` path therefore leaves it OFF, while release/CI runs enable it.
COVERAGE=0
# --release : enforce the checks that only matter when actually cutting a release
#            — currently the per-locale store changelog notes (SECTION 1). Off by
#            default so the on-every-build `make android` path does not demand the
#            translated store release notes, which are only needed at
#            `make release-android` time. The android/Makefile `release` and
#            `bundle` targets pass it; `debug`/`unit-test`/`lint` do not.
RELEASE=0
for arg in "$@"; do
    case "$arg" in
        --Werror|-Werror|--werror) WERROR=1 ;;
        --coverage) COVERAGE=1 ;;
        --release) RELEASE=1 ;;
        -h|--help)
            echo "Usage: tools/release-check.sh [--Werror] [--coverage] [--release]"
            echo "  --Werror     treat warnings as errors (non-zero exit on any warning)"
            echo "  --coverage   also run the Kover coverage gate (:app:koverVerify)"
            echo "  --release    also enforce release-only checks (per-locale store changelogs)"
            exit 0
            ;;
        *)
            echo "release-check.sh: unknown option '$arg' (try --help)" >&2
            exit 2
            ;;
    esac
done

# Output helpers – each increments the relevant counter and prints a

# ── Locate the repo root ──────────────────────────────────────────────────────
# $BASH_SOURCE[0] is the path to this script.
# cd + pwd -P resolves symlinks to give the canonical physical path.
# The script now lives in tools/ at the repository ROOT, so anchor to the sibling
# android/ directory (SCRIPT_DIR/../android). Every path below stays relative to
# android/ exactly as before (app/... for build files, ../ for repo-root files),
# so the relocation needs no other path edits here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR/../android"

# Shared library: colours, counters, output helpers, file-path constants and the
# extract_version_* helpers. Sourced after the cd so its android/-relative paths
# resolve. See tools/release-checks/lib.sh.
source "$SCRIPT_DIR/release-checks/lib.sh"


# ── Pre-flight: verify all required files exist ───────────────────────────────
# Without these files the rest of the checks cannot run.
for f in "$BUILD_GRADLE" "$CHANGELOG" "$README" \
          "$APPDB_KT" "$BACKUP_MANAGER_KT" "$SUPPORTED_LOCALES_KT" \
          "$LOCALE_CONFIG_XML" "$BASE_STRINGS_XML"; do
    if [[ ! -f "$f" ]]; then
        echo -e "${RED}FATAL: Required file not found: $f${NC}"
        echo "The script self-anchors to android/; ensure the tree is intact."
        exit 1
    fi
done
# ── Source the per-check scripts (each defines one check_* function; see
# tools/release-checks/). The loop order is documentation only -- main() below
# fixes the actual run order.
for _check in \
    version-consistency \
    changelog \
    room-migrations \
    locale-consistency \
    documentation \
    log-guards \
    no-german-comments \
    backup-version \
    markdown-syntax \
    metadata-lengths \
    reproducible-build-hygiene \
    third-party-notices \
    accessibility-labels \
    signing-key-fingerprint \
    bestpractices-complete \
    coverage; do
    source "$SCRIPT_DIR/release-checks/$_check.sh"
done

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
    check_markdown_syntax
    check_metadata_lengths
    check_reproducible_build_hygiene
    check_third_party_notices
    check_accessibility_labels
    check_signing_key_fingerprint
    check_bestpractices_complete
    check_coverage

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
