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
package de.godisch.potillus.util

import de.godisch.potillus.domain.SharedTestVectors
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

// =============================================================================
// ReportChartVectorTest – the report's presentation arithmetic, pinned
// =============================================================================
//
// The same vectors drive Swift's ReportChartTests. Bar heights, axis-label
// thinning and the category palette decide what the PDF LOOKS like, and a
// difference here is a visible difference between two reports of the same
// drinking.
// =============================================================================

class ReportChartVectorTest {

    companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("report-chart")
        const val EPS = 1e-9

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        fun JSONArray.ints(): List<Int> = (0 until length()).map { getInt(it) }
    }

    @Test
    fun `pct matches the shared vectors`() {
        VECTORS.getJSONArray("pct").objects().forEach { case ->
            assertEquals(
                case.getString("description"),
                case.getDouble("expected"),
                PdfReportBuilder.pct(case.getDouble("value"), case.getDouble("max")),
                EPS,
            )
        }
    }

    @Test
    fun `chartLabelIndices matches the shared vectors`() {
        VECTORS.getJSONArray("labelIndices").objects().forEach { case ->
            assertEquals(
                case.getString("description"),
                case.getJSONArray("expected").ints(),
                PdfReportBuilder.chartLabelIndices(case.getInt("count")).toList(),
            )
        }
    }

    @Test
    fun `categoryColor matches the shared vectors`() {
        VECTORS.getJSONArray("categoryColor").objects().forEach { case ->
            assertEquals(
                case.getString("categoryName"),
                case.getString("expected"),
                PdfReportBuilder.categoryColor(case.getString("categoryName")),
            )
        }
    }

    /**
     * The step is a 32-bit Float, and the truncation that follows lands on other
     * indices than the same arithmetic in Double would. Sixteen of the first four
     * hundred series lengths differ, `n = 32` — a month of daily buckets — among
     * them. If this test ever fails, someone widened the Float and the iOS report
     * now draws a different axis than this one.
     */
    @Test
    fun `the step is a Float and it matters`() {
        assertEquals(
            listOf(0, 4, 8, 13, 17, 22, 26, 30, 31),
            PdfReportBuilder.chartLabelIndices(32).toList(),
        )

        val target = 8
        val doubleStep = ((32 - 1).toDouble() / (target - 1)).coerceAtLeast(1.0)
        val inDouble = (0 until target)
            .map { (it * doubleStep).toInt().coerceAtMost(31) }
            .toSortedSet()
            .apply { add(31) }

        assertNotEquals(
            "if these ever agree, the Float in chartLabelIndices has been lost",
            inDouble.toList(),
            PdfReportBuilder.chartLabelIndices(32).toList(),
        )
    }
}
