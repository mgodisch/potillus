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
// StatsWindow.swift – which days a statistics period covers
// =============================================================================
//
// Three periods, each with a comparison period immediately before it, and a user
// setting that can cut both short. Pure, because every one of those interactions
// is a place to be off by a day.
//
// THE COMPARISON PERIOD IS ADJACENT AND EQUAL-LENGTH
//   Week: the seven days ending today, against the seven before them.
//   Month: this month so far, against the whole previous calendar month.
//   Year: this year so far, against the whole previous year.
//
//   Note the asymmetry in month and year: a partial current period is compared
//   against a complete previous one. Android does this, and the trend is a
//   comparison of grams PER DAY, which is what makes it fair — twelve days into
//   January, the daily average is compared, not the total.
//
// THE FLOOR
//   `statsFromDate` is the user saying "my history before this date is not mine
//   to be judged by" — imported data, a fresh start. It raises the beginning of
//   BOTH windows. Three cases follow, and only the third is surprising:
//
//     - floor before both: nothing changes.
//     - floor inside the current period: the current window shrinks, the previous
//       window vanishes (its `from` exceeds its `to`), and there is no baseline.
//     - floor inside the PREVIOUS period: the previous window shrinks, and a
//       shorter baseline is compared against a longer current one. This is fair
//       BECAUSE the comparison is per-day, and unfair if anyone ever compares the
//       totals. `effectivePeriodDays` divides by the days that remain.
// =============================================================================

/// The three spans the statistics screen can show.
public enum StatsPeriod: String, Sendable, Equatable, CaseIterable {
    case week = "WEEK"
    case month = "MONTH"
    case year = "YEAR"
}

/// A period and the period it is compared against, as logical dates.
public struct StatsWindow: Sendable, Equatable {
    public let from: String
    public let to: String
    public let previousFrom: String
    public let previousTo: String

    /// Whether the previous window contains any days at all. An inverted range —
    /// which the floor can produce — means there is no baseline, not zero grams.
    public var hasBaseline: Bool { previousFrom <= previousTo }
}

public enum StatsWindows {

    /// The window for `period`, `offset` periods before the one containing `today`.
    ///
    /// WHERE THE WINDOW ENDS
    ///   At `offset == 0` it ends on `today`: the current month is the part of it
    ///   that has happened, not the whole month, or every average would be divided
    ///   by days still to come. At `offset > 0` the period is over, so it ends on
    ///   its own last day. Kotlin's `StatsWindows.window` draws the same line, and
    ///   the shared vectors pin both cases.
    ///
    /// WHY EVERY OFFSET IS MEASURED FROM TODAY
    ///   The offset is subtracted in one step rather than one period at a time.
    ///   Stepping would drift: from 31 March, one month back clamps to 28 February,
    ///   and a second step from there would land on 28 January and lose the 31st.
    ///
    /// - Parameters:
    ///   - today: A logical date, `yyyy-MM-dd`.
    ///   - offset: Whole periods to go back; 0 is the current one. Negative values
    ///     would name a period after today, which cannot be observed yet, and are
    ///     treated as 0.
    public static func window(period: StatsPeriod, today: String, offset: Int = 0) -> StatsWindow? {
        guard let todayDate = DayResolver.parseDate(today) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let steps = max(0, offset)

        // The day the offset period is anchored on: today itself at offset 0.
        let anchorComponent: Calendar.Component
        switch period {
        case .week: anchorComponent = .day
        case .month: anchorComponent = .month
        case .year: anchorComponent = .year
        }
        let anchorValue = period == .week ? -7 * steps : -steps
        guard let anchor = calendar.date(byAdding: anchorComponent, value: anchorValue, to: todayDate)
        else { return nil }

        let from: Date
        let previousFrom: Date
        let to: Date

        switch period {
        case .week:
            // The anchor plus the six days before it, and the seven before those.
            // A rolling seven days ends on its anchor, not on a calendar boundary.
            guard let start = calendar.date(byAdding: .day, value: -6, to: anchor),
                  let previousStart = calendar.date(byAdding: .day, value: -7, to: start)
            else { return nil }
            from = start
            previousFrom = previousStart
            to = anchor

        case .month:
            guard let start = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: anchor)
                  ),
                  let previousStart = calendar.date(byAdding: .month, value: -1, to: start),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)
            else { return nil }
            from = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
            previousFrom = calendar.date(
                bySettingHour: 12, minute: 0, second: 0, of: previousStart
            ) ?? previousStart
            to = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: monthEnd) ?? monthEnd

        case .year:
            guard let start = calendar.date(
                    from: calendar.dateComponents([.year], from: anchor)
                  ),
                  let previousStart = calendar.date(byAdding: .year, value: -1, to: start),
                  let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start)
            else { return nil }
            from = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
            previousFrom = calendar.date(
                bySettingHour: 12, minute: 0, second: 0, of: previousStart
            ) ?? previousStart
            to = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: yearEnd) ?? yearEnd
        }

        // The previous window always ends the day before the current one begins.
        guard let previousTo = calendar.date(byAdding: .day, value: -1, to: from) else {
            return nil
        }

        return StatsWindow(
            from: DayResolver.formatDate(from),
            // At offset 0 this is `today` itself; the branch above computed the
            // period's own last day, which only applies once the period is over.
            to: steps == 0 ? today : DayResolver.formatDate(to),
            previousFrom: DayResolver.formatDate(previousFrom),
            previousTo: DayResolver.formatDate(previousTo)
        )
    }

    /// Raises both windows' start to `floor`, if the user set one.
    ///
    /// String comparison, not date arithmetic: `yyyy-MM-dd` sorts
    /// chronologically, which is the entire reason the schema stores it that way.
    public static func applyingFloor(_ window: StatsWindow, floor: String) -> StatsWindow {
        guard !floor.isEmpty else { return window }
        return StatsWindow(
            from: max(window.from, floor),
            to: window.to,
            previousFrom: max(window.previousFrom, floor),
            previousTo: window.previousTo
        )
    }
}
