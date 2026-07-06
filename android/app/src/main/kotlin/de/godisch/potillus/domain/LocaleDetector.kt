/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
package de.godisch.potillus.domain

// =============================================================================
// LocaleDetector.kt – First-launch language detection (T-03 fix)
// =============================================================================
//
// WHY EXTRACTED FROM PotillusApp?
//   The language-detection logic (match system locale against supported BCP-47
//   tags, fall back to "en") was previously a private suspend fun inside
//   PotillusApp. That placement had two drawbacks for a teaching app:
//     1. The logic could not be unit-tested: PotillusApp requires a real
//        Android Application context that is unavailable on the JVM.
//     2. Readers of PotillusApp had to navigate into the function to understand
//        the matching strategy; a named object is easier to find and reference.
//
//   Moving the pure matching logic here (no Android dependency, no suspend)
//   makes it testable in LocaleDetectorTest on the JVM. PotillusApp.kt retains
//   the side-effectful parts (DataStore write, AppCompatDelegate call) and
//   delegates the detection step to LocaleDetector.detect().
//
// MATCHING STRATEGY (script-aware since the v0.79.0 QA review):
//   1. Exact full-tag match on the IETF language tag, e.g. "zh-CN", "pt-BR".
//   2. Language + region with the script subtag DROPPED, e.g. the
//      "zh-Hant-TW" that modern Android actually reports → "zh-TW".
//   3. Chinese script/region disambiguation for the remaining zh variants
//      (Hant script or TW/HK/MO region → "zh-TW", otherwise "zh-CN").
//   4. Base-language match on the language subtag alone, e.g. "de-AT" → "de"
//      (with the Norwegian macrolanguage alias "no" folded onto "nb").
//   5. Fall back to "en" (the base locale present in values/).
//
//   Only locales present in [supportedTags] are ever returned; the app never
//   falls back to a "best-guess sibling" that it does not actually ship.
// =============================================================================

import java.util.Locale

/**
 * Pure, Android-free helper that maps a JVM [Locale] to the best-matching
 * BCP-47 language tag from a set of supported tags.
 *
 * All methods are static (the object is a Kotlin singleton) and pure: the
 * same inputs always produce the same output with no side effects, making
 * them straightforward to unit-test without a device.
 */
object LocaleDetector {

    /**
     * Returns the best-matching supported BCP-47 tag for [systemLocale].
     *
     * Matching is tried in order of specificity:
     * 1. Full IETF tag match (e.g. `"zh-CN"`, `"pt-BR"`, `"de"`).
     * 2. Language + region with the SCRIPT subtag dropped. Modern Android
     *    reports Chinese with an explicit script — `"zh-Hant-TW"`,
     *    `"zh-Hans-CN"` — so the full tag never equals the shipped `"zh-TW"` /
     *    `"zh-CN"`. Comparing only language+region closes that gap (found in
     *    the v0.79.0 QA review: Traditional/Simplified Chinese users were
     *    silently forced to English on first launch, and the persisted choice
     *    even overrode Android's own — correct — resource fallback).
     * 3. Chinese script/region mapping for the remaining `zh` variants that
     *    carry neither a supported full tag nor a supported language+region:
     *    the `Hant` script (or, without a script, the traditionally
     *    Traditional-script regions TW/HK/MO) selects `"zh-TW"`; everything
     *    else — `Hans`, bare `"zh"`, `"zh-SG"` — selects `"zh-CN"`. This step
     *    only ever returns tags that are actually in [supportedTags].
     * 4. Base-language match (e.g. `"de-AT"` → `"de"`).
     * 5. `"en"` as the unconditional fallback.
     *
     * NORWEGIAN ALIAS: the ISO macrolanguage code `"no"` and the Bokmål code
     * `"nb"` denote the same shipped translation. Android itself reports `nb`,
     * but store-locale codes (Google Play uses `no-NO`) and older sources use
     * `no`; [normalizeLanguage] folds `no` onto `nb` before the language-based
     * steps so both spellings find the `values-nb` translation. (The screenshot
     * suite feeds store locales through this function — see ScreenshotTest.)
     *
     * @param systemLocale  The JVM locale to match (typically [Locale.getDefault]).
     * @param supportedTags The set of BCP-47 tags the app ships translations for,
     *                      e.g. [de.godisch.potillus.l10n.SupportedLocales.TAGS].
     * @return A tag from [supportedTags], or `"en"` if none matched.
     */
    fun detect(systemLocale: Locale, supportedTags: Set<String>): String {
        val fullTag = systemLocale.toLanguageTag() // e.g. "zh-Hant-TW", "pt-BR", "de"
        val baseLang = normalizeLanguage(systemLocale.language) // e.g. "zh", "pt", "nb"
        val region = systemLocale.country // e.g. "TW", "BR", "" when absent

        // Step 1: exact full-tag match (covers region-specific translations on
        // devices that report no script subtag).
        supportedTags.firstOrNull { it.equals(fullTag, ignoreCase = true) }
            ?.let { return it }

        // Step 2: language + region, ignoring any script subtag
        // ("zh-Hant-TW" → "zh-TW", "zh-Hans-CN" → "zh-CN").
        if (region.isNotEmpty()) {
            val langRegion = "$baseLang-$region"
            supportedTags.firstOrNull { it.equals(langRegion, ignoreCase = true) }
                ?.let { return it }
        }

        // Step 3: Chinese script/region disambiguation for the variants left
        // over after steps 1–2 (e.g. "zh-Hant-HK", bare "zh", "zh-SG").
        if (baseLang == "zh") {
            val traditional = systemLocale.script.equals("Hant", ignoreCase = true) ||
                (systemLocale.script.isEmpty() && region in setOf("TW", "HK", "MO"))
            val zhTag = if (traditional) "zh-TW" else "zh-CN"
            supportedTags.firstOrNull { it.equals(zhTag, ignoreCase = true) }
                ?.let { return it }
        }

        // Step 4: base-language match (e.g. "de-AT" → "de", "no-NO" → "nb").
        supportedTags.firstOrNull { it.equals(baseLang, ignoreCase = true) }
            ?.let { return it }

        // Step 5: English base-locale fallback.
        return "en"
    }

    /**
     * Folds language-code aliases onto the code the app's resources use.
     *
     * Currently only Norwegian: `"no"` (the ISO 639 macrolanguage) → `"nb"`
     * (Bokmål, the code Android reports and `values-nb/` ships under). Android's
     * own resource matcher treats the two as compatible; this keeps the pure-JVM
     * detector in line with that behaviour.
     */
    private fun normalizeLanguage(language: String): String = if (language.equals("no", ignoreCase = true)) "nb" else language.lowercase(Locale.ROOT)
}
