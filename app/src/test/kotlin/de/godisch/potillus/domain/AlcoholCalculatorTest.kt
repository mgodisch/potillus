/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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

import de.godisch.potillus.domain.model.*
import org.junit.Assert.*
import org.junit.Test

class AlcoholCalculatorTest {

    // ── calculateGrams ────────────────────────────────────────────────────────

    @Test fun `calculateGrams Pils 500ml 4_9pct`() {
        val result = AlcoholCalculator.calculateGrams(500, 4.9)
        assertEquals(19.32, result, 0.01)
    }

    @Test fun `calculateGrams Rotwein 200ml 13pct`() {
        val result = AlcoholCalculator.calculateGrams(200, 13.0)
        assertEquals(20.51, result, 0.01)
    }

    @Test fun `calculateGrams Whisky 40ml 40pct`() {
        val result = AlcoholCalculator.calculateGrams(40, 40.0)
        assertEquals(12.62, result, 0.01)
    }

    @Test fun `calculateGrams alkoholfrei returns zero`() {
        assertEquals(0.0, AlcoholCalculator.calculateGrams(500, 0.0), 0.0)
    }

    @Test fun `calculateGrams rounds to two decimals`() {
        val result = AlcoholCalculator.calculateGrams(330, 4.9)
        assertTrue("Result must have ≤ 2 decimal places", result == Math.round(result * 100.0) / 100.0)
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

    // ── soberByMillis ──────────────────────────────────────────────────────────

    @Test fun `soberByMillis zero or negative BAC returns nowMillis`() {
        val now = 1_700_000_000_000L
        assertEquals(now, AlcoholCalculator.soberByMillis(0.0,  now))
        assertEquals(now, AlcoholCalculator.soberByMillis(-1.0, now))
    }

    @Test fun `soberByMillis 0_15 permille adds exactly 1 hour`() {
        // 0.15 ‰ / 0.15 ‰h = 1 h = MILLIS_PER_HOUR ms
        val now      = 1_700_000_000_000L
        val expected = now + AlcoholCalculator.MILLIS_PER_HOUR.toLong()
        assertEquals(expected, AlcoholCalculator.soberByMillis(0.15, now))
    }

    @Test fun `soberByMillis 0_5 permille adds 3h20m`() {
        // 0.5 / 0.15 = 3.333... h = 12_000_000 ms
        val now = 0L
        val result = AlcoholCalculator.soberByMillis(0.5, now)
        assertEquals(12_000_000.0, result.toDouble(), 1_000.0)  // 1 s tolerance for floating-point
    }

    @Test fun `soberByMillis result is always at least nowMillis`() {
        val now = System.currentTimeMillis()
        assertTrue("soberByMillis result must always be >= nowMillis", AlcoholCalculator.soberByMillis(1.5, now) >= now)
    }

    // ── getLimitInfo ──────────────────────────────────────────────────────────

    @Test fun `getLimitInfo maps the three limits from settings`() {
        val settings = AppSettings(dailyLimitGrams = 25.0, weeklyLimitGrams = 120.0, maxDrinkDaysPerWeek = 4)
        val info = AlcoholCalculator.getLimitInfo(settings)
        assertEquals(25.0,  info.limitGrams,        0.0)
        assertEquals(120.0, info.weeklyLimitGrams,  0.0)
        assertEquals(4,     info.maxDrinkDaysPerWeek)
    }

    @Test fun `getLimitInfo defaults are 20-100-5`() {
        val info = AlcoholCalculator.getLimitInfo(AppSettings())
        assertEquals(20.0,  info.limitGrams,       0.0)
        assertEquals(100.0, info.weeklyLimitGrams, 0.0)
        assertEquals(5,     info.maxDrinkDaysPerWeek)
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

    @Test fun `binge threshold is the conservative 48g`() {
        assertEquals(48.0, AlcoholCalculator.BINGE_THRESHOLD, 0.0)
    }

    // ── trafficLight ──────────────────────────────────────────────────────────

    /**
     * Helper that calls trafficLight with all three limits explicit.
     * Defaults: daily 20 g, weekly 1000 g (effectively unlimited so it does not
     * interfere), 5 drink days/week, nothing consumed today.
     */
    private fun light(
        gramsPerDrink: Double,
        todayGrams: Double         = 0.0,
        dailyLimitGrams: Double    = 20.0,
        weeklyTotalGrams: Double   = 0.0,
        weeklyLimitGrams: Double   = 1000.0,
        drinkDaysThisWeek: Int     = 0,
        maxDrinkDaysPerWeek: Int   = 5
    ) = AlcoholCalculator.trafficLight(
        gramsPerDrink       = gramsPerDrink,
        todayGrams          = todayGrams,
        dailyLimitGrams     = dailyLimitGrams,
        weeklyTotalGrams    = weeklyTotalGrams,
        weeklyLimitGrams    = weeklyLimitGrams,
        drinkDaysThisWeek   = drinkDaysThisWeek,
        maxDrinkDaysPerWeek = maxDrinkDaysPerWeek
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
            light(gramsPerDrink = 5.0, todayGrams = 0.0, weeklyTotalGrams = 95.0, weeklyLimitGrams = 100.0)
        )
    }

    @Test fun `trafficLight RED when weekly budget exhausted`() {
        assertEquals(
            TrafficLight.RED,
            light(gramsPerDrink = 5.0, weeklyTotalGrams = 100.0, weeklyLimitGrams = 100.0)
        )
    }

    @Test fun `trafficLight RED when today not a drink day and weekly drink-day budget used up`() {
        // today 0 g (not a drink day), 5 past drink days, max 5 → starting a 6th day is RED
        assertEquals(
            TrafficLight.RED,
            light(gramsPerDrink = 5.0, todayGrams = 0.0, dailyLimitGrams = 100.0,
                  drinkDaysThisWeek = 5, maxDrinkDaysPerWeek = 5)
        )
    }

    @Test fun `trafficLight RED when today IS a drink day but there were already max past drink days`() {
        // today is a drink day (drinkDaysThisWeek includes it = 6), 5 past days, max 5
        // → pastDrinkDays = 6 - 1 = 5 >= 5 → RED (per spec, the 6th drink day itself is over budget)
        assertEquals(
            TrafficLight.RED,
            light(gramsPerDrink = 5.0, todayGrams = 5.0, dailyLimitGrams = 100.0,
                  drinkDaysThisWeek = 6, maxDrinkDaysPerWeek = 5)
        )
    }

    @Test fun `trafficLight drink-day gate does not fire on an allowed already-counted day`() {
        // today is a drink day, only 4 past drink days (drinkDaysThisWeek = 5, max 5)
        // → pastDrinkDays = 4 < 5 → gate does not fire; daily gram check decides → GREEN
        assertEquals(
            TrafficLight.GREEN,
            light(gramsPerDrink = 5.0, todayGrams = 5.0, dailyLimitGrams = 20.0,
                  drinkDaysThisWeek = 5, maxDrinkDaysPerWeek = 5)
        )
    }

    // ── countLimitViolations ───────────────────────────────────────────────────

    private fun ds(date: String, grams: Double) = DaySummary(date, grams, 1)

    @Test fun `countLimitViolations counts days over the daily limit`() {
        // 2026-01-05..06 (Mon, Tue). Daily limit 20: only the 25 g day is over.
        val v = AlcoholCalculator.countLimitViolations(
            summaries = listOf(ds("2026-01-05", 25.0), ds("2026-01-06", 10.0)),
            dailyLimitGrams = 20.0, weeklyLimitGrams = 1000.0, maxDrinkDaysPerWeek = 7, weekStartDay = 1
        )
        assertEquals(1, v.daysOverDailyLimit)
    }

    @Test fun `countLimitViolations counts the overshoot day and all later days in the week`() {
        // Mon–Fri, 10 g each; weekly limit 25 g. Cumulative: 10,20,30,40,50.
        // > 25 from the 3rd day (30) onward → days 3,4,5 = 3.
        val week = listOf(
            ds("2026-01-05", 10.0), ds("2026-01-06", 10.0), ds("2026-01-07", 10.0),
            ds("2026-01-08", 10.0), ds("2026-01-09", 10.0)
        )
        val v = AlcoholCalculator.countLimitViolations(
            summaries = week, dailyLimitGrams = 1000.0, weeklyLimitGrams = 25.0, maxDrinkDaysPerWeek = 7, weekStartDay = 1
        )
        assertEquals(3, v.daysOverWeeklyLimit)
    }

    @Test fun `countLimitViolations counts drink days beyond the weekly drink-day limit`() {
        // 7 consumption days in one week, max 5 → the 6th and 7th day count → 2.
        val week = (5..11).map { ds("2026-01-%02d".format(it), 5.0) }  // Mon 05 .. Sun 11
        val v = AlcoholCalculator.countLimitViolations(
            summaries = week, dailyLimitGrams = 1000.0, weeklyLimitGrams = 1000.0, maxDrinkDaysPerWeek = 5, weekStartDay = 1
        )
        assertEquals(2, v.daysOverDrinkDayLimit)
    }

    @Test fun `countLimitViolations resets per week`() {
        // Two separate weeks, 6 drink days each, max 5 → 1 over per week → 2 total.
        val w1 = (5..10).map { ds("2026-01-%02d".format(it), 5.0) }   // Mon 05 .. Sat 10
        val w2 = (12..17).map { ds("2026-01-%02d".format(it), 5.0) }  // Mon 12 .. Sat 17
        val v = AlcoholCalculator.countLimitViolations(
            summaries = w1 + w2, dailyLimitGrams = 1000.0, weeklyLimitGrams = 1000.0, maxDrinkDaysPerWeek = 5, weekStartDay = 1
        )
        assertEquals(2, v.daysOverDrinkDayLimit)
    }

    @Test fun `countLimitViolations ignores alcohol-free days for weekly and drink-day checks`() {
        // A 0 g day is not a drink day and adds nothing to the weekly running total.
        val week = listOf(ds("2026-01-05", 0.0), ds("2026-01-06", 30.0))
        val v = AlcoholCalculator.countLimitViolations(
            summaries = week, dailyLimitGrams = 1000.0, weeklyLimitGrams = 25.0, maxDrinkDaysPerWeek = 1, weekStartDay = 1
        )
        // Only the 30 g day is a consumption day: it is the 1st drink day (not over the
        // max of 1) but pushes the week over 25 g → weekly = 1, drink-day = 0.
        assertEquals(1, v.daysOverWeeklyLimit)
        assertEquals(0, v.daysOverDrinkDayLimit)
    }
}
