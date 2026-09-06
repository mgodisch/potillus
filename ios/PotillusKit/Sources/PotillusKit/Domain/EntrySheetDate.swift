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
// EntrySheetDate.swift – what the entry sheet fills its date field with
// =============================================================================
//
// The twin of Android's `domain/EntrySheetDate.kt`, rule for rule.
//
// THE PROBLEM THIS SOLVES
//   The sheet shows a DATE and a TIME, both editable. The user almost always
//   touches only the time — they are logging a drink, not filing a record — so
//   the date has to follow along, and the way it should follow depends on where
//   the sheet was opened:
//
//     TODAY SCREEN / DRINKS LIST. "02:00" typed at 06:00 means four hours ago,
//     not twenty hours from now. The rule is the most recent past.
//
//     CALENDAR. The user tapped a day and is recording a drink they had THEN.
//     The rule is to keep the entry on that logical day, which for a time before
//     the day-change boundary means the FOLLOWING calendar day.
//
//     EDITING. Nothing follows. The date and the time are the entry's.
//
// AND WHY IT STOPS
//   The moment the user picks a date themselves, the follow-up falls silent for
//   the rest of the sheet — otherwise they could not hold a date they had just
//   chosen. The sheet tracks that; this file only says what to fill in while it
//   is still filling.
//
// WHY IT IS A PURE FUNCTION AND NOT SHEET CODE
//   Everything here is arithmetic over a date, a time and a boundary, and the
//   cases that matter — the small hours, a boundary after 20:00, a tapped day
//   that happens to be today — are the ones a UI test reaches worst. The two
//   ports are held together by their tests rather than by a shared vector,
//   because nothing outside the sheet depends on the answer.
// =============================================================================

/// Where an entry sheet was opened, which decides how its date follows the time.
public enum EntryDayOrigin: Sendable, Equatable {
    /// The Today screen or the drinks list: the drink is being logged as it happens.
    case now
    /// A tapped calendar day: the drink belongs to that logical day.
    case calendar
    /// An existing entry: its own reading, and nothing follows.
    case edit
}

/// A wall-clock reading as the sheet holds it.
///
/// `date` is any instant on the intended CALENDAR day, read in the sheet's zone —
/// which is the shape SwiftUI's date picker binds to. The time of day it carries
/// is meaningless; `hour` and `minute` are the reading.
public struct EntryReading: Sendable, Equatable {
    public let date: Date
    public let hour: Int
    public let minute: Int

    /// Spelled out because the app target composes readings for `compose`;
    /// a memberwise initialiser is internal and would not reach it.
    public init(date: Date, hour: Int, minute: Int) {
        self.date = date
        self.hour = hour
        self.minute = minute
    }
}

/// A reading as the sheet SAVES it: the instant, and the frame it is recorded in.
///
/// The pair `onSave` hands to the model. The two are composed together by
/// `EntrySheetDate.compose` and must not be taken apart: an instant read in one
/// frame and stored with another comes back at an hour nobody typed.
public struct ComposedReading: Sendable, Equatable {
    public let timestampMillis: Int64
    public let utcOffsetSeconds: Int
}

/// The date and time an entry sheet opens with, and how the date follows the time.
public enum EntrySheetDate {

    /// The time a calendar sheet offers when the tapped day is not today.
    private static let calendarDefaultHour = 20

    /// The instant `reading` falls on, and the frame it is recorded in.
    ///
    /// TWO FRAMES, AND THE SHEET SAYS WHICH. A reading is a date and a time of
    /// day; to become an instant it needs a frame, and there are two candidates:
    ///
    ///  - `recordedOffsetSeconds` given: the user is correcting a time INSIDE a
    ///    recorded reading — editing an entry and leaving its date alone. The
    ///    reading is composed in the frame the entry recorded, and that frame
    ///    is kept. The device zone plays no part: a Berlin entry corrected from
    ///    Tokyo is still a Berlin reading, and a row whose offset was backfilled
    ///    from another zone keeps the frame it was given.
    ///
    ///  - `nil`: a new reading — logging a drink, or moving an entry to another
    ///    date. It is composed in `timeZone`, the device zone in production,
    ///    and the offset that zone had at the resulting instant is recorded
    ///    with it. This is the rule a date change follows everywhere in the
    ///    app; see `DayResolver.utcOffsetSeconds` for why the zone and not the
    ///    old offset.
    ///
    /// Composing the instant in one frame while keeping the offset of another
    /// was the defect of the 0.86.0 review: the sheet built every instant in
    /// the device zone and then attached the recorded offset to it, so an
    /// untouched edit could move a reading by the difference between the two.
    ///
    /// The calendar day is read off `reading.date` in `timeZone` — the zone
    /// the sheet's `Date` is held in — whichever frame the instant is then
    /// composed in. A time that does not exist in `timeZone` (the
    /// spring-forward gap) resolves to what `Calendar` offers instead; a fixed
    /// offset has no gaps. `EntrySheetDate.compose` in Kotlin is the twin.
    public static func compose(
        reading: EntryReading,
        recordedOffsetSeconds: Int?,
        timeZone: TimeZone = .current
    ) -> ComposedReading {
        var shown = Calendar(identifier: .gregorian)
        shown.timeZone = timeZone
        var parts = shown.dateComponents([.year, .month, .day], from: reading.date)
        parts.hour = reading.hour
        parts.minute = reading.minute
        parts.second = 0

        if let recorded = recordedOffsetSeconds,
           let frame = TimeZone(secondsFromGMT: recorded) {
            var fixed = Calendar(identifier: .gregorian)
            fixed.timeZone = frame
            let instant = fixed.date(from: parts) ?? reading.date
            return ComposedReading(
                timestampMillis: Int64((instant.timeIntervalSince1970 * 1000).rounded()),
                utcOffsetSeconds: recorded
            )
        }
        let instant = shown.date(from: parts) ?? reading.date
        return ComposedReading(
            timestampMillis: Int64((instant.timeIntervalSince1970 * 1000).rounded()),
            utcOffsetSeconds: timeZone.secondsFromGMT(for: instant)
        )
    }

    /// The reading a sheet opens with.
    ///
    /// `.now`: the present moment, which is what someone logging a drink means.
    ///
    /// `.calendar`: the tapped day at 20:00 — an evening hour, and one that is
    /// safe for every day-change time the user can set, including one after
    /// 20:00, because the placement below puts it on the following calendar day
    /// then. When the tapped day IS the running logical day the sheet opens on
    /// the present moment instead, so tapping today in the calendar behaves like
    /// the Today screen rather than jumping the clock to the evening.
    ///
    /// `.edit` is not answered here: an edited entry opens on its own recorded
    /// reading, which the sheet has and this function does not.
    public static func initial(
        origin: EntryDayOrigin,
        logicalDay: String,
        changeHour: Int,
        changeMinute: Int,
        now: Date,
        timeZone: TimeZone = .current
    ) -> EntryReading {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let here = EntryReading(date: now, hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        guard origin == .calendar else { return here }

        let nowMillis = Int64((now.timeIntervalSince1970 * 1000).rounded())
        let runningDay = DayResolver.today(
            now: nowMillis, changeHour: changeHour, changeMinute: changeMinute, timeZone: timeZone
        )
        guard logicalDay != runningDay,
              let placed = placeOnLogicalDay(
                  logicalDay, hour: calendarDefaultHour, minute: 0,
                  changeHour: changeHour, changeMinute: changeMinute, calendar: calendar
              )
        else { return here }

        return EntryReading(date: placed, hour: calendarDefaultHour, minute: 0)
    }

    /// The date to move to after the user changed only the TIME, or `nil` when
    /// nothing follows. The caller keeps the date it has in that case.
    public static func followUp(
        origin: EntryDayOrigin,
        logicalDay: String,
        changeHour: Int,
        changeMinute: Int,
        hour: Int,
        minute: Int,
        now: Date,
        timeZone: TimeZone = .current
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        switch origin {
        case .edit:
            return nil

        // The most recent past: a time later than the present one has not
        // happened today, so it happened yesterday. Equality counts as today —
        // "now" is a moment that has just passed, not one still to come.
        case .now:
            let parts = calendar.dateComponents([.hour, .minute], from: now)
            let nowHour = parts.hour ?? 0
            let nowMinute = parts.minute ?? 0
            let isAhead = hour > nowHour || (hour == nowHour && minute > nowMinute)
            return isAhead ? calendar.date(byAdding: .day, value: -1, to: now) : now

        // Stay on the day the user tapped, whatever time they choose.
        case .calendar:
            return placeOnLogicalDay(
                logicalDay, hour: hour, minute: minute,
                changeHour: changeHour, changeMinute: changeMinute, calendar: calendar
            )
        }
    }

    /// The CALENDAR day a wall-clock time falls on when it is to belong to the
    /// LOGICAL day `logicalDay`, as an instant in `calendar`'s zone.
    ///
    /// A logical day runs from one boundary to the next, so a time before the
    /// boundary sits on the following calendar day. `DayResolver.parseDate`
    /// anchors a day at noon UTC, so its year, month and day are read there and
    /// re-composed in the sheet's zone rather than shifted as an instant.
    private static func placeOnLogicalDay(
        _ logicalDay: String,
        hour: Int,
        minute: Int,
        changeHour: Int,
        changeMinute: Int,
        calendar: Calendar
    ) -> Date? {
        guard let day = DayResolver.parseDate(logicalDay) else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = utc.dateComponents([.year, .month, .day], from: day)
        guard let placed = calendar.date(from: DateComponents(
            year: parts.year, month: parts.month, day: parts.day, hour: 12
        )) else { return nil }

        let isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)
        return isBeforeChangeTime ? calendar.date(byAdding: .day, value: 1, to: placed) : placed
    }
}
