/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * =============================================================================
 */
package de.godisch.potillus.l10n

// =============================================================================
// SupportedLocales.kt — Single source of truth for all supported locales
// =============================================================================
//
// PURPOSE
//   This file is the authoritative list of every language Potillus supports.
//   Previously the list was duplicated in two places:
//     • res/xml/locale_config.xml  (system / per-app language picker)
//     • LanguageDropdown in SettingsScreen.kt  (in-app selector)
//   That duplication caused repeated bugs where newly added string resources
//   were invisible to users because one or both registration points were
//   forgotten.  Moving the data here gives us:
//     1. A single place to edit when adding a language.
//     2. A unit-testable object (no Android runtime required).
//     3. A compile-time reference for LanguageDropdown.
//
// HOW TO ADD A NEW LANGUAGE
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │ Step 1 – String resources                                           │
//   │   Create  app/src/main/res/values-<qualifier>/strings.xml           │
//   │   and translate all keys.  Use  values-de/  as the source of truth. │
//   │   Android qualifier syntax:  values-fr/  values-pt-rBR/  values-zh-rCN/ │
//   │                                                                     │
//   │ Step 2 – Register here (THIS FILE)                                  │
//   │   Add one  Locale(tag, autonym)  entry to the ALL list below.       │
//   │   • tag     = plain BCP-47, no "r" prefix:  "pt-BR"  "zh-CN"       │
//   │   • autonym = language name written in its own script               │
//   │   Keep the list sorted alphabetically by autonym.                   │
//   │                                                                     │
//   │ Step 3 – locale_config.xml                                          │
//   │   Add  <locale android:name="<tag>"/>  to                           │
//   │   app/src/main/res/xml/locale_config.xml.                           │
//   │   Without this entry the language is invisible in the system picker. │
//   │                                                                     │
//   │ Step 4 – Run the unit tests                                         │
//   │   ./gradlew :app:test  (or run LocaleSyncTest in Android Studio)    │
//   │   The tests verify all three artefacts are in sync and every        │
//   │   strings.xml is complete.                                           │
//   └─────────────────────────────────────────────────────────────────────┘
//
// RTL LANGUAGES (Arabic, Hebrew, …)
//   android:supportsRtl="true" is already set in AndroidManifest.xml.
//   No further code changes are needed; Compose mirrors the layout
//   automatically.
// =============================================================================

/**
 * A supported locale, identified by its BCP-47 [tag] and displayed to the
 * user by its [autonym] (the language name written in its own script).
 *
 * @param tag     BCP-47 language tag without the Android "r" region prefix,
 *                e.g. `"pt-BR"`, `"zh-CN"`, `"de"`.
 * @param autonym The language's own name, e.g. `"Deutsch"`, `"中文（简体）"`.
 */
data class Locale(val tag: String, val autonym: String)

/**
 * Central registry of every locale Potillus ships with.
 *
 * Consumed by:
 *  - [de.godisch.potillus.ui.screen.LanguageDropdown] — in-app language selector
 *  - [de.godisch.potillus.l10n.LocaleSyncTest]        — sync / completeness tests
 *
 * locale_config.xml must mirror this list exactly (validated by the test).
 */
object SupportedLocales {

    /**
     * All supported locales, sorted alphabetically by autonym.
     *
     * The English base locale ("en") is included here so the dropdown can
     * offer it explicitly, even though it has no  values-en/  directory
     * (Android falls back to  values/  automatically).
     */
    val ALL: List<Locale> = listOf(
        // ── Indonesian (also serves as Malay ms fallback) ────────────────────
        Locale("id",    "Bahasa Indonesia"),
        // ── Malay (Standard Malaysian; shares vocabulary with Indonesian) ──────
        Locale("ms",    "Bahasa Melayu"),
        // ── Welsh (Cymraeg; official language of Wales, UK) ───────────────────
        Locale("cy",    "Cymraeg"),
        // ── Danish ───────────────────────────────────────────────────────────────
        Locale("da",    "Dansk"),
        // ── German (primary development language / string source of truth) ───
        Locale("de",    "Deutsch"),
        // ── Estonian ─────────────────────────────────────────────────────────────
        Locale("et",    "Eesti"),
        // ── English (base locale — no values-en/ dir, falls back to values/) ─
        Locale("en",    "English"),
        // ── Spanish ──────────────────────────────────────────────────────────────
        Locale("es",    "Español"),
        // ── French ───────────────────────────────────────────────────────────────
        Locale("fr",    "Français"),
        // ── Faroese (Føroyskt; official language of the Faroe Islands) ───────────
        Locale("fo",    "Føroyskt"),
        // ── Irish ────────────────────────────────────────────────────────────────
        Locale("ga",    "Gaeilge"),
        // ── Hausa (Latin Boko orthography; lingua franca of West/Central Africa) ──
        Locale("ha",    "Hausa"),
        // ── Croatian ─────────────────────────────────────────────────────────────
        Locale("hr",    "Hrvatski"),
        // ── Italian ──────────────────────────────────────────────────────────────
        Locale("it",    "Italiano"),
        // ── Swahili (Kiswahili; lingua franca of East/Central Africa) ────────────
        Locale("sw",    "Kiswahili"),
        // ── Latin (novelty locale) ───────────────────────────────────────────────
        Locale("la",    "Latina"),
        // ── Latvian ──────────────────────────────────────────────────────────────
        Locale("lv",    "Latviešu"),
        // ── Lithuanian ───────────────────────────────────────────────────────────
        Locale("lt",    "Lietuvių"),
        // ── Luxembourgish (Lëtzebuergesch; national language of Luxembourg) ──────
        Locale("lb",    "Lëtzebuergesch"),
        // ── Hungarian ────────────────────────────────────────────────────────────
        Locale("hu",    "Magyar"),
        // ── Maltese ──────────────────────────────────────────────────────────────
        Locale("mt",    "Malti"),
        // ── Dutch ────────────────────────────────────────────────────────────────
        Locale("nl",    "Nederlands"),
        // ── Norwegian Bokmål ─────────────────────────────────────────────────────
        Locale("nb",    "Norsk bokmål"),
        // ── Polish ───────────────────────────────────────────────────────────────
        Locale("pl",    "Polski"),
        // ── Portuguese (European) ────────────────────────────────────────────────
        Locale("pt",    "Português"),
        // ── Portuguese (Brazilian) ───────────────────────────────────────────────
        Locale("pt-BR", "Português (Brasil)"),
        // ── Romanian ─────────────────────────────────────────────────────────────
        Locale("ro",    "Română"),
        // ── Slovak ───────────────────────────────────────────────────────────────
        Locale("sk",    "Slovenčina"),
        // ── Slovenian ────────────────────────────────────────────────────────────
        Locale("sl",    "Slovenščina"),
        // ── Finnish ──────────────────────────────────────────────────────────────
        Locale("fi",    "Suomi"),
        // ── Swedish ──────────────────────────────────────────────────────────────
        Locale("sv",    "Svenska"),
        // ── Vietnamese (Latin + combining tonal diacritics — do not strip!) ───
        Locale("vi",    "Tiếng Việt"),
        // ── Turkish (Latin + ç ğ ı İ ö ş ü; dotted-i handled by Android) ────
        Locale("tr",    "Türkçe"),
        // ── Yoruba (tonal diacritics are essential — do not strip) ────────────────
        Locale("yo",    "Yorùbá"),
        // ── Icelandic (Íslenska) ─────────────────────────────────────────────────
        Locale("is",    "Íslenska"),
        // ── Czech ────────────────────────────────────────────────────────────────
        Locale("cs",    "Čeština"),
        // ── Greek ────────────────────────────────────────────────────────────────
        Locale("el",    "Ελληνικά"),
        // ── Bulgarian ────────────────────────────────────────────────────────────
        Locale("bg",    "Български"),
        // ── Russian ──────────────────────────────────────────────────────────────
        Locale("ru",    "Русский"),
        // ── Ukrainian (Cyrillic — same font stack as Russian) ─────────────────
        Locale("uk",    "Українська"),
        // ── Hebrew ─────────────────────────────────────────── RTL ──────────
        Locale("he",    "עברית"),
        // ── Arabic ─────────────────────────────────────────── RTL ──────────
        Locale("ar",    "العربية"),
        // ── Hindi (Devanagari — rendered via Noto Sans Devanagari, API 21+) ──
        Locale("hi",    "हिन्दी"),
        // ── Bengali (Bengali script — rendered via Noto Sans Bengali, API 21+) ─
        Locale("bn",    "বাংলা"),
        // ── Marathi (Devanagari — same font stack as Hindi, API 21+) ─────────────
        Locale("mr",    "मराठी"),
        // ── Tamil (Tamil script — rendered via Noto Sans Tamil, API 21+) ──────────
        Locale("ta",    "தமிழ்"),
        // ── Telugu (Telugu script — rendered via Noto Sans Telugu, API 21+) ────────
        Locale("te",    "తెలుగు"),
        // ── Thai (Thai script — rendered via Noto Sans Thai, API 21+) ────────
        Locale("th",    "ภาษาไทย"),
        // ── Chinese, Simplified (Mainland China / Singapore) ─────────────────
        Locale("zh-CN", "中文（简体）"),
        // ── Chinese, Traditional (Taiwan / Hong Kong / Macau) ────────────────────
        Locale("zh-TW", "中文（繁體）"),
        // ── Japanese (Kanji/Hiragana/Katakana) ───────────────────────────────
        Locale("ja",    "日本語"),
        // ── Korean (Hangul — rendered via Noto Sans KR, API 21+) ─────────────
        Locale("ko",    "한국어")
    )

    /**
     * Convenience set of all BCP-47 tags for O(1) membership checks.
     * Used by [LocaleSyncTest] and the locale_config validator.
     */
    val TAGS: Set<String> = ALL.map { it.tag }.toSet()
}
