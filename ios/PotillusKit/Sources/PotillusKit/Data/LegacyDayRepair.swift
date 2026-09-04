// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import Foundation

// =============================================================================
// LegacyDayRepair.swift – rescuing calendar entries written before v0.85.0
// =============================================================================
//
// The twin of Android's `data/repository/LegacyDayRepair.kt`, rule for rule.
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
//   jump to the evening it was typed, weeks away, on every screen at once. So
//   these rows are rebuilt from the intention the user actually expressed.
//
// HOW THEY ARE RECOGNISED
//   By a gap of TWO OR MORE calendar days between `logicalDate` and the calendar
//   day of the reading. Nothing that works correctly produces that gap: a
//   day-change boundary moves an entry by at most one day, so does a
//   daylight-saving switch, and so does the Today screen's placement rule.
//
//   ONE KNOWN MISFIRE, ACCEPTED. A pre-0.86.0 row whose reading is before the
//   boundary already sits on calendar day D+1 with `logicalDate` D. If the v4
//   migration backfilled its offset from a zone lying Δ hours EAST of where it
//   was written, the reading moves by Δ and reaches D+2 once Δ ≥ 24 h − t, with
//   t the time of day. Such a row is then repaired although it needs no repair,
//   and the repair does no harm: it rebuilds the instant from `logicalDate` and
//   the reading, restoring the very logical day the row already had. A
//   three-day threshold would instead abandon genuine calendar entries booked
//   for the day before yesterday, which are common.
//
// WHAT IS KNOWN ABOUT THE TIME ON THIS SIDE
//   Less than on Android. There the entry dialog of that era built its timestamp
//   from `now` with the hour and minute substituted, so the time was the typed
//   one and only the date came from the day of typing. The iOS changelog for
//   0.83.0 says only that the timestamp stays the moment of typing. If that is
//   what happened, a repaired entry sits some hours away from the actual drink —
//   but on the day the user chose, which is nearer the truth than the day they
//   happened to type on.
//
// WHY THIS DOES NOT USE `DayResolver`
//   Reading a zone's historical offset exists there too, and placing a wall-clock
//   time on a logical day did until the entry sheet grew a date field. Both are
//   spelled out here on purpose. A repair runs ONCE per device, and a device that has already run it
//   must not be reinterpreted by a later change to the domain; a device that has
//   not yet run it must compute what one that ran it a year ago computed.
//   Binding the repair to a moving definition would give two phones with the
//   same history two different answers.
// =============================================================================

/// A wall-clock reading: the instant, and the frame it is to be read in.
///
/// The pair the repair rewrites. Both move together — changing the instant
/// without re-reading the offset would leave the row claiming a frame it was
/// never in.
public struct RepairedReading: Sendable, Equatable {
    public let timestampMillis: Int64
    public let utcOffsetSeconds: Int
}

/// Rebuilds the timestamps of entries whose stored day contradicts their reading.
public enum LegacyDayRepair {

    /// A gap of this many calendar days or more marks a pre-0.85.0 calendar entry.
    private static let suspiciousDayGap = 2

    /// A Gregorian calendar pinned to UTC, for zone-independent day arithmetic.
    ///
    /// A private copy of the one in `DayResolver`, for the reason in the file
    /// header. Anchoring at noon, as `DayResolver.parseDate` does, is not needed
    /// here: nothing below adds or subtracts days from a parsed date, it only
    /// counts whole days between two of them.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// Canonical `yyyy-MM-dd`, in UTC and a fixed POSIX locale so the formatter
    /// never adopts a device locale's alternate calendar or numerals.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// The corrected reading for one row, or nil when the row is sound.
    ///
    /// Nil is the answer for the overwhelming majority of rows and means "do not
    /// touch this one". Returning the unchanged reading instead would make every
    /// caller rewrite every row, and a rewrite that changes nothing still costs a
    /// write and still pushes the row through every observation.
    ///
    /// - Parameters:
    ///   - timestampMillis:  The instant as stored.
    ///   - utcOffsetSeconds: The frame as stored (backfilled by the v4 migration
    ///                       for rows that predate the column).
    ///   - logicalDate:      The day the row is filed under — for a damaged row,
    ///                       the only surviving record of what the user meant.
    ///   - changeHour:       Hour of the day-change boundary to rebuild under.
    ///   - changeMinute:     Minute of that boundary.
    ///   - timeZone:         Zone the rebuilt instant is read in. The device zone
    ///                       in production: the same assumption logging an entry
    ///                       makes, namely that the phone is where its owner is.
    public static func repair(
        timestampMillis: Int64,
        utcOffsetSeconds: Int,
        logicalDate: String,
        changeHour: Int,
        changeMinute: Int,
        timeZone: TimeZone = .current
    ) -> RepairedReading? {
        // A row whose `logicalDate` is not a canonical date is left alone rather
        // than guessed at. The backup gate rejects such a value, and the column
        // has been written by the app itself for every other row, so this is a
        // guard and not a path with a user behind it.
        guard let filedUnder = parseCanonicalDay(logicalDate) else { return nil }
        guard let reading = readingComponents(
            timestampMillis: timestampMillis, utcOffsetSeconds: utcOffsetSeconds
        ) else { return nil }
        guard let gap = wholeDaysBetween(filedUnder, reading.day), abs(gap) >= suspiciousDayGap else {
            return nil
        }

        // The TIME survives, the DATE is replaced.
        guard let rebuilt = instantOnLogicalDate(
            logicalDate: filedUnder,
            hour: reading.hour,
            minute: reading.minute,
            changeHour: changeHour,
            changeMinute: changeMinute,
            timeZone: timeZone
        ) else { return nil }

        return RepairedReading(
            timestampMillis: Int64((rebuilt.timeIntervalSince1970 * 1000.0).rounded()),
            // Re-read, not carried over: the row is being moved to another date,
            // and the offset of the old instant says nothing about the new one.
            // This is the rule a date change follows everywhere in the app.
            utcOffsetSeconds: timeZone.secondsFromGMT(for: rebuilt)
        )
    }

    /// The wall-clock day and time of an instant, read in its recorded frame.
    ///
    /// A named type rather than a three-member tuple: SwiftLint's `large_tuple`
    /// refuses those, and with reason — `.0`, `.1`, `.2` at the call site would
    /// hide which of two integers is the hour.
    private struct Reading {
        /// The calendar day, anchored in UTC so it can be counted against the
        /// parsed `logicalDate` without either of them carrying a zone into the
        /// comparison.
        let day: Date
        let hour: Int
        let minute: Int
    }

    /// The wall-clock day and time of an instant, read in its recorded frame.
    private static func readingComponents(
        timestampMillis: Int64, utcOffsetSeconds: Int
    ) -> Reading? {
        guard let frameZone = TimeZone(secondsFromGMT: utcOffsetSeconds) else { return nil }
        var frame = Calendar(identifier: .gregorian)
        frame.timeZone = frameZone
        let instant = Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
        let parts = frame.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        guard let hour = parts.hour, let minute = parts.minute,
              let day = utcCalendar.date(from: DateComponents(
                  year: parts.year, month: parts.month, day: parts.day
              ))
        else { return nil }
        return Reading(day: day, hour: hour, minute: minute)
    }

    /// The canonical `yyyy-MM-dd` as a UTC-anchored day, or nil.
    ///
    /// The round trip is what makes it canonical: `DateFormatter` would otherwise
    /// accept a day the month does not have and hand back a neighbouring one.
    private static func parseCanonicalDay(_ dateString: String) -> Date? {
        guard let parsed = dateFormatter.date(from: dateString),
              dateFormatter.string(from: parsed) == dateString
        else { return nil }
        return parsed
    }

    /// Whole calendar days from `from` to `to`, signed.
    private static func wholeDaysBetween(_ from: Date, _ to: Date) -> Int? {
        utcCalendar.dateComponents([.day], from: from, to: to).day
    }

    /// The instant a wall-clock time falls on, on a given LOGICAL day.
    ///
    /// A logical day runs from one boundary to the next, so a time before the
    /// boundary belongs to the following CALENDAR day: with a 04:00 boundary,
    /// 01:00 on the logical 30th is 01:00 on the calendar 31st. The private twin
    /// `DayResolver` carried a public twin of this until the entry sheet grew a
    /// date field and stopped needing one; the copy here was never that twin, and
    /// outlives it for the reason in the file header.
    ///
    /// The day's year, month and day are re-composed in `timeZone` rather than
    /// shifted as an instant, so the result is the wall-clock time in that zone
    /// and not the same moment seen from elsewhere.
    private static func instantOnLogicalDate(
        logicalDate: Date,
        hour: Int,
        minute: Int,
        changeHour: Int,
        changeMinute: Int,
        timeZone: TimeZone
    ) -> Date? {
        let isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let day = utcCalendar.dateComponents([.year, .month, .day], from: logicalDate)
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = hour
        components.minute = minute
        guard let placed = calendar.date(from: components) else { return nil }
        // A time that does not exist in the zone — the spring-forward gap —
        // resolves to what `Calendar` offers instead, which is the behaviour the
        // Kotlin twin inherits from `ZonedDateTime`.
        return isBeforeChangeTime
            ? calendar.date(byAdding: .day, value: 1, to: placed)
            : placed
    }
}
