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
// DrinksModelTests.swift – the catalogue, and what it refuses
// =============================================================================
//
// Against a real in-memory database. The interesting cases are the refusals: a
// write the validator rejects must not reach the database, and a delete must not
// orphan an entry.
// =============================================================================

@MainActor
final class DrinksModelTests: XCTestCase {

    private var environment: AppEnvironment!
    private var model: DrinksModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
        model = DrinksModel(drinks: environment.drinks)
    }

    override func tearDown() async throws {
        model.stop()
        try await super.tearDown()
    }

    /// The observation is asynchronous; the repositories are not. Tests that only
    /// care about what reached the database read it directly.
    private func stored() throws -> [DrinkDefinition] {
        try environment.drinks.allOnce()
    }

    // ── Adding ───────────────────────────────────────────────────────────────

    func testAValidDrinkIsStored() throws {
        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))

        let catalogue = try stored()
        XCTAssertEqual(catalogue.map(\.name), ["Pils"])
        XCTAssertNil(model.violation)
    }

    /// The name is stored trimmed, by the helper that measured it. Validating one
    /// string and persisting another is how an over-long name reaches the table.
    func testTheStoredNameIsTrimmed() throws {
        XCTAssertTrue(model.add(name: "  Pils  ", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        XCTAssertEqual(try stored().first?.name, "Pils")
    }

    func testAnInvalidDrinkIsRejectedAndNothingIsStored() throws {
        XCTAssertFalse(model.add(name: "", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        XCTAssertEqual(model.violation, .init(field: .name, reason: .blank))
        XCTAssertTrue(try stored().isEmpty)

        XCTAssertFalse(model.add(name: "Pils", volumeMl: 0, alcoholPercent: 4.9, category: .beer))
        XCTAssertEqual(model.violation, .init(field: .volumeMl, reason: .outOfRange))

        XCTAssertFalse(model.add(name: "Pils", volumeMl: 500, alcoholPercent: .nan, category: .beer))
        XCTAssertEqual(model.violation, .init(field: .alcoholPercent, reason: .notFinite))

        XCTAssertTrue(try stored().isEmpty, "no rejected write may reach the database")
    }

    /// A drink of 5001 ml is a typo, and the model says which field is wrong.
    func testTheVolumeBoundIsEnforcedByTheModelNotOnlyTheView() throws {
        XCTAssertFalse(model.add(name: "Pils", volumeMl: 5_001, alcoholPercent: 4.9, category: .beer))
        XCTAssertEqual(model.violation, .init(field: .volumeMl, reason: .outOfRange))
    }

    // ── Updating ─────────────────────────────────────────────────────────────

    func testAnUpdateIsValidatedLikeAnAdd() throws {
        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        var drink = try XCTUnwrap(try stored().first)

        drink.volumeMl = 0
        XCTAssertFalse(model.update(drink), "update must not trust its caller")
        XCTAssertEqual(model.violation, .init(field: .volumeMl, reason: .outOfRange))
        XCTAssertEqual(try stored().first?.volumeMl, 500, "the old value survives")
    }

    func testTogglingAFavouriteGoesThroughValidation() throws {
        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        let drink = try XCTUnwrap(try stored().first)
        XCTAssertFalse(drink.isFavorite)

        XCTAssertTrue(model.toggleFavorite(drink))
        XCTAssertTrue(try XCTUnwrap(try stored().first).isFavorite)

        XCTAssertTrue(model.toggleFavorite(try XCTUnwrap(try stored().first)))
        XCTAssertFalse(try XCTUnwrap(try stored().first).isFavorite)
    }

    // ── Deleting ─────────────────────────────────────────────────────────────

    func testAnUnusedDrinkIsDeleted() throws {
        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        let drink = try XCTUnwrap(try stored().first)

        XCTAssertTrue(model.delete(drink))
        XCTAssertTrue(try stored().isEmpty)
        XCTAssertNil(model.deleteBlocked)
    }

    /// The guard exists so the user reads "Pils is used by 1 entry" rather than a
    /// SQLite foreign-key error.
    func testADrinkWithEntriesIsNotDeletedAndSaysWhy() throws {
        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        let drink = try XCTUnwrap(try stored().first)

        _ = try environment.entries.add(
            ConsumptionEntry(
                drinkId: drink.id, drinkName: drink.name, volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: 19.3, timestampMillis: 1_000, logicalDate: "2026-01-01"
            )
        )

        XCTAssertFalse(model.delete(drink))
        XCTAssertEqual(model.deleteBlocked, DeleteBlocked(drinkName: "Pils", entryCount: 1))
        XCTAssertEqual(try stored().count, 1, "the drink survives")
        XCTAssertNil(model.failure, "a blocked delete is not a failure")
    }

    // ── The error surface ────────────────────────────────────────────────────

    /// A successful write must clear the previous complaint, or the view keeps
    /// showing an error about a field the user has since fixed.
    func testASuccessfulWriteClearsThePreviousViolation() throws {
        XCTAssertFalse(model.add(name: "", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        XCTAssertNotNil(model.violation)

        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        XCTAssertNil(model.violation)
    }

    func testClearErrorsResetsEverything() throws {
        XCTAssertFalse(model.add(name: "", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        model.clearErrors()
        XCTAssertNil(model.violation)
        XCTAssertNil(model.deleteBlocked)
        XCTAssertNil(model.failure)
    }

    // ── Observation ──────────────────────────────────────────────────────────

    /// The catalogue arrives through the stream, favourites first.
    func testObservationDeliversTheCatalogueFavouritesFirst() async throws {
        XCTAssertTrue(model.add(name: "Whisky", volumeMl: 40, alcoholPercent: 40, category: .spirits))
        XCTAssertTrue(model.add(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer))
        let pils = try XCTUnwrap(try stored().first { $0.name == "Pils" })
        XCTAssertTrue(model.toggleFavorite(pils))

        model.start()
        try await waitUntil { self.model.state.drinks.count == 2 }

        XCTAssertEqual(model.state.drinks.map(\.name), ["Pils", "Whisky"])
    }

    /// Polls the main actor until `condition` holds. The observation is a stream,
    /// so there is no completion to await; a fixed sleep would be flaky.
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
