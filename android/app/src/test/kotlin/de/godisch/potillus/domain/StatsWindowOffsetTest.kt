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
// StatsWindowOffsetTest.kt
// =============================================================================
//
// The offset CEILING, which no shared vector covers: the vectors pin what a
// window looks like at a given offset, this pins how far back the user may go.
//
// The distinction the tests keep returning to is period arithmetic against day
// counting. 31 January and 1 February are one month apart although two days lie
// between them, and a floor on the 1st of this month allows no step back at all.
// The week is the deliberate exception: it is a rolling seven-day window, so
// whole sevens separate two of them.
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Test

class StatsWindowOffsetTest {

    // ── Months ───────────────────────────────────────────────────────────────

    @Test
    fun `a floor inside the current month allows no step back`() {
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.MONTH, "2026-07-30", "2026-07-01"))
    }

    @Test
    fun `a floor one day before the month allows one step`() {
        // Two days apart, one period apart: the boundary is what counts.
        assertEquals(1, StatsWindows.offsetOf(StatsPeriod.MONTH, "2026-02-01", "2026-01-31"))
    }

    @Test
    fun `month offsets count boundaries across a year end`() {
        assertEquals(11, StatsWindows.offsetOf(StatsPeriod.MONTH, "2026-07-30", "2025-08-15"))
    }

    // ── Years ────────────────────────────────────────────────────────────────

    @Test
    fun `a floor inside the current year allows no step back`() {
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.YEAR, "2026-07-30", "2026-01-01"))
    }

    @Test
    fun `year offsets count calendar years, not elapsed days`() {
        assertEquals(2, StatsWindows.offsetOf(StatsPeriod.YEAR, "2026-07-30", "2024-12-31"))
    }

    // ── The rolling week ─────────────────────────────────────────────────────

    @Test
    fun `a floor inside the current seven days allows no step back`() {
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.WEEK, "2026-07-30", "2026-07-24"))
    }

    @Test
    fun `whole sevens separate rolling weeks`() {
        assertEquals(1, StatsWindows.offsetOf(StatsPeriod.WEEK, "2026-07-30", "2026-07-23"))
        assertEquals(2, StatsWindows.offsetOf(StatsPeriod.WEEK, "2026-07-30", "2026-07-16"))
    }

    @Test
    fun `a partial week does not add a step`() {
        // Thirteen days back is still one whole seven, not two.
        assertEquals(1, StatsWindows.offsetOf(StatsPeriod.WEEK, "2026-07-30", "2026-07-17"))
    }

    // ── Bounds that must not open the offset up ───────────────────────────────

    @Test
    fun `a day after today names no past period`() {
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.MONTH, "2026-07-30", "2026-08-01"))
    }

    @Test
    fun `today itself names the current period`() {
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.MONTH, "2026-07-30", "2026-07-30"))
    }

    /**
     * An unreadable bound yields 0 rather than an open range.
     *
     * The floor comes from storage and a backup file may carry anything. Reading a
     * broken value as "no limit" would let the screen wander into empty windows;
     * reading it as "no step back" keeps it where the data is.
     */
    @Test
    fun `an unparseable bound closes the offset`() {
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.MONTH, "2026-07-30", "2026-02-30"))
        assertEquals(0, StatsWindows.offsetOf(StatsPeriod.MONTH, "not a date", "2026-01-01"))
    }
}
