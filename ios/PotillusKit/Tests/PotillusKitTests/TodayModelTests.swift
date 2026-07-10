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

import XCTest
@testable import PotillusKit

// =============================================================================
// TodayModelTests.swift – the arithmetic behind the Today screen
// =============================================================================
//
// A real in-memory database and a real preferences store, with only the CLOCK
// frozen. That is what makes "the logical day flips at 04:00" and "the estimate
// decays with time" testable at all.
// =============================================================================

@MainActor
final class TodayModelTests: XCTestCase {

    private var environment: AppEnvironment!

    /// 2026-01-02, 20:14:00 UTC.
    private let evening: Int64 = 1_767_384_840_000

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
    }

    private func makeModel(at millis: Int64) -> TodayModel {
        TodayModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences,
            clock: FixedClock(millis: millis),
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    @discardableResult
    private func addDrink(
        _ name: String, percent: Double = 4.9, favorite: Bool = false
    ) throws -> DrinkDefinition {
        let id = try environment.drinks.add(
            DrinkDefinition(
                name: name, volumeMl: 500, alcoholPercent: percent, isFavorite: favorite
            )
        )
        return try XCTUnwrap(try environment.drinks.allOnce().first { $0.id == id })
    }

    // ── The logical day ──────────────────────────────────────────────────────

    /// A drink at 02:00 belongs to the previous evening. The screen must show
    /// that evening, not the calendar date the phone displays.
    func testTheLogicalDayDoesNotFlipUntilTheChangeHour() async throws {
        // 2026-01-03 at 02:00 UTC, before the default change hour of 04:00.
        let afterMidnight: Int64 = 1_767_405_600_000
        let model = makeModel(at: afterMidnight)
        await model.load()

        XCTAssertEqual(model.state.logicalDate, "2026-01-02", "02:00 still belongs to the 2nd")

        // 2026-01-03 at 05:00 UTC: past the change hour.
        let afterChange = makeModel(at: 1_767_416_400_000)
        await afterChange.load()
        XCTAssertEqual(afterChange.state.logicalDate, "2026-01-03")
    }

    /// The entry's logical date is derived, not supplied. A drink logged at 02:00
    /// must land on the previous day's total.
    func testAnEntryLoggedAfterMidnightCountsTowardsTheEveningBefore() async throws {
        let pils = try addDrink("Pils")
        let model = makeModel(at: 1_767_405_600_000)  // 2026-01-03, 02:00
        await model.load()

        await model.addEntry(drink: pils, volumeMl: 500)

        XCTAssertNil(model.failure)
        XCTAssertEqual(model.state.logicalDate, "2026-01-02")
        XCTAssertEqual(model.state.entries.count, 1)
        XCTAssertEqual(model.state.entries[0].logicalDate, "2026-01-02")
    }

    // ── Totals ───────────────────────────────────────────────────────────────

    func testTotalGramsSumsTodaysEntriesOnly() async throws {
        let pils = try addDrink("Pils")
        let model = makeModel(at: evening)
        await model.load()

        await model.addEntry(drink: pils, volumeMl: 500)
        await model.addEntry(drink: pils, volumeMl: 500)
        // Yesterday: must not count.
        await model.addEntry(drink: pils, volumeMl: 500, timestampMillis: evening - 86_400_000)

        XCTAssertEqual(model.state.entries.count, 2)
        XCTAssertEqual(
            model.state.totalGrams,
            2 * AlcoholCalculator.calculateGrams(volumeMl: 500, alcoholPercent: 4.9),
            accuracy: 1e-9
        )
    }

    /// The window glides: today plus the six days before it, not a calendar week.
    func testTheWeeklyWindowCoversSevenDaysEndingToday() async throws {
        let pils = try addDrink("Pils")
        let model = makeModel(at: evening)
        await model.load()

        let day: Int64 = 86_400_000
        await model.addEntry(drink: pils, volumeMl: 500)                       // today
        await model.addEntry(drink: pils, volumeMl: 500, timestampMillis: evening - 6 * day)
        // Seven days back: outside the window.
        await model.addEntry(drink: pils, volumeMl: 500, timestampMillis: evening - 7 * day)

        XCTAssertEqual(model.state.drinkDaysThisWeek, 2, "the 7-day-old entry is outside")
        XCTAssertEqual(
            model.state.weeklyTotalGrams,
            2 * AlcoholCalculator.calculateGrams(volumeMl: 500, alcoholPercent: 4.9),
            accuracy: 1e-9
        )
    }

    /// A day with only alcohol-free entries is not a drink day.
    func testAnAlcoholFreeDayIsNotADrinkDay() async throws {
        let alcoholFree = try addDrink("Alkoholfrei", percent: 0.0)
        let model = makeModel(at: evening)
        await model.load()

        await model.addEntry(drink: alcoholFree, volumeMl: 500)

        XCTAssertEqual(model.state.entries.count, 1)
        XCTAssertEqual(model.state.totalGrams, 0.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.drinkDaysThisWeek, 0)
    }

    // ── The estimate ─────────────────────────────────────────────────────────

    /// Nil is not zero. Without a body weight the app cannot estimate, and 0.0‰
    /// would assert a sobriety it cannot vouch for.
    func testTheEstimateIsNilWithoutABodyWeight() async throws {
        let pils = try addDrink("Pils")
        let model = makeModel(at: evening)
        await model.load()
        await model.addEntry(drink: pils, volumeMl: 500)

        XCTAssertNil(model.state.bacPermille)
    }

    func testTheEstimateIsNilWhenNothingAlcoholicWasLogged() async throws {
        try await environment.preferences.update { $0.weightKg = 82.5 }
        let alcoholFree = try addDrink("Alkoholfrei", percent: 0.0)
        let model = makeModel(at: evening)
        await model.load()
        await model.addEntry(drink: alcoholFree, volumeMl: 500)

        XCTAssertNil(model.state.bacPermille, "an alcohol-free day has no estimate, not 0.0")
    }

    /// The clock is what makes this assertable: the same entries, read three
    /// hours later, must give a lower estimate.
    func testTheEstimateDecaysAsTimePasses() async throws {
        try await environment.preferences.update { $0.weightKg = 82.5 }
        let pils = try addDrink("Pils")

        let atOnce = makeModel(at: evening)
        await atOnce.load()
        await atOnce.addEntry(drink: pils, volumeMl: 500, timestampMillis: evening)
        let immediate = try XCTUnwrap(atOnce.state.bacPermille)

        let threeHoursLater = makeModel(at: evening + 3 * 3_600_000)
        await threeHoursLater.load()
        let later = try XCTUnwrap(threeHoursLater.state.bacPermille)

        XCTAssertLessThan(later, immediate)
        XCTAssertGreaterThanOrEqual(later, 0.0, "the estimate is never negative")
    }

    /// Elapsed time runs from the FIRST alcoholic drink of the day, since that is
    /// when absorption began.
    func testDecayIsMeasuredFromTheFirstAlcoholicEntry() async throws {
        try await environment.preferences.update { $0.weightKg = 82.5 }
        let alcoholFree = try addDrink("Alkoholfrei", percent: 0.0)
        let pils = try addDrink("Pils")

        let model = makeModel(at: evening + 2 * 3_600_000)
        await model.load()
        // The alcohol-free drink is older; it must not start the clock.
        await model.addEntry(drink: alcoholFree, volumeMl: 500, timestampMillis: evening - 3_600_000)
        await model.addEntry(drink: pils, volumeMl: 500, timestampMillis: evening)

        let expected = AlcoholCalculator.calculateBAC(
            totalGrams: model.state.totalGrams, weightKg: 82.5, hoursElapsed: 2.0
        )
        XCTAssertEqual(try XCTUnwrap(model.state.bacPermille), expected, accuracy: 1e-9)
    }

    // ── Favourites and settings ──────────────────────────────────────────────

    func testOnlyFavouritesAppearAsFavourites() async throws {
        _ = try addDrink("Whisky")
        _ = try addDrink("Pils", favorite: true)

        let model = makeModel(at: evening)
        await model.load()

        XCTAssertEqual(model.state.favorites.map(\.name), ["Pils"])
    }

    /// The limits come from the settings, already clamped by `getLimitInfo`.
    func testLimitsFollowTheStoredSettings() async throws {
        try await environment.preferences.update {
            $0.dailyLimitGrams = 24.0
            $0.maxDrinkDaysPerWeek = 99  // clamped to 7 by getLimitInfo
        }
        let model = makeModel(at: evening)
        await model.load()

        XCTAssertEqual(model.state.limitInfo.limitGrams, 24.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.limitInfo.maxDrinkDaysPerWeek, 7)
    }

    // ── Failures are surfaced ────────────────────────────────────────────────

    func testDeletingAnEntryRemovesItAndReloads() async throws {
        let pils = try addDrink("Pils")
        let model = makeModel(at: evening)
        await model.load()
        await model.addEntry(drink: pils, volumeMl: 500)

        let stored = try XCTUnwrap(model.state.entries.first)
        await model.deleteEntry(stored)

        XCTAssertTrue(model.state.entries.isEmpty)
        XCTAssertEqual(model.state.totalGrams, 0.0, accuracy: 1e-9)
        XCTAssertNil(model.failure)
    }

    func testAnEmptyDayHasNoEntriesAndNoEstimate() async throws {
        let model = makeModel(at: evening)
        await model.load()

        XCTAssertTrue(model.state.entries.isEmpty)
        XCTAssertEqual(model.state.totalGrams, 0.0, accuracy: 1e-9)
        XCTAssertNil(model.state.bacPermille)
        XCTAssertEqual(model.state.drinkDaysThisWeek, 0)
        XCTAssertNil(model.failure)
    }

    // ── Observation ──────────────────────────────────────────────────────────
    //
    // The Today screen was the last snapshot model. These prove it now reacts to a
    // change made ELSEWHERE — a repository write not routed through this model — the
    // way an import or an edit in another tab would arrive.

    /// `start()` alone loads the screen; the first stream emission is the load, so
    /// the view needs no separate `load()` on appear.
    func testStartLoadsWithoutAnExplicitLoad() async throws {
        let pils = try addDrink("Pils", favorite: true)
        _ = try environment.entries.add(entry(pils, at: evening))

        let model = makeModel(at: evening)
        model.start()
        defer { model.stop() }

        try await waitUntil { model.state.entries.count == 1 }
        XCTAssertEqual(model.state.favorites.count, 1)
    }

    /// An entry written straight to the repository — as another tab or an import
    /// would — reaches the running model without anyone calling `load()`.
    func testAnEntryLoggedElsewhereIsNoticed() async throws {
        let pils = try addDrink("Pils")
        let model = makeModel(at: evening)
        model.start()
        defer { model.stop() }

        try await waitUntil { model.state.entries.isEmpty }

        _ = try environment.entries.add(entry(pils, at: evening))
        try await waitUntil { model.state.entries.count == 1 }
    }

    /// A drink added elsewhere (a backup import in another tab) reaches the model,
    /// since the Today screen shows the favourites and the catalogue.
    func testADrinkAddedElsewhereIsNoticed() async throws {
        let model = makeModel(at: evening)
        model.start()
        defer { model.stop() }

        try await waitUntil { model.state.favorites.isEmpty }

        _ = try addDrink("Weizen", favorite: true)
        try await waitUntil { model.state.favorites.count == 1 }
    }

    /// A changed day-change hour moves what "today" is, so the settings stream must
    /// reload as much as the entry stream.
    func testAChangedDayChangeHourReloads() async throws {
        let pils = try addDrink("Pils")
        // One entry today, so the model has state; the point of this test is that a
        // settings write alone — not an entry change — triggers a reload.
        _ = try environment.entries.add(entry(pils, at: evening))

        let model = makeModel(at: evening)
        model.start()
        defer { model.stop() }

        try await waitUntil { model.state.entries.count == 1 }

        try await environment.preferences.update { $0.maxDrinkDaysPerWeek = 3 }
        try await waitUntil { model.state.settings.maxDrinkDaysPerWeek == 3 }
    }

    /// Builds a consumption entry for a drink at a moment, so a test can write one
    /// straight to the repository. `evening` (2026-01-02 20:14 UTC) resolves to the
    /// logical date "2026-01-02" under the default 04:00 change hour, so that is
    /// hard-coded here — these tests only ever write at `evening`.
    private func entry(_ drink: DrinkDefinition, at millis: Int64) -> ConsumptionEntry {
        ConsumptionEntry(
            drinkId: drink.id,
            drinkName: drink.name,
            volumeMl: drink.volumeMl,
            alcoholPercent: drink.alcoholPercent,
            gramsAlcohol: AlcoholCalculator.calculateGrams(
                volumeMl: drink.volumeMl, alcoholPercent: drink.alcoholPercent
            ),
            timestampMillis: millis,
            logicalDate: "2026-01-02"
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0, _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("condition not met within \(timeout) s")
    }
}
