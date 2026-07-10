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
// EntryLoggerTests.swift – one derivation, two screens
// =============================================================================
//
// The Today screen and the Drinks screen both log drinks. The point of
// `EntryLogger` is that they cannot produce differently-shaped entries; these
// tests pin the derivation itself.
// =============================================================================

@MainActor
final class EntryLoggerTests: XCTestCase {

    private var environment: AppEnvironment!

    /// 2026-01-02, 20:14:00 UTC.
    private let evening: Int64 = 1_767_384_840_000

    /// 2026-01-03, 02:00:00 UTC — before the 04:00 day change.
    private let afterMidnight: Int64 = 1_767_405_600_000

    private let utc = TimeZone(identifier: "UTC")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
    }

    private func makeLogger(at millis: Int64) -> EntryLogger {
        EntryLogger(
            entries: environment.entries,
            preferences: environment.preferences,
            clock: FixedClock(millis: millis),
            timeZone: utc
        )
    }

    private func pils() -> DrinkDefinition {
        DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer)
    }

    // ── The pure derivation ──────────────────────────────────────────────────

    /// Grams follow from volume and strength. A caller may not supply them.
    func testGramsAreDerivedFromVolumeAndStrength() {
        let entry = EntryLogger.makeEntry(
            drink: pils(), volumeMl: 500, timestampMillis: evening, note: "",
            settings: AppSettings(), timeZone: utc
        )
        XCTAssertEqual(
            entry.gramsAlcohol,
            AlcoholCalculator.calculateGrams(volumeMl: 500, alcoholPercent: 4.9),
            accuracy: 1e-9
        )
    }

    /// A drink at 02:00 belongs to the previous evening, because the user's day
    /// changes at 04:00 — not at midnight.
    func testTheLogicalDateFollowsTheDayChangeHourNotTheCalendar() {
        let entry = EntryLogger.makeEntry(
            drink: pils(), volumeMl: 500, timestampMillis: afterMidnight, note: "",
            settings: AppSettings(), timeZone: utc
        )
        XCTAssertEqual(entry.logicalDate, "2026-01-02")
    }

    /// A user who changes the day-change hour changes which day a drink lands on.
    func testAnEarlierDayChangeHourMovesTheEntryToTheNewDay() {
        var settings = AppSettings()
        settings.dayChangeHour = 1

        let entry = EntryLogger.makeEntry(
            drink: pils(), volumeMl: 500, timestampMillis: afterMidnight, note: "",
            settings: settings, timeZone: utc
        )
        XCTAssertEqual(entry.logicalDate, "2026-01-03", "02:00 is past a 01:00 change")
    }

    /// The drink's name and strength are copied into the entry, so a later rename
    /// or correction does not rewrite history.
    func testTheEntryCarriesTheDrinksNameAndStrengthAtTheTimeOfLogging() {
        let entry = EntryLogger.makeEntry(
            drink: pils(), volumeMl: 330, timestampMillis: evening, note: "on the terrace",
            settings: AppSettings(), timeZone: utc
        )
        XCTAssertEqual(entry.drinkId, 1)
        XCTAssertEqual(entry.drinkName, "Pils")
        XCTAssertEqual(entry.alcoholPercent, 4.9, accuracy: 1e-9)
        XCTAssertEqual(entry.volumeMl, 330)
        XCTAssertEqual(entry.note, "on the terrace")
    }

    // ── Storing ──────────────────────────────────────────────────────────────

    func testLoggingStoresTheEntryAndDefaultsToNow() async throws {
        let drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9)
        )
        let drink = try XCTUnwrap(try environment.drinks.allOnce().first { $0.id == drinkId })

        let logger = makeLogger(at: evening)
        _ = try await logger.log(drink: drink, volumeMl: 500)

        let stored = try XCTUnwrap(try environment.entries.all().first)
        XCTAssertEqual(stored.timestampMillis, evening, "the clock supplies 'now'")
        XCTAssertEqual(stored.logicalDate, "2026-01-02")
    }

    /// The Drinks screen logs the same entry the Today screen would.
    func testBothScreensProduceTheSameEntry() async throws {
        let drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9)
        )
        let drink = try XCTUnwrap(try environment.drinks.allOnce().first { $0.id == drinkId })

        // The Drinks screen's path.
        let logger = makeLogger(at: evening)
        _ = try await logger.log(drink: drink, volumeMl: 500, timestampMillis: evening)

        // The Today screen's path.
        let today = TodayModel(
            entries: environment.entries, drinks: environment.drinks,
            preferences: environment.preferences,
            clock: FixedClock(millis: evening), timeZone: utc
        )
        await today.load()
        await today.addEntry(drink: drink, volumeMl: 500, timestampMillis: evening)

        let stored = try environment.entries.all()
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(stored[0].gramsAlcohol, stored[1].gramsAlcohol, accuracy: 1e-12)
        XCTAssertEqual(stored[0].logicalDate, stored[1].logicalDate)
        XCTAssertEqual(stored[0].drinkId, stored[1].drinkId)
    }

    // ── The pre-selection ────────────────────────────────────────────────────

    /// The sheet opens on the drink most recently logged, not the most frequent:
    /// people repeat what they just had.
    func testTheLastUsedDrinkIsTheMostRecentlyLoggedOne() async throws {
        let pilsId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9)
        )
        let wineId = try environment.drinks.add(
            DrinkDefinition(name: "Wine", volumeMl: 200, alcoholPercent: 13)
        )
        let catalogue = try environment.drinks.allOnce()
        let pils = try XCTUnwrap(catalogue.first { $0.id == pilsId })
        let wine = try XCTUnwrap(catalogue.first { $0.id == wineId })

        let logger = makeLogger(at: evening)
        // Pils twice, wine once — but wine last.
        _ = try await logger.log(drink: pils, volumeMl: 500, timestampMillis: evening - 7_200_000)
        _ = try await logger.log(drink: pils, volumeMl: 500, timestampMillis: evening - 3_600_000)
        _ = try await logger.log(drink: wine, volumeMl: 200, timestampMillis: evening)

        let model = TodayModel(
            entries: environment.entries, drinks: environment.drinks,
            preferences: environment.preferences,
            clock: FixedClock(millis: evening), timeZone: utc
        )
        await model.load()

        XCTAssertEqual(model.state.lastUsedDrink?.name, "Wine")
        XCTAssertEqual(model.state.drinks.count, 2, "the sheet can pick from the whole catalogue")
    }

    func testAnEmptyLogHasNoPreselection() async throws {
        let model = TodayModel(
            entries: environment.entries, drinks: environment.drinks,
            preferences: environment.preferences,
            clock: FixedClock(millis: evening), timeZone: utc
        )
        await model.load()
        XCTAssertNil(model.state.lastUsedDrink)
    }

    // ── The observable wrapper ───────────────────────────────────────────────

    func testTheLogModelReportsSuccessAndClearsItsFailure() async throws {
        let drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9)
        )
        let drink = try XCTUnwrap(try environment.drinks.allOnce().first { $0.id == drinkId })

        let model = EntryLogModel(logger: makeLogger(at: evening))
        let stored = await model.log(drink: drink, volumeMl: 500)

        XCTAssertTrue(stored)
        XCTAssertNil(model.failure)
        XCTAssertEqual(try environment.entries.all().count, 1)
    }
}
