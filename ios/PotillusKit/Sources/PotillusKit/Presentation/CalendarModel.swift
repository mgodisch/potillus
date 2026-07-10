// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
import Observation

// =============================================================================
// CalendarModel.swift – a month of logical days
// =============================================================================
//
// The counterpart of Android's `CalendarViewModel`, month view only. The YEAR
// view is deliberately absent: it is a second layout over the same summaries, and
// it arrives with the Statistics screen, which already owns per-month aggregation.
//
// THE MONTH IS NOT AN INSTANT
//   A cell is a logical day — the string "2026-01-02" — because that is what the
//   entries carry. Navigating months therefore moves integers, never dates, and
//   no time zone or DST transition can shift the grid relative to its contents.
//   Only "today" is read from the clock, once.
// =============================================================================

/// What the calendar screen shows.
public struct CalendarState: Sendable, Equatable {

    public var year: Int = 0
    public var month: Int = 0

    /// The grid: days, leading blanks, weekday headers.
    public var grid = MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: 1)

    /// Summaries for the visible month, keyed by logical date. A day with no
    /// entries is absent, not zero.
    public var summaries: [String: DaySummary] = [:]

    /// Today's logical date, for the "today" ring.
    public var today: String = ""

    /// The day the user tapped, if any.
    public var selectedDate: String?

    /// Entries of the selected day, oldest first.
    public var selectedEntries: [ConsumptionEntry] = []

    /// Their grams, summed.
    public var totalGramsSelected: Double = 0.0

    public var limitInfo: LimitInfo = AlcoholCalculator.getLimitInfo(AppSettings())

    public init() {}
}

@MainActor
@Observable
public final class CalendarModel {

    public private(set) var state = CalendarState()
    public private(set) var failure: String?

    private let entries: any EntryRepositoryProtocol
    private let preferences: any PreferencesStoring
    private let clock: any Clock
    private let timeZone: TimeZone
    private let firstDayOfWeekIso: Int

    public init(
        entries: any EntryRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current,
        firstDayOfWeekIso: Int = DayResolver.firstDayOfWeekIso()
    ) {
        self.entries = entries
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
        self.firstDayOfWeekIso = firstDayOfWeekIso
    }

    // ── Loading ──────────────────────────────────────────────────────────────

    /// Loads the month containing today, unless a month is already shown.
    public func load() async {
        let settings = await preferences.load()
        let nowMillis = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        let today = DayResolver.resolve(
            timestampMillis: nowMillis,
            changeHour: settings.dayChangeHour,
            changeMinute: settings.dayChangeMinute,
            timeZone: timeZone
        )

        state.today = today
        state.limitInfo = AlcoholCalculator.getLimitInfo(settings)

        if state.year == 0 {
            // "2026-01-02" — parsed as integers, not as a date.
            let parts = today.split(separator: "-").compactMap { Int($0) }
            state.year = parts.count == 3 ? parts[0] : 2026
            state.month = parts.count == 3 ? parts[1] : 1
        }
        await reloadMonth()
    }

    /// Fetches the visible month's summaries and re-reads the selection.
    private func reloadMonth() async {
        state.grid = MonthGrid(
            year: state.year, month: state.month, firstDayOfWeekIso: firstDayOfWeekIso
        )
        guard let range = state.grid.range else { return }

        do {
            let summaries = try entries.dailySummaries(from: range.from, to: range.to)
            state.summaries = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })
            try reloadSelection()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    private func reloadSelection() throws {
        guard let date = state.selectedDate else {
            state.selectedEntries = []
            state.totalGramsSelected = 0.0
            return
        }
        let dayEntries = try entries.inRange(from: date, to: date)
        state.selectedEntries = dayEntries
        state.totalGramsSelected = dayEntries.reduce(0.0) { $0 + $1.gramsAlcohol }
    }

    // ── Navigation ───────────────────────────────────────────────────────────

    /// Integer arithmetic, so December → January cannot go wrong.
    public func previousMonth() async {
        if state.month == 1 {
            state.month = 12
            state.year -= 1
        } else {
            state.month -= 1
        }
        clearSelection()
        await reloadMonth()
    }

    public func nextMonth() async {
        if state.month == 12 {
            state.month = 1
            state.year += 1
        } else {
            state.month += 1
        }
        clearSelection()
        await reloadMonth()
    }

    /// A selection belongs to the month it was made in; carrying it across would
    /// show January's entries under a February heading.
    private func clearSelection() {
        state.selectedDate = nil
        state.selectedEntries = []
        state.totalGramsSelected = 0.0
    }

    // ── Selection ────────────────────────────────────────────────────────────

    /// Selects `date`, or deselects when it is already selected.
    public func select(_ date: String?) async {
        state.selectedDate = (date == state.selectedDate) ? nil : date
        do {
            try reloadSelection()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    public func deleteEntry(_ entry: ConsumptionEntry) async {
        do {
            try entries.delete(entry)
        } catch {
            failure = String(describing: error)
            return
        }
        await reloadMonth()
    }

    /// Whether a day exceeded the daily limit. Absent days are not over.
    public func isOverLimit(_ date: String) -> Bool {
        guard let summary = state.summaries[date] else { return false }
        return AlcoholCalculator.isOverLimit(
            totalGrams: summary.totalGrams, limitGrams: state.limitInfo.limitGrams
        )
    }
}
