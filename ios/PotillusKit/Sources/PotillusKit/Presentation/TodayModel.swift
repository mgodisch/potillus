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
import Observation

// =============================================================================
// TodayModel.swift – the state behind the Today screen
// =============================================================================
//
// The counterpart of Android's `TodayViewModel`. It lives in the KIT, not in the
// app target, for the reason that governs this whole port: the app target is not
// covered by `swift test`, and this is where the arithmetic happens. The SwiftUI
// view above it should contain layout and nothing else.
//
// TIME IS INJECTED
//   Two things here depend on "now": which logical day is being shown, and how
//   far the blood-alcohol estimate has decayed. Both take it from a `Clock`. A
//   test can therefore assert that the day flips at 04:00 without waiting for it.
//
// THE MONTHLY FIGURES, AND WHAT STAYS IN THE VIEW
//   `monthlyAvgPerDay` and `monthTrend` are computed here, exactly as Android's
//   `TodayViewModel` does — pure numbers, no locale. The two LABELS Android also
//   carries in its state, the standalone month name and the weekly date range,
//   are deliberately NOT here: they are locale-dependent formatting, and the kit
//   holds no locale. The view formats them from `logicalDate` and `weekStart` in
//   the in-app locale, so the arithmetic stays testable and the kit stays free of
//   `DateFormatter` locale choices.
// =============================================================================

/// Everything the Today screen renders. A value: computing it has no side effects.
public struct TodayState: Sendable, Equatable {

    /// The logical day being shown, `yyyy-MM-dd`.
    public var logicalDate: String = ""

    /// Today's entries, oldest first.
    public var entries: [ConsumptionEntry] = []

    /// Sum of `gramsAlcohol` over `entries`.
    public var totalGrams: Double = 0.0

    /// The limits in force, already clamped.
    public var limitInfo: LimitInfo = AlcoholCalculator.getLimitInfo(AppSettings())

    /// Days with any alcohol in the trailing 7-day window, today included.
    public var drinkDaysThisWeek: Int = 0

    /// Grams across that same window.
    public var weeklyTotalGrams: Double = 0.0

    /// First day of the trailing 7-day window, `yyyy-MM-dd`. The view formats the
    /// `weekStart … logicalDate` range in the in-app locale.
    public var weekStart: String = ""

    /// Average grams of alcohol per day for the current calendar month so far: the
    /// month's grams divided by the days elapsed (1st … today, inclusive), clipped
    /// by `statsFromDate`. The Statistics month view shows the same figure.
    public var monthlyAvgPerDay: Double = 0.0

    /// Direction of `monthlyAvgPerDay` versus the per-day average over the whole
    /// period from `statsFromDate` up to the day before this month. `.flat` when no
    /// such baseline exists.
    public var monthTrend: Trend = .flat

    /// The Widmark estimate in per mille, or nil when it cannot be computed.
    ///
    /// Nil is not zero. Nil means "we do not know" — the user has not entered a
    /// body weight, or nothing alcoholic was logged today. Showing 0.0‰ in that
    /// case would assert sobriety the app cannot vouch for.
    public var bacPermille: Double?

    /// The drinks the user starred, for one-tap logging.
    public var favorites: [DrinkDefinition] = []

    /// The whole catalogue, for the entry sheet's picker.
    public var drinks: [DrinkDefinition] = []

    /// The drink of the most recent entry, pre-selected when the sheet opens.
    /// Nil when nothing has ever been logged.
    public var lastUsedDrink: DrinkDefinition?

    public var settings: AppSettings = AppSettings()

    public init() {}
}

/// Builds `TodayState` and applies the user's actions.
///
/// `@MainActor` because SwiftUI observes it; `@Observable` so a mutation of
/// `state` redraws the view without a `Published` per field.
@MainActor
@Observable
public final class TodayModel {

    public private(set) var state = TodayState()

    /// Set when a load or a write failed. The view shows it; nothing is silently
    /// swallowed.
    public private(set) var failure: String?

    private let entries: any EntryRepositoryProtocol
    private let drinks: any DrinkRepositoryProtocol
    private let preferences: any PreferencesStoring
    private let clock: any Clock
    private let timeZone: TimeZone

    /// How long the ticker in `start()` sleeps between reloads.
    ///
    /// 60 seconds, Android's `TICK_INTERVAL_MS`, and for the same two reasons
    /// spelled out in its KDoc: BAC changes about 0.0025 ‰ per minute, so a
    /// finer resolution buys nothing the eye can see, and one wakeup per minute
    /// also bounds the day-rollover latency to the resolution of the
    /// day-change setting itself. Injectable so a test can tick in
    /// milliseconds instead of sleeping a minute.
    private let tickInterval: Duration

    /// The live subscriptions, torn down by `stop()`.
    private var observations: [Task<Void, Never>] = []

    public init(
        entries: any EntryRepositoryProtocol,
        drinks: any DrinkRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current,
        tickInterval: Duration = .seconds(60)
    ) {
        self.entries = entries
        self.drinks = drinks
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
        self.tickInterval = tickInterval
    }

    // ── Observation ──────────────────────────────────────────────────────────
    //
    // WHY THE TICKERS ARE `_` AND THE WORK IS `load()`
    //   The three windows this screen shows — today's entries, the drinks
    //   catalogue, the trailing seven days — all depend on the settings:
    //   `dayChangeHour` moves what "today" is, and "today" moves the weekly window.
    //   So the streams cannot each carry their own slice of data; only `load()`
    //   knows which days matter. The streams carry the FACT that something changed,
    //   and `load()` recomputes the one consistent moment. This is the same shape
    //   as StatsModel and CalendarModel.
    //
    //   `observeAllDates()` fires on any transaction touching the entries — a new
    //   entry, an edited one, a deleted one — even when the DISTINCT date list is
    //   unchanged (GRDB may notify identical values, and this does not ask it to
    //   dedupe). `observeDrinks()` covers a drink added or a backup imported in
    //   another tab. `preferences.observe()` covers a changed day-change hour or
    //   limit. The first emission of each arrives at once, which loads the screen —
    //   the view needs no separate `load()` on appear.

    /// Subscribes to the database and the settings. Safe to call again; the previous
    /// subscriptions are cancelled first, so a re-appearing view does not accumulate
    /// them.
    public func start() {
        stop()

        observations = [
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await _ in self.entries.observeAllDates() {
                        // See CalendarModel.start(): guard against a late element
                        // delivered between stop() and the observation tearing
                        // down, which would otherwise still write state.
                        if Task.isCancelled { break }
                        await self.load()
                    }
                } catch {
                    self.failure = String(describing: error)
                }
            },
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await _ in self.drinks.observeDrinks() {
                        if Task.isCancelled { break }
                        await self.load()
                    }
                } catch {
                    self.failure = String(describing: error)
                }
            },
            Task { [weak self] in
                guard let self else { return }
                for await _ in await self.preferences.observe() {
                    if Task.isCancelled { break }
                    await self.load()
                }
            },
            // The ticker. The three streams above fire on DATA events; nothing
            // fires on the passage of time — yet two of this screen's numbers
            // are functions of "now". Without the ticker the BAC estimate stays
            // frozen at the value of the last load (it is advertised as live,
            // and it decays ~0.15 ‰/h), and the logical day never rolls over
            // while the screen stays open: every window stays pinned to
            // yesterday past the day-change time. Android runs the same
            // 60-second ticker for the same two jobs (TodayViewModel's KDoc).
            // The reload is unconditional here — unlike Stats and Calendar,
            // which tick day-keyed — because the BAC needs every minute, not
            // just the boundary one.
            Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    // A cancellation during the sleep throws; `try?` turns that
                    // into a normal wakeup and the loop condition ends the task.
                    try? await Task.sleep(for: self.tickInterval)
                    if Task.isCancelled { break }
                    await self.load()
                }
            }
        ]
    }

    /// Cancels the live subscriptions. Called from the view's `onDisappear` and on
    /// the next `start()`.
    public func stop() {
        observations.forEach { $0.cancel() }
        observations = []
    }

    // ── Loading ──────────────────────────────────────────────────────────────

    /// Recomputes the whole state from the stores in one consistent pass. Driven by
    /// `start()`'s streams now, and still safe to call directly after a write.
    public func load() async {
        do {
            let settings = await preferences.load()
            let nowMillis = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())

            let today = DayResolver.resolve(
                timestampMillis: nowMillis,
                changeHour: settings.dayChangeHour,
                changeMinute: settings.dayChangeMinute,
                timeZone: timeZone
            )

            let todaysEntries = try entries.inRange(from: today, to: today)
            let totalGrams = todaysEntries.reduce(0.0) { $0 + $1.gramsAlcohol }

            var next = TodayState()
            next.logicalDate = today
            next.entries = todaysEntries
            next.totalGrams = totalGrams
            next.limitInfo = AlcoholCalculator.getLimitInfo(settings)
            next.settings = settings
            let catalogue = try drinks.allOnce()
            next.drinks = catalogue
            next.favorites = catalogue.filter(\.isFavorite)
            // Pre-selection follows the LAST entry, not the most frequent one:
            // people tend to repeat what they just had.
            if let last = try entries.lastEntry() {
                next.lastUsedDrink = catalogue.first { $0.id == last.drinkId }
            }
            next.bacPermille = Self.bac(for: todaysEntries, totalGrams: totalGrams,
                                        settings: settings, nowMillis: nowMillis)

            let window = try weeklyWindow(endingOn: today)
            next.drinkDaysThisWeek = window.filter { $0.totalGrams > 0.0 }.count
            next.weeklyTotalGrams = window.reduce(0.0) { $0 + $1.totalGrams }

            if let todayDate = DayResolver.parseDate(today) {
                next.weekStart = DayResolver.formatDate(
                    DayResolver.addingDays(-(AlcoholCalculator.windowDays - 1), to: todayDate)
                )
            }

            let month = try monthlyAverage(today: today, statsFloor: settings.statsFromDate)
            next.monthlyAvgPerDay = month.average
            next.monthTrend = month.trend

            state = next
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    /// The trailing 7-day window: today and the six days before it.
    ///
    /// A gliding window, not a calendar week — the app has no configurable first
    /// weekday, and "this week" that resets on Monday would let a Sunday binge
    /// vanish overnight.
    private func weeklyWindow(endingOn today: String) throws -> [DaySummary] {
        guard let end = DayResolver.parseDate(today) else { return [] }
        let start = end.addingTimeInterval(-Double(AlcoholCalculator.windowDays - 1) * 86_400)
        return try entries.dailySummaries(
            from: DayResolver.formatDate(start), to: today
        )
    }

    /// The current month's grams-per-day average and its trend against the
    /// pre-month baseline. A faithful port of Android's `TodayViewModel`.
    ///
    /// The month's lower bound is the 1st — or a `statsFromDate` that falls INSIDE
    /// the running month, which then clips both the summed grams and the effective-
    /// day divisor to the identical span (the v0.81.0 Android QA fix). The baseline
    /// is the per-day average over `[statsFromDate, last day before this month]`,
    /// and exists only when the statistics start lies before this month; without it
    /// `Trend.of` returns `.flat`.
    private func monthlyAverage(
        today: String, statsFloor: String
    ) throws -> (average: Double, trend: Trend) {
        let monthStr = String(today.prefix(7)) + "-01"
        let hasBaseline = !statsFloor.isEmpty && statsFloor < monthStr
        let monthFromStr = (!statsFloor.isEmpty && statsFloor > monthStr) ? statsFloor : monthStr
        let historyFrom = hasBaseline ? statsFloor : monthFromStr

        let history = try entries.dailySummaries(from: historyFrom, to: today)
        let curMonth = history.filter { $0.date >= monthFromStr }
        let days = DayResolver.effectivePeriodDays(
            from: monthFromStr, today: today,
            todayIsDrinkDay: curMonth.contains { $0.date == today }
        )
        let average = days > 0 ? curMonth.reduce(0.0) { $0 + $1.totalGrams } / Double(days) : 0.0

        var baselineAvg = 0.0
        if hasBaseline, let monthDate = DayResolver.parseDate(monthStr) {
            let prevEnd = DayResolver.formatDate(DayResolver.addingDays(-1, to: monthDate))
            let baselineDays = DayResolver.inclusiveDates(from: statsFloor, to: prevEnd).count
            let baselineSum = history.filter { $0.date < monthStr }.reduce(0.0) { $0 + $1.totalGrams }
            baselineAvg = baselineDays > 0 ? baselineSum / Double(baselineDays) : 0.0
        }
        return (average, Trend.of(currentAvg: average, prevAvg: baselineAvg))
    }

    /// The Widmark estimate, or nil when it would be a guess.
    ///
    /// Mirrors Android exactly: a weight is required, and at least one entry with
    /// alcohol in it. The elapsed time runs from the FIRST alcoholic entry of the
    /// day, since that is when absorption began.
    private static func bac(
        for entries: [ConsumptionEntry], totalGrams: Double,
        settings: AppSettings, nowMillis: Int64
    ) -> Double? {
        guard settings.weightKg > 0 else { return nil }
        let alcoholic = entries.filter { $0.alcoholPercent > 0.0 }
        guard let firstTimestamp = alcoholic.map(\.timestampMillis).min() else { return nil }

        let hoursElapsed = Double(nowMillis - firstTimestamp) / AlcoholCalculator.millisPerHour
        return AlcoholCalculator.calculateBAC(
            totalGrams: totalGrams, weightKg: settings.weightKg, hoursElapsed: hoursElapsed
        )
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    /// Logs a drink at the given instant, defaulting to now.
    ///
    /// The grams and the logical date are computed here, not taken from the
    /// caller: they are derived facts, and a view that could pass its own would
    /// eventually pass a wrong one.
    public func addEntry(
        drink: DrinkDefinition, volumeMl: Int, timestampMillis: Int64? = nil, note: String = ""
    ) async {
        // The derivation lives in `EntryLogger`, so the Drinks screen and this one
        // cannot produce differently-shaped entries.
        let entry = EntryLogger.makeEntry(
            drink: drink,
            volumeMl: volumeMl,
            timestampMillis: timestampMillis
                ?? Int64((clock.now().timeIntervalSince1970 * 1000).rounded()),
            note: note,
            settings: state.settings,
            timeZone: timeZone
        )

        // The new row id is discarded explicitly rather than silenced with
        // `@discardableResult` on the protocol: it is real information, and a
        // caller that does not want it should have to say so.
        await perform { _ = try self.entries.add(entry) }
    }

    public func deleteEntry(_ entry: ConsumptionEntry) async {
        await perform { try self.entries.delete(entry) }
    }

    public func updateEntry(_ entry: ConsumptionEntry) async {
        await perform { try self.entries.update(entry) }
    }

    /// Runs a write, then reloads. A failed write leaves the state untouched and
    /// surfaces the reason rather than pretending the entry was saved.
    private func perform(_ write: @escaping () throws -> Void) async {
        do {
            try write()
        } catch {
            failure = String(describing: error)
            return
        }
        await load()
    }
}
