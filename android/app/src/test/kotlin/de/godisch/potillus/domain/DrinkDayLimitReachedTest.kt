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
// DrinkDayLimitReachedTest.kt
// =============================================================================
//
// The predicate answers "would drinking now exceed the drink-day allowance?".
// Two displays depend on it — the traffic-light dot and the drink-days bar — and
// before v0.81.0 the bar used a simpler rule and could contradict the dot.
// =============================================================================

import de.godisch.potillus.domain.model.TrafficLight
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DrinkDayLimitReachedTest {

    /**
     * At the cap, with today already a drink day: another drink today adds no
     * further drink day, so the allowance is not yet reached.
     */
    @Test
    fun `at the cap with today already a drink day the allowance is not reached`() {
        assertFalse(AlcoholCalculator.drinkDayLimitReached(5, 5, todayIsDrinkDay = true))
    }

    /**
     * The same 5 / 5 shown to the user, but today is still dry: the first drink
     * would spend a sixth drink day. This is the case the old bar got wrong.
     */
    @Test
    fun `at the cap with today still dry the allowance is reached`() {
        assertTrue(AlcoholCalculator.drinkDayLimitReached(5, 5, todayIsDrinkDay = false))
    }

    @Test
    fun `beyond the cap the allowance is reached either way`() {
        assertTrue(AlcoholCalculator.drinkDayLimitReached(6, 5, todayIsDrinkDay = true))
        assertTrue(AlcoholCalculator.drinkDayLimitReached(6, 5, todayIsDrinkDay = false))
    }

    @Test
    fun `below the cap the allowance is not reached`() {
        assertFalse(AlcoholCalculator.drinkDayLimitReached(4, 5, todayIsDrinkDay = false))
        assertFalse(AlcoholCalculator.drinkDayLimitReached(4, 5, todayIsDrinkDay = true))
        assertFalse(AlcoholCalculator.drinkDayLimitReached(0, 5, todayIsDrinkDay = false))
    }

    /**
     * The predicate must agree with the gate [AlcoholCalculator.trafficLight]
     * applies, across the whole grid: the dot and the bar answer one question.
     */
    @Test
    fun `the predicate matches the traffic-light gate everywhere`() {
        for (maxDays in 1..7) {
            for (days in 0..(maxDays + 2)) {
                for (todayIsDrinkDay in listOf(true, false)) {
                    if (days == 0 && todayIsDrinkDay) continue

                    val predicate =
                        AlcoholCalculator.drinkDayLimitReached(days, maxDays, todayIsDrinkDay)

                    // The dot: a serving that would otherwise fit must still be RED
                    // once the drink-day gate trips.
                    val dot = AlcoholCalculator.trafficLight(
                        gramsPerDrink = 10.0,
                        todayGrams = if (todayIsDrinkDay) 10.0 else 0.0,
                        dailyLimitGrams = 1_000.0,
                        weeklyTotalGrams = 0.0,
                        weeklyLimitGrams = 10_000.0,
                        drinkDaysThisWeek = days,
                        maxDrinkDaysPerWeek = maxDays,
                    )

                    val message = "days=$days max=$maxDays todayIsDrinkDay=$todayIsDrinkDay"
                    if (predicate) {
                        assertTrue(message, dot == TrafficLight.RED)
                    } else {
                        assertFalse(message, dot == TrafficLight.RED)
                    }
                }
            }
        }
    }
}
