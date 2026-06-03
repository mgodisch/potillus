/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

class DayResolverTest {

    private val zone = ZoneId.of("Europe/Berlin")

    // Hilfsmethode: LocalDateTime → Unix-Millisekunden in einer fixen Zeitzone
    private fun toMillis(ldt: LocalDateTime): Long =
        ldt.atZone(zone).toInstant().toEpochMilli()

    // ── Basisfall: nach Tageswechsel ──────────────────────────────────────────

    @Test fun `resolve 04h01 stays same day`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 4, 1))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-24", day)
    }

    @Test fun `resolve 12h00 stays same day`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 12, 0))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-24", day)

    }

    @Test fun `resolve 23h59 stays same day`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 23, 59))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-24", day)
    }

    // ── Vor Tageswechsel → Vortag ─────────────────────────────────────────────

    @Test fun `resolve 03h59 maps to previous day`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 3, 59))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-23", day)
    }

    @Test fun `resolve 02h30 maps to previous day`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 2, 30))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-23", day)
    }

    @Test fun `resolve 00h00 (midnight) maps to previous day`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 0, 0))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-23", day)
    }

    // ── Exakt auf Tageswechsel-Zeitpunkt ─────────────────────────────────────

    @Test fun `resolve exactly at change time stays same day`() {
        // 04:00 ist NICHT vor 04:00, also gleicher Tag
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 4, 0))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-05-24", day)
    }

    // ── Benutzerdefinierter Tageswechsel ──────────────────────────────────────

    @Test fun `resolve custom change time 06h00`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 5, 59))
        val day = DayResolver.resolve(ts, 6, 0, zone)
        assertEquals("2025-05-23", day)
    }

    @Test fun `resolve custom change time 06h00 after`() {
        val ts  = toMillis(LocalDateTime.of(2025, 5, 24, 6, 0))
        val day = DayResolver.resolve(ts, 6, 0, zone)
        assertEquals("2025-05-24", day)
    }

    @Test fun `resolve change time with minutes`() {
        // Tageswechsel um 04:30 → 04:29 ist Vortag, 04:30 ist heute
        val tsBefore = toMillis(LocalDateTime.of(2025, 5, 24, 4, 29))
        val tsAt     = toMillis(LocalDateTime.of(2025, 5, 24, 4, 30))
        assertEquals("2025-05-23", DayResolver.resolve(tsBefore, 4, 30, zone))
        assertEquals("2025-05-24", DayResolver.resolve(tsAt,     4, 30, zone))
    }

    // ── Monatsgrenzen ──────────────────────────────────────────────────────────

    @Test fun `resolve maps midnight Jan 1 to Dec 31`() {
        val ts  = toMillis(LocalDateTime.of(2025, 1, 1, 0, 0))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2024-12-31", day)
    }

    @Test fun `resolve maps midnight March 1 to Feb 28 in non-leap year`() {
        val ts  = toMillis(LocalDateTime.of(2025, 3, 1, 0, 0))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2025-02-28", day)
    }

    @Test fun `resolve maps midnight March 1 to Feb 29 in leap year`() {
        val ts  = toMillis(LocalDateTime.of(2024, 3, 1, 0, 0))
        val day = DayResolver.resolve(ts, 4, 0, zone)
        assertEquals("2024-02-29", day)
    }

    // ── parseDate & formatDate ──────────────────────────────────────────────

    @Test fun `parseDate round trips formatDate`() {
        val original = LocalDate.of(2025, 5, 24)
        val str      = DayResolver.formatDate(original)
        val parsed   = DayResolver.parseDate(str)
        assertEquals(original, parsed)
    }

    @Test fun `parseDate format is ISO`() {
        val str = DayResolver.formatDate(LocalDate.of(2025, 5, 7))
        assertEquals("2025-05-07", str)  // No single-digit months/days without a leading zero
    }

    // ── computeCurrentAbstinence ────────────────────────────────────────────

    @Test fun `computeCurrentAbstinence empty list returns 0`() {
        assertEquals(0, DayResolver.computeCurrentAbstinence(emptyList(), "2025-05-24"))
    }

    @Test fun `computeCurrentAbstinence last date is today returns 0`() {
        // Heute getrunken → aktuelle Abstinenz = 0
        assertEquals(0, DayResolver.computeCurrentAbstinence(listOf("2025-05-22", "2025-05-24"), "2025-05-24"))
    }

    @Test fun `computeCurrentAbstinence last drink 3 days ago counts 2 completed dry days`() {
        // Last drink 2025-05-21, today 2025-05-24. Completed dry days: 05-22, 05-23.
        // Today (05-24) is in progress and the drink day itself are both excluded → 2.
        assertEquals(2, DayResolver.computeCurrentAbstinence(listOf("2025-05-20", "2025-05-21"), "2025-05-24"))
    }

    @Test fun `computeCurrentAbstinence last drink two days ago counts 1`() {
        // Regression for the reported bug: drink on T-2, none since, today T → exactly
        // one completed dry day (T-1). Previously this returned 2.
        assertEquals(1, DayResolver.computeCurrentAbstinence(listOf("2026-01-10"), "2026-01-12"))
    }

    @Test fun `computeCurrentAbstinence drank yesterday counts 0 today not over`() {
        // Last drink 2025-05-23, today 2025-05-24: no completed dry day yet → 0.
        assertEquals(0, DayResolver.computeCurrentAbstinence(listOf("2025-05-23"), "2025-05-24"))
    }

    // ── computeLongestAbstinence ────────────────────────────────────────────

    @Test fun `computeLongestAbstinence empty list returns 0`() {
        assertEquals(0, DayResolver.computeLongestAbstinence(emptyList()))
    }

    @Test fun `computeLongestAbstinence single entry returns 0`() {
        assertEquals(0, DayResolver.computeLongestAbstinence(listOf("2025-05-24")))
    }

    @Test fun `computeLongestAbstinence consecutive days returns 0`() {
        // No gap between consecutive days
        assertEquals(0, DayResolver.computeLongestAbstinence(listOf("2025-05-22", "2025-05-23", "2025-05-24")))
    }

    @Test fun `computeLongestAbstinence finds longest gap`() {
        // Gaps: 2, 5, 1 → longest = 5
        val dates = listOf("2025-05-01", "2025-05-04", "2025-05-10", "2025-05-12")
        assertEquals(5, DayResolver.computeLongestAbstinence(dates))
    }

    @Test fun `computeLongestAbstinence single gap`() {
        assertEquals(4, DayResolver.computeLongestAbstinence(listOf("2025-05-01", "2025-05-06")))
    }

    // ── computeCurrentAbstinence mit statsFrom ────────────────────────────────

    @Test fun `computeCurrentAbstinence empty list with statsFrom returns days since statsFrom`() {
        // No entries, statsFrom = Jan 1, today = Jan 10 → 9 days
        assertEquals(9, DayResolver.computeCurrentAbstinence(emptyList(), "2025-01-10", "2025-01-01"))
    }

    @Test fun `computeCurrentAbstinence empty list statsFrom equals today returns 0`() {
        assertEquals(0, DayResolver.computeCurrentAbstinence(emptyList(), "2025-05-24", "2025-05-24"))
    }

    @Test fun `computeCurrentAbstinence empty list statsFrom in future returns 0`() {
        assertEquals(0, DayResolver.computeCurrentAbstinence(emptyList(), "2025-05-24", "2025-05-30"))
    }

    @Test fun `computeCurrentAbstinence with entries statsFrom is ignored`() {
        // Last entry May 21, today May 24 → completed dry days May 22, May 23 = 2
        // (statsFrom plays no role once drink entries exist).
        assertEquals(2, DayResolver.computeCurrentAbstinence(listOf("2025-05-21"), "2025-05-24", "2025-01-01"))
    }

    // ── computeLongestAbstinence mit today und statsFrom ─────────────────────

    @Test fun `computeLongestAbstinence empty list with statsFrom and today`() {
        // No entries: longest = days from statsFrom to today = 9
        assertEquals(9, DayResolver.computeLongestAbstinence(emptyList(), "2025-01-10", "2025-01-01"))
    }

    @Test fun `computeLongestAbstinence tail gap included`() {
        // Last entry May 1, today May 10 → completed dry days May 2..May 9 = 8
        // (last drink day and in-progress today both excluded).
        assertEquals(8, DayResolver.computeLongestAbstinence(listOf("2025-05-01"), "2025-05-10"))
    }

    @Test fun `computeLongestAbstinence tail gap two days ago counts 1`() {
        // Mirror of the reported scenario for the tail gap: drink on T-2, today T → 1.
        assertEquals(1, DayResolver.computeLongestAbstinence(listOf("2026-01-10"), "2026-01-12"))
    }

    @Test fun `computeLongestAbstinence initial gap dominates`() {
        // statsFrom Jan 1, first entry May 1 → initial gap = 120 days (Jan 31 + Feb 28 + Mar 31 + Apr 30)
        // Simpler example: statsFrom May 1, first entry May 11, today May 12
        // Initial gap = 10 (May 1..May 10), tail gap = 0 → longest = 10
        assertEquals(10, DayResolver.computeLongestAbstinence(listOf("2025-05-11"), "2025-05-12", "2025-05-01"))
    }

    @Test fun `computeLongestAbstinence backward compat no today no statsFrom`() {
        // Old call signature (only sortedDates) must still work
        val dates = listOf("2025-05-01", "2025-05-04", "2025-05-10", "2025-05-12")
        assertEquals(5, DayResolver.computeLongestAbstinence(dates))
    }

    @Test fun `computeCurrentAbstinence future drink date returns 0`() {
        // A drink date strictly after today (e.g. from a corrupted import or timezone edge case)
        // must return 0, not a negative number or crash.
        // The guard `sortedDates.last() >= today` covers both today and the future.
        val today = "2025-06-01"
        val futureDrink = "2025-06-02"
        assertEquals(0, DayResolver.computeCurrentAbstinence(listOf(futureDrink), today))
    }
}
