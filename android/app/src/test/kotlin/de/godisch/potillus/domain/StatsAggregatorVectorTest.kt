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
// StatsAggregatorVectorTest.kt – cross-platform parity suite for the three
// aggregations behind the Statistics screen and the report
// =============================================================================
//
// Asserts `StatsAggregator` against `test-vectors/stats-aggregator.json`, the
// file the iOS suite loads too (`StatsAggregatorVectorTest.swift`). Every
// vector entry carries `utcOffsetSeconds`, so the clock hour is fixed by the
// file and this test is independent of the JVM's default zone.
// =============================================================================

import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class StatsAggregatorVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("stats-aggregator")
        const val EPS = 1e-9
    }

    @Test
    fun `the three aggregations match the shared vectors`() {
        val cases = VECTORS.getJSONArray("cases")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val description = case.getString("description")
            val drinks = case.getJSONArray("drinks").let { arr ->
                (0 until arr.length()).map { i ->
                    val pair = arr.getJSONArray(i)
                    DrinkDefinition(
                        id = pair.getLong(0),
                        name = "drink ${pair.getLong(0)}",
                        volumeMl = 100,
                        alcoholPercent = 5.0,
                        category = DrinkCategory.valueOf(pair.getString(1)),
                    )
                }
            }
            val entries = case.getJSONArray("entries").let { arr ->
                (0 until arr.length()).map { i -> arr.getJSONObject(i).toEntry() }
            }
            val expected = case.getJSONObject("expected")

            val breakdown = StatsAggregator.categoryBreakdown(entries, drinks)
            val expectedBreakdown = expected.getJSONObject("categoryBreakdown")
            assertEquals("$description: categories", expectedBreakdown.keys().asSequence().toSet(), breakdown.keys.map { it.name }.toSet())
            breakdown.forEach { (category, grams) ->
                assertEquals("$description: ${category.name}", expectedBreakdown.getDouble(category.name), grams, EPS)
            }
            assertDoubles("$description: hourlyGrams", expected.getJSONArray("hourlyGrams"), StatsAggregator.hourlyGrams(entries))
            assertDoubles(
                "$description: hourBucketAverages",
                expected.getJSONArray("hourBucketAverages"),
                StatsAggregator.hourBucketAverages(entries, case.getInt("effectivePeriodDays")),
            )
        }
    }

    private fun assertDoubles(message: String, expected: JSONArray, actual: List<Double>) {
        assertEquals("$message: size", expected.length(), actual.size)
        for (i in 0 until expected.length()) {
            assertEquals("$message[$i]", expected.getDouble(i), actual[i], EPS)
        }
    }

    /** The vector's entry object as a domain entry; the fields the aggregations do not read are filled with placeholders. */
    private fun JSONObject.toEntry() = ConsumptionEntry(
        drinkId = getLong("drinkId"),
        drinkName = "drink ${getLong("drinkId")}",
        volumeMl = 100,
        alcoholPercent = 5.0,
        gramsAlcohol = getDouble("gramsAlcohol"),
        timestampMillis = getLong("timestampMillis"),
        utcOffsetSeconds = getInt("utcOffsetSeconds"),
        logicalDate = "2026-08-15",
    )
}
