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
// ChartBucketingVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts the JVM implementation against `test-vectors/chart-bucketing.json`,
// the same file the iOS Swift suite loads. Covers Trend, granularity selection,
// and the bucketing rules — including the two consequences of the in-progress
// day (it leaves the divisor, and its bucket is never abstinent).
//
// This complements — it does not replace — ChartBucketingTest.kt and TrendTest.kt,
// which remain the authoritative unit suites the vectors were harvested from.
// =============================================================================

import de.godisch.potillus.domain.model.DaySummary
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class ChartBucketingVectorTest {

    private companion object {
        const val EPS = 0.001
        val VECTORS: JSONObject = SharedTestVectors.load("chart-bucketing")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }
    }

    // ── Trend ────────────────────────────────────────────────────────────────

    @Test
    fun `trend matches the shared vectors`() {
        VECTORS.getJSONArray("trend").objects().forEach { case ->
            val actual = Trend.of(
                currentAvg = case.getDouble("currentAvg"),
                prevAvg = case.getDouble("prevAvg"),
            )
            // The JSON stores the Kotlin enum constant name, so valueOf maps directly.
            val expected = Trend.valueOf(case.getString("expected"))
            assertEquals("trend: ${case.getString("description")}", expected, actual)
        }
    }

    // ── granularityForSpan ───────────────────────────────────────────────────

    @Test
    fun `granularityForSpan matches the shared vectors`() {
        VECTORS.getJSONArray("granularityForSpan").objects().forEach { case ->
            val actual = ChartBucketing.granularityForSpan(case.getInt("days"))
            val expected = ChartGranularity.valueOf(case.getString("expected"))
            assertEquals(
                "granularityForSpan: ${case.getString("description")}",
                expected,
                actual,
            )
        }
    }

    // ── bucketize ────────────────────────────────────────────────────────────

    @Test
    fun `bucketize matches the shared vectors`() {
        VECTORS.getJSONArray("bucketize").objects().forEach { case ->
            val label = case.getString("description")
            val actual = ChartBucketing.bucketize(
                summaries = case.daySummaries(),
                from = case.getString("from"),
                to = case.getString("to"),
                granularity = ChartGranularity.valueOf(case.getString("granularity")),
                inProgressDay = if (case.has("inProgressDay")) case.getString("inProgressDay") else null,
            )
            val expected = case.getJSONArray("expected")
            assertEquals("bucket count: $label", expected.length(), actual.size)

            for (index in 0 until expected.length()) {
                val want = expected.getJSONObject(index)
                assertEquals(
                    "labelDate[$index]: $label",
                    want.getString("labelDate"),
                    actual[index].labelDate,
                )
                assertEquals(
                    "avgPerDay[$index]: $label",
                    want.getDouble("avgPerDay"),
                    actual[index].avgPerDay,
                    EPS,
                )
                assertEquals(
                    "isAbstinent[$index]: $label",
                    want.getBoolean("isAbstinent"),
                    actual[index].isAbstinent,
                )
            }
        }
    }

    /**
     * Converts the vector's positional `[isoDate, grams]` pairs into DaySummary
     * values. The pairs are positional to keep the JSON compact and neutral
     * between the two languages.
     */
    private fun JSONObject.daySummaries(): List<DaySummary> {
        val days = getJSONArray("summaries")
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
