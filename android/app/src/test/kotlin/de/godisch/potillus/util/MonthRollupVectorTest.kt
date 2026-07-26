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
package de.godisch.potillus.util

import de.godisch.potillus.domain.SharedTestVectors
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// =============================================================================
// MonthRollupVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts MonthRollup against `test-vectors/month-rollup.json`, the same file the
// iOS suite loads. The cap exists so a report over a long period still fits its
// sheet; the summary row's average is the summed grams over the summed days, and
// a reimplementation that averages the monthly averages instead gets a different
// number for every period whose months differ in length — which is all of them.
// =============================================================================

class MonthRollupVectorTest {

    private companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("month-rollup")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        fun JSONObject.toMonthStat() = MonthStat(
            monthKey = getString("monthKey"),
            drinkDays = getInt("drinkDays"),
            totalGrams = getDouble("totalGrams"),
            avgPerCalendarDay = getDouble("avgPerCalendarDay"),
            daysOverDailyLimit = getInt("daysOverDailyLimit"),
            effectiveDays = getInt("effectiveDays"),
            rollupFromKey = if (isNull("rollupFromKey")) null else getString("rollupFromKey"),
        )
    }

    @Test
    fun `the kept count matches the shared vectors`() {
        assertEquals(VECTORS.getInt("keep"), MonthRollup.KEEP)
    }

    @Test
    fun `capped matches the shared vectors`() {
        VECTORS.getJSONArray("cases").objects().forEach { case ->
            val what = case.getString("description")
            val input = case.getJSONArray("months").objects().map { it.toMonthStat() }.toList()
            val expected = case.getJSONArray("expected").objects().map { it.toMonthStat() }.toList()
            val actual = MonthRollup.capped(input)

            assertEquals("$what: row count", expected.size, actual.size)
            expected.zip(actual).forEachIndexed { i, (want, got) ->
                assertEquals("$what: row $i monthKey", want.monthKey, got.monthKey)
                assertEquals("$what: row $i rollupFromKey", want.rollupFromKey, got.rollupFromKey)
                assertEquals("$what: row $i drinkDays", want.drinkDays, got.drinkDays)
                assertEquals("$what: row $i totalGrams", want.totalGrams, got.totalGrams, 1e-6)
                assertEquals("$what: row $i average", want.avgPerCalendarDay, got.avgPerCalendarDay, 1e-6)
                assertEquals("$what: row $i over", want.daysOverDailyLimit, got.daysOverDailyLimit)
                assertEquals("$what: row $i effectiveDays", want.effectiveDays, got.effectiveDays)
            }
        }
    }

    /**
     * The table never grows past one summary plus the kept months, whatever the
     * period. This is the property the cap exists for, asserted as a property
     * rather than only through the vector's particular lengths.
     */
    @Test
    fun `the table never exceeds the kept count plus one`() {
        val month = MonthStat("2025-01", 1, 10.0, 1.0, 0, 30)
        for (size in 1..40) {
            val input = (1..size).map { month.copy(monthKey = "2025-%02d".format((it - 1) % 12 + 1)) }
            val capped = MonthRollup.capped(input)
            assertEquals(
                "a $size-month period must not print more than ${MonthRollup.KEEP + 1} rows",
                minOf(size, MonthRollup.KEEP + 1),
                capped.size,
            )
        }
    }

    /** A table that is not capped carries no summary row. */
    @Test
    fun `a short table has no summary row`() {
        val month = MonthStat("2025-01", 1, 10.0, 1.0, 0, 30)
        MonthRollup.capped(List(MonthRollup.KEEP + 1) { month }).forEach {
            assertNull("no row may be a span while nothing is folded", it.rollupFromKey)
        }
    }
}
