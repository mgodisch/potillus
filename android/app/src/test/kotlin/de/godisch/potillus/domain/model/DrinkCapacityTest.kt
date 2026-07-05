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
package de.godisch.potillus.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [DrinkCapacity], in particular its derived [DrinkCapacity.todayIsDrinkDay]
 * flag.
 */
class DrinkCapacityTest {

    private fun capacity(todayGrams: Double) = DrinkCapacity(
        todayGrams = todayGrams,
        dailyLimitGrams = 20.0,
        weeklyTotalGrams = 50.0,
        weeklyLimitGrams = 100.0,
        drinkDaysThisWeek = 2,
        maxDrinkDaysPerWeek = 5
    )

    @Test fun `todayIsDrinkDay is true when grams above zero`() {
        assertTrue(capacity(0.1).todayIsDrinkDay)
    }

    @Test fun `todayIsDrinkDay is false when no grams logged`() {
        assertFalse(capacity(0.0).todayIsDrinkDay)
    }

    @Test fun `fields are preserved`() {
        val c = capacity(12.0)
        assertEquals(12.0, c.todayGrams, 0.0)
        assertEquals(100.0, c.weeklyLimitGrams, 0.0)
        assertEquals(5, c.maxDrinkDaysPerWeek)
    }
}
