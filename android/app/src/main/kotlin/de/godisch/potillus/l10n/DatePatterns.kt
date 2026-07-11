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
//   together with the separator that attaches it — leaves the locale's
//   day/month fields and separator. Repeated pattern letters are then
//   collapsed ("dd.MM" → "d.M") so single-digit days/months render without
//   padding, matching the app's previous compact style. Finally the day/month
//   ORDER is aligned with the locale's MEDIUM pattern: a year-first SHORT
//   pattern (Swedish "y-MM-dd") says nothing about the order the locale uses
//   WITHOUT a year, and taking it literally rendered "6-28" for Swedish where
//   the convention is "28/6" (see alignDayMonthOrder below).
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
 * Matches a quoted pattern literal such as `'de'` (Portuguese "d 'de' MMM 'de' y")
 * or the escaped quote `''`. Literals must be blanked before LOCATING the day and
 * month fields, because their text may contain the letters 'd' or 'M' — the
 * Portuguese `'de'` literal starts with a 'd' that is NOT a day field.
 */
private val QUOTED_LITERAL = Regex("'[^']*'")

/**
 * Splits a compact two-field day/month pattern into (leading separator, first
 * field, middle separator, second field, trailing separator), where each field
 * is a run of 'd' or 'M' letters. Used by [alignDayMonthOrder] to swap the two
 * fields while keeping every separator character exactly where it was.
 */
private val TWO_FIELD_PATTERN = Regex("^([^A-Za-z]*)([dM]+)([^A-Za-z]*)([dM]+)([^A-Za-z]*)$")

/**
 * The locale's SHORT date pattern reduced to its day and month fields, for
 * compact "day + month" labels such as "28.6" (de), "6/28" (en-US, ja).
 *
 * Derivation: take the locale's full SHORT date pattern from java.time
 * (ISO chronology, so no era field can appear), remove the year field and its
 * attached separators, collapse repeated pattern letters so values render
 * unpadded, and finally align the day/month ORDER with the locale's MEDIUM
 * pattern (see [alignDayMonthOrder] for why the SHORT order alone is not
 * trustworthy). If the result unexpectedly lacks a day or month field (a
 * defensive guard — no CLDR locale shipped with the JDK/ICU behaves that way),
 * the full SHORT pattern is returned unchanged rather than something unusable.
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
    if (!stripped.contains('d') || !stripped.contains('M')) return full
    return alignDayMonthOrder(stripped, locale)
}

/**
 * Swaps the day and month fields of [stripped] when their order contradicts
 * the locale's MEDIUM date pattern, keeping every separator in place.
 *
 * WHY THE SHORT ORDER ALONE IS NOT TRUSTWORTHY (the Swedish case):
 *   Some locales use an ISO-like, YEAR-FIRST short pattern — Swedish is
 *   "y-MM-dd". Stripping the year from it leaves "M-d", i.e. MONTH first,
 *   although the Swedish convention for a compact day+month label is day
 *   first ("28/6"; CLDR's `Md` skeleton for sv is "d/M"). The year-first
 *   layout says nothing about the day/month order the locale uses when no
 *   year is present. The MEDIUM pattern, by contrast, spells the fields out
 *   in the locale's natural reading order for every locale this app ships
 *   ("d MMM y" for sv, "MMM d, y" for en-US, "y年M月d日" for zh), so its
 *   day/month order is the authoritative one. Verified by executing both
 *   derivations against all 21 shipped locales: the MEDIUM order matches the
 *   CLDR `Md` skeleton everywhere, and Swedish is the single locale where the
 *   SHORT-derived order disagrees (found in the v0.79.0 QA review — the
 *   previous test suite even pinned the wrong Swedish expectation).
 *
 * Quoted literals (e.g. the Portuguese "d 'de' MMM 'de' y") are blanked before
 * locating the fields so literal text containing 'd'/'M' cannot skew the order
 * detection. If either pattern is too unusual to locate both fields, [stripped]
 * is returned unchanged (defensive; does not occur for any shipped locale).
 */
private fun alignDayMonthOrder(stripped: String, locale: Locale): String {
    val medium = DateTimeFormatterBuilder.getLocalizedDateTimePattern(
        FormatStyle.MEDIUM,
        null,
        IsoChronology.INSTANCE,
        locale,
    ).replace(QUOTED_LITERAL, " ")

    val mediumDayFirst = medium.indexOf('d') < medium.indexOf('M')
    val strippedDayFirst = stripped.indexOf('d') < stripped.indexOf('M')
    if (medium.indexOf('d') < 0 || medium.indexOf('M') < 0) return stripped // defensive
    if (mediumDayFirst == strippedDayFirst) return stripped

    // Swap the two fields, keeping the separators exactly where they are:
    // "M-d" → "d-M", "M. d." → "d. M.".
    val m = TWO_FIELD_PATTERN.matchEntire(stripped) ?: return stripped // defensive
    val (lead, first, mid, second, trail) = m.destructured
    return "$lead$second$mid$first$trail"
}
