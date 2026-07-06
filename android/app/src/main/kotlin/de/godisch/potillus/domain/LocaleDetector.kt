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
// MATCHING STRATEGY (unchanged, now documented centrally):
//   1. Exact full-tag match on the IETF language tag, e.g. "zh-CN", "pt-BR".
//      Covers region variants where a dedicated translation exists.
//   2. Base-language match on the language subtag alone, e.g. "de", "fr".
//      Covers systems configured for a dialect whose full tag is not in the
//      supported set (e.g. "de-AT" → "de").
//   3. Fall back to "en" (the base locale present in values/).
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
     * 2. Base-language match (e.g. `"de-AT"` → `"de"`).
     * 3. `"en"` as the unconditional fallback.
     *
     * @param systemLocale  The JVM locale to match (typically [Locale.getDefault]).
     * @param supportedTags The set of BCP-47 tags the app ships translations for,
     *                      e.g. [de.godisch.potillus.l10n.SupportedLocales.TAGS].
     * @return A tag from [supportedTags], or `"en"` if none matched.
     */
    fun detect(systemLocale: Locale, supportedTags: Set<String>): String {
        val fullTag = systemLocale.toLanguageTag() // e.g. "zh-CN", "pt-BR", "de"
        val baseLang = systemLocale.language // e.g. "zh",    "pt",    "de"

        // Step 1: exact full-tag match (covers region-specific translations).
        supportedTags.firstOrNull { it.equals(fullTag, ignoreCase = true) }
            ?.let { return it }

        // Step 2: base-language match (e.g. "de-AT" → "de").
        supportedTags.firstOrNull { it.equals(baseLang, ignoreCase = true) }
            ?.let { return it }

        // Step 3: English base-locale fallback.
        return "en"
    }
}
