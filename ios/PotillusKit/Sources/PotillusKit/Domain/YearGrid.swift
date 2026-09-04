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
// YearGrid.swift – twelve months as one heat-map
// =============================================================================
//
// The year view is the same summaries laid out a second way: twelve `MonthGrid`s
// side by side, each cell a logical day coloured by that day's total. There is no
// new date arithmetic here — every month is built by `MonthGrid`, which already
// owns the leading-blank count and the UTC anchoring — and no new query either:
// the twelve months are one range, "YYYY-01-01" through "YYYY-12-31".
//
// WHAT THIS TYPE ADDS
//   The window. Not every day of the year is the app's to speak about, and this
//   is the one rule the year view has that the month view does not:
//
//     - after the logical today lies the future, which cannot have been
//       abstinent yet.
//     - before the statistics start date lies the span the user excluded from
//       every statistic. Entries there are excluded too, so drawing them would
//       show the heat-map counting what the Statistics screen does not.
//
//   Both are drawn as nothing at all. A neutral cell is what an abstinent day
//   gets, so using it for these days would put a claim on the screen that no
//   entry supports — on a fresh install, where the start date defaults to the
//   install day (`PreferencesStore.seedOnFirstLaunch`), that claim would cover
//   most of the grid. Android reached the same conclusion in its 0.85.0 round and
//   hides the same two spans in `YearCalendarView`.
//
// WHY A TYPE AND NOT A LOOP IN THE VIEW
//   The decision is a pure function of four strings, so it can be asserted
//   directly, which is what `YearGridTests` does for the boundaries that are easy
//   to get wrong: the start date itself is drawn, today is drawn, tomorrow is not.
//   Android states the same rule in `domain/YearGrid.kt`, for the same reason.
// =============================================================================

/// A year of logical days, arranged as twelve month grids.
public struct YearGrid: Sendable, Equatable {

    /// One month of the year, in calendar order.
    public struct Month: Sendable, Equatable {
        /// 1 = January … 12 = December.
        public let month: Int
        /// The month's own layout: days, leading blanks, weekday order.
        public let grid: MonthGrid
    }

    /// The four-digit year this grid covers.
    public let year: Int

    /// January through December.
    public let months: [Month]

    /// Last day drawn, inclusive: the logical today as `yyyy-MM-dd`.
    public let today: String

    /// First day drawn, inclusive, or `nil` when no statistics start date is set.
    public let statsFrom: String?

    /// Builds the grid for `year`.
    ///
    /// - Parameters:
    ///   - year: Four-digit year.
    ///   - firstDayOfWeekIso: 1 = Monday … 7 = Sunday, from
    ///     `DayResolver.firstDayOfWeekIso()`.
    ///   - today: The logical today (`DayResolver.today`), not the wall-clock
    ///     date: the day-change time decides which day the user is in.
    ///   - statsFrom: The statistics start date, or empty for none. The empty
    ///     string is the app-wide sentinel for "no floor set"
    ///     (`AppSettings.statsFromDate`), and it arrives here as `nil`.
    public init(year: Int, firstDayOfWeekIso: Int, today: String, statsFrom: String) {
        self.year = year
        self.today = today
        self.statsFrom = statsFrom.isEmpty ? nil : statsFrom
        self.months = (1...12).map { month in
            Month(
                month: month,
                grid: MonthGrid(year: year, month: month, firstDayOfWeekIso: firstDayOfWeekIso)
            )
        }
    }

    /// The whole year, for the summary query.
    ///
    /// Deliberately the FULL year rather than the drawn window: the query is one
    /// range either way, and clipping it here would tie the fetched data to the
    /// window, so a start date changed while the screen is open would need a
    /// refetch rather than a redraw.
    public var range: (from: String, to: String) {
        (String(format: "%04d-01-01", year), String(format: "%04d-12-31", year))
    }

    /// Whether `date` is inside the drawn window.
    ///
    /// String comparison, not date parsing: `yyyy-MM-dd` is fixed-width and
    /// zero-padded, so lexicographic order IS chronological order. The same
    /// shortcut the statistics window takes (`StatsWindow.applyingFloor`).
    ///
    /// Both bounds are inclusive. The start date is a day the user chose to count
    /// from, and today is a day in progress, so neither is excluded.
    public func isDrawn(_ date: String) -> Bool {
        if date > today { return false }
        if let floor = statsFrom, date < floor { return false }
        return true
    }
}
