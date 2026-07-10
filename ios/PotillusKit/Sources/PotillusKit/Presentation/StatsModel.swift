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
// StatsModel.swift – assembling the Statistics screen
// =============================================================================
//
// Nothing is computed here. The window comes from `StatsWindows`, the four
// aggregations from `StatsAggregator`, the violations from `AlcoholCalculator`,
// the streaks from `DayResolver`, the chart from `ChartBucketing`. This file
// fetches, delegates, and puts the results in one struct — which is all a view
// model should ever do, and is exactly what Android's `StatsViewModel` does not.
//
// Exports (CSV, PDF) are deliberately absent; they arrive with their own patches.
// =============================================================================

/// Everything the statistics screen shows.
public struct StatsState: Sendable, Equatable {

    public var period: StatsPeriod = .month

    /// The days actually covered, after the user's floor.
    public var from: String = ""
    public var to: String = ""

    /// Per-day totals across the period, chronologically.
    public var dataPoints: [DaySummary] = []

    /// The chart's bars, already bucketed.
    public var chartBuckets: [ChartBucket] = []
    public var chartGranularity: ChartGranularity = .daily

    public var totalGrams: Double = 0.0
    public var averagePerDay: Double = 0.0
    public var averagePerDrinkDay: Double = 0.0

    public var daysOverDailyLimit: Int = 0
    public var daysOverWeeklyLimit: Int = 0
    public var daysOverDrinkDayLimit: Int = 0

    public var abstinentDays: Int = 0
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0

    /// Change against the previous period, in percent. Zero when there is no
    /// baseline — which is not the same as "no change", and the arrow says so.
    public var trendPercent: Double = 0.0
    public var trend: Trend = .flat

    /// Whether a comparable previous period exists at all. False when the user's
    /// `statsFromDate` cuts into the current period.
    public var hasBaseline: Bool = true

    public var categoryBreakdown: [DrinkCategory: Double] = [:]

    /// Average grams per day in each three-hour bucket, 0–3 … 21–24.
    public var hourBucketAverages: [Double] = Array(repeating: 0.0, count: 8)

    /// ISO weekday numbers in display order, and their averages. `nil` marks a
    /// weekday the period does not contain.
    public var weekdayOrder: [Int] = []
    public var weekdayAverages: [Double?] = []

    public var limitInfo: LimitInfo = AlcoholCalculator.getLimitInfo(AppSettings())
    public var today: String = ""

    public init() {}
}

@MainActor
@Observable
public final class StatsModel {

    public private(set) var state = StatsState()
    public private(set) var failure: String?

    private let entries: any EntryRepositoryProtocol
    private let drinks: any DrinkRepositoryProtocol
    private let preferences: any PreferencesStoring
    private let clock: any Clock
    private let timeZone: TimeZone
    private let firstDayOfWeekIso: Int

    /// The live subscriptions, torn down by `stop()`.
    private var observations: [Task<Void, Never>] = []

    public init(
        entries: any EntryRepositoryProtocol,
        drinks: any DrinkRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current,
        firstDayOfWeekIso: Int = DayResolver.firstDayOfWeekIso()
    ) {
        self.entries = entries
        self.drinks = drinks
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
        self.firstDayOfWeekIso = firstDayOfWeekIso
    }

    public func setPeriod(_ period: StatsPeriod) async {
        state.period = period
        await load()
    }

    // ── Observation ──────────────────────────────────────────────────────────
    //
    // Android's StatsViewModel combines the period selector, the settings, and the
    // set of logged dates into one Flow, and re-runs the inner database queries with
    // `flatMapLatest`. The screen is live: log a drink, and the statistics behind it
    // have already changed.
    //
    // This model used to be a SNAPSHOT. It loaded on `.task` and on pull-to-refresh,
    // and nothing else. Import a backup while the statistics screen sits in another
    // tab, come back, and it shows the numbers from before the import. Add an entry
    // on the Today screen, and the totals here are a drink behind. Neither says so.
    //
    // WHY THE TICKERS ARE `_` AND THE WORK IS `reload()`
    //   `reload()` recomputes the window from the period and the settings, and then
    //   fetches. It is the only thing that knows which days matter, so the streams
    //   do not carry data — they carry the fact that something changed.
    //
    //   `observeAllDates()` fetches `SELECT DISTINCT logicalDate`, whose value does
    //   NOT change when the grams on an existing day are edited. It still fires:
    //   GRDB's `ValueObservation` notifies on every transaction that touches the
    //   tracked region and, by its own documentation, "may notify consecutive
    //   identical values". Duplicates are removed only by asking for
    //   `removeDuplicates()`, which this deliberately does not.
    //
    //   The settings stream matters as much: `dayChangeHour` moves what "today" is,
    //   and `statsFromDate` moves the floor of every window.

    /// Subscribes to the database and to the settings.
    ///
    /// Safe to call again; the previous subscriptions are cancelled first, so a
    /// re-appearing view does not accumulate them. The first emission of each stream
    /// arrives immediately, which is what loads the screen — no separate `load()`
    /// call is needed on appear.
    public func start() {
        stop()

        observations = [
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await _ in self.entries.observeAllDates() {
                        await self.load()
                    }
                } catch {
                    self.failure = String(describing: error)
                }
            },
            Task { [weak self] in
                guard let self else { return }
                for await _ in await self.preferences.observe() {
                    await self.load()
                }
            }
        ]
    }

    public func stop() {
        observations.forEach { $0.cancel() }
        observations = []
    }

    /// Recomputes the whole state.
    public func load() async {
        do {
            try await reload()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    /// Fetches, delegates, and assembles. Every number it stores was computed by a
    /// tested function elsewhere.
    private func reload() async throws {
        let settings = await preferences.load()
        let nowMillis = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        let today = DayResolver.resolve(
            timestampMillis: nowMillis,
            changeHour: settings.dayChangeHour,
            changeMinute: settings.dayChangeMinute,
            timeZone: timeZone
        )

        guard let raw = StatsWindows.window(period: state.period, today: today) else { return }
        let floor = settings.statsFromDate
        let window = StatsWindows.applyingFloor(raw, floor: floor)

        // The current period.
        let summaries = try entries.dailySummaries(from: window.from, to: window.to)
        let periodEntries = try entries.inRange(from: window.from, to: window.to)
        let catalogue = try drinks.allOnce()

        // The baseline. An inverted range is not an error: the floor cut it away.
        let previous = window.hasBaseline
            ? try entries.dailySummaries(from: window.previousFrom, to: window.previousTo)
            : []

        let totalGrams = summaries.reduce(0.0) { $0 + $1.totalGrams }
        let drinkDays = summaries.filter { $0.totalGrams > 0.0 }.count

        // `effectivePeriodDays` excludes an unfinished dry day, so today's absence
        // of drinking does not dilute the average until the day is over.
        let todayIsDrinkDay = summaries.contains { $0.date == window.to && $0.totalGrams > 0.0 }
        let periodDays = DayResolver.effectivePeriodDays(
            from: window.from, today: window.to, todayIsDrinkDay: todayIsDrinkDay
        )

        let limitInfo = AlcoholCalculator.getLimitInfo(settings)
        let violations = AlcoholCalculator.countLimitViolations(
            summaries: summaries,
            dailyLimitGrams: limitInfo.limitGrams,
            weeklyLimitGrams: limitInfo.weeklyLimitGrams,
            maxDrinkDaysPerWeek: limitInfo.maxDrinkDaysPerWeek
        )

        let averagePerDay = StatsAggregator.averagePerDay(
            totalGrams: totalGrams, effectivePeriodDays: periodDays
        )

        // The baseline's average is over its OWN length, whole days, since it is a
        // finished period. Comparing per-day is what keeps a partial month fair.
        let previousDays = Self.dayCount(from: window.previousFrom, to: window.previousTo)
        let previousTotal = previous.reduce(0.0) { $0 + $1.totalGrams }
        let previousAverage = previousDays > 0 ? previousTotal / Double(previousDays) : 0.0

        // Streaks look at the whole history above the floor, not just this period:
        // a dry streak began before the month did.
        let allDates = try entries.allDates()
        let streakDates = floor.isEmpty ? allDates : allDates.filter { $0 >= floor }

        let granularity: ChartGranularity = state.period == .year ? .monthly : .daily

        var next = StatsState()
        next.period = state.period
        next.from = window.from
        next.to = window.to
        next.today = today
        next.dataPoints = summaries
        next.chartGranularity = granularity
        next.chartBuckets = ChartBucketing.bucketize(
            summaries: summaries, from: window.from, to: window.to,
            granularity: granularity, inProgressDay: window.to
        )
        next.totalGrams = totalGrams
        next.averagePerDay = averagePerDay
        next.averagePerDrinkDay = StatsAggregator.averagePerDrinkDay(
            totalGrams: totalGrams, drinkDays: drinkDays
        )
        next.daysOverDailyLimit = violations.daysOverDailyLimit
        next.daysOverWeeklyLimit = violations.daysOverWeeklyLimit
        next.daysOverDrinkDayLimit = violations.daysOverDrinkDayLimit
        next.abstinentDays = max(periodDays - drinkDays, 0)
        next.currentStreak = DayResolver.computeCurrentAbstinence(
            sortedDates: streakDates, today: today, statsFrom: floor
        )
        next.longestStreak = DayResolver.computeLongestAbstinence(
            sortedDates: streakDates, today: today, statsFrom: floor
        )
        next.hasBaseline = window.hasBaseline
        next.trendPercent = StatsAggregator.trendPercent(
            currentAveragePerDay: averagePerDay, previousAveragePerDay: previousAverage
        )
        next.trend = Trend.of(currentAvg: averagePerDay, prevAvg: previousAverage)
        next.categoryBreakdown = StatsAggregator.categoryBreakdown(
            entries: periodEntries, drinks: catalogue
        )
        next.hourBucketAverages = StatsAggregator.hourBucketAverages(
            entries: periodEntries, effectivePeriodDays: periodDays, timeZone: timeZone
        )
        next.weekdayOrder = StatsAggregator.weekdayOrder(firstDayOfWeekIso: firstDayOfWeekIso)
        next.weekdayAverages = StatsAggregator.weekdayAverages(
            summaries: summaries, firstDayOfWeekIso: firstDayOfWeekIso
        )
        next.limitInfo = limitInfo

        state = next
    }

    /// Inclusive day count between two logical dates, or zero for an inverted range.
    nonisolated private static func dayCount(from: String, to: String) -> Int {
        guard let start = DayResolver.parseDate(from),
              let end = DayResolver.parseDate(to),
              start <= end
        else { return 0 }
        return Int(end.timeIntervalSince(start) / 86_400) + 1
    }
}
