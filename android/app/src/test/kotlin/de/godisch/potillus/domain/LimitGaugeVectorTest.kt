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
// LimitGaugeVectorTest.kt – cross-platform parity suite for the progress bars
// =============================================================================
//
// Asserts `LimitGauge` against `test-vectors/limit-gauge.json`, the file the
// iOS suite loads too (`LimitGaugeVectorTest.swift`). The composables that
// draw the bars only map [Emphasis] onto colours; the rules are here.
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Test

class LimitGaugeVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("limit-gauge")
        const val EPS = 1e-6
    }

    @Test
    fun `the gram bar matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("grams")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val description = case.getString("description")
            val total = case.getDouble("totalGrams")
            val limit = case.getDouble("limitGrams")
            assertEquals("$description: fill", case.getDouble("fill"), LimitGauge.fillFraction(total, limit).toDouble(), EPS)
            assertEquals("$description: emphasis", Emphasis.valueOf(case.getString("emphasis")), LimitGauge.emphasis(total, limit))
        }
    }

    @Test
    fun `the drink-day bar matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("drinkDays")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val description = case.getString("description")
            val days = case.getInt("drinkDays")
            val cap = case.getInt("maxDrinkDays")
            val today = case.getBoolean("todayIsDrinkDay")
            assertEquals("$description: fill", case.getDouble("fill"), LimitGauge.drinkDaysFillFraction(days, cap).toDouble(), EPS)
            assertEquals(
                "$description: emphasis",
                Emphasis.valueOf(case.getString("emphasis")),
                LimitGauge.drinkDaysEmphasis(days, cap, today),
            )
        }
    }
}
