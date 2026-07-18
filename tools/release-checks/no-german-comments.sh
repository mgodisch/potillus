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
    # Scan the Kotlin sources, the Gradle build scripts, the Swift sources of the
    # iOS port, and the Python/shell tooling — the convention covers "all source
    # code … build files" (CONTRIBUTING, "English everywhere"), and tools/ is
    # 5,700 lines of it. Widened in the 0.83.0 QA round twice: first for the
    # German prose that sat in build.gradle.kts, exactly the file class the old
    # *.kt-only filter skipped; then for tools/, which the convention has always
    # covered and no gate ever read (the thirteenth round found the scope, not a
    # violation — tools/ was already clean, and this keeps it that way). The
    # build scripts are named explicitly (a recursive *.kts glob would descend
    # into .gradle/ caches), the iOS and tools roots are scanned only when
    # present so a partial source drop skips them gracefully, and every grep is
    # `|| true`-guarded: "found nothing" is grep exit 1, which `set -e` would
    # otherwise turn into a dead gate — the §10 lesson.
    # We pipe through grep -E twice: first to find comment lines, then to find German.
    matches=$(
        {
            grep -rn --include='*.kt' "//\|^\s*\*" "$SOURCE_ROOT" || true
            grep -n "//" build.gradle.kts settings.gradle.kts app/build.gradle.kts \
                2>/dev/null || true
            if [[ -d ../ios ]]; then
                grep -rn --include='*.swift' --exclude-dir='.build' \
                     --exclude-dir='DerivedData' "//" ../ios || true
            fi
            if [[ -d ../tools ]]; then
                grep -rn --include='*.py' --include='*.sh' "#" ../tools || true
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
