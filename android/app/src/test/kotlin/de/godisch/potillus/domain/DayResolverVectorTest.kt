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
package de.godisch.potillus.domain

// =============================================================================
// DayResolverVectorTest.kt – cross-platform parity suite for the logical day
// =============================================================================
//
// Asserts the JVM implementation against `test-vectors/day-resolver.json`, the
// same file the iOS Swift suite loads. The logical-day boundary decides which
// day every entry belongs to, so a divergence would silently corrupt daily
// totals, the rolling 7-day window, violation counts and streaks alike.
//
// The vectors cover what a recorded frame leaves of the two traps: each instant
// around a daylight-saving switch is read once in the offset before it and once
// in the offset after, and the same instant is read in two frames. A fixed
// offset knows no switch, so the pairs are the statement `resolve` can still
// make — and the one that lands on two days is the one that matters.
//
// This complements — it does not replace — DayResolverTest.kt, which remains the
// authoritative, expressive unit suite the vectors were harvested from.
// =============================================================================

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.util.Locale

class DayResolverVectorTest {

    private companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("day-resolver")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        /** Reads a JSON string array into a Kotlin list. */
        fun JSONObject.stringList(key: String): List<String> {
            val array = getJSONArray(key)
            return (0 until array.length()).map { array.getString(it) }
        }
    }

    // ── resolve ──────────────────────────────────────────────────────────────

    @Test
    fun `resolve matches the shared vectors`() {
        VECTORS.getJSONArray("resolve").objects().forEach { case ->
            val actual = DayResolver.resolve(
                timestampMillis = case.getLong("epochMillis"),
                utcOffsetSeconds = case.getInt("utcOffsetSeconds"),
                changeHour = case.getInt("changeHour"),
                changeMinute = case.getInt("changeMinute"),
            )
            assertEquals(
                "resolve: ${case.getString("description")}",
                case.getString("expected"),
                actual,
            )
        }
    }

    // ── logicalDayDiffers ────────────────────────────────────────────────────

    @Test
    fun `logicalDayDiffers matches the shared vectors`() {
        VECTORS.getJSONArray("logicalDayDiffers").objects().forEach { case ->
            val actual = DayResolver.logicalDayDiffers(
                timestampMillis = case.getLong("epochMillis"),
                utcOffsetSeconds = case.getInt("utcOffsetSeconds"),
                changeHour = case.getInt("changeHour"),
                changeMinute = case.getInt("changeMinute"),
                logicalDay = case.getString("logicalDay"),
            )
            assertEquals(
                "logicalDayDiffers: ${case.getString("description")}",
                case.getBoolean("expected"),
                actual,
            )
        }
    }

    /**
     * The same instant is a different logical day in a different frame. This is
     * not a quirk to smooth over — it is why the offset is an explicit parameter
     * rather than an ambient global. 23:00 read at −04:00 is already 05:00 the
     * next day at +02:00, so with a 04:00 boundary the two readings disagree by
     * one day. The entry keeps the frame it was written in, so the day it counts
     * toward does not move when the device zone does.
     */
    @Test
    fun `resolve follows the offset it is given for the same instant`() {
        val instant = 1_748_142_000_000L
        val atMinusFour = DayResolver.resolve(instant, -4 * 3600, 4, 0)
        val atPlusTwo = DayResolver.resolve(instant, 2 * 3600, 4, 0)
        assertNotEquals("The same instant must resolve per frame", atMinusFour, atPlusTwo)
    }

    // ── effectivePeriodDays ──────────────────────────────────────────────────

    @Test
    fun `effectivePeriodDays matches the shared vectors`() {
        VECTORS.getJSONArray("effectivePeriodDays").objects().forEach { case ->
            val actual = DayResolver.effectivePeriodDays(
                from = case.getString("from"),
                today = case.getString("today"),
                todayIsDrinkDay = case.getBoolean("todayIsDrinkDay"),
            )
            assertEquals(
                "effectivePeriodDays: ${case.getString("description")}",
                case.getInt("expected"),
                actual,
            )
        }
    }

    // ── windowDays ───────────────────────────────────────────────────────────

    @Test
    fun `windowDays matches the shared vectors`() {
        VECTORS.getJSONArray("windowDays").objects().forEach { case ->
            val actual = DayResolver.windowDays(
                from = case.getString("from"),
                to = case.getString("to"),
                today = case.getString("today"),
                todayIsDrinkDay = case.getBoolean("todayIsDrinkDay"),
            )
            assertEquals(
                "windowDays: ${case.getString("description")}",
                case.getInt("expected"),
                actual,
            )
        }
    }

    // ── computeCurrentAbstinence ─────────────────────────────────────────────

    @Test
    fun `computeCurrentAbstinence matches the shared vectors`() {
        VECTORS.getJSONArray("computeCurrentAbstinence").objects().forEach { case ->
            val actual = DayResolver.computeCurrentAbstinence(
                sortedDates = case.stringList("dates"),
                today = case.getString("today"),
                statsFrom = case.getString("statsFrom"),
            )
            assertEquals(
                "computeCurrentAbstinence: ${case.getString("description")}",
                case.getInt("expected"),
                actual,
            )
        }
    }

    // ── computeLongestAbstinence ─────────────────────────────────────────────

    @Test
    fun `computeLongestAbstinence matches the shared vectors`() {
        VECTORS.getJSONArray("computeLongestAbstinence").objects().forEach { case ->
            val actual = DayResolver.computeLongestAbstinence(
                sortedDates = case.stringList("dates"),
                today = case.getString("today"),
                statsFrom = case.getString("statsFrom"),
            )
            assertEquals(
                "computeLongestAbstinence: ${case.getString("description")}",
                case.getInt("expected"),
                actual,
            )
        }
    }

    // ── firstDayOfWeekIso ────────────────────────────────────────────────────
    //
    // The number that heads column 0 of the calendar grid and orders the report's
    // weekday histogram. Two numbering schemes meet across the two platforms:
    // `WeekFields.of(locale).firstDayOfWeek.value` counts Monday as 1, while
    // Foundation's `Calendar.firstWeekday` counts Sunday as 1 and the Swift side
    // converts. A conversion nobody asserts is a week rotated by one day on one
    // platform, which is why the vectors reached this function in the 0.85.0 QA
    // round: until then neither suite pinned it.

    @Test
    fun `firstDayOfWeekIso matches the shared vectors`() {
        VECTORS.getJSONArray("firstDayOfWeekIso").objects().forEach { case ->
            val actual = DayResolver.firstDayOfWeekIso(
                Locale.forLanguageTag(case.getString("languageTag")),
            )
            assertEquals(
                "firstDayOfWeekIso: ${case.getString("description")}",
                case.getInt("expected"),
                actual,
            )
        }
    }
}
