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
#  release-check.sh – Libellus Potionis release readiness checker
# =============================================================================
#
# PURPOSE
#   Verifies all invariants that must hold before a new Libellus Potionis release is
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
#   It is NOT a per-build gate: the everyday build gates on lint and check-guides
#   alone. Run this invariant gate during development with `make release-check`
#   (which passes --Werror); `make release-android` runs it with --release before an
#   artifact is staged.
#
# OPTIONS
#   --Werror   Treat warnings as errors: exit non-zero if any warning is
#              emitted, even when no hard FAIL occurred.
#   --coverage Additionally run the Kover coverage gate (:app:koverVerify),
#              which hard-fails if LINE < 90 or BRANCH < 75 over the
#              JVM-unit-testable scope. Opt-in because it runs Gradle and the
#              unit-test suite (slow); `make release-check` leaves it off, and
#              release/CI runs enable it.
#
# EXIT CODES
#   0  All checks passed (warnings allowed unless --Werror is given).
#   1  At least one FAIL (or, under --Werror, at least one warning); NOT safe to
#      tag.
#   2  Invalid command-line option.
#
# CHECKS PERFORMED
#   This runner sources a shared library and one file per check, then calls them
#   in a fixed order (see main() at the bottom). Each check lives in its own file
#   under tools/release-checks/ and is documented there at teaching depth -- that
#   file, not this header, is the single source of truth for what a check does:
#
#     lib.sh                        colours, counters, output helpers, file-path
#                                   constants and the extract_version_* helpers
#     version-consistency.sh        versionName / CHANGELOG / README agree;
#                                   versionCode integer; store-changelog coupling
#     changelog.sh                  top ## vX.Y.Z entry matches and has a body
#     room-migrations.sh            @Database N has MIGRATION_(N-1)_N + schemas
#     locale-consistency.sh         values-* ↔ SupportedLocales ↔ locale_config
#     documentation.sh              GPL header + KDoc on every Kotlin declaration
#     log-guards.sh                 Log.* wrapped in if (BuildConfig.DEBUG)
#     no-german-comments.sh         comments/KDoc are English (CONTRIBUTING §3)
#     backup-version.sh             BACKUP_VERSION matches its KDoc migration notes
#     markdown-syntax.sh            authored docs + rendered guides are well-formed
#     metadata-lengths.sh           store metadata within per-file length limits
#     reproducible-build-hygiene.sh F-Droid reproducible-build invariants
#     third-party-notices.sh        SBOM-driven NOTICE/licence reproduction
#     accessibility-labels.sh       contentDescription discipline
#     signing-key-fingerprint.sh    the SECURITY.md fingerprint is single-sourced
#     bestpractices-complete.sh     the OpenSSF/OSPS self-assessment is complete
#     coverage.sh                   the opt-in Kover coverage gate (--coverage)
#
# HOW TO ADD A NEW CHECK
#   1. Add tools/release-checks/<topic>.sh defining one check_<topic>() function
#      (copy a sibling's header; call pass/warn/fail from lib.sh).
#   2. Add <topic> to the source loop below and check_<topic> to main().
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
#            slip silently past the gate. The Makefile `release-check` target
#            passes --Werror; `release-android` runs the gate with --release.
WERROR=0
# --coverage : additionally run the Kover coverage gate (./gradlew :app:koverVerify).
#            Opt-in because it launches Gradle and runs the unit-test suite, which
#            is far slower than the static checks; `make release-check` therefore leaves
#            it OFF, while release/CI runs enable it.
COVERAGE=0
# --release : enforce the checks that only matter when actually cutting a release
#            — currently the per-locale store changelog notes (SECTION 1). Off by
#            default so a plain `make release-check` does not demand the translated store
#            release notes, which are only needed at `make release-android` time,
#            which passes --release.
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
    echo -e "${BOLD}║   Libellus Potionis – Release Readiness Check    ║${NC}"
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
