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
// The vectors cover the two traps: DST transitions (the spring-forward gap and
// the fall-back repetition) and cross-timezone instants.
//
// This complements — it does not replace — DayResolverTest.kt, which remains the
// authoritative, expressive unit suite the vectors were harvested from.
// =============================================================================

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.ZoneId
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
                changeHour = case.getInt("changeHour"),
                changeMinute = case.getInt("changeMinute"),
                zoneId = ZoneId.of(case.getString("zoneId")),
            )
            assertEquals(
                "resolve: ${case.getString("description")}",
                case.getString("expected"),
                actual,
            )
        }
    }

    // ── instantOnLogicalDate ─────────────────────────────────────────────────

    @Test
    fun `instantOnLogicalDate matches the shared vectors`() {
        VECTORS.getJSONArray("instantOnLogicalDate").objects().forEach { case ->
            val actual = DayResolver.instantOnLogicalDate(
                logicalDate = case.getString("logicalDate"),
                hour = case.getInt("hour"),
                minute = case.getInt("minute"),
                changeHour = case.getInt("changeHour"),
                changeMinute = case.getInt("changeMinute"),
                zoneId = ZoneId.of(case.getString("zoneId")),
            )
            assertEquals(
                "instantOnLogicalDate: ${case.getString("description")}",
                case.getLong("expected"),
                actual,
            )
        }
    }

    /**
     * [DayResolver.instantOnLogicalDate] and [DayResolver.resolve] are inverses:
     * an instant built for a logical date must resolve back to it. This is the
     * property the calendar relies on when it logs to a day other than today.
     */
    @Test
    fun `instantOnLogicalDate round trips through resolve`() {
        val berlin = ZoneId.of("Europe/Berlin")
        listOf(20 to 0, 1 to 0, 4 to 0, 3 to 59, 23 to 30).forEach { (hour, minute) ->
            val millis = DayResolver.instantOnLogicalDate(
                logicalDate = "2026-08-30",
                hour = hour,
                minute = minute,
                changeHour = 4,
                changeMinute = 0,
                zoneId = berlin,
            )
            assertEquals(
                "round trip at $hour:$minute",
                "2026-08-30",
                DayResolver.resolve(millis!!, 4, 0, berlin),
            )
        }
    }

    /** A date the parser does not accept yields null rather than a guess. */
    @Test
    fun `instantOnLogicalDate rejects a non canonical date`() {
        assertNull(
            DayResolver.instantOnLogicalDate(
                logicalDate = "2026-8-30",
                hour = 20,
                minute = 0,
                changeHour = 4,
                changeMinute = 0,
                zoneId = ZoneId.of("Europe/Berlin"),
            ),
        )
    }

    /**
     * The same instant is a different logical day in different zones. This is not
     * a quirk to smooth over — it is why the zone is an explicit parameter rather
     * than an ambient global. 23:00 in New York is already 05:00 the next day in
     * Berlin, so with a 04:00 boundary the two zones disagree by one day.
     */
    @Test
    fun `resolve is timezone dependent for the same instant`() {
        val instant = 1_748_142_000_000L
        val inNewYork = DayResolver.resolve(instant, 4, 0, ZoneId.of("America/New_York"))
        val inBerlin = DayResolver.resolve(instant, 4, 0, ZoneId.of("Europe/Berlin"))
        assertNotEquals("The same instant must resolve per zone", inNewYork, inBerlin)
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
