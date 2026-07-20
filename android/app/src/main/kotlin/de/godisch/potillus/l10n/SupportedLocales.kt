/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
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
        // ── Latin-script autonyms (alphabetical) ─────────────────────────────
        // ── Danish ───────────────────────────────────────────────────────────
        Locale("da", "Dansk"),
        // ── German (primary development language / string source of truth) ───
        Locale("de", "Deutsch"),
        // ── English (base locale — no values-en/ dir, falls back to values/) ─
        Locale("en", "English"),
        // ── Spanish ──────────────────────────────────────────────────────────
        Locale("es", "Español"),
        // ── French ───────────────────────────────────────────────────────────
        Locale("fr", "Français"),
        // ── Italian ──────────────────────────────────────────────────────────
        Locale("it", "Italiano"),
        // ── Dutch ────────────────────────────────────────────────────────────
        Locale("nl", "Nederlands"),
        // ── Norwegian Bokmål ─────────────────────────────────────────────────
        Locale("nb", "Norsk bokmål"),
        // ── Polish ───────────────────────────────────────────────────────────
        Locale("pl", "Polski"),
        // ── Portuguese (European) ────────────────────────────────────────────
        Locale("pt", "Português"),
        // ── Portuguese (Brazilian) ───────────────────────────────────────────
        Locale("pt-BR", "Português (Brasil)"),
        // ── Romanian ─────────────────────────────────────────────────────────
        Locale("ro", "Română"),
        // ── Swedish ──────────────────────────────────────────────────────────
        Locale("sv", "Svenska"),
        // ── Czech (Č sorts after the plain-Latin block) ──────────────────────
        Locale("cs", "Čeština"),
        // ── Greek ────────────────────────────────────────────────────────────
        Locale("el", "Ελληνικά"),
        // ── Cyrillic ─────────────────────────────────────────────────────────
        // ── Russian ──────────────────────────────────────────────────────────
        Locale("ru", "Русский"),
        // ── Ukrainian (Cyrillic — same font stack as Russian) ─────────────────
        Locale("uk", "Українська"),
        // ── CJK ──────────────────────────────────────────────────────────────
        // ── Chinese, Simplified (Mainland China / Singapore) ─────────────────
        Locale("zh-CN", "中文（简体）"),
        // ── Chinese, Traditional (Taiwan / Hong Kong / Macau) ────────────────
        Locale("zh-TW", "中文（繁體）"),
        // ── Japanese (Kanji/Hiragana/Katakana) ───────────────────────────────
        Locale("ja", "日本語"),
        // ── Korean (Hangul — rendered via Noto Sans KR, API 21+) ─────────────
        Locale("ko", "한국어"),
    )

    /**
     * Convenience set of all BCP-47 tags for O(1) membership checks.
     * Used by [LocaleSyncTest] and the locale_config validator.
     */
    val TAGS: Set<String> = ALL.map { it.tag }.toSet()

    /**
     * Language tags that other writers of the shared backup format use for a
     * language THIS catalogue spells differently.
     *
     * The one divergence today is Chinese: iOS String Catalogs key Chinese by
     * SCRIPT (`zh-Hans` / `zh-Hant`), so the iOS app stores — and therefore
     * exports into its backups — the script tags, while this catalogue uses the
     * REGION tags (`zh-CN` / `zh-TW`) that Android's `values-zh-rCN/` resource
     * qualifiers are built from. Without this map, restoring an iOS backup with
     * `"language": "zh-Hans"` on Android silently degraded the explicit language
     * choice to `""` (follow the system) — found in the v0.84.0 QA round. The
     * map is the mirror image of `migratedTags` in the iOS
     * `SupportedLocales.swift`, which rewrites `zh-CN` → `zh-Hans` for the
     * opposite restore direction.
     *
     * Internal (not private) so [LocaleSyncTest] can assert that every key maps
     * onto a tag the catalogue actually ships.
     */
    internal val MIGRATED_TAGS: Map<String, String> = mapOf(
        "zh-Hans" to "zh-CN",
        "zh-Hant" to "zh-TW",
    )

    /**
     * Normalises a raw language tag to this catalogue's canonical spelling, or
     * `""` (the "follow the system language" sentinel) for anything unknown.
     *
     * Two steps, in this order — the same order as the iOS `canonicalTag`:
     *  1. MIGRATION: a sibling-platform spelling from [MIGRATED_TAGS] is
     *     rewritten to this catalogue's tag first (`zh-Hans` → `zh-CN`), so an
     *     iOS backup restores its Chinese language choice instead of dropping
     *     to System.
     *  2. CANONICALISATION: the (possibly migrated) tag is matched against
     *     [ALL] case-insensitively, and the CATALOGUE's own casing is returned
     *     (`"DE"` → `"de"`, `"pt-br"` → `"pt-BR"`).
     *
     * An unknown tag becomes `""` rather than an error, so a backup written by
     * a newer app version that added a language restores gracefully — the same
     * degrade-to-default contract every other settings field follows in
     * [de.godisch.potillus.util.BackupManager.parseBackupJson].
     *
     * @param raw The tag as found in a backup file or stored preference.
     * @return The canonical tag from [ALL], or `""` when unsupported.
     */
    fun canonicalTag(raw: String): String {
        val migrated = MIGRATED_TAGS.entries
            .firstOrNull { it.key.equals(raw, ignoreCase = true) }?.value ?: raw
        return ALL.firstOrNull { it.tag.equals(migrated, ignoreCase = true) }?.tag ?: ""
    }
}
