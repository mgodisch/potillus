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

import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.WeekdayProfile
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for [PdfReportData.from], the report's pure (Context-free) data layer.
 *
 * These verify the structural figures that feed the PDF. Time-of-day hour averages
 * are intentionally NOT asserted to exact values because they depend on the test
 * runner's time zone; only their invariant (the two percentages sum to 100) is checked.
 */
class PdfReportDataTest {

    private val beer = DrinkDefinition(
        id = 1,
        name = "Beer",
        volumeMl = 500,
        alcoholPercent = 5.0,
        category = DrinkCategory.BEER,
    )
    private val wine = DrinkDefinition(
        id = 2,
        name = "Wine",
        volumeMl = 200,
        alcoholPercent = 13.0,
        category = DrinkCategory.WINE,
    )

    private fun entry(date: String, drinkId: Long, grams: Double) = ConsumptionEntry(
        id = 0,
        drinkId = drinkId,
        drinkName = "x",
        volumeMl = 0,
        alcoholPercent = 0.0,
        gramsAlcohol = grams,
        timestampMillis = 0L,
        logicalDate = date,
        utcOffsetSeconds = 0,
    )

    /** Two months of data: one over-limit day (25 g > 20 g) in January, one quiet day in February. */
    private val entries = listOf(
        entry("2026-01-10", 1, 19.3),
        entry("2026-01-20", 2, 25.0), // over the 20 g daily limit
        entry("2026-02-05", 1, 10.0),
    )
    private val drinks = listOf(beer, wine)
    private val settings = AppSettings() // dailyLimit 20 g, weight 0 (no week-start setting any more)

    private fun build() = PdfReportData.from(entries, drinks, settings)

    @Test fun `counts drink days and total grams`() {
        val d = build()
        assertEquals(3, d.drinkDays)
        assertEquals(54.3, d.totalGrams, 0.001)
        assertEquals("2026-01-10", d.firstDate)
        assertEquals("2026-02-05", d.lastDate)
        assertEquals(d.totalDays - d.drinkDays, d.abstinentDays)
    }

    @Test fun `monthly aggregation marks the over-limit month`() {
        val months = build().months
        assertEquals(2, months.size)
        assertEquals("2026-01", months[0].monthKey)
        assertEquals(2, months[0].drinkDays)
        assertEquals(1, months[0].daysOverDailyLimit) // the 25 g day
        assertEquals("2026-02", months[1].monthKey)
        assertEquals(0, months[1].daysOverDailyLimit)
    }

    @Test fun `categories are sorted by grams with whole-percent shares summing to 100`() {
        val cats = build().categories
        assertEquals("BEER", cats[0].categoryName) // 29.3 g > 25.0 g
        assertEquals(29.3, cats[0].grams, 0.001)
        assertEquals("WINE", cats[1].categoryName)
        assertEquals(54, cats[0].percent)
        assertEquals(46, cats[1].percent)
        assertEquals(100, cats.sumOf { it.percent })
    }

    @Test fun `daily limit violation is counted once`() {
        assertEquals(1, build().violations.daysOverDailyLimit)
    }

    @Test fun `no binge days below the 60 g threshold`() {
        assertEquals(0, build().bingeDays)
        assertEquals(60.0, PdfReportData.bingeThreshold, 0.0)
    }

    @Test fun `weekday order starts on the locale first weekday and rotates through all seven`() {
        val d = build()
        // The first column now follows the device/JVM locale rather than a fixed
        // Monday, so assert against the same source the production code uses.
        val expectedFirst = DayResolver.firstDayOfWeekIso()
        assertEquals(expectedFirst, d.weekdayOrder.first())
        // Regardless of the start day, the order must be the seven ISO weekdays 1..7
        // with no gaps or duplicates, rotated to begin at expectedFirst.
        val expectedOrder = (0..6).map { (expectedFirst - 1 + it) % 7 + 1 }
        assertEquals(expectedOrder, d.weekdayOrder)
        assertEquals(7, d.weekdayAverages.size)
    }

    @Test fun `hourly histogram has 24 buckets summing to the total grams`() {
        val d = build()
        assertEquals(24, d.hourlyGrams.size)
        // The buckets partition the consumption, so they must add up to the total.
        assertEquals(d.totalGrams, d.hourlyGrams.sum(), 0.001)
        // All fixture entries share timestamp 0L (the same clock hour), so exactly
        // one bucket carries the whole total and the rest are empty.
        assertEquals(1, d.hourlyGrams.count { it > 0.0 })
    }

    @Test fun `weekday averages divide by every occurrence of the weekday`() {
        // 2026-01-01 is a Thursday; the period 01-01…01-28 holds four of them.
        // 40 g on one of them reads 10 g, not 40: the three dry Thursdays are
        // Thursdays too. The seven bars then sum to a week's consumption.
        val summaries = listOf(DaySummary("2026-01-01", 40.0, 1))
        val averages = WeekdayProfile.averages(summaries, "2026-01-01", "2026-01-28", 1)

        assertEquals(10.0, averages[3]!!, 0.001)
        assertEquals(0.0, averages[0]!!, 0.001)
        assertEquals(10.0, averages.filterNotNull().sum(), 0.001)
    }

    @Test fun `a weekday outside the range is null, a dry one is zero`() {
        // A single-day range: only Thursday occurs in it at all. Null and zero
        // are different statements and the chart draws them differently.
        val averages = WeekdayProfile.averages(
            listOf(DaySummary("2026-01-01", 0.0, 1)),
            "2026-01-01",
            "2026-01-01",
            1,
        )
        assertEquals(0.0, averages[3]!!, 0.001)
        assertNull(averages[0])
    }

    @Test fun `hourly histogram reads an entry in its recorded frame`() {
        // 2026-03-02T00:30Z, logged where the offset was +01:00 — 01:30 there.
        // The device zone the test runs in must not decide the bucket; only the
        // recorded frame may, which is the whole point of storing it.
        val logged = ConsumptionEntry(
            drinkId = 1,
            drinkName = "x",
            volumeMl = 500,
            alcoholPercent = 5.0,
            gramsAlcohol = 10.0,
            timestampMillis = 1_772_411_400_000L,
            logicalDate = "2026-03-01",
            utcOffsetSeconds = 3600,
        )
        val d = PdfReportData.from(listOf(logged), drinks, settings)
        assertEquals(10.0, d.hourlyGrams[1], 0.001)
        assertEquals(0.0, d.hourlyGrams[0], 0.001)
    }

    @Test fun `medians complement the mean KPIs`() {
        val d = build()
        // Per-drink-day totals: 10.0, 19.3, 25.0 → median 19.3.
        assertEquals(19.3, d.medianPerDrinkDay, 0.001)
        // Per-calendar-day median spans all 27 days in [01-10 … 02-05]; with only
        // three drink days the middle value is an abstinent (0 g) day.
        assertEquals(0.0, d.medianPerDay, 0.001)
        // Drink days per month: Jan 2, Feb 1 → mean 1.5, median 1.5.
        assertEquals(1.5, d.avgDrinkDaysPerMonth, 0.001)
        assertEquals(1.5, d.medianDrinkDaysPerMonth, 0.001)
    }

    @Test fun `partial first and last months divide grams by in-period days only`() {
        // Regression test for the partial-month bug: the g/day of a started month
        // must use only the days that lie inside the report period, never the full
        // calendar-month length (which would dilute the figure with not-yet-recorded
        // "abstinent" days).
        val months = build().months
        // January is entered on the 10th → 22 in-period days (10 Jan … 31 Jan):
        //   (19.3 + 25.0) / 22 ≈ 2.0136 g/day  (NOT / 31).
        assertEquals(2.0136, months[0].avgPerCalendarDay, 0.001)
        // February ends on the 5th → 5 in-period days (1 Feb … 5 Feb):
        //   10.0 / 5 = 2.0 g/day  (NOT / 28).
        assertEquals(2.0, months[1].avgPerCalendarDay, 0.001)
    }

    @Test fun `peak consumption fields capture the worst day and worst 7-day window`() {
        val d = build()
        // Daily totals are 19.3 (Jan 10), 25.0 (Jan 20), 10.0 (Feb 5); worst day = 25.0.
        assertEquals(25.0, d.maxPerDay, 0.001)
        // The three drink days are all > 7 days apart, so no rolling 7-day window holds
        // two of them; the worst window therefore equals the single heaviest day.
        assertEquals(25.0, d.maxPer7Days, 0.001)
    }

    // ── Abstinence streaks (v0.79.0 QA regression tests) ──────────────────────
    //
    // PdfReportData reads "today" through DayResolver.today(), which honours the
    // test-only DayResolver.clockOverride. Pinning the clock makes the ongoing
    // (tail) streak deterministic, so these tests can assert exact day counts.
    // The pin is cleared in a finally block so it can never leak into other tests
    // sharing the JVM (the override lives in the DayResolver singleton).

    /**
     * Runs [block] with the wall clock pinned to UTC midnight of [isoDate], and
     * always clears the pin afterwards. AppSettings' default day-change time is
     * 04:00, so a 12:00 UTC instant resolves to [isoDate] itself in every zone a
     * CI runner realistically uses; midday is used for the same safety margin the
     * screenshot suite applies.
     */
    private fun withToday(isoDate: String, block: () -> Unit) {
        DayResolver.clockOverride = java.time.Clock.fixed(
            java.time.Instant.parse("${isoDate}T12:00:00Z"),
            java.time.ZoneOffset.UTC,
        )
        try {
            block()
        } finally {
            DayResolver.clockOverride = null
        }
    }

    @Test fun `longest abstinence includes the ongoing tail streak`() {
        // Historical gaps: Jan 10 → Jan 20 (9 dry days) and Jan 20 → Feb 5 (15 dry
        // days). With today pinned to 2026-03-01 the tail run after the last drink
        // (Feb 6 … Feb 28) holds 23 completed dry days and must win. The legacy
        // no-`today` computation ignored the tail and reported 15 here — smaller
        // than the current streak, which is impossible by definition.
        withToday("2026-03-01") {
            val d = build()
            assertEquals(23, d.currentAbstinence)
            assertEquals(23, d.longestAbstinence)
        }
    }

    @Test fun `longest abstinence is never smaller than the current streak`() {
        // Definition invariant: the current streak IS one of the candidate runs, so
        // longest >= current must hold for ANY "today". Probe a spread of dates.
        for (today in listOf("2026-02-06", "2026-02-10", "2026-02-20", "2026-06-30")) {
            withToday(today) {
                val d = build()
                assertTrue(
                    "longest (${d.longestAbstinence}) < current (${d.currentAbstinence}) for today=$today",
                    d.longestAbstinence >= d.currentAbstinence,
                )
            }
        }
    }

    // ── Alcohol-free days (v0.85.0) ───────────────────────────────────────────

    /**
     * A day of alcohol-free entries belongs to the reporting period but is not a
     * drink day: it is abstinent, it stays out of the drink-day divisor, and it
     * leaves an abstinence run intact.
     *
     * The day carries entries, so the summary row exists and every figure here
     * used to read it as drinking. The extra day sits in the middle of the
     * fixture's longest gap (Jan 20 → Feb 5, 15 dry days), which the old reading
     * split into two runs of seven.
     */
    @Test fun `a day of alcohol-free entries is abstinent`() {
        val withAlcoholFreeDay = entries + entry("2026-01-28", 1, 0.0)
        val d = PdfReportData.from(withAlcoholFreeDay, drinks, settings)

        assertEquals("the 0.0 g day is not a drink day", 3, d.drinkDays)
        assertEquals(d.totalDays - d.drinkDays, d.abstinentDays)
        assertEquals("its grams change nothing", 54.3, d.totalGrams, 0.001)
        assertEquals("nor does it enter the drink-day average", 18.1, d.avgPerDrinkDay, 0.001)
        assertEquals("January keeps its two drink days", 2, d.months[0].drinkDays)
        // The long gap stays one 15-day run rather than splitting into 7 and 7.
        withToday("2026-02-06") {
            assertEquals(15, PdfReportData.from(withAlcoholFreeDay, drinks, settings).longestAbstinence)
        }
    }

    // ── Historical export ranges (v0.81.0 QA fix) ─────────────────────────────

    /**
     * A report over a HISTORICAL range anchors its streaks at the period end,
     * not at the real today (v0.81.0 QA regression test).
     *
     * With today pinned four months after the data and periodEnd = 2026-02-28,
     * the streaks must read exactly as they did "on" 2026-03-01 (periodEnd + 1,
     * the anchor for a range whose last day is complete): the tail run Feb 6 …
     * Feb 28 holds 23 completed dry days. Before the fix the anchor was the
     * real today (2026-06-30 here), so every day from Feb 6 to Jun 29 counted
     * as abstinent — 144 days of "current abstinence" in a report that ends in
     * February, regardless of any drinking after the range.
     */
    @Test fun `historical range anchors the streaks at the period end`() {
        withToday("2026-06-30") {
            val d = PdfReportData.from(entries, drinks, settings, periodEnd = "2026-02-28")
            assertEquals(23, d.currentAbstinence)
            assertEquals(23, d.longestAbstinence)
        }
    }

    /**
     * A range that ends TODAY keeps the real-today anchor, preserving the
     * in-progress-day semantics and the parity with the Statistics screen —
     * the figures must equal the legacy (periodEnd = null) computation.
     */
    @Test fun `range ending today keeps the real-today streak anchor`() {
        withToday("2026-03-01") {
            val explicit = PdfReportData.from(entries, drinks, settings, periodEnd = "2026-03-01")
            val legacy = build() // periodEnd = null → today anchor
            assertEquals(legacy.currentAbstinence, explicit.currentAbstinence)
            assertEquals(legacy.longestAbstinence, explicit.longestAbstinence)
            assertEquals(23, explicit.currentAbstinence)
        }
    }

    // ── The reporting window ──────────────────────────────────────────────────
    //
    // The shared vectors pin the arithmetic of a window; these cover what a file
    // cannot reach — the agreement with DayResolver.windowDays, and the two
    // degenerate shapes a user can still ask for.

    /**
     * A window is exactly as long as the Statistics screen's, day for day.
     *
     * The report expresses the window as a pair of dates and the screen as a
     * count, so the two rules could drift apart without either looking wrong on
     * its own. This walks the four shapes that matter: a historical window, one
     * ending today with and without a drink on it, and one shorter than the
     * entries' own span.
     */
    @Test fun `totalDays equals the shared window rule`() {
        withToday("2026-03-01") {
            // No entry falls on 2026-03-01, so the running day is dry in every
            // shape below; that is the third argument to windowDays.
            listOf(
                "2026-01-01" to "2026-02-28", // ends in the past
                "2026-01-01" to "2026-03-01", // ends today, today still dry
                "2026-02-01" to "2026-02-05", // narrower than the entries' span
            ).forEach { (from, to) ->
                val d = PdfReportData.from(
                    entries,
                    drinks,
                    settings,
                    periodStart = from,
                    periodEnd = to,
                )
                assertEquals(
                    "$from … $to",
                    DayResolver.windowDays(from, to, "2026-03-01", false),
                    d.totalDays,
                )
            }
        }
    }

    /**
     * A window ending today counts today once alcohol is on it, and waits while
     * the day is still dry — the superposition rule the Statistics screen
     * applies, arrived at here through the reported last day.
     */
    @Test fun `a window ending today waits for the running day`() {
        withToday("2026-02-06") {
            val dry = PdfReportData.from(
                entries,
                drinks,
                settings,
                periodStart = "2026-02-01",
                periodEnd = "2026-02-06",
            )
            assertEquals("2026-02-05", dry.lastDate)
            assertEquals(5, dry.totalDays)

            val wet = PdfReportData.from(
                entries + entry("2026-02-06", 1, 8.0),
                drinks,
                settings,
                periodStart = "2026-02-01",
                periodEnd = "2026-02-06",
            )
            assertEquals("2026-02-06", wet.lastDate)
            assertEquals(6, wet.totalDays)
        }
    }

    /**
     * "Today only", exported before the first drink of the day: dropping the
     * running day would leave a window of no days at all, and a report over
     * nothing states nothing. The raw window stands there instead.
     */
    @Test fun `a one-day window on a dry today keeps that day`() {
        withToday("2026-02-05") {
            val d = PdfReportData.from(
                listOf(entry("2026-02-05", 1, 0.0)),
                drinks,
                settings,
                periodStart = "2026-02-05",
                periodEnd = "2026-02-05",
            )
            assertEquals("2026-02-05", d.firstDate)
            assertEquals("2026-02-05", d.lastDate)
            assertEquals(1, d.totalDays)
        }
    }

    /**
     * Only one bound is not a window: a caller that passes `periodEnd` alone —
     * as the historical streak anchor did before the window existed — still gets
     * the entry span, so no legacy call changed its figures.
     */
    @Test fun `periodEnd alone leaves the entry span in place`() {
        withToday("2026-06-30") {
            val d = PdfReportData.from(entries, drinks, settings, periodEnd = "2026-02-28")
            assertEquals("2026-01-10", d.firstDate)
            assertEquals("2026-02-05", d.lastDate)
        }
    }

    /**
     * Every month the period covers is a row, the dry ones included. Without
     * this the table skipped a month whose days the KPIs above it had counted,
     * and a reader could not tell an abstinent month from a missing one.
     */
    @Test fun `a month without entries keeps its row`() {
        withToday("2026-06-30") {
            val d = PdfReportData.from(
                entries,
                drinks,
                settings,
                periodStart = "2026-01-01",
                periodEnd = "2026-04-30",
            )
            assertEquals(
                listOf("2026-01", "2026-02", "2026-03", "2026-04"),
                d.months.map { it.monthKey },
            )
            val march = d.months.single { it.monthKey == "2026-03" }
            assertEquals(0, march.drinkDays)
            assertEquals(0.0, march.totalGrams, 0.001)
            assertEquals(31, march.effectiveDays)
        }
    }
}
