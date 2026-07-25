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
#  release-checks/no-german-comments.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 7 – NO GERMAN IN SOURCE CODE
#
# WHY THIS MATTERS:
#   The project documentation standard (CONTRIBUTING.md, "English
#   everywhere") requires all source code comments, KDoc, and BUILD FILES to
#   be written in English.  German prose in code comments is confusing for
#   international contributors.  The scan covers the Kotlin sources, the
#   Gradle build scripts, and the Swift sources of the iOS port (when
#   present).  Translation strings in values-de/strings.xml are excluded.
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
    section "7 / 15 — NO GERMAN IN SOURCE CODE COMMENTS"

    # German words calibrated to produce zero false positives on the current tree.
    # Each entry uses whole-word matching (\b anchors in the grep pattern).
    # The list is WRITTEN in the natural case of each word — capitalised entries
    # are German nouns, which are always capitalised; lowercase entries are verb
    # and modal forms. The match itself is case-INSENSITIVE (`grep -iE` below),
    # so the casing here is documentation, not a filter. That is deliberate: a
    # noun that slipped in lowercase is still caught. Until the 0.84.0 QA round
    # this comment claimed the matching was case-sensitive, which the `-i` flag
    # had never made true.
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
    # Scan the Kotlin sources, the Gradle build scripts, the Swift sources of the
    # iOS port, and the Python/shell tooling — the convention covers "all source
    # code … build files" (CONTRIBUTING, "English everywhere"), and tools/ is
    # 5,700 lines of it. Widened in the 0.83.0 QA round twice: first for the
    # German prose that sat in build.gradle.kts, exactly the file class the old
    # *.kt-only filter skipped; then for tools/, which the convention has always
    # covered and no gate ever read (the thirteenth round found the scope, not a
    # violation — tools/ was already clean, and this keeps it that way). Widened
    # again in the 0.84.0 QA round for the MAKE layer: tools/check-headers.py had
    # just gained `.mk` and the `Makefile` basename, so the build files count as
    # sources the project owns, while this gate still could not see them. That
    # round found the scope, not a violation either — the Makefiles were clean.
    # Widened once more for the declarative build and configuration files —
    # the version catalog, gradle.properties, the ProGuard rules, the CI
    # definitions, project.yml, the SwiftLint and REUSE and osv-scanner configs,
    # the F-Droid metadata. check-headers.py had long counted .yml, .toml,
    # .properties and .pro as project-owned sources; those eighteen files were
    # simply the last class no comment-language gate read. Clean as well.
    # The build scripts are named explicitly (a recursive *.kts glob would descend
    # into .gradle/ caches), the iOS, tools and make roots are scanned only when
    # present so a partial source drop skips them gracefully, and every grep is
    # `|| true`-guarded: "found nothing" is grep exit 1, which `set -e` would
    # otherwise turn into a dead gate — the §10 lesson.
    # We pipe through grep -E twice: first to find comment lines, then to find German.
    matches=$(
        {
            grep -rn --include='*.kt' "//\|^\s*\*" "$SOURCE_ROOT" || true
            grep -n "//" build.gradle.kts settings.gradle.kts app/build.gradle.kts \
                2>/dev/null || true
            grep -n "#" Makefile 2>/dev/null || true
            grep -n "#" ../Makefile ../ios/Makefile 2>/dev/null || true
            if [[ -d ../make ]]; then
                grep -rn --include='*.mk' "#" ../make || true
            fi
            if [[ -d ../ios ]]; then
                grep -rn --include='*.swift' --exclude-dir='.build' \
                     --exclude-dir='DerivedData' "//" ../ios || true
            fi
            if [[ -d ../tools ]]; then
                grep -rn --include='*.py' --include='*.sh' "#" ../tools || true
            fi
            # The declarative build and configuration files. check-headers.py
            # already counts these suffixes as project-owned sources and demands
            # a license header in each, so the English-everywhere convention
            # covers them too; this gate could not see them. Named as explicit
            # roots rather than a tree-wide glob, for the same reason the .kts
            # scripts are: a recursive walk would descend into build/ and
            # .gradle/ caches. Absent roots are skipped, so a partial source drop
            # does not fail here.
            grep -n "#" gradle/libs.versions.toml gradle.properties \
                app/proguard-rules.pro 2>/dev/null || true
            grep -n "#" ../.gitlab-ci.yml ../security-insights.yml \
                ../REUSE.toml ../osv-scanner.toml 2>/dev/null || true
            if [[ -d ../.github/workflows ]]; then
                grep -rn --include='*.yml' "#" ../.github/workflows || true
            fi
            if [[ -d ../ios ]]; then
                grep -n "#" ../ios/project.yml ../ios/.swiftlint.yml \
                    2>/dev/null || true
            fi
            if [[ -d ../fdroid ]]; then
                grep -rn --include='*.yml' "#" ../fdroid || true
            fi
        } | grep -iE "\b(${pattern})\b" | head -15 || true
    )

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
