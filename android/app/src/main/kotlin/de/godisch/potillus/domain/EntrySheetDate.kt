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
import java.time.LocalDateTime

// =============================================================================
// EntrySheetDate.kt – what the entry sheet fills its date field with
// =============================================================================
//
// THE PROBLEM THIS SOLVES
//   The sheet shows a DATE and a TIME, both editable. The user almost always
//   touches only the time — they are logging a drink, not filing a record — so
//   the date has to follow along, and it has to follow the way the user means it.
//   Which way that is depends on where the sheet was opened:
//
//     TODAY SCREEN / DRINKS LIST. "02:00" typed at 06:00 means four hours ago,
//     not twenty hours from now. The rule is the most recent past: a time later
//     than the current one belongs to yesterday.
//
//     CALENDAR. The user tapped a day and is recording a drink they had THEN.
//     The rule is to keep the entry on that logical day, which for a time before
//     the day-change boundary means the FOLLOWING calendar day: 01:00 on the
//     logical 10th is 01:00 on the calendar 11th.
//
//     EDITING. Nothing follows. The date and the time are the entry's, and
//     moving one must not move the other behind the user's back.
//
// AND WHY IT STOPS
//   The moment the user picks a date themselves, the follow-up falls silent for
//   the rest of the sheet. Otherwise they could not hold a date they had just
//   chosen: the next turn of the time wheel would take it away again. The sheet
//   tracks that; this file only says what to fill in while it is still filling.
//
// WHY IT IS A PURE FUNCTION AND NOT SHEET CODE
//   Everything here is arithmetic over a date, a time and a boundary, and the
//   cases that matter — the small hours, a boundary after 20:00, a calendar day
//   that happens to be today — are the ones a UI test reaches worst. Kept out of
//   the sheet, they are ordinary unit tests. `EntrySheetDate.swift` is the twin;
//   the two are held together by their tests rather than by a shared vector,
//   because nothing outside the sheet depends on the answer.
// =============================================================================

/** Where an entry sheet was opened, which decides how its date follows the time. */
enum class EntryDayOrigin {
    /** The Today screen or the drinks list: the drink is being logged as it happens. */
    NOW,

    /** A tapped calendar day: the drink belongs to that logical day. */
    CALENDAR,

    /** An existing entry: its own reading, and nothing follows. */
    EDIT,
}

/** A wall-clock reading as the sheet holds it: a calendar date and a time of day. */
data class EntryReading(val date: LocalDate, val hour: Int, val minute: Int)

/** The date and time an entry sheet opens with, and how the date follows the time. */
object EntrySheetDate {

    /** The time a calendar sheet offers when the tapped day is not today. */
    private const val CALENDAR_DEFAULT_HOUR = 20

    /**
     * The reading a sheet opens with.
     *
     * NOW: the present moment, which is what someone logging a drink means.
     *
     * CALENDAR: the tapped day at 20:00 — an evening hour, and one that is safe
     * for every day-change time the user can set, including one after 20:00,
     * because [placeOnLogicalDay] puts it on the following calendar day then.
     * When the tapped day IS the running logical day the sheet opens on the
     * present moment instead, so tapping today in the calendar behaves like the
     * Today screen rather than jumping the clock to the evening.
     *
     * EDIT is not answered here: an edited entry opens on its own recorded
     * reading, which the sheet has and this function does not.
     *
     * @param origin       Where the sheet was opened.
     * @param logicalDay   The logical day the sheet was opened on.
     * @param changeHour   Hour of the day-change boundary (0–23).
     * @param changeMinute Minute of that boundary (0–59).
     * @param now          The current local date and time.
     */
    fun initial(
        origin: EntryDayOrigin,
        logicalDay: String,
        changeHour: Int,
        changeMinute: Int,
        now: LocalDateTime,
    ): EntryReading {
        val here = EntryReading(now.toLocalDate(), now.hour, now.minute)
        if (origin != EntryDayOrigin.CALENDAR) return here

        val day = parseOrNull(logicalDay) ?: return here
        val runningDay = DayResolver.today(changeHour, changeMinute)
        if (logicalDay == runningDay) return here

        return EntryReading(
            date = placeOnLogicalDay(day, CALENDAR_DEFAULT_HOUR, 0, changeHour, changeMinute),
            hour = CALENDAR_DEFAULT_HOUR,
            minute = 0,
        )
    }

    /**
     * The date to move to after the user changed only the TIME, or `null` when
     * nothing follows.
     *
     * `null` for [EntryDayOrigin.EDIT], and for a date the sheet cannot parse.
     * The caller keeps the date it has in that case.
     *
     * @param hour   The time of day the user has now set.
     * @param minute The same.
     * @param now    The current local date and time; only [EntryDayOrigin.NOW]
     *               reads it.
     */
    fun followUp(
        origin: EntryDayOrigin,
        logicalDay: String,
        changeHour: Int,
        changeMinute: Int,
        hour: Int,
        minute: Int,
        now: LocalDateTime,
    ): LocalDate? = when (origin) {
        EntryDayOrigin.EDIT -> null

        // The most recent past: a time later than the present one has not
        // happened today, so it happened yesterday. Equality counts as today —
        // "now" is a moment that has just passed, not one still to come.
        EntryDayOrigin.NOW ->
            if (hour > now.hour || (hour == now.hour && minute > now.minute)) {
                now.toLocalDate().minusDays(1)
            } else {
                now.toLocalDate()
            }

        // Stay on the day the user tapped, whatever time they choose.
        EntryDayOrigin.CALENDAR ->
            parseOrNull(logicalDay)?.let { placeOnLogicalDay(it, hour, minute, changeHour, changeMinute) }
    }

    /**
     * The CALENDAR day a wall-clock time falls on when it is to belong to the
     * LOGICAL day [day].
     *
     * A logical day runs from one boundary to the next, so a time before the
     * boundary sits on the following calendar day. This is the same mapping
     * `DayResolver.resolve` performs in reverse; it is spelled out here rather
     * than shared because `resolve` works on an instant and an offset, and the
     * sheet has neither until it has composed one.
     */
    private fun placeOnLogicalDay(
        day: LocalDate,
        hour: Int,
        minute: Int,
        changeHour: Int,
        changeMinute: Int,
    ): LocalDate {
        val isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)
        return if (isBeforeChangeTime) day.plusDays(1) else day
    }

    /** The logical day as a date, or `null` when it is not a canonical one. */
    private fun parseOrNull(logicalDay: String): LocalDate? = runCatching { DayResolver.parseDate(logicalDay) }.getOrNull()
}
