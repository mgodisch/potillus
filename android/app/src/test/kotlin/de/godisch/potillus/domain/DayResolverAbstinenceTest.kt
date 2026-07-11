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

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Branch tests for [DayResolver.computeLongestAbstinence] covering the empty-history,
 * initial-gap and tail-gap paths that the main DayResolverTest does not exercise.
 */
class DayResolverAbstinenceTest {

    @Test fun `no history and no today is zero`() {
        assertEquals(0, DayResolver.computeLongestAbstinence(emptyList()))
    }

    @Test fun `no history counts the statsFrom to today span`() {
        assertEquals(
            4,
            DayResolver.computeLongestAbstinence(emptyList(), today = "2026-01-05", statsFrom = "2026-01-01"),
        )
    }

    @Test fun `initial gap before the first drink is counted`() {
        assertEquals(
            9,
            DayResolver.computeLongestAbstinence(listOf("2026-01-10"), statsFrom = "2026-01-01"),
        )
    }

    @Test fun `tail gap after the last drink up to today is counted`() {
        assertEquals(
            4,
            DayResolver.computeLongestAbstinence(listOf("2026-01-10"), today = "2026-01-15"),
        )
    }
}
