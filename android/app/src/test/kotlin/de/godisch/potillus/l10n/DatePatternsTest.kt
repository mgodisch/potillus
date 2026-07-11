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

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Unit tests for [shortDayMonthPattern] (`DatePatterns.kt`).
 *
 * WHAT IS COVERED:
 *   - The year field (and its attached separator) is removed for every locale
 *     the app ships — the pattern must never leak a year into the compact
 *     labels.
 *   - The locale's day/month ORDER matches the locale's convention: day-first
 *     for the European locales INCLUDING Swedish (whose year-first SHORT
 *     pattern must not leak a month-first order), month-first for
 *     en-US / ja / zh / ko.
 *   - Repeated pattern letters are collapsed, so values render unpadded
 *     ("28.6", not "28.06").
 *   - Every produced pattern actually FORMATS (no stray literals that
 *     DateTimeFormatter.ofPattern would reject).
 *
 * WHY ASSERTIONS AVOID EXACT PATTERN STRINGS (mostly):
 *   The source patterns come from the JDK's CLDR data, which can shift in
 *   minor ways between JDK releases (e.g. "y" vs "yy"). Asserting structural
 *   properties (no year, correct field order, formattability) keeps the test
 *   green across JDK updates while still failing on real regressions. The two
 *   exact-string cases (de, en-US) pin the canonical outputs the UI shows.
 */
class DatePatternsTest {

    /** The BCP-47 tags of every locale the app ships (SupportedLocales.ALL). */
    private val appLocales = listOf(
        "cs", "da", "de", "el", "en", "es", "fr", "it", "ja", "ko",
        "nb", "nl", "pl", "pt", "pt-BR", "ro", "ru", "sv", "uk",
        "zh-CN", "zh-TW",
    ).map(Locale::forLanguageTag)

    @Test fun `german pattern is unpadded day-dot-month`() {
        assertEquals("d.M", shortDayMonthPattern(Locale.GERMAN))
    }

    @Test fun `en-US pattern is month-slash-day`() {
        assertEquals("M/d", shortDayMonthPattern(Locale.US))
    }

    @Test fun `no app locale leaks a year field`() {
        for (locale in appLocales) {
            val pattern = shortDayMonthPattern(locale)
            assertFalse(
                "pattern for $locale must not contain a year field: $pattern",
                pattern.contains('y') || pattern.contains('u'),
            )
        }
    }

    @Test fun `every app locale keeps both day and month and formats cleanly`() {
        val probe = LocalDate.of(2026, 6, 28)
        for (locale in appLocales) {
            val pattern = shortDayMonthPattern(locale)
            assertTrue("pattern for $locale lacks a day field: $pattern", pattern.contains('d'))
            assertTrue("pattern for $locale lacks a month field: $pattern", pattern.contains('M'))
            // Must be a valid ofPattern() input AND render both numbers.
            val rendered = DateTimeFormatter.ofPattern(pattern, locale).format(probe)
            assertTrue("rendered '$rendered' for $locale lacks the day", rendered.contains("28"))
            assertTrue("rendered '$rendered' for $locale lacks the month", rendered.contains("6"))
        }
    }

    @Test fun `month-first locales put the month before the day`() {
        for (tag in listOf("en-US", "ja", "zh-CN", "zh-TW")) {
            val pattern = shortDayMonthPattern(Locale.forLanguageTag(tag))
            assertTrue(
                "month must precede day for $tag: $pattern",
                pattern.indexOf('M') < pattern.indexOf('d'),
            )
        }
    }

    @Test fun `day-first locales put the day before the month`() {
        // sv is deliberately in THIS list: its SHORT pattern is year-first
        // ("y-MM-dd"), whose naive year-stripping yields month-first — but the
        // Swedish day+month convention is day-first ("28/6", CLDR Md = "d/M").
        // The pre-v0.79.0 suite pinned sv as month-first, enshrining the bug.
        for (tag in listOf("de", "fr", "it", "es", "nl", "pl", "ru", "uk", "el", "pt", "pt-BR", "sv")) {
            val pattern = shortDayMonthPattern(Locale.forLanguageTag(tag))
            assertTrue(
                "day must precede month for $tag: $pattern",
                pattern.indexOf('d') < pattern.indexOf('M'),
            )
        }
    }

    @Test fun `repeated pattern letters are collapsed to render unpadded values`() {
        for (locale in appLocales) {
            val pattern = shortDayMonthPattern(locale)
            assertFalse("padded day field for $locale: $pattern", pattern.contains("dd"))
            assertFalse("padded month field for $locale: $pattern", pattern.contains("MM"))
        }
    }

    /**
     * Property: for every shipped locale, the derived day/month ORDER equals the
     * order of the locale's MEDIUM date pattern — the pattern that spells the
     * fields out in the locale's natural reading order (quoted literals such as
     * the Portuguese `'de'` are blanked before locating the fields, since their
     * text may contain the letters 'd'/'M'). This is the invariant the Swedish
     * fix rests on; it guards every locale, present and future, against the
     * year-first-SHORT-pattern trap in one sweep.
     */
    @Test fun `derived order matches the MEDIUM pattern order for every app locale`() {
        for (locale in appLocales) {
            val medium = java.time.format.DateTimeFormatterBuilder
                .getLocalizedDateTimePattern(
                    java.time.format.FormatStyle.MEDIUM,
                    null,
                    java.time.chrono.IsoChronology.INSTANCE,
                    locale,
                )
                .replace(Regex("'[^']*'"), " ")
            val pattern = shortDayMonthPattern(locale)
            assertEquals(
                "day/month order for $locale (derived '$pattern' vs MEDIUM '$medium')",
                medium.indexOf('d') < medium.indexOf('M'),
                pattern.indexOf('d') < pattern.indexOf('M'),
            )
        }
    }
}
