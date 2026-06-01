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

    @Test fun `calculateBAC male 80kg 20g 0h`() {
        // c = 20 / (80 * 0.7) - 0.15 * 0 = 0.357 ‰
        val bac = AlcoholCalculator.calculateBAC(20.0, 80.0, Gender.MALE, 0.0)
        assertEquals(0.36, bac, 0.01)
    }

    @Test fun `calculateBAC female 60kg 12g 0h`() {
        // c = 12 / (60 * 0.6) - 0 = 0.333 ‰
        val bac = AlcoholCalculator.calculateBAC(12.0, 60.0, Gender.FEMALE, 0.0)
        assertEquals(0.33, bac, 0.01)
    }

    @Test fun `calculateBAC decreases over time`() {
        val bac0h = AlcoholCalculator.calculateBAC(40.0, 75.0, Gender.MALE, 0.0)
        val bac2h = AlcoholCalculator.calculateBAC(40.0, 75.0, Gender.MALE, 2.0)
        assertTrue("BAC after 2h must be less than BAC at 0h", bac2h < bac0h)
    }

    @Test fun `calculateBAC never negative`() {
        val bac = AlcoholCalculator.calculateBAC(10.0, 80.0, Gender.MALE, 10.0)
        assertTrue("BAC must never be negative", bac >= 0.0)
    }

    @Test fun `calculateBAC zero weight returns zero`() {
        assertEquals(0.0, AlcoholCalculator.calculateBAC(20.0, 0.0, Gender.MALE, 0.0), 0.0)
    }

    @Test fun `calculateBAC zero grams returns zero`() {
        assertEquals(0.0, AlcoholCalculator.calculateBAC(0.0, 80.0, Gender.MALE, 0.0), 0.0)
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

    @Test fun `getLimitInfo WHO male = 20g`() {
        val settings = AppSettings(gender = Gender.MALE, limitMode = LimitMode.WHO)
        assertEquals(20.0, AlcoholCalculator.getLimitInfo(settings).limitGrams, 0.0)
    }

    @Test fun `getLimitInfo WHO female = 10g`() {
        val settings = AppSettings(gender = Gender.FEMALE, limitMode = LimitMode.WHO)
        assertEquals(10.0, AlcoholCalculator.getLimitInfo(settings).limitGrams, 0.0)
    }

    @Test fun `getLimitInfo DHS male = 24g`() {
        val settings = AppSettings(gender = Gender.MALE, limitMode = LimitMode.DHS)
        assertEquals(24.0, AlcoholCalculator.getLimitInfo(settings).limitGrams, 0.0)
    }

    @Test fun `getLimitInfo DHS female = 12g`() {
        val settings = AppSettings(gender = Gender.FEMALE, limitMode = LimitMode.DHS)
        assertEquals(12.0, AlcoholCalculator.getLimitInfo(settings).limitGrams, 0.0)
    }

    @Test fun `getLimitInfo CUSTOM returns customLimitGrams`() {
        val settings = AppSettings(limitMode = LimitMode.CUSTOM, customLimitGrams = 30.0)
        assertEquals(30.0, AlcoholCalculator.getLimitInfo(settings).limitGrams, 0.0)
    }

    @Test fun `getLimitInfo returns correct mode`() {
        assertEquals(LimitMode.WHO,    AlcoholCalculator.getLimitInfo(AppSettings(limitMode = LimitMode.WHO)).mode)
        assertEquals(LimitMode.DHS,    AlcoholCalculator.getLimitInfo(AppSettings(limitMode = LimitMode.DHS)).mode)
        assertEquals(LimitMode.CUSTOM, AlcoholCalculator.getLimitInfo(AppSettings(limitMode = LimitMode.CUSTOM)).mode)
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

    @Test fun `bingeThreshold male = 60g`() {
        assertEquals(60.0, AlcoholCalculator.bingeThreshold(Gender.MALE), 0.0)
    }

    @Test fun `bingeThreshold female = 48g`() {
        assertEquals(48.0, AlcoholCalculator.bingeThreshold(Gender.FEMALE), 0.0)
    }

    @Test fun `WHO limits correct`() {
        assertEquals(20.0, AlcoholCalculator.WHO_LIMIT_MALE,   0.0)
        assertEquals(10.0, AlcoholCalculator.WHO_LIMIT_FEMALE, 0.0)
    }

    @Test fun `DHS limits correct`() {
        assertEquals(24.0, AlcoholCalculator.DHS_LIMIT_MALE,   0.0)
        assertEquals(12.0, AlcoholCalculator.DHS_LIMIT_FEMALE, 0.0)
    }

    // ── trafficLight ──────────────────────────────────────────────────────────

    /**
     * Helper that calls trafficLight with all parameters explicit.
     * Budget defaults: daily mode, 20 g limit, 5 drink days / week, 0 today.
     */
    private fun light(
        gramsPerDrink: Double,
        consumedGrams: Double,
        gramBudget: Double        = 20.0,
        rawTodayGrams: Double     = 0.0,
        drinkDaysThisWeek: Int    = 0,
        maxDrinkDaysPerWeek: Int  = 5
    ) = AlcoholCalculator.trafficLight(
        gramsPerDrink        = gramsPerDrink,
        consumedGrams        = consumedGrams,
        gramBudget           = gramBudget,
        rawTodayGrams        = rawTodayGrams,
        drinkDaysThisWeek    = drinkDaysThisWeek,
        maxDrinkDaysPerWeek  = maxDrinkDaysPerWeek
    )

    @Test fun `trafficLight alcohol-free drink is always GREEN`() {
        // gramsPerDrink == 0 → no budget consumed → always GREEN regardless of state
        assertEquals(TrafficLight.GREEN, light(gramsPerDrink = 0.0, consumedGrams = 25.0))
    }

    @Test fun `trafficLight GREEN when two or more servings fit`() {
        // Budget = 20 g, consumed = 0 g, drink = 5 g → 4 servings remain → GREEN
        assertEquals(TrafficLight.GREEN, light(gramsPerDrink = 5.0, consumedGrams = 0.0, gramBudget = 20.0))
    }

    @Test fun `trafficLight YELLOW when exactly one serving fits`() {
        // Budget = 20 g, consumed = 15 g, drink = 6 g → floor((20-15)/6) = 0 → RED
        // Use consumed = 14 g, drink = 6 g → floor(6/6) = 1 → YELLOW
        assertEquals(TrafficLight.YELLOW, light(gramsPerDrink = 6.0, consumedGrams = 14.0, gramBudget = 20.0))
    }

    @Test fun `trafficLight RED when no serving fits`() {
        // Budget = 20 g, consumed = 20 g, drink = 5 g → 0 servings remain → RED
        assertEquals(TrafficLight.RED, light(gramsPerDrink = 5.0, consumedGrams = 20.0, gramBudget = 20.0))
    }

    @Test fun `trafficLight RED when over budget`() {
        // consumed > budget → remaining < 0, clamped to 0 → 0 servings → RED
        assertEquals(TrafficLight.RED, light(gramsPerDrink = 5.0, consumedGrams = 25.0, gramBudget = 20.0))
    }

    @Test fun `trafficLight RED when drink-day budget exhausted and today is not yet a drink day`() {
        // maxDrinkDays = 5, drinkDaysThisWeek = 5, rawTodayGrams = 0
        // → today is NOT yet a drink day AND budget exhausted → RED regardless of gram headroom
        assertEquals(
            TrafficLight.RED,
            light(
                gramsPerDrink       = 5.0,
                consumedGrams       = 0.0,
                gramBudget          = 100.0,   // plenty of gram budget
                rawTodayGrams       = 0.0,
                drinkDaysThisWeek   = 5,
                maxDrinkDaysPerWeek = 5
            )
        )
    }

    @Test fun `trafficLight ignores drink-day limit when today already counts as a drink day`() {
        // drinkDaysThisWeek = 5 (= max), but rawTodayGrams > 0 → today is already a drink day
        // → drink-day gate does NOT fire; gram check determines the result
        assertEquals(
            TrafficLight.GREEN,
            light(
                gramsPerDrink       = 5.0,
                consumedGrams       = 5.0,
                gramBudget          = 20.0,
                rawTodayGrams       = 5.0,   // today already is a drink day
                drinkDaysThisWeek   = 5,
                maxDrinkDaysPerWeek = 5
            )
        )
    }

    @Test fun `trafficLight weekly mode RED when weekly gram budget exhausted`() {
        // weeklyBudget = 5 days × 20 g = 100 g; weeklyConsumed = 100 g → RED
        assertEquals(
            TrafficLight.RED,
            light(
                gramsPerDrink = 5.0,
                consumedGrams = 100.0,   // weekly total passed as consumedGrams in weekly mode
                gramBudget    = 100.0    // 5 × 20 g
            )
        )
    }

    @Test fun `trafficLight weekly mode GREEN when weekly gram budget has headroom`() {
        // weeklyBudget = 100 g, weeklyConsumed = 80 g, drink = 5 g → 4 servings → GREEN
        assertEquals(
            TrafficLight.GREEN,
            light(gramsPerDrink = 5.0, consumedGrams = 80.0, gramBudget = 100.0)
        )
    }
}
