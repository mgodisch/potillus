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

import XCTest
@testable import PotillusKit

// =============================================================================
// AppEnvironmentTests.swift – the wiring itself
// =============================================================================
//
// A composition root has no logic to test, only connections. What CAN go wrong
// is that two components end up talking to different databases, or that the
// importer writes to a preferences store nobody reads. Those are the assertions
// here.
// =============================================================================

final class AppEnvironmentTests: XCTestCase {

    /// The ephemeral environment must be usable end to end, since previews and
    /// screenshot runs depend on it.
    func testEphemeralEnvironmentIsFullyFunctional() async throws {
        let environment = try AppEnvironment.makeEphemeral()

        let drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer)
        )
        _ = try environment.entries.add(
            ConsumptionEntry(
                drinkId: drinkId, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: 19.3, timestampMillis: 1_000, logicalDate: "2026-01-01"
            )
        )

        XCTAssertEqual(try environment.entries.all().count, 1)

        // The await is hoisted: XCTAssert* takes autoclosures, which are
        // synchronous, so `await` cannot appear inside one.
        let settings = await environment.preferences.load()
        XCTAssertEqual(settings, AppSettings())
    }

    /// Both repositories must see the same rows, or a drink added on one screen
    /// would be invisible on the next.
    func testRepositoriesShareOneDatabase() throws {
        let environment = try AppEnvironment.makeEphemeral()

        let drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9)
        )
        XCTAssertEqual(try environment.drinks.countEntries(forDrink: drinkId), 0)

        _ = try environment.entries.add(
            ConsumptionEntry(
                drinkId: drinkId, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: 19.3, timestampMillis: 1_000, logicalDate: "2026-01-01"
            )
        )
        XCTAssertEqual(
            try environment.drinks.countEntries(forDrink: drinkId), 1,
            "the drink repository must see the entry repository's write"
        )
    }

    /// The importer must write into the same preferences store the UI observes,
    /// or a restored theme would not appear until the next launch.
    func testTheImporterWritesIntoTheObservedPreferencesStore() async throws {
        let environment = try AppEnvironment.makeEphemeral()

        let settings = BackupSettings(
            themeMode: "NIGHT", dayChangeHour: 4, dayChangeMinute: 0,
            dailyLimitGrams: 20.0, weeklyLimitGrams: 100.0, maxDrinkDaysPerWeek: 5,
            statsFromDate: "", biometricEnabled: false, allowScreenshots: false,
            alternativeStatusSymbols: false, language: "", weightKg: 0.0
        )
        let backup = BackupFile(
            version: 3, exportedAt: "2026-07-09T12:00:00Z",
            drinks: [], entries: [], settings: settings
        )

        try await environment.importer.restore(backup, mode: .replace)

        let stored = await environment.preferences.load()
        XCTAssertEqual(stored.themeMode, .night)
    }

    /// Two ephemeral environments must not share state, or one test would leak
    /// into the next.
    func testEphemeralEnvironmentsAreIsolated() async throws {
        let first = try AppEnvironment.makeEphemeral()
        let second = try AppEnvironment.makeEphemeral()

        _ = try first.drinks.add(DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9))
        try await first.preferences.update { $0.weightKg = 82.5 }

        XCTAssertEqual(try second.entries.all().count, 0)
        let secondSettings = await second.preferences.load()
        XCTAssertEqual(secondSettings.weightKg, 0.0, "preferences must not be shared")
    }
}
