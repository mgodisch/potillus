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
// MonthGridVectorTest.kt – cross-platform parity suite for the month grid
// =============================================================================
//
// Asserts `MonthGrid` against `test-vectors/month-grid.json`, the file the iOS
// suite loads too (`MonthGridVectorTest.swift` against PotillusKit's MonthGrid).
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.YearMonth

class MonthGridVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("month-grid")
    }

    @Test
    fun `the grid matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("cases")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val description = case.getString("description")
            val grid = MonthGrid.of(
                YearMonth.of(case.getInt("year"), case.getInt("month")),
                case.getInt("firstDayOfWeekIso"),
            )
            val expected = case.getJSONObject("expected")
            assertEquals("$description: leadingBlanks", expected.getInt("leadingBlanks"), grid.leadingBlanks)
            assertEquals("$description: dayCount", expected.getInt("dayCount"), grid.dayCount)
            assertEquals("$description: cellCount", expected.getInt("cellCount"), grid.cellCount)
        }
    }
}
