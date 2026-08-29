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

import java.time.LocalDate

/**
 * The year heat-map's drawing window: pure date arithmetic, no Android types.
 *
 * The year view lays the same day summaries out a second time, twelve months
 * side by side. Everything about that layout is the composable's business; this
 * object owns the one question that is not, because it decides what the app
 * claims rather than how it looks.
 *
 * The counterpart is `Domain/YearGrid.swift` in PotillusKit, which carries the
 * same name and the same rule. Neither reads the other: they are held together
 * by `test-vectors/year-grid.json`, which both suites load.
 */
object YearGrid {

    /**
     * Whether the year heat-map draws the cell for [date].
     *
     * This is the ONE rule the year view has that the month view does not. It is
     * stated here, in the domain layer, for the reason every rule here is: the
     * composable that draws the grid must not be the only place it can be read or
     * tested. iOS states the same rule in `YearGrid.isDrawn`, and
     * `test-vectors/year-grid.json` pins both sides against each other.
     *
     * Two spans are not the app's to speak about:
     *
     *   - after [today] lies the future, which cannot have been abstinent yet.
     *   - before [statsFrom] lies the span the user excluded from every statistic.
     *     Entries there are excluded too, so drawing them would show the heat-map
     *     counting what the Statistics screen does not.
     *
     * BOTH BOUNDS ARE INCLUSIVE. [today] itself is drawn and so is [statsFrom]
     * itself; only the day beyond each is not. iOS compares the same two bounds as
     * `yyyy-MM-dd` STRINGS, which is chronological for a zero-padded fixed-width
     * format, so the two implementations agree by construction — but a strict
     * comparison introduced on one side and not the other is silent drift, which is
     * what the shared vector exists to catch.
     *
     * @param date      The cell's logical day.
     * @param today     Logical today, from [de.godisch.potillus.domain.DayResolver].
     * @param statsFrom Statistics start floor, or `null` when none is set.
     * @return `true` when the cell is drawn, `false` when it renders as nothing.
     */
    fun isDrawn(date: LocalDate, today: LocalDate, statsFrom: LocalDate?): Boolean {
        if (date.isAfter(today)) return false
        if (statsFrom != null && date.isBefore(statsFrom)) return false
        return true
    }
}
