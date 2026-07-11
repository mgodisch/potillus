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
// MonthGrid.swift – laying a month out in weeks
// =============================================================================
//
// Pure arithmetic, extracted from the view because this is where calendars go
// wrong: a leading-blank count that is off by one shifts every date in the month
// onto the wrong weekday, and the bug is invisible in any month that happens to
// begin on the first column.
//
// Everything here is UTC. A calendar cell is a LOGICAL DAY — a label like
// "2026-01-02" — not an instant, so a time zone would only introduce a way for
// the grid to disagree with the entries it displays.
// =============================================================================

/// One month, arranged as the rows a calendar draws.
public struct MonthGrid: Sendable, Equatable {

    /// The days of the month, in order, as `yyyy-MM-dd`.
    public let days: [String]

    /// How many empty cells precede the first day, given the week's first day.
    public let leadingBlanks: Int

    /// The weekday headers, ISO numbered (1 = Monday … 7 = Sunday), starting at
    /// the locale's first day. A view maps these to names.
    public let weekdayOrder: [Int]

    /// Builds the grid for `year`/`month`.
    ///
    /// - Parameters:
    ///   - year: Four-digit year.
    ///   - month: 1 = January … 12 = December.
    ///   - firstDayOfWeekIso: 1 = Monday … 7 = Sunday, from
    ///     `DayResolver.firstDayOfWeekIso()`.
    public init(year: Int, month: Int, firstDayOfWeekIso: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 12  // noon, as everywhere else, to stay clear of DST

        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            self.days = []
            self.leadingBlanks = 0
            self.weekdayOrder = []
            return
        }

        self.days = range.map { day in
            String(format: "%04d-%02d-%02d", year, month, day)
        }

        // `component(.weekday,…)` is Sunday-based (1 = Sunday); convert to ISO.
        let sundayBased = calendar.component(.weekday, from: firstOfMonth)
        let firstDayIso = sundayBased == 1 ? 7 : sundayBased - 1

        // How far the first of the month sits from the week's first column.
        // The +7 keeps the result non-negative before the modulo; without it a
        // month beginning on Sunday in a Monday-first locale yields -6.
        self.leadingBlanks = (firstDayIso - firstDayOfWeekIso + 7) % 7

        self.weekdayOrder = (0..<7).map { offset in
            (firstDayOfWeekIso - 1 + offset) % 7 + 1
        }
    }

    /// The first and last day of the month, for the summary query.
    public var range: (from: String, to: String)? {
        guard let first = days.first, let last = days.last else { return nil }
        return (first, last)
    }

    /// Total cells the grid occupies, rounded up to whole weeks.
    public var cellCount: Int {
        let used = leadingBlanks + days.count
        return Int((Double(used) / 7.0).rounded(.up)) * 7
    }
}
