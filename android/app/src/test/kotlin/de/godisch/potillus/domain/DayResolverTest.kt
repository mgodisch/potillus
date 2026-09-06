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

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

class DayResolverTest {

    private val zone = ZoneId.of("Europe/Berlin")

    // Helper: LocalDateTime → Unix milliseconds in a fixed time zone
    private fun toMillis(ldt: LocalDateTime): Long = ldt.atZone(zone).toInstant().toEpochMilli()

    // The offset the zone was at that instant — the reading an entry would
    // record with it. `resolve` looks nothing up on its own any more.
    private fun offsetAt(millis: Long): Int = DayResolver.utcOffsetSeconds(millis, zone)

    // ── Base case: after the day change ─────────────────────────────────────

    @Test fun `resolve 04h01 stays same day`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 4, 1))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-24", day)
    }

    @Test fun `resolve 12h00 stays same day`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 12, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-24", day)
    }

    @Test fun `resolve 23h59 stays same day`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 23, 59))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-24", day)
    }

    // ── Before the day change → previous day ────────────────────────────────

    @Test fun `resolve 03h59 maps to previous day`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 3, 59))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-23", day)
    }

    @Test fun `resolve 02h30 maps to previous day`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 2, 30))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-23", day)
    }

    @Test fun `resolve 00h00 (midnight) maps to previous day`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 0, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-23", day)
    }

    // ── Exactly on the day-change boundary ──────────────────────────────────

    @Test fun `resolve exactly at change time stays same day`() {
        // 04:00 ist NICHT vor 04:00, also gleicher Tag
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 4, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-05-24", day)
    }

    // ── A day change the user set ───────────────────────────────────────────

    @Test fun `resolve custom change time 06h00`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 5, 59))
        val day = DayResolver.resolve(ts, offsetAt(ts), 6, 0)
        assertEquals("2025-05-23", day)
    }

    @Test fun `resolve custom change time 06h00 after`() {
        val ts = toMillis(LocalDateTime.of(2025, 5, 24, 6, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 6, 0)
        assertEquals("2025-05-24", day)
    }

    @Test fun `resolve change time with minutes`() {
        // Day change at 04:30 → 04:29 is the previous day, 04:30 is today
        val tsBefore = toMillis(LocalDateTime.of(2025, 5, 24, 4, 29))
        val tsAt = toMillis(LocalDateTime.of(2025, 5, 24, 4, 30))
        assertEquals("2025-05-23", DayResolver.resolve(tsBefore, offsetAt(tsBefore), 4, 30))
        assertEquals("2025-05-24", DayResolver.resolve(tsAt, offsetAt(tsAt), 4, 30))
    }

    // ── Month boundaries ────────────────────────────────────────────────────

    @Test fun `resolve maps midnight Jan 1 to Dec 31`() {
        val ts = toMillis(LocalDateTime.of(2025, 1, 1, 0, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2024-12-31", day)
    }

    @Test fun `resolve maps midnight March 1 to Feb 28 in non-leap year`() {
        val ts = toMillis(LocalDateTime.of(2025, 3, 1, 0, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2025-02-28", day)
    }

    @Test fun `resolve maps midnight March 1 to Feb 29 in leap year`() {
        val ts = toMillis(LocalDateTime.of(2024, 3, 1, 0, 0))
        val day = DayResolver.resolve(ts, offsetAt(ts), 4, 0)
        assertEquals("2024-02-29", day)
    }

    // ── The note about a differing day ───────────────────────────────────────

    /**
     * The same reading answers differently depending on the day the sheet was
     * opened on: 03:00 on the 11th counts toward the 10th, so a sheet opened on
     * the 11th has something to say and one opened on the 10th does not.
     */
    @Test fun `logicalDayDiffers compares the reading against the sheet's day`() {
        val ts = toMillis(LocalDateTime.of(2026, 3, 11, 3, 0))
        assertTrue(DayResolver.logicalDayDiffers(ts, offsetAt(ts), 4, 0, "2026-03-11"))
        assertFalse(DayResolver.logicalDayDiffers(ts, offsetAt(ts), 4, 0, "2026-03-10"))
    }

    // ── parseDate & formatDate ──────────────────────────────────────────────

    @Test fun `parseDate round trips formatDate`() {
        val original = LocalDate.of(2025, 5, 24)
        val str = DayResolver.formatDate(original)
        val parsed = DayResolver.parseDate(str)
        assertEquals(original, parsed)
    }

    @Test fun `parseDate format is ISO`() {
        val str = DayResolver.formatDate(LocalDate.of(2025, 5, 7))
        assertEquals("2025-05-07", str) // No single-digit months/days without a leading zero
    }

    // ── computeCurrentAbstinence ────────────────────────────────────────────

    @Test fun `computeCurrentAbstinence empty list returns 0`() {
        assertEquals(0, DayResolver.computeCurrentAbstinence(emptyList(), "2025-05-24"))
    }

    @Test fun `computeCurrentAbstinence last date is today returns 0`() {
        // Drank today → the current abstinence is 0
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

    // ── computeCurrentAbstinence with statsFrom ─────────────────────────────

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

    @Test fun `computeCurrentAbstinence a floor before the entries changes nothing`() {
        // Last entry May 21, today May 24 → completed dry days May 22, May 23 = 2.
        assertEquals(2, DayResolver.computeCurrentAbstinence(listOf("2025-05-21"), "2025-05-24", "2025-01-01"))
    }

    @Test fun `computeCurrentAbstinence drops drink days before the floor`() {
        // The April drink lies before the May 1 floor and is invisible: the streak
        // then runs from the floor, May 1..May 9 = 9 completed dry days. Without
        // the floor applied inside the function this read 8 (from the April drink).
        assertEquals(9, DayResolver.computeCurrentAbstinence(listOf("2025-04-01"), "2025-05-10", "2025-05-01"))
        assertEquals(
            2,
            DayResolver.computeCurrentAbstinence(listOf("2025-04-01", "2025-05-07"), "2025-05-10", "2025-05-01"),
        )
    }

    @Test fun `computeLongestAbstinence does not open a gap across the floor`() {
        // Floored to [May 7]: head gap May 1..May 6 = 6, tail May 8..May 9 = 2 → 6.
        // Unfiltered, the April 1 → May 7 gap would have read 35.
        assertEquals(
            6,
            DayResolver.computeLongestAbstinence(listOf("2025-04-01", "2025-05-07"), "2025-05-10", "2025-05-01"),
        )
    }

    // ── computeLongestAbstinence with today and statsFrom ───────────────────

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

    // ── effectivePeriodDays ───────────────────────────────────────────────────

    @Test fun `effectivePeriodDays excludes the in-progress day unless it is a drink day`() {
        // 1 June … 24 June. 23 days are completed (1st..23rd); today is the 24th.
        assertEquals(23, DayResolver.effectivePeriodDays("2026-06-01", "2026-06-24", todayIsDrinkDay = false))
        // A drink logged today resolves it to a drink day, so it joins the period.
        assertEquals(24, DayResolver.effectivePeriodDays("2026-06-01", "2026-06-24", todayIsDrinkDay = true))
    }

    @Test fun `effectivePeriodDays on the first day is 0 dry or 1 after a drink`() {
        // from == today: no completed days yet, so the period is empty until the
        // first drink resolves today into the period.
        assertEquals(0, DayResolver.effectivePeriodDays("2026-06-01", "2026-06-01", todayIsDrinkDay = false))
        assertEquals(1, DayResolver.effectivePeriodDays("2026-06-01", "2026-06-01", todayIsDrinkDay = true))
    }

    @Test fun `effectivePeriodDays returns 0 for an inverted range`() {
        assertEquals(0, DayResolver.effectivePeriodDays("2026-06-10", "2026-06-01", todayIsDrinkDay = true))
    }
    // ── The recorded local frame ─────────────────────────────────────────────

    @Test fun `utcOffsetSeconds reads the offset in force at that instant`() {
        val berlin = ZoneId.of("Europe/Berlin")
        // 2026-01-15T12:00Z is winter in Berlin: +01:00.
        val winter = Instant.parse("2026-01-15T12:00:00Z").toEpochMilli()
        // 2026-07-15T12:00Z is summer: +02:00.
        val summer = Instant.parse("2026-07-15T12:00:00Z").toEpochMilli()
        assertEquals(3600, DayResolver.utcOffsetSeconds(winter, berlin))
        assertEquals(7200, DayResolver.utcOffsetSeconds(summer, berlin))
    }

    @Test fun `localDateTime reads the entry in its recorded frame`() {
        // 22:30 in Berlin in January, read from a device that has since moved to
        // New York. The recorded frame still says 22:30 — and there is no zone to
        // pass in any more, which is what makes that unconditional.
        val instant = Instant.parse("2026-01-15T21:30:00Z").toEpochMilli()
        val local = DayResolver.localDateTime(instant, 3600)
        assertEquals(22, local.hour)
        assertEquals(30, local.minute)
        assertEquals(15, local.dayOfMonth)
    }

    @Test fun `localDateTime reads a frame of UTC as UTC`() {
        // Zero is an offset like any other, not "nothing recorded". The nullable
        // column that made the distinction is gone: schema 4 gave every row a
        // frame, and with it went the fallback that read an unset one in the
        // device zone.
        val instant = Instant.parse("2026-01-15T21:30:00Z").toEpochMilli()
        val local = DayResolver.localDateTime(instant, 0)
        assertEquals(21, local.hour)
        assertEquals(30, local.minute)
    }

    @Test fun `localDateTime survives a daylight-saving switch`() {
        // Logged at 02:30 Berlin summer time on the day before the autumn switch,
        // read after it. The recorded +02:00 keeps the reading at 02:30; deriving
        // the offset from the zone at READ time would have moved it to 01:30.
        val instant = Instant.parse("2026-10-24T00:30:00Z").toEpochMilli()
        val recorded = DayResolver.localDateTime(instant, 7200)
        assertEquals(2, recorded.hour)
        assertEquals(30, recorded.minute)
    }

    // ── today() and the pinned clock ─────────────────────────────────────────

    @Test fun `today reads the instant and the offset from the same clock`() {
        // 2026-06-10T01:00Z is 10:00 on the 10th in Tokyo and 21:00 on the 9th
        // in New York. With a 04:00 boundary the logical day is the 10th in the
        // one zone and the 9th in the other, whatever zone this JVM runs in —
        // which is the point: until the v0.86.0 QA round the offset came from
        // the process default while the instant came from the pinned clock.
        val instant = Instant.parse("2026-06-10T01:00:00Z")
        try {
            DayResolver.clockOverride = java.time.Clock.fixed(instant, ZoneId.of("Asia/Tokyo"))
            assertEquals("2026-06-10", DayResolver.today(4, 0))
            DayResolver.clockOverride = java.time.Clock.fixed(instant, ZoneId.of("America/New_York"))
            assertEquals("2026-06-09", DayResolver.today(4, 0))
        } finally {
            DayResolver.clockOverride = null // never leak the pin to other tests
        }
    }
}
