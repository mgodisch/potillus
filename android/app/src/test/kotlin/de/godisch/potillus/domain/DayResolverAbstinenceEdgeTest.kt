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

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Further branch tests for [DayResolver.computeLongestAbstinence]: the
 * statsFrom-after-today guard in the empty-history case, and the inter-drink gap
 * loop that a single-date history never exercises.
 */
class DayResolverAbstinenceEdgeTest {

    @Test fun `empty history with statsFrom on or after today is zero`() {
        assertEquals(
            0,
            DayResolver.computeLongestAbstinence(emptyList(), today = "2026-01-01", statsFrom = "2026-01-05"),
        )
    }

    @Test fun `the longest inter-drink gap is taken across several dates`() {
        // Gaps: 01-01 -> 01-10 is 8 abstinent days; 01-10 -> 01-12 is 1. Longest = 8.
        assertEquals(
            8,
            DayResolver.computeLongestAbstinence(listOf("2026-01-01", "2026-01-10", "2026-01-12")),
        )
    }
}
