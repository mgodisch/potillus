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
// DrinkCapacityModel – the day's remaining budget, for the traffic-light dots
// =============================================================================
//
// The drinks list and the entry sheet each show a coloured dot per drink: how
// many more servings fit before a limit is crossed. Both need the SAME snapshot
// of today's consumption, and both must refresh when an entry is logged or a
// limit changes. This model is that snapshot.
//
// It is a deliberately small sibling of `TodayModel`. The Today screen already
// computes these numbers, but the drinks screen is a separate tab with its own
// models and no `TodayState`, and pulling in the whole Today model (BAC, month
// trend, favourites) to colour a dot would be far too much. So this model
// recomputes only the six figures `DrinkCapacity` needs, from the same stores,
// driven by the same streams:
//   - `entries.observeAllDates()` fires on any entry write, so logging a drink
//     re-colours every dot at once.
//   - `preferences.observe()` fires on a limit or day-change edit, and on the
//     `alternativeStatusSymbols` toggle that switches the dots to glyphs.
// =============================================================================

@MainActor
@Observable
public final class DrinkCapacityModel {

    /// The current day's budget snapshot. Seeded from the default limits with no
    /// consumption (a green dot), so the first paint before `load()` completes is
    /// optimistic rather than a flash of red from an all-zero limit.
    public private(set) var capacity: DrinkCapacity = {
        let limits = AlcoholCalculator.getLimitInfo(AppSettings())
        return DrinkCapacity(
            dailyLimitGrams: limits.limitGrams,
            weeklyLimitGrams: limits.weeklyLimitGrams,
            maxDrinkDaysPerWeek: limits.maxDrinkDaysPerWeek
        )
    }()

    /// Whether the dots should carry colour-blind glyphs instead of plain colour,
    /// mirroring `AppSettings.alternativeStatusSymbols`.
    public private(set) var useSymbols = false

    private let entries: any EntryRepositoryProtocol
    private let preferences: any PreferencesStoring
    private let clock: any Clock
    private let timeZone: TimeZone

    private var observations: [Task<Void, Never>] = []

    public init(
        entries: any EntryRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current
    ) {
        self.entries = entries
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
    }

    public convenience init(environment: AppEnvironment, timeZone: TimeZone = .current) {
        self.init(
            entries: environment.entries,
            preferences: environment.preferences,
            clock: environment.clock,
            timeZone: timeZone
        )
    }

    /// Starts the observations. Idempotent via `stop()`, and safe to call again
    /// after `stop()`. Same shape as `TodayModel.start()`: any change on either
    /// stream recomputes the one consistent snapshot in `load()`.
    public func start() {
        stop()
        observations = [
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await _ in self.entries.observeAllDates() {
                        if Task.isCancelled { break }
                        await self.load()
                    }
                } catch {
                    // A dropped stream leaves the last good snapshot in place; the
                    // dot is a hint, not a gate, so there is nothing to surface.
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

    /// Cancels the observations.
    public func stop() {
        observations.forEach { $0.cancel() }
        observations.removeAll()
    }

    /// Recomputes the snapshot from the stores in one pass. Public so a test can
    /// drive it directly without the streams.
    public func load() async {
        let settings = await preferences.load()
        let nowMillis = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        let today = DayResolver.resolve(
            timestampMillis: nowMillis,
            changeHour: settings.dayChangeHour,
            changeMinute: settings.dayChangeMinute,
            timeZone: timeZone
        )
        let limits = AlcoholCalculator.getLimitInfo(settings)
        do {
            let todaysEntries = try entries.inRange(from: today, to: today)
            let todayGrams = todaysEntries.reduce(0.0) { $0 + $1.gramsAlcohol }

            let window = try weeklyWindow(endingOn: today)
            capacity = DrinkCapacity(
                todayGrams: todayGrams,
                dailyLimitGrams: limits.limitGrams,
                weeklyTotalGrams: window.reduce(0.0) { $0 + $1.totalGrams },
                weeklyLimitGrams: limits.weeklyLimitGrams,
                drinkDaysThisWeek: window.filter { $0.totalGrams > 0.0 }.count,
                maxDrinkDaysPerWeek: limits.maxDrinkDaysPerWeek
            )
        } catch {
            // Keep the last good snapshot on a read error.
        }
        useSymbols = settings.alternativeStatusSymbols
    }

    /// The trailing seven-day window: today and the six days before it. The same
    /// gliding window `TodayModel` uses, so the two screens agree day for day.
    private func weeklyWindow(endingOn today: String) throws -> [DaySummary] {
        guard let end = DayResolver.parseDate(today) else { return [] }
        let start = end.addingTimeInterval(-Double(AlcoholCalculator.windowDays - 1) * 86_400)
        return try entries.dailySummaries(from: DayResolver.formatDate(start), to: today)
    }

    deinit {
        observations.forEach { $0.cancel() }
    }
}
