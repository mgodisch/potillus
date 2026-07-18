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
#  release-checks/locale-consistency.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


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
    section "4 / 15 — LOCALE CONSISTENCY"

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

    # ── Check D: store-locale directories (fastlane ↔ Google Play ↔ app) ─────
    #
    # The fastlane metadata tree is pushed to Google Play by the deploy lane
    # (`upload_to_play_store` in fastlane/Fastfile), and Play accepts ONLY the
    # store-listing language codes from its fixed list — mostly region-qualified
    # ("cs-CZ", "ja-JP", "no-NO"), a few bare ("ro", "uk"). A directory named
    # with a bare code Play does not know is rejected at upload time, i.e. the
    # listing silently never reaches the store (the v0.79.0 QA review found 14
    # of the 21 listings in that state). F-Droid reads the SAME tree and accepts
    # region-qualified codes, so the Play list is the binding constraint.
    #
    # Two invariants:
    #   D1. Every metadata locale directory is a valid Play store-listing code.
    #   D2. Mapped onto the app's translation tags (full tag first, then the
    #       bare language subtag, with the Norwegian macrolanguage alias
    #       no → nb — the same order LocaleDetector.detect uses), the store
    #       locales cover SupportedLocales.ALL exactly: one listing per shipped
    #       language, no listing without a translation.
    #
    # PLAY_LOCALES is Google Play's supported store-listing language list
    # (source: Play Console "Supported languages", checked 2026-06). Update it
    # here if Google extends the list.
    local PLAY_LOCALES=" af sq am ar hy-AM az-AZ eu-ES be bn-BD bg my-MM ca \
zh-HK zh-CN zh-TW hr cs-CZ da-DK nl-NL en-AU en-CA en-IN en-SG en-GB en-US \
en-ZA et fil fi-FI fr-FR fr-CA gl-ES ka-GE de-DE el-GR gu iw-IL hi-IN hu-HU \
is-IS id it-IT ja-JP kn-IN kk km-KH ko-KR ky-KG lo-LA lv lt mk-MK ms ml-IN \
mr-IN mn-MN ne-NP no-NO fa pl-PL pt-BR pt-PT pa ro rm ru-RU sr si-LK sk sl \
es-419 es-ES es-US sw sv-SE ta-IN te-IN th tr-TR uk ur vi zu "

    local store_locales store_ok=1
    store_locales=$(find "$FASTLANE_DIR" -mindepth 2 -maxdepth 2 -type d -name changelogs \
                        | sed 's|/changelogs$||' | xargs -rn1 basename | sort)

    # D1: every store directory carries a code Play actually accepts.
    local loc
    while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        if [[ "$PLAY_LOCALES" != *" $loc "* ]]; then
            fail "store locale '$loc' (fastlane/metadata/android/) is not a Google Play store-listing code — the deploy lane cannot upload this listing"
            store_ok=0
        fi
    done <<< "$store_locales"

    # D2: store locales ↔ app translations, via the store→app tag mapping.
    local mapped_tags="" app_tag lang
    while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        lang="${loc%%-*}"
        [[ "$lang" == "no" ]] && lang="nb"   # Norwegian macrolanguage alias
        if echo "$kt_tags" | grep -qx "$loc"; then
            app_tag="$loc"                    # full tag shipped (pt-BR, zh-CN, …)
        elif echo "$kt_tags" | grep -qx "$lang"; then
            app_tag="$lang"                   # language subtag shipped (cs, de, …)
        else
            fail "store locale '$loc' maps to no shipped translation (neither '$loc' nor '$lang' is in SupportedLocales.ALL)"
            store_ok=0
            continue
        fi
        mapped_tags+="$app_tag"$'\n'
    done <<< "$store_locales"

    local unlisted_tags
    unlisted_tags=$(comm -23 <(echo "$kt_tags") <(printf '%s' "$mapped_tags" | sort -u) || true)
    if [[ -n "$unlisted_tags" ]]; then
        while IFS= read -r tag; do
            [[ -n "$tag" ]] && fail "app language '$tag' has no store-listing directory under fastlane/metadata/android/"
        done <<< "$unlisted_tags"
        store_ok=0
    fi

    if [[ "$store_ok" -eq 1 ]]; then
        local store_count
        store_count=$(echo "$store_locales" | grep -c . || true)
        pass "store-locale directories are valid Play codes and map 1:1 onto the app's $store_count languages"
    fi
}
