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
package de.godisch.potillus.data.repository

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit
import kotlin.math.abs

// =============================================================================
// LegacyDayRepair.kt – rescuing calendar entries written before v0.85.0
// =============================================================================
//
// THE DAMAGE
//   Until v0.85.0, adding an entry from the calendar stored the instant of the
//   day it was BOOKED ON, not of the day it was booked FOR. The stored
//   `logicalDate` said "12 March"; the timestamp said "26 March, 19:04, the
//   evening I typed it in". The two contradicted each other, and the app
//   believed the date.
//
//   Once the logical day is DERIVED from the timestamp, believing the date is no
//   longer an option. Left alone, such a row would not shift by a day — it would
//   jump to the evening it was typed, weeks away, in every screen at once. So
//   these rows are rebuilt from the intention the user actually expressed.
//
// HOW THEY ARE RECOGNISED
//   By a gap of TWO OR MORE calendar days between `logicalDate` and the calendar
//   day of the reading. Nothing that works correctly can produce that gap: a
//   day-change boundary moves an entry by at most one day, so does a daylight
//   saving switch, and so does the Today screen's own placement rule. Two days
//   means the row came from the old calendar path.
//
//   ONE KNOWN MISFIRE, ACCEPTED. A pre-0.86.0 row whose reading is before the
//   boundary already sits on calendar day D+1 with `logicalDate` D. If schema 4
//   backfilled its offset from a zone that lies Δ hours EAST of where it was
//   written, the reading moves by Δ and reaches D+2 once Δ ≥ 24 h − t, with t
//   the time of day — from twenty hours east at a 04:00 boundary. Such a row is
//   then repaired although it needs no repair, and the repair does no harm: it
//   rebuilds the instant from `logicalDate` and the reading, which restores the
//   very logical day the row already had. The alternative, a three-day
//   threshold, would abandon genuine calendar entries booked for the day before
//   yesterday, which are common.
//
// WHY THIS DOES NOT USE `DayResolver`
//   Reading a zone's historical offset exists in `DayResolver` too, and placing a
//   wall-clock time on a logical day did until the entry sheet grew a date field.
//   Both are spelled out here on purpose. A repair runs ONCE per device, and a device
//   that has already run it must not be reinterpreted by a later change to the
//   domain; a device that has not yet run it must compute the same thing as one
//   that ran it a year ago. Binding the repair to a moving definition would give
//   two phones with the same history two different answers. `DayResolver.resolve`
//   itself is not among the copies: nothing here resolves a day.
// =============================================================================

/**
 * A wall-clock reading: the instant, and the frame it is to be read in.
 *
 * The pair the repair rewrites. Both members move together — changing the
 * instant without re-reading the offset would leave the row claiming a frame it
 * was never in.
 */
data class RepairedReading(
    val timestampMillis: Long,
    val utcOffsetSeconds: Int,
)

/**
 * Rebuilds the timestamps of entries whose stored day contradicts their reading.
 *
 * Stateless; the zone is passed in so a test can pin it.
 */
object LegacyDayRepair {

    /** The canonical `"YYYY-MM-DD"` spelling, as everything else in the app uses. */
    private val DATE_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    /** A gap of this many calendar days or more marks a pre-0.85.0 calendar entry. */
    private const val SUSPICIOUS_DAY_GAP = 2L

    /**
     * The corrected reading for one row, or `null` when the row is sound.
     *
     * `null` is the answer for the overwhelming majority of rows and means "do
     * not touch this one". Returning the unchanged reading instead would make
     * every caller rewrite every row, and a rewrite that changes nothing still
     * costs a write and still bumps the row through every observing query.
     *
     * @param timestampMillis  The instant as stored.
     * @param utcOffsetSeconds The frame as stored (backfilled by `MIGRATION_3_4`
     *                         for rows that predate the column).
     * @param logicalDate      The day the row is filed under — for a damaged row,
     *                         the only surviving record of what the user meant.
     * @param changeHour       Hour of the day-change boundary to rebuild under.
     * @param changeMinute     Minute of that boundary.
     * @param zoneId           Zone the rebuilt instant is read in. The device
     *                         zone in production: the same assumption logging an
     *                         entry makes, namely that the phone is where its
     *                         owner is.
     */
    fun repair(
        timestampMillis: Long,
        utcOffsetSeconds: Int,
        logicalDate: String,
        changeHour: Int,
        changeMinute: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): RepairedReading? {
        val filedUnder = parseOrNull(logicalDate) ?: return null
        val reading = LocalDateTime.ofInstant(
            Instant.ofEpochMilli(timestampMillis),
            ZoneOffset.ofTotalSeconds(utcOffsetSeconds),
        )
        val gap = abs(ChronoUnit.DAYS.between(filedUnder, reading.toLocalDate()))
        if (gap < SUSPICIOUS_DAY_GAP) return null

        // The TIME survives, the DATE is replaced. For Android the time is known
        // to be the one the user typed: the entry dialog of that era built its
        // timestamp from `LocalDateTime.now()` with the hour and minute
        // substituted, so only the date came from the day of typing. (iOS
        // recorded the moment of typing instead — see the note in its twin.)
        val rebuilt = instantOnLogicalDate(
            logicalDate = filedUnder,
            hour = reading.hour,
            minute = reading.minute,
            changeHour = changeHour,
            changeMinute = changeMinute,
            zoneId = zoneId,
        )
        return RepairedReading(
            timestampMillis = rebuilt,
            // Re-read, not carried over: the row is being moved to another date,
            // and the offset of the old instant says nothing about the new one.
            // This is the rule a date change follows everywhere in the app.
            utcOffsetSeconds = offsetAt(rebuilt, zoneId),
        )
    }

    /**
     * The instant a wall-clock time falls on, on a given LOGICAL day.
     *
     * A logical day runs from one boundary to the next, so a time before the
     * boundary belongs to the following CALENDAR day: with a 04:00 boundary,
     * 01:00 on the logical 30th is 01:00 on the calendar 31st.
     *
     * `DayResolver` carried a public function of the same shape until the entry
     * sheet grew a date field and stopped needing one. The copy here was never
     * that function and outlives it, for the reason in the file header.
     *
     * A time that does not exist in the zone (the spring-forward gap) resolves to
     * what the zone offers instead, which is `ZonedDateTime`'s own behaviour.
     */
    private fun instantOnLogicalDate(
        logicalDate: LocalDate,
        hour: Int,
        minute: Int,
        changeHour: Int,
        changeMinute: Int,
        zoneId: ZoneId,
    ): Long {
        val isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)
        val calendarDay = if (isBeforeChangeTime) logicalDate.plusDays(1) else logicalDate
        return calendarDay.atTime(hour, minute).atZone(zoneId).toInstant().toEpochMilli()
    }

    /** The offset [zoneId] was at [timestampMillis], through its historical rules. */
    private fun offsetAt(timestampMillis: Long, zoneId: ZoneId): Int =
        zoneId.rules.getOffset(Instant.ofEpochMilli(timestampMillis)).totalSeconds

    /**
     * The stored date, or `null` when it is not a date at all.
     *
     * A row whose `logicalDate` cannot be parsed is left alone rather than
     * guessed at. The backup importer rejects such a value at its own gate, and
     * the column has been written by the app itself for every other row, so this
     * is a guard and not a code path with a user behind it.
     */
    private fun parseOrNull(logicalDate: String): LocalDate? = try {
        LocalDate.parse(logicalDate, DATE_FORMATTER)
    } catch (_: DateTimeParseException) {
        null
    }
}
