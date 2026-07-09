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

import de.godisch.potillus.domain.model.*
import org.junit.Assert.*
import org.junit.Test

class AlcoholCalculatorTest {

    // ── calculateGrams ────────────────────────────────────────────────────────

    @Test fun `calculateGrams Pils 500ml 4_9pct`() {
        val result = AlcoholCalculator.calculateGrams(500, 4.9)
        assertEquals(19.3, result, 0.001)
    }

    @Test fun `calculateGrams Rotwein 200ml 13pct`() {
        val result = AlcoholCalculator.calculateGrams(200, 13.0)
        assertEquals(20.5, result, 0.001)
    }

    @Test fun `calculateGrams Whisky 40ml 40pct`() {
        val result = AlcoholCalculator.calculateGrams(40, 40.0)
        assertEquals(12.6, result, 0.001)
    }

    @Test fun `calculateGrams alkoholfrei returns zero`() {
        assertEquals(0.0, AlcoholCalculator.calculateGrams(500, 0.0), 0.0)
    }

    @Test fun `calculateGrams rounds to one decimal`() {
        val result = AlcoholCalculator.calculateGrams(330, 4.9)
        assertTrue("Result must have ≤ 1 decimal place", result == Math.round(result * 10.0) / 10.0)
    }

    @Test fun `calculateGrams 188ml 13_5pct is 20_0 g (not over a 20 g limit)`() {
        // Regression: 188 × 0.135 × 0.789 = 20.024 g. Previously stored as 20.02
        // and displayed as "20.0 g", yet counted as over a 20 g limit. With 0.1 g
        // rounding it is 20.0 g, matching the display and the limit comparison.
        val result = AlcoholCalculator.calculateGrams(188, 13.5)
        assertEquals(20.0, result, 0.001)
    }

    // ── calculateBAC (Widmark) ─────────────────────────────────────────────────

    // r is now fixed at the conservative value 0.6 (worst-case / maximum BAC),
    // so the per-sex parameter is gone from the signature.

    @Test fun `calculateBAC 80kg 20g 0h`() {
        // c = 20 / (80 * 0.6) - 0.15 * 0 = 0.4167 ‰
        val bac = AlcoholCalculator.calculateBAC(20.0, 80.0, 0.0)
        assertEquals(0.42, bac, 0.01)
    }

    @Test fun `calculateBAC 60kg 12g 0h`() {
        // c = 12 / (60 * 0.6) - 0 = 0.333 ‰
        val bac = AlcoholCalculator.calculateBAC(12.0, 60.0, 0.0)
        assertEquals(0.33, bac, 0.01)
    }

    @Test fun `calculateBAC decreases over time`() {
        val bac0h = AlcoholCalculator.calculateBAC(40.0, 75.0, 0.0)
        val bac2h = AlcoholCalculator.calculateBAC(40.0, 75.0, 2.0)
        assertTrue("BAC after 2h must be less than BAC at 0h", bac2h < bac0h)
    }

    @Test fun `calculateBAC never negative`() {
        val bac = AlcoholCalculator.calculateBAC(10.0, 80.0, 10.0)
        assertTrue("BAC must never be negative", bac >= 0.0)
    }

    @Test fun `calculateBAC zero weight returns zero`() {
        assertEquals(0.0, AlcoholCalculator.calculateBAC(20.0, 0.0, 0.0), 0.0)
    }

    @Test fun `calculateBAC zero grams returns zero`() {
        assertEquals(0.0, AlcoholCalculator.calculateBAC(0.0, 80.0, 0.0), 0.0)
    }

    // ── getLimitInfo ──────────────────────────────────────────────────────────

    @Test fun `getLimitInfo maps the three limits from settings`() {
        val settings = AppSettings(dailyLimitGrams = 25.0, weeklyLimitGrams = 120.0, maxDrinkDaysPerWeek = 4)
        val info = AlcoholCalculator.getLimitInfo(settings)
        assertEquals(25.0, info.limitGrams, 0.0)
        assertEquals(120.0, info.weeklyLimitGrams, 0.0)
        assertEquals(4, info.maxDrinkDaysPerWeek)
    }

    @Test fun `getLimitInfo defaults are 20-100-5`() {
        val info = AlcoholCalculator.getLimitInfo(AppSettings())
        assertEquals(20.0, info.limitGrams, 0.0)
        assertEquals(100.0, info.weeklyLimitGrams, 0.0)
        assertEquals(5, info.maxDrinkDaysPerWeek)
    }

    @Test fun `getLimitInfo clamps maxDrinkDaysPerWeek into 1 to 7`() {
        assertEquals(7, AlcoholCalculator.getLimitInfo(AppSettings(maxDrinkDaysPerWeek = 9)).maxDrinkDaysPerWeek)
        assertEquals(1, AlcoholCalculator.getLimitInfo(AppSettings(maxDrinkDaysPerWeek = 0)).maxDrinkDaysPerWeek)
    }

    // ── limitPercent ──────────────────────────────────────────────────────────

    @Test fun `limitPercent 50pct`() {
        assertEquals(0.5f, AlcoholCalculator.limitPercent(12.0, 24.0), 0.01f)
    }

    @Test fun `limitPercent 100pct`() {
        assertEquals(1.0f, AlcoholCalculator.limitPercent(24.0, 24.0), 0.01f)
    }

    @Test fun `limitPercent over limit not clamped`() {
        // limitPercent does NOT clamp – callers decide what to do with values > 1.0
        assertEquals(1.5f, AlcoholCalculator.limitPercent(36.0, 24.0), 0.01f)
    }

    @Test fun `limitPercent zero limitGrams returns 0`() {
        assertEquals(0f, AlcoholCalculator.limitPercent(10.0, 0.0), 0.0f)
    }

    @Test fun `limitPercent negative totalGrams clamped to 0`() {
        // coerceAtLeast(0f) must prevent negative results (e.g. after data correction)
        assertEquals(0f, AlcoholCalculator.limitPercent(-5.0, 24.0), 0.0f)
    }

    // ── Clinical constants ────────────────────────────────────────────────────

    @Test fun `binge threshold is the conservative 60g`() {
        assertEquals(60.0, AlcoholCalculator.BINGE_THRESHOLD, 0.0)
    }

    // ── trafficLight ──────────────────────────────────────────────────────────

    /**
     * Helper that calls trafficLight with all three limits explicit.
     * Defaults: daily 20 g, weekly 1000 g (effectively unlimited so it does not
     * interfere), 5 drink days/week, nothing consumed today.
     */
    private fun light(
        gramsPerDrink: Double,
        todayGrams: Double = 0.0,
        dailyLimitGrams: Double = 20.0,
        weeklyTotalGrams: Double = 0.0,
        weeklyLimitGrams: Double = 1000.0,
        drinkDaysThisWeek: Int = 0,
        maxDrinkDaysPerWeek: Int = 5,
    ) = AlcoholCalculator.trafficLight(
        gramsPerDrink = gramsPerDrink,
        todayGrams = todayGrams,
        dailyLimitGrams = dailyLimitGrams,
        weeklyTotalGrams = weeklyTotalGrams,
        weeklyLimitGrams = weeklyLimitGrams,
        drinkDaysThisWeek = drinkDaysThisWeek,
        maxDrinkDaysPerWeek = maxDrinkDaysPerWeek,
    )

    @Test fun `trafficLight alcohol-free drink is always GREEN`() {
        assertEquals(TrafficLight.GREEN, light(gramsPerDrink = 0.0, todayGrams = 25.0))
    }

    @Test fun `trafficLight GREEN when two or more servings fit`() {
        // daily 20 g, today 0 g, drink 5 g → 4 servings fit → GREEN
        assertEquals(TrafficLight.GREEN, light(gramsPerDrink = 5.0, todayGrams = 0.0))
    }

    @Test fun `trafficLight YELLOW when exactly one serving fits (daily)`() {
        // daily 20 g, today 14 g, drink 6 g → floor(6/6) = 1 → YELLOW
        assertEquals(TrafficLight.YELLOW, light(gramsPerDrink = 6.0, todayGrams = 14.0))
    }

    @Test fun `trafficLight RED when no serving fits (daily)`() {
        assertEquals(TrafficLight.RED, light(gramsPerDrink = 5.0, todayGrams = 20.0))
    }

    @Test fun `trafficLight RED when over daily budget`() {
        assertEquals(TrafficLight.RED, light(gramsPerDrink = 5.0, todayGrams = 25.0))
    }

    @Test fun `trafficLight weekly limit can force YELLOW even with daily headroom`() {
        // daily allows 4 (today 0 of 20), but weekly leaves only 5 g (95 of 100) → min = 1 → YELLOW
        assertEquals(
            TrafficLight.YELLOW,
            light(gramsPerDrink = 5.0, todayGrams = 0.0, weeklyTotalGrams = 95.0, weeklyLimitGrams = 100.0),
        )
    }

    @Test fun `trafficLight RED when weekly budget exhausted`() {
        assertEquals(
            TrafficLight.RED,
            light(gramsPerDrink = 5.0, weeklyTotalGrams = 100.0, weeklyLimitGrams = 100.0),
        )
    }

    @Test fun `trafficLight RED when today not a drink day and weekly drink-day budget used up`() {
        // today 0 g (not a drink day), 5 past drink days, max 5 → starting a 6th day is RED
        assertEquals(
            TrafficLight.RED,
            light(
                gramsPerDrink = 5.0,
                todayGrams = 0.0,
                dailyLimitGrams = 100.0,
                drinkDaysThisWeek = 5,
                maxDrinkDaysPerWeek = 5,
            ),
        )
    }

    @Test fun `trafficLight RED when today IS a drink day but there were already max past drink days`() {
        // today is a drink day (drinkDaysThisWeek includes it = 6), 5 past days, max 5
        // → pastDrinkDays = 6 - 1 = 5 >= 5 → RED (per spec, the 6th drink day itself is over budget)
        assertEquals(
            TrafficLight.RED,
            light(
                gramsPerDrink = 5.0,
                todayGrams = 5.0,
                dailyLimitGrams = 100.0,
                drinkDaysThisWeek = 6,
                maxDrinkDaysPerWeek = 5,
            ),
        )
    }

    @Test fun `trafficLight drink-day gate does not fire on an allowed already-counted day`() {
        // today is a drink day, only 4 past drink days (drinkDaysThisWeek = 5, max 5)
        // → pastDrinkDays = 4 < 5 → gate does not fire; daily gram check decides → GREEN
        assertEquals(
            TrafficLight.GREEN,
            light(
                gramsPerDrink = 5.0,
                todayGrams = 5.0,
                dailyLimitGrams = 20.0,
                drinkDaysThisWeek = 5,
                maxDrinkDaysPerWeek = 5,
            ),
        )
    }

    // ── countLimitViolations ───────────────────────────────────────────────────

    private fun ds(date: String, grams: Double) = DaySummary(date, grams, 1)

    // As of v0.62.0 these checks use a gliding 7-day window (today + the previous
    // six calendar days) instead of a fixed calendar week, so the violation counts
    // below are derived from trailing windows, not Monday-to-Sunday buckets.

    @Test fun `countLimitViolations counts days over the daily limit`() {
        // 2026-01-05..06. Daily limit 20: only the 25 g day is over. The daily check
        // is a plain per-day comparison, unaffected by the rolling window.
        val v = AlcoholCalculator.countLimitViolations(
            summaries = listOf(ds("2026-01-05", 25.0), ds("2026-01-06", 10.0)),
            dailyLimitGrams = 20.0,
            weeklyLimitGrams = 1000.0,
            maxDrinkDaysPerWeek = 7,
        )
        assertEquals(1, v.daysOverDailyLimit)
    }

    @Test fun `countLimitViolations counts every day whose trailing 7-day total is over the limit`() {
        // Five consecutive days, 10 g each; 7-day limit 25 g. All five sit inside a
        // single 7-day window, so the trailing total per day is 10,20,30,40,50.
        // > 25 from the 3rd day (30) onward → days 3,4,5 = 3.
        val days = listOf(
            ds("2026-01-05", 10.0),
            ds("2026-01-06", 10.0),
            ds("2026-01-07", 10.0),
            ds("2026-01-08", 10.0),
            ds("2026-01-09", 10.0),
        )
        val v = AlcoholCalculator.countLimitViolations(
            summaries = days,
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 25.0,
            maxDrinkDaysPerWeek = 7,
        )
        assertEquals(3, v.daysOverWeeklyLimit)
    }

    @Test fun `countLimitViolations does not carry grams across a gap wider than the window`() {
        // Two 30 g days eight days apart (01-01, 01-09). They never share a 7-day
        // window, so each is judged on its own 30 g > 25 g → 2 (no carry-over that a
        // calendar week with a Monday reset might or might not have produced).
        val v = AlcoholCalculator.countLimitViolations(
            summaries = listOf(ds("2026-01-01", 30.0), ds("2026-01-09", 30.0)),
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 25.0,
            maxDrinkDaysPerWeek = 7,
        )
        assertEquals(2, v.daysOverWeeklyLimit)
    }

    @Test fun `countLimitViolations window boundary is an inclusive seven calendar days`() {
        // A 6-day gap keeps both days in the same window; a 7-day gap does not.
        // 01-01 + 01-07 (6 days apart): on 01-07 the window [01-01..01-07] holds both
        // → 20 + 20 = 40 > 30 → one over (01-01 alone is 20, not over).
        val withinWindow = AlcoholCalculator.countLimitViolations(
            summaries = listOf(ds("2026-01-01", 20.0), ds("2026-01-07", 20.0)),
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 30.0,
            maxDrinkDaysPerWeek = 7,
        )
        assertEquals(1, withinWindow.daysOverWeeklyLimit)

        // 01-01 + 01-08 (7 days apart): on 01-08 the window [01-02..01-08] excludes
        // 01-01 → only 20 g → nothing over.
        val outsideWindow = AlcoholCalculator.countLimitViolations(
            summaries = listOf(ds("2026-01-01", 20.0), ds("2026-01-08", 20.0)),
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 30.0,
            maxDrinkDaysPerWeek = 7,
        )
        assertEquals(0, outsideWindow.daysOverWeeklyLimit)
    }

    @Test fun `countLimitViolations counts drink days beyond the limit within a 7-day window`() {
        // 7 consumption days inside one window, max 5 → the 6th and 7th day count → 2.
        val days = (5..11).map { ds("2026-01-%02d".format(it), 5.0) } // 05 .. 11
        val v = AlcoholCalculator.countLimitViolations(
            summaries = days,
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 1000.0,
            maxDrinkDaysPerWeek = 5,
        )
        assertEquals(2, v.daysOverDrinkDayLimit)
    }

    @Test fun `countLimitViolations drink-day window does not reset on a weekday boundary`() {
        // Eight consecutive drink days 05..12 (spanning the Sun 11 → Mon 12 boundary),
        // max 5. Trailing drink-day counts: 1,2,3,4,5,6,7,7 → days 10,11,12 are over.
        // A calendar week with a Monday reset would have made 12 the "1st" day again;
        // the rolling window keeps counting → 3 violations, proving no weekly reset.
        val days = (5..12).map { ds("2026-01-%02d".format(it), 5.0) } // Mon 05 .. Mon 12
        val v = AlcoholCalculator.countLimitViolations(
            summaries = days,
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 1000.0,
            maxDrinkDaysPerWeek = 5,
        )
        assertEquals(3, v.daysOverDrinkDayLimit)
    }

    @Test fun `countLimitViolations ignores alcohol-free days for window and drink-day checks`() {
        // A 0 g day is not a drink day and never enters the window.
        val days = listOf(ds("2026-01-05", 0.0), ds("2026-01-06", 30.0))
        val v = AlcoholCalculator.countLimitViolations(
            summaries = days,
            dailyLimitGrams = 1000.0,
            weeklyLimitGrams = 25.0,
            maxDrinkDaysPerWeek = 1,
        )
        // Only the 30 g day is a consumption day: it is the 1st drink day in its window
        // (not over the max of 1) but exceeds the 25 g window limit → weekly 1, drink-day 0.
        assertEquals(1, v.daysOverWeeklyLimit)
        assertEquals(0, v.daysOverDrinkDayLimit)
    }

    // ── isOverLimit / exactly-at-limit floating point (v0.79.0 QA) ────────────

    /**
     * Reaching a limit EXACTLY is allowed on every surface — even when the total
     * is a binary-floating-point SUM of 0.1-g-grid values that does not hit the
     * limit bit-exactly. 14.3 is not representable in binary, so seven summands
     * of 14.3/14.2 accumulate to 100.000000000000014…; a strict `>` (the
     * pre-v0.79.0 comparison) flagged that as an exceedance the user could not
     * see, against the "displayed number == compared number" principle.
     */
    @Test fun `isOverLimit tolerates drift at the exact boundary but not a real exceedance`() {
        // A total that DISPLAYS as exactly the limit but carries upward binary
        // drift (the incremental window sum below produces exactly this kind of
        // value) must not count as an exceedance …
        assertFalse(AlcoholCalculator.isOverLimit(100.0 + 1e-12, 100.0))
        assertFalse(AlcoholCalculator.isOverLimit(100.0, 100.0))
        // … while the smallest REAL exceedance on the 0.1 g data grid still trips.
        assertTrue(AlcoholCalculator.isOverLimit(100.1, 100.0))
        assertFalse(AlcoholCalculator.isOverLimit(99.9, 100.0))
    }

    /**
     * The sliding 7-day window of [AlcoholCalculator.countLimitViolations]
     * maintains its gram sum INCREMENTALLY (add on entry, subtract on eviction),
     * which accumulates additional drift on top of plain summation. A window
     * whose days total exactly the 100 g limit — reached only after earlier days
     * have been evicted, so the subtractive path is exercised — must not be
     * counted as over the weekly limit.
     */
    @Test fun `countLimitViolations does not flag a window at exactly the weekly limit`() {
        // Days 1–2 fall out of the window again (forcing the subtractive
        // eviction path); days 3–9 form a full 7-day window summing exactly
        // 100.0 on the 0.1 g grid. With THIS sequence the incrementally
        // maintained double sum provably lands at 100.00000000000001 (verified
        // by replaying the algorithm on the JVM), so the pre-v0.79.0 strict `>`
        // counted the day as over the weekly limit — the regression this pins.
        val exactWindow = listOf(14.3, 14.3, 14.3, 14.3, 14.3, 14.3, 14.2)
        val summaries = listOf(0.1, 0.1).mapIndexed { i, g ->
            DaySummary("2026-06-%02d".format(i + 1), g, 1)
        } + exactWindow.mapIndexed { i, g ->
            DaySummary("2026-06-%02d".format(i + 3), g, 1)
        }
        val v = AlcoholCalculator.countLimitViolations(
            summaries = summaries,
            dailyLimitGrams = 100.0, // no day exceeds this; isolates the weekly check
            weeklyLimitGrams = 100.0,
            maxDrinkDaysPerWeek = 7,
        )
        assertEquals(0, v.daysOverWeeklyLimit)
        assertEquals(0, v.daysOverDailyLimit)
    }
}
