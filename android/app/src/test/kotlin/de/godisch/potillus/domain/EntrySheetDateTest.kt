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
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The entry sheet's date field, as arithmetic.
 *
 * These are the cases a UI test reaches worst — the small hours, a day-change
 * time after the sheet's default hour, a tapped day that happens to be today —
 * which is why the rule lives in [EntrySheetDate] rather than in the dialog.
 * `EntrySheetDateTests.swift` is the twin.
 */
class EntrySheetDateTest {

    private fun at(text: String): LocalDateTime = LocalDateTime.parse(text)

    private fun date(text: String): LocalDate = LocalDate.parse(text)

    // ── The Today screen and the drinks list ─────────────────────────────────

    @Test fun `the today sheet opens on the present moment`() {
        val reading = EntrySheetDate.initial(
            origin = EntryDayOrigin.NOW,
            logicalDay = "2026-03-10",
            changeHour = 4,
            changeMinute = 0,
            now = at("2026-03-11T06:00"),
        )
        assertEquals(EntryReading(date("2026-03-11"), 6, 0), reading)
    }

    @Test fun `a time later than now belongs to yesterday`() {
        // It is 06:00 and the user types 02:00: four hours ago, not twenty hours
        // ahead. The gap this closes is the whole reason the rule exists.
        assertEquals(
            date("2026-03-11"),
            EntrySheetDate.followUp(EntryDayOrigin.NOW, "2026-03-10", 4, 0, 2, 0, at("2026-03-11T06:00")),
        )
        assertEquals(
            date("2026-03-10"),
            EntrySheetDate.followUp(EntryDayOrigin.NOW, "2026-03-10", 4, 0, 23, 0, at("2026-03-11T06:00")),
        )
    }

    @Test fun `the present minute counts as today, the next one as yesterday`() {
        assertEquals(
            date("2026-03-11"),
            EntrySheetDate.followUp(EntryDayOrigin.NOW, "2026-03-10", 4, 0, 6, 0, at("2026-03-11T06:00")),
        )
        assertEquals(
            date("2026-03-10"),
            EntrySheetDate.followUp(EntryDayOrigin.NOW, "2026-03-10", 4, 0, 6, 1, at("2026-03-11T06:00")),
        )
    }

    @Test fun `the mirrored case, an evening time typed after midnight`() {
        // 01:00, the user adds the beer they had at 23:00. Two hours back, not
        // twenty-one forward — which is what taking the running calendar day
        // would have made of it.
        assertEquals(
            date("2026-03-10"),
            EntrySheetDate.followUp(EntryDayOrigin.NOW, "2026-03-10", 4, 0, 23, 0, at("2026-03-11T01:00")),
        )
    }

    // ── The calendar ─────────────────────────────────────────────────────────

    @Test fun `a tapped day opens in the evening`() {
        val reading = EntrySheetDate.initial(
            origin = EntryDayOrigin.CALENDAR,
            logicalDay = "2026-03-10",
            changeHour = 4,
            changeMinute = 0,
            now = at("2026-03-15T12:00"),
        )
        assertEquals(EntryReading(date("2026-03-10"), 20, 0), reading)
    }

    @Test fun `a day-change time after the default hour puts the default on the next day`() {
        // With a 21:00 boundary, 20:00 belongs to the day before — so the sheet
        // offers the calendar 11th to keep the entry on the logical 10th. The
        // default hour is taste; this is what makes it safe for every setting.
        val reading = EntrySheetDate.initial(
            origin = EntryDayOrigin.CALENDAR,
            logicalDay = "2026-03-10",
            changeHour = 21,
            changeMinute = 0,
            now = at("2026-03-15T12:00"),
        )
        assertEquals(EntryReading(date("2026-03-11"), 20, 0), reading)
    }

    @Test fun `tapping today opens on the present moment`() {
        // Otherwise tapping today in the calendar would jump the clock to the
        // evening, which is not what someone logging a drink now means.
        val reading = EntrySheetDate.initial(
            origin = EntryDayOrigin.CALENDAR,
            logicalDay = "2026-03-10",
            changeHour = 4,
            changeMinute = 0,
            now = at("2026-03-10T12:00"),
        )
        assertEquals(EntryReading(date("2026-03-10"), 12, 0), reading)
    }

    @Test fun `the calendar keeps the entry on the tapped day whatever the time`() {
        assertEquals(
            date("2026-03-10"),
            EntrySheetDate.followUp(EntryDayOrigin.CALENDAR, "2026-03-10", 4, 0, 23, 0, at("2026-03-15T12:00")),
        )
        // Before the boundary, so the FOLLOWING calendar day keeps it on the 10th.
        assertEquals(
            date("2026-03-11"),
            EntrySheetDate.followUp(EntryDayOrigin.CALENDAR, "2026-03-10", 4, 0, 1, 0, at("2026-03-15T12:00")),
        )
        // Exactly on the boundary is not before it.
        assertEquals(
            date("2026-03-10"),
            EntrySheetDate.followUp(EntryDayOrigin.CALENDAR, "2026-03-10", 4, 0, 4, 0, at("2026-03-15T12:00")),
        )
    }

    // ── Editing ──────────────────────────────────────────────────────────────

    @Test fun `editing follows nothing`() {
        assertNull(
            EntrySheetDate.followUp(EntryDayOrigin.EDIT, "2026-03-10", 4, 0, 2, 0, at("2026-03-11T06:00")),
        )
    }

    // ── Guards ───────────────────────────────────────────────────────────────

    @Test fun `a day that is not a canonical date falls back to the present moment`() {
        assertEquals(
            EntryReading(date("2026-03-15"), 12, 0),
            EntrySheetDate.initial(EntryDayOrigin.CALENDAR, "2026-3-10", 4, 0, at("2026-03-15T12:00")),
        )
        assertNull(
            EntrySheetDate.followUp(EntryDayOrigin.CALENDAR, "2026-3-10", 4, 0, 1, 0, at("2026-03-15T12:00")),
        )
    }

    // ── Composing the instant ─────────────────────────────────────────────────

    private val berlinWinter = 3600
    private val tokyo: ZoneId = ZoneId.of("Asia/Tokyo")

    @Test fun `a correction inside a recorded reading stays in its frame`() {
        // A Berlin entry (+01:00) edited from Tokyo (+09:00), date left alone:
        // 22:00 is still 22:00 Berlin time, so the instant is 21:00Z and the
        // offset is the recorded one. Composing in the device zone here would
        // have put the row at 13:00Z, reading 14:00 in its own frame.
        val composed = EntrySheetDate.compose(
            reading = EntryReading(date("2026-01-15"), 22, 0),
            recordedOffsetSeconds = berlinWinter,
            zoneId = tokyo,
        )
        assertEquals(1_768_510_800_000L, composed.timestampMillis) // 2026-01-15T21:00Z
        assertEquals(berlinWinter, composed.utcOffsetSeconds)
    }

    @Test fun `a new reading is taken in the device zone`() {
        // Logging, or moving an entry to another date: the frame is where the
        // user is now, and the offset is the one that zone had at the instant.
        val composed = EntrySheetDate.compose(
            reading = EntryReading(date("2026-01-15"), 22, 0),
            recordedOffsetSeconds = null,
            zoneId = tokyo,
        )
        assertEquals(1_768_482_000_000L, composed.timestampMillis) // 2026-01-15T13:00Z
        assertEquals(9 * 3600, composed.utcOffsetSeconds)
    }

    @Test fun `a new reading records the offset of its own date, not of today`() {
        // The zone's historical rules answer for the reading's instant: a winter
        // date composed in Berlin gets +01:00 even if the test runs in summer.
        val composed = EntrySheetDate.compose(
            reading = EntryReading(date("2026-01-15"), 22, 0),
            recordedOffsetSeconds = null,
            zoneId = ZoneId.of("Europe/Berlin"),
        )
        assertEquals(berlinWinter, composed.utcOffsetSeconds)
        assertEquals(1_768_510_800_000L, composed.timestampMillis)
    }
}
