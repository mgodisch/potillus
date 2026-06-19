/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
 *
 * UNIT TEST — ChartBucketing
 *
 * WHY THIS FILE EXISTS (teaching note)
 *   ChartBucketing turns the sparse "days with entries only" summaries into the
 *   continuous, gap-free series the consumption chart and the PDF report both
 *   draw. Its arithmetic is subtle — gap filling, per-day averaging, end-of-period
 *   clamping and calendar-month snapping — and it is pure (no Android types), so
 *   it is exactly the kind of logic that should be pinned down by fast JVM tests.
 *   These tests are the regression net for that behaviour.
 */
package de.godisch.potillus.domain

import de.godisch.potillus.domain.model.DaySummary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChartBucketingTest {

    // ── granularityForSpan ────────────────────────────────────────────────────

    @Test fun `granularityForSpan picks DAILY up to 35 days`() {
        assertEquals(ChartGranularity.DAILY, ChartBucketing.granularityForSpan(1))
        assertEquals(ChartGranularity.DAILY, ChartBucketing.granularityForSpan(35))
    }

    @Test fun `granularityForSpan picks WEEKLY between 36 and 366 days`() {
        assertEquals(ChartGranularity.WEEKLY, ChartBucketing.granularityForSpan(36))
        assertEquals(ChartGranularity.WEEKLY, ChartBucketing.granularityForSpan(366))
    }

    @Test fun `granularityForSpan picks MONTHLY beyond 366 days`() {
        assertEquals(ChartGranularity.MONTHLY, ChartBucketing.granularityForSpan(367))
    }

    // ── bucketize: DAILY ──────────────────────────────────────────────────────

    @Test fun `daily fills gaps with abstinent zero buckets`() {
        val summaries = listOf(
            DaySummary("2026-01-01", 10.0, 1),
            DaySummary("2026-01-03", 30.0, 2)
        )
        val result = ChartBucketing.bucketize(summaries, "2026-01-01", "2026-01-03", ChartGranularity.DAILY)

        assertEquals(3, result.size)

        assertEquals("2026-01-01", result[0].labelDate)
        assertEquals(10.0, result[0].avgPerDay, 1e-9)
        assertFalse(result[0].isAbstinent)

        // 2026-01-02 has no entries → a zero, abstinent bucket fills the gap.
        assertEquals("2026-01-02", result[1].labelDate)
        assertEquals(0.0, result[1].avgPerDay, 1e-9)
        assertTrue(result[1].isAbstinent)

        assertEquals(30.0, result[2].avgPerDay, 1e-9)
        assertFalse(result[2].isAbstinent)
    }

    @Test fun `from after to yields empty list`() {
        val result = ChartBucketing.bucketize(emptyList(), "2026-01-05", "2026-01-01", ChartGranularity.DAILY)
        assertTrue(result.isEmpty())
    }

    // ── bucketize: WEEKLY ─────────────────────────────────────────────────────

    @Test fun `weekly bucket averages over all seven calendar days`() {
        // One drink day of 70 g inside a full 7-day window → mean per day = 10 g.
        val summaries = listOf(DaySummary("2026-01-01", 70.0, 1))
        val result = ChartBucketing.bucketize(summaries, "2026-01-01", "2026-01-07", ChartGranularity.WEEKLY)

        assertEquals(1, result.size)
        assertEquals("2026-01-01", result[0].labelDate)
        assertEquals(10.0, result[0].avgPerDay, 1e-9)
        assertFalse(result[0].isAbstinent)
    }

    @Test fun `weekly bucket is clamped to the period end`() {
        // The period is only 3 days, so the (would-be 7-day) bucket averages over 3.
        val summaries = listOf(DaySummary("2026-01-01", 30.0, 1))
        val result = ChartBucketing.bucketize(summaries, "2026-01-01", "2026-01-03", ChartGranularity.WEEKLY)

        assertEquals(1, result.size)
        assertEquals(10.0, result[0].avgPerDay, 1e-9)   // 30 g / 3 days
    }

    // ── bucketize: MONTHLY ────────────────────────────────────────────────────

    @Test fun `monthly buckets snap to the first of each calendar month`() {
        val summaries = listOf(DaySummary("2026-02-10", 28.0, 1))
        val result = ChartBucketing.bucketize(summaries, "2026-01-15", "2026-03-10", ChartGranularity.MONTHLY)

        assertEquals(3, result.size)
        // The first (mid-month) bucket keeps its real start date as the label,
        // but the next two snap to the 1st of the month.
        assertEquals("2026-01-15", result[0].labelDate)
        assertEquals("2026-02-01", result[1].labelDate)
        assertEquals("2026-03-01", result[2].labelDate)

        // January and March are abstinent; February averages 28 g over 28 days.
        assertTrue(result[0].isAbstinent)
        assertEquals(28.0 / 28.0, result[1].avgPerDay, 1e-9)
        assertTrue(result[2].isAbstinent)
    }
}
