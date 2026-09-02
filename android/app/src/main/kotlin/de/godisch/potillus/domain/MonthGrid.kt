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

import java.time.YearMonth

// =============================================================================
// MonthGrid.kt – where day 1 sits in a seven-column month
// =============================================================================
//
// The Kotlin twin of PotillusKit's `MonthGrid`. The calendar screen and the
// year heat-map both lay a month out as rows of seven cells, and each used to
// compute the alignment inline — the same expression, written twice, tested
// nowhere. Here it is written once, and pinned to the iOS grid by
// `test-vectors/month-grid.json` (`MonthGridVectorTest` on each side).
//
// The rotation is the one `WeekdayProfile.order` performs for its columns; the
// two must agree, or a bar and a cell would name different weekdays.
// =============================================================================

/** The shape of one month in a seven-column grid. */
data class MonthGrid(
    /** Empty cells before day 1, so day 1 lands under its weekday header. */
    val leadingBlanks: Int,
    /** Days in the month. */
    val dayCount: Int,
) {
    /** Cells the grid needs: whole rows of seven. */
    val cellCount: Int get() = rowCount * 7

    /** Rows the grid needs. */
    val rowCount: Int get() = (leadingBlanks + dayCount + 6) / 7

    companion object {
        /**
         * The grid for [month] when the week starts on [firstDayOfWeekIso]
         * (ISO, 1 = Monday).
         */
        fun of(month: YearMonth, firstDayOfWeekIso: Int): MonthGrid = MonthGrid(
            leadingBlanks = (month.atDay(1).dayOfWeek.value - firstDayOfWeekIso + 7) % 7,
            dayCount = month.lengthOfMonth(),
        )
    }
}
