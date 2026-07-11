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
            DaySummary("2026-01-03", 30.0, 2),
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
        assertEquals(10.0, result[0].avgPerDay, 1e-9) // 30 g / 3 days
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

    // ── bucketize: in-progress day (today in superposition) ───────────────────

    @Test fun `in-progress empty today is excluded from its bucket's day count`() {
        // June 1..24, drinks logged on three earlier days (total 460.0 g). Today
        // (the 24th) has no entry yet. The June bucket therefore spans 24 calendar
        // days, but the unfinished, empty today must NOT dilute the average:
        // 460 / 23 completed days, not 460 / 24.
        val summaries = listOf(
            DaySummary("2026-06-05", 200.0, 1),
            DaySummary("2026-06-12", 150.0, 1),
            DaySummary("2026-06-20", 110.0, 1),
        )
        val result = ChartBucketing.bucketize(
            summaries,
            "2026-06-01",
            "2026-06-24",
            ChartGranularity.MONTHLY,
            inProgressDay = "2026-06-24",
        )

        assertEquals(1, result.size)
        assertEquals(460.0 / 23.0, result[0].avgPerDay, 1e-9)
        // Without the in-progress hint the same data divides by all 24 days.
        val naive = ChartBucketing.bucketize(
            summaries,
            "2026-06-01",
            "2026-06-24",
            ChartGranularity.MONTHLY,
        )
        assertEquals(460.0 / 24.0, naive[0].avgPerDay, 1e-9)
    }

    @Test fun `in-progress today counts when it is already a drink day`() {
        // Same window, but a drink was logged today (the 24th): today resolves to
        // a drink day and joins the period, so the divisor is the full 24 days.
        val summaries = listOf(
            DaySummary("2026-06-05", 200.0, 1),
            DaySummary("2026-06-12", 150.0, 1),
            DaySummary("2026-06-24", 110.0, 1),
        )
        val result = ChartBucketing.bucketize(
            summaries,
            "2026-06-01",
            "2026-06-24",
            ChartGranularity.MONTHLY,
            inProgressDay = "2026-06-24",
        )

        assertEquals(460.0 / 24.0, result[0].avgPerDay, 1e-9)
    }

    // ── bucketize: isAbstinent obeys the "completed period" rule ───────────────
    //
    // A green tick promises "this whole period was recorded alcohol-free". A period
    // that still contains the in-progress current day is not finished, so it must
    // NOT be flagged abstinent until the day-change time passes. These tests lock
    // that in for every granularity, plus the historical (no in-progress) path.

    @Test fun `in-progress empty today is NOT abstinent (daily bucket)`() {
        // WEEK/MONTH views use DAILY buckets, so today is its own bucket. With no
        // drink logged yet its grams are 0, but it is still open — no green tick.
        val result = ChartBucketing.bucketize(
            summaries = emptyList(),
            from = "2026-06-24",
            to = "2026-06-24",
            granularity = ChartGranularity.DAILY,
            inProgressDay = "2026-06-24",
        )

        assertEquals(1, result.size)
        assertFalse("the open current day must not earn an abstinence tick", result[0].isAbstinent)
        // It is also not a bar: no completed day, so the average is 0. The renderer
        // draws this "not abstinent, zero average" bucket as an empty slot.
        assertEquals(0.0, result[0].avgPerDay, 1e-9)
    }

    @Test fun `a past empty day IS abstinent (daily bucket)`() {
        // Regression guard for the common case: a finished dry day keeps its tick.
        // June 23 is empty and lies before the in-progress 24th, so it is a
        // completed abstinent day.
        val result = ChartBucketing.bucketize(
            summaries = emptyList(),
            from = "2026-06-23",
            to = "2026-06-24",
            granularity = ChartGranularity.DAILY,
            inProgressDay = "2026-06-24",
        )

        assertEquals(2, result.size)
        assertTrue("a finished dry day stays abstinent", result[0].isAbstinent) // 23rd
        assertFalse("the open current day is not abstinent", result[1].isAbstinent) // 24th
    }

    @Test fun `current month with only dry completed days is NOT abstinent (monthly bucket)`() {
        // YEAR view uses MONTHLY buckets. The current month has several completed
        // dry days (June 1..23) plus the still-open 24th and zero grams overall.
        // Because the month still holds the open day it is not yet a completed
        // period, so Variante B withholds the tick even though nothing was drunk.
        val result = ChartBucketing.bucketize(
            summaries = emptyList(),
            from = "2026-06-01",
            to = "2026-06-24",
            granularity = ChartGranularity.MONTHLY,
            inProgressDay = "2026-06-24",
        )

        assertEquals(1, result.size)
        assertFalse("a month still containing today is not a completed dry period", result[0].isAbstinent)
    }

    @Test fun `a fully past dry month IS abstinent (monthly bucket, historical)`() {
        // The PDF export path (inProgressDay = null) and any month strictly in the
        // past: an all-zero month is a finished abstinent period and keeps its tick.
        val result = ChartBucketing.bucketize(
            summaries = emptyList(),
            from = "2026-05-01",
            to = "2026-05-31",
            granularity = ChartGranularity.MONTHLY,
            // inProgressDay omitted → null → historical semantics
        )

        assertEquals(1, result.size)
        assertTrue("a fully completed dry month is abstinent", result[0].isAbstinent)
    }
}
