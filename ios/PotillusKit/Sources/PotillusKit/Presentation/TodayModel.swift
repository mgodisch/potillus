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

    // ── Loading ──────────────────────────────────────────────────────────────

    /// Recomputes the whole state from the stores.
    ///
    /// A snapshot, not a subscription. The screen calls it on appear and after
    /// each of its own writes. Live observation across three independent streams
    /// — entries, drinks, settings — whose windows depend on the settings, is a
    /// separate problem, and doing it wrong means a screen that redraws itself
    /// into an inconsistent moment.
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
            next.favorites = try drinks.allOnce().filter(\.isFavorite)
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
        let timestamp = timestampMillis
            ?? Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        let settings = state.settings

        let entry = ConsumptionEntry(
            drinkId: drink.id,
            drinkName: drink.name,
            volumeMl: volumeMl,
            alcoholPercent: drink.alcoholPercent,
            gramsAlcohol: AlcoholCalculator.calculateGrams(
                volumeMl: volumeMl, alcoholPercent: drink.alcoholPercent
            ),
            timestampMillis: timestamp,
            logicalDate: DayResolver.resolve(
                timestampMillis: timestamp,
                changeHour: settings.dayChangeHour,
                changeMinute: settings.dayChangeMinute,
                timeZone: timeZone
            ),
            note: note
        )

        await perform { try self.entries.add(entry) }
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
            _ = try write()
        } catch {
            failure = String(describing: error)
            return
        }
        await load()
    }
}
