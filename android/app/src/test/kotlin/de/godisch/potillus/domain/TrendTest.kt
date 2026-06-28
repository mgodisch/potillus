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

import org.junit.Assert.assertEquals
import org.junit.Test

class TrendTest {

    @Test fun `lower current average than previous is DOWN`() {
        assertEquals(Trend.DOWN, Trend.of(currentAvg = 18.8, prevAvg = 20.0))
    }

    @Test fun `higher current average than previous is UP`() {
        assertEquals(Trend.UP, Trend.of(currentAvg = 22.4, prevAvg = 20.0))
    }

    @Test fun `equal at 0_1 g precision is FLAT`() {
        // Exactly equal.
        assertEquals(Trend.FLAT, Trend.of(currentAvg = 20.0, prevAvg = 20.0))
        // Different in the raw value but equal once rounded to 0.1 g (20.04 → 20.0,
        // 19.96 → 20.0) → still FLAT.
        assertEquals(Trend.FLAT, Trend.of(currentAvg = 20.04, prevAvg = 19.96))
    }

    @Test fun `a 0_1 g difference is enough to show a trend`() {
        assertEquals(Trend.DOWN, Trend.of(currentAvg = 19.9, prevAvg = 20.0))
        assertEquals(Trend.UP,   Trend.of(currentAvg = 20.1, prevAvg = 20.0))
    }

    @Test fun `no previous value is FLAT`() {
        // prevAvg <= 0 means "no comparable previous month" → no arrow.
        assertEquals(Trend.FLAT, Trend.of(currentAvg = 18.8, prevAvg = 0.0))
        assertEquals(Trend.FLAT, Trend.of(currentAvg = 0.0,  prevAvg = 0.0))
    }
}
