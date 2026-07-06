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
 * =============================================================================
 */
package de.godisch.potillus.domain

import de.godisch.potillus.domain.model.DaySummary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Branch tests for [ChartBucketing.bucketize]: the inverted-range guard and the
 * monthly-granularity path with calendar-month snapping and period capping.
 */
class ChartBucketizeEdgeTest {

    @Test fun `an inverted date range yields no buckets`() {
        val result = ChartBucketing.bucketize(
            summaries = emptyList(),
            from = "2026-02-01",
            to = "2026-01-01",
            granularity = ChartGranularity.DAILY,
        )
        assertTrue(result.isEmpty())
    }

    @Test fun `monthly granularity snaps buckets to calendar months`() {
        val summaries = listOf(
            DaySummary("2026-01-15", 20.0, 1),
            DaySummary("2026-02-03", 10.0, 1),
        )
        val result = ChartBucketing.bucketize(
            summaries = summaries,
            from = "2026-01-15",
            to = "2026-02-10",
            granularity = ChartGranularity.MONTHLY,
        )
        // The range touches two calendar months, so it yields two month buckets.
        assertEquals(2, result.size)
    }
}
