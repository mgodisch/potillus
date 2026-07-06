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
package de.godisch.potillus.l10n

// =============================================================================
// DatePatterns.kt — locale-aware SHORT date patterns without a year component
// =============================================================================
//
// THE PROBLEM THIS SOLVES
//   Two places in the app show a compact "day + month" date — the weekly range
//   label on the Today screen ("28.6.–4.7.") and the x-axis tick labels of the
//   PDF report chart. Both used to hard-code the German/European pattern
//   "d.M.", which renders the WRONG order for locales like en-US ("6/28"),
//   Japanese or Chinese ("6/28"-style as well) — an odd gap in an app whose
//   other output is carefully localized.
//
// WHY NOT android.text.format.DateFormat.getBestDateTimePattern()?
//   That Android API would be the canonical answer (it resolves a CLDR
//   skeleton like "dM" per locale), but it is unavailable in local JVM unit
//   tests: the stubbed android.jar returns null and the callers below live in
//   ViewModel code that IS unit-tested on the JVM. The pure-java.time approach
//   here keeps the logic device-free and directly testable (DatePatternsTest).
//
// HOW IT WORKS
//   java.time exposes each locale's full SHORT date pattern (e.g. "dd.MM.yy"
//   for de, "M/d/yy" for en-US, "y/MM/dd" for ja). Stripping the year field —
//   together with the separator that attaches it — leaves exactly the
//   locale's day/month order and separator. Repeated pattern letters are then
//   collapsed ("dd.MM" → "d.M") so single-digit days/months render without
//   padding, matching the app's previous compact style.
// =============================================================================

import java.time.chrono.IsoChronology
import java.time.format.DateTimeFormatterBuilder
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Matches the year field of a date pattern together with the non-letter
 * separator characters that attach it — e.g. ".yy" in "dd.MM.yy", "yy. " in
 * "yy. M. d." or "y/" in "y/MM/dd". Pattern letters for the year are 'y'
 * (year-of-era) and 'u' (proleptic year); everything that is not a pattern
 * letter (dots, slashes, hyphens, spaces) counts as separator.
 */
private val YEAR_WITH_SEPARATORS = Regex("[^A-Za-z]*[yu]+[^A-Za-z]*")

/** Collapses runs of the same pattern letter to one ("dd" → "d", "MM" → "M"). */
private val REPEATED_PATTERN_LETTER = Regex("([A-Za-z])\\1+")

/**
 * The locale's SHORT date pattern reduced to its day and month fields, for
 * compact "day + month" labels such as "28.6" (de), "6/28" (en-US, ja).
 *
 * Derivation: take the locale's full SHORT date pattern from java.time
 * (ISO chronology, so no era field can appear), remove the year field and its
 * attached separators, and collapse repeated pattern letters so values render
 * unpadded. If the result unexpectedly lacks a day or month field (a defensive
 * guard — no CLDR locale shipped with the JDK/ICU behaves that way), the full
 * SHORT pattern is returned unchanged rather than something unusable.
 *
 * @param locale The locale whose day/month ORDER and SEPARATOR to use —
 *               normally `context.formattingLocale()` so the label follows the
 *               in-app language.
 * @return A [java.time.format.DateTimeFormatter.ofPattern]-compatible pattern
 *         containing a day-of-month and a month field, e.g. "d.M" or "M/d".
 */
fun shortDayMonthPattern(locale: Locale): String {
    val full = DateTimeFormatterBuilder.getLocalizedDateTimePattern(
        FormatStyle.SHORT,
        null,
        IsoChronology.INSTANCE,
        locale,
    )
    val stripped = full
        .replace(YEAR_WITH_SEPARATORS, "")
        .replace(REPEATED_PATTERN_LETTER, "$1")
    return if (stripped.contains('d') && stripped.contains('M')) stripped else full
}
