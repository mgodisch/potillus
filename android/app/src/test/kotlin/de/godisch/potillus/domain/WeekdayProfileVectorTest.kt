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
// WeekdayProfileVectorTest.kt – cross-platform parity suite for the weekday chart
// =============================================================================
//
// Asserts `WeekdayProfile` against `test-vectors/weekday-profile.json`, the file
// the iOS suite loads too (`WeekdayProfileVectorTest.swift` against
// `StatsAggregator.weekdayAverages`). Until the v0.86.0 review this object had no
// test of its own: the Statistics screen and the PDF report both draw it, and
// the two ports had been compared by reading. The `summaries` are positional
// `[isoDate, grams]` pairs, as in chart-bucketing.json.
// =============================================================================

import de.godisch.potillus.domain.model.DaySummary
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WeekdayProfileVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("weekday-profile")
    }

    @Test
    fun `order matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("order")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val first = case.getInt("firstDayOfWeekIso")
            assertEquals("order for first day $first", case.getJSONArray("expected").toIntList(), WeekdayProfile.order(first))
        }
    }

    @Test
    fun `averages match the shared vectors`() {
        val cases = VECTORS.getJSONArray("averages")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val description = case.getString("description")
            val actual = WeekdayProfile.averages(
                summaries = case.daySummaries(),
                from = case.getString("from"),
                to = case.getString("to"),
                firstDayOfWeekIso = case.getInt("firstDayOfWeekIso"),
                inProgressDay = case.optString("inProgressDay").takeIf { it.isNotEmpty() },
            )
            val expected = case.getJSONArray("expected")
            assertEquals("$description: column count", expected.length(), actual.size)
            for (column in 0 until expected.length()) {
                if (expected.isNull(column)) {
                    assertNull("$description: column $column", actual[column])
                } else {
                    assertEquals("$description: column $column", expected.getDouble(column), actual[column]!!, 1e-9)
                }
            }
        }
    }

    private fun JSONArray.toIntList(): List<Int> = (0 until length()).map { getInt(it) }

    /** The vector's positional `[isoDate, grams]` pairs as DaySummary values. */
    private fun JSONObject.daySummaries(): List<DaySummary> {
        val days = getJSONArray("summaries")
        return (0 until days.length()).map { index ->
            val pair = days.getJSONArray(index)
            DaySummary(date = pair.getString(0), totalGrams = pair.getDouble(1), entryCount = 1)
        }
    }
}
