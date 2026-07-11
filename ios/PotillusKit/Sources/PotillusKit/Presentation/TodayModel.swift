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
// WHAT IS DELIBERATELY ABSENT
//   `monthlyAvgPerDay`, `monthTrend`, `weeklyRangeLabel` and `currentMonthLabel`
//   exist in the Android state and are NOT here yet. Each is a formatted, locale-
//   dependent string or a statistic the Statistics screen owns; they arrive with
//   localisation. Porting them now would mean inventing a date format before the
//   String Catalogs exist, and inventing it twice.
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

    /// The live subscriptions, torn down by `stop()`.
    private var observations: [Task<Void, Never>] = []

    public init(
        entries: any EntryRepositoryProtocol,
        drinks: any DrinkRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current
    ) {
        self.entries = entries
        self.drinks = drinks
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
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
