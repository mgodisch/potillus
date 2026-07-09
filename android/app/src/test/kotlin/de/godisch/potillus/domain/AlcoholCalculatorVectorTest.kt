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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.domain

// =============================================================================
// AlcoholCalculatorVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts the JVM implementation against `test-vectors/alcohol-calculator.json`,
// the same file the iOS Swift suite loads. Together the two suites close the
// parity loop: a formula changed on one platform alone turns the other red.
//
// This complements — it does not replace — AlcoholCalculatorTest.kt. That suite
// remains the authoritative, expressive unit test; the vectors were harvested
// from it. This file exists so the *shared contract* is enforced on this side
// too, and so any future edit to the vectors is felt on both platforms at once.
// =============================================================================

import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.TrafficLight
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlcoholCalculatorVectorTest {

    private companion object {
        /** Absolute tolerance, matching the epsilon used by AlcoholCalculatorTest. */
        const val EPS = 0.001

        /** Loaded once; a failure here fails the whole class, by design. */
        val VECTORS: JSONObject = SharedTestVectors.load("alcohol-calculator")

        /** Iterates a JSON array of objects as a Kotlin sequence. */
        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }
    }

    // ── Constants ────────────────────────────────────────────────────────────
    //
    // The vector file restates the constants. Asserting them catches a whole
    // class of silent divergence: changing the ethanol density or the binge
    // threshold on one platform only fails here immediately.

    @Test
    fun `constants match the shared vectors`() {
        val constants = VECTORS.getJSONObject("constants")
        assertEquals(constants.getDouble("ethanolDensity"), AlcoholCalculator.ETHANOL_DENSITY, 0.0)
        assertEquals(constants.getDouble("bingeThreshold"), AlcoholCalculator.BINGE_THRESHOLD, 0.0)
        assertEquals(constants.getInt("windowDays"), AlcoholCalculator.WINDOW_DAYS)
        // The epsilon is private; assert its effect instead of its value: a value
        // one epsilon-tenth above the limit must not count as an exceedance.
        val eps = constants.getDouble("limitEpsilon")
        assertFalse(AlcoholCalculator.isOverLimit(20.0 + eps / 10.0, 20.0))
        assertTrue(AlcoholCalculator.isOverLimit(20.0 + eps * 10.0, 20.0))
    }

    // ── calculateGrams ───────────────────────────────────────────────────────

    @Test
    fun `calculateGrams matches the shared vectors`() {
        VECTORS.getJSONArray("calculateGrams").objects().forEach { case ->
            val actual = AlcoholCalculator.calculateGrams(
                volumeMl = case.getInt("volumeMl"),
                alcoholPercent = case.getDouble("alcoholPercent"),
            )
            assertEquals(
                "calculateGrams: ${case.getString("description")}",
                case.getDouble("expected"), actual, EPS,
            )
        }
    }

    // ── calculateBAC ─────────────────────────────────────────────────────────

    @Test
    fun `calculateBAC matches the shared vectors`() {
        VECTORS.getJSONArray("calculateBAC").objects().forEach { case ->
            val actual = AlcoholCalculator.calculateBAC(
                totalGrams = case.getDouble("totalGrams"),
                weightKg = case.getDouble("weightKg"),
                hoursElapsed = case.getDouble("hoursElapsed"),
            )
            assertEquals(
                "calculateBAC: ${case.getString("description")}",
                case.getDouble("expected"), actual, EPS,
            )
        }
    }

    // ── limitPercent ─────────────────────────────────────────────────────────

    @Test
    fun `limitPercent matches the shared vectors`() {
        VECTORS.getJSONArray("limitPercent").objects().forEach { case ->
            val actual = AlcoholCalculator.limitPercent(
                totalGrams = case.getDouble("totalGrams"),
                limitGrams = case.getDouble("limitGrams"),
            )
            assertEquals(
                "limitPercent: ${case.getString("description")}",
                case.getDouble("expected"), actual.toDouble(), EPS,
            )
        }
    }

    // ── isOverLimit ──────────────────────────────────────────────────────────
    //
    // The tolerance is the fix for a real bug: 0.1-g values summed as binary
    // doubles can drift above an exactly-met limit, and a strict `>` then reports
    // an exceedance the user cannot see.

    @Test
    fun `isOverLimit matches the shared vectors`() {
        VECTORS.getJSONArray("isOverLimit").objects().forEach { case ->
            val actual = AlcoholCalculator.isOverLimit(
                totalGrams = case.getDouble("totalGrams"),
                limitGrams = case.getDouble("limitGrams"),
            )
            assertEquals(
                "isOverLimit: ${case.getString("description")}",
                case.getBoolean("expected"), actual,
            )
        }
    }

    /**
     * Reproduces the drift the tolerance exists for: summing these three
     * 0.1-g-grid values yields 190.60000000000002 against a 190.6 g limit.
     */
    @Test
    fun `floating point drift is not an exceedance`() {
        val drifted = 44.5 + 80.9 + 65.2
        assertTrue("Precondition: the sum really does drift", drifted > 190.6)
        assertFalse(AlcoholCalculator.isOverLimit(drifted, 190.6))
    }

    // ── trafficLight ─────────────────────────────────────────────────────────

    @Test
    fun `trafficLight matches the shared vectors`() {
        VECTORS.getJSONArray("trafficLight").objects().forEach { case ->
            val actual = AlcoholCalculator.trafficLight(
                gramsPerDrink = case.getDouble("gramsPerDrink"),
                todayGrams = case.getDouble("todayGrams"),
                dailyLimitGrams = case.getDouble("dailyLimitGrams"),
                weeklyTotalGrams = case.getDouble("weeklyTotalGrams"),
                weeklyLimitGrams = case.getDouble("weeklyLimitGrams"),
                drinkDaysThisWeek = case.getInt("drinkDaysThisWeek"),
                maxDrinkDaysPerWeek = case.getInt("maxDrinkDaysPerWeek"),
            )
            // The JSON stores the Kotlin enum constant name, so valueOf maps directly.
            val expected = TrafficLight.valueOf(case.getString("expected"))
            assertEquals("trafficLight: ${case.getString("description")}", expected, actual)
        }
    }

    // ── countLimitViolations ─────────────────────────────────────────────────

    @Test
    fun `countLimitViolations matches the shared vectors`() {
        VECTORS.getJSONArray("countLimitViolations").objects().forEach { case ->
            val actual = AlcoholCalculator.countLimitViolations(
                summaries = case.daySummaries(),
                dailyLimitGrams = case.getDouble("dailyLimitGrams"),
                weeklyLimitGrams = case.getDouble("weeklyLimitGrams"),
                maxDrinkDaysPerWeek = case.getInt("maxDrinkDaysPerWeek"),
            )
            val expected = case.getJSONObject("expected")
            val label = case.getString("description")
            assertEquals(
                "daysOverDailyLimit: $label",
                expected.getInt("daysOverDailyLimit"), actual.daysOverDailyLimit,
            )
            assertEquals(
                "daysOverWeeklyLimit: $label",
                expected.getInt("daysOverWeeklyLimit"), actual.daysOverWeeklyLimit,
            )
            assertEquals(
                "daysOverDrinkDayLimit: $label",
                expected.getInt("daysOverDrinkDayLimit"), actual.daysOverDrinkDayLimit,
            )
        }
    }

    /**
     * Summaries arrive from the database in arbitrary order, so the sliding
     * window must sort them itself. Reversing the input must change nothing.
     */
    @Test
    fun `countLimitViolations is order independent`() {
        VECTORS.getJSONArray("countLimitViolations").objects().forEach { case ->
            val summaries = case.daySummaries()
            val forward = AlcoholCalculator.countLimitViolations(
                summaries, case.getDouble("dailyLimitGrams"),
                case.getDouble("weeklyLimitGrams"), case.getInt("maxDrinkDaysPerWeek"),
            )
            val reversed = AlcoholCalculator.countLimitViolations(
                summaries.reversed(), case.getDouble("dailyLimitGrams"),
                case.getDouble("weeklyLimitGrams"), case.getInt("maxDrinkDaysPerWeek"),
            )
            assertEquals("order dependence: ${case.getString("description")}", forward, reversed)
        }
    }

    /**
     * Converts the vector's positional `[isoDate, grams]` pairs into DaySummary
     * values. The pairs are positional to keep the JSON compact and neutral
     * between the two languages.
     */
    private fun JSONObject.daySummaries(): List<DaySummary> {
        val days = getJSONArray("days")
        return (0 until days.length()).map { index ->
            val pair = days.getJSONArray(index)
            DaySummary(
                date = pair.getString(0),
                totalGrams = pair.getDouble(1),
                entryCount = 1,
            )
        }
    }
}
