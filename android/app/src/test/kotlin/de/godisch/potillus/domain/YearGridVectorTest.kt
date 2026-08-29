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
// YearGridVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts `isDrawn` against `test-vectors/year-grid.json`, the same file
// YearGridVectorTest.swift loads for PotillusKit's `YearGrid.isDrawn`.
//
// The rule lived as an expression inside YearCalendarView until the 0.85.0 QA
// round, where no JVM test could reach it, and in ui/component until it moved
// here: the two platforms carried the same three-line predicate and only one of
// them was pinned. The vectors exist so that a bound moved from inclusive to
// exclusive on either side turns the OTHER side's suite red.
//
// WHY THE DATES ARE PARSED HERE AND COMPARED AS STRINGS ON iOS
//   Android holds a cell's day as a LocalDate and iOS as a `yyyy-MM-dd` string.
//   Both orderings are the same for this format, and each side converts at its
//   own edge — which is precisely the seam a shared vector is for.
// =============================================================================

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class YearGridVectorTest {

    private companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("year-grid")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        /** `statsFrom` is JSON null when no statistics start date is set. */
        fun JSONObject.statsFrom(): LocalDate? =
            if (isNull("statsFrom")) null else LocalDate.parse(getString("statsFrom"))
    }

    @Test
    fun `the drawing window matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("isDrawn")

        // A vector file that failed to load, or that lost its cases in an edit,
        // would let this suite pass by testing nothing at all.
        assertEquals("the vector file must carry its cases", 13, cases.length())

        cases.objects().forEach { case ->
            val label = case.getString("description")
            val actual = YearGrid.isDrawn(
                LocalDate.parse(case.getString("date")),
                LocalDate.parse(case.getString("today")),
                case.statsFrom(),
            )
            assertEquals(label, case.getBoolean("expected"), actual)
        }
    }
}
