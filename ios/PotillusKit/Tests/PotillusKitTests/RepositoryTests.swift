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
// RepositoryTests.swift – query semantics the UI depends on
// =============================================================================
//
// These are not vector-driven: the vectors cover pure calculation, whereas a
// repository's contract is about ORDERING, FILTERING and REFERENTIAL INTEGRITY.
// Each test names the Room DAO query it mirrors, so a reader can check the two
// implementations agree by reading them side by side.
//
// Every test runs against a real in-memory SQLite database, not a mock. Mocking
// the database would test the mock; the interesting failures (a wrong ORDER BY,
// a foreign key that is not enforced) only appear against SQLite itself.
// =============================================================================

final class RepositoryTests: XCTestCase {

    private var database: AppDatabase!
    private var drinks: DrinkRepository!
    private var entries: EntryRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try AppDatabase(inMemory: true)
        drinks = DrinkRepository(database: database)
        entries = EntryRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        drinks = nil
        entries = nil
        try super.tearDownWithError()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    @discardableResult
    private func addDrink(
        _ name: String,
        favorite: Bool = false,
        preset: Bool = false,
        category: DrinkCategory = .beer
    ) throws -> Int64 {
        try drinks.add(
            DrinkDefinition(
                name: name, volumeMl: 500, alcoholPercent: 4.9,
                isPreset: preset, isFavorite: favorite, category: category
            )
        )
    }

    @discardableResult
    private func addEntry(
        drinkId: Int64, at millis: Int64, on date: String, grams: Double = 10.0
    ) throws -> Int64 {
        try entries.add(
            ConsumptionEntry(
                drinkId: drinkId, drinkName: "x", volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: grams, timestampMillis: millis, logicalDate: date
            )
        )
    }

    /// Takes the first value an observation publishes. Observations emit their
    /// initial value immediately, so this never hangs on a populated database.
    private func firstValue<T>(_ stream: AsyncThrowingStream<T, Error>) async throws -> T {
        for try await value in stream { return value }
        throw XCTSkip("observation finished without emitting a value")
    }

    // ── Drinks ───────────────────────────────────────────────────────────────

    /// `SELECT * FROM drinks ORDER BY isFavorite DESC, name ASC`
    func testDrinksAreOrderedFavouritesFirstThenAlphabetically() async throws {
        try addDrink("Zwickel")
        try addDrink("Alt")
        try addDrink("Weizen", favorite: true)
        try addDrink("Bock", favorite: true)

        let observed = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(observed.map(\.name), ["Bock", "Weizen", "Alt", "Zwickel"])
    }

    func testAddReturnsTheAssignedRowId() throws {
        let first = try addDrink("A")
        let second = try addDrink("B")
        XCTAssertGreaterThan(second, first)
    }

    func testUpdatePersistsEveryField() async throws {
        let id = try addDrink("Pils")
        try drinks.update(
            DrinkDefinition(
                id: id, name: "Pils 0.33", volumeMl: 330, alcoholPercent: 5.2,
                isFavorite: true, category: .wine
            )
        )

        let observed = try await firstValue(drinks.observeDrinks())
        let updated = try XCTUnwrap(observed.first)
        XCTAssertEqual(updated.name, "Pils 0.33")
        XCTAssertEqual(updated.volumeMl, 330)
        XCTAssertEqual(updated.alcoholPercent, 5.2, accuracy: 1e-9)
        XCTAssertTrue(updated.isFavorite)
        XCTAssertEqual(updated.category, .wine)
    }

    /// `SELECT COUNT(*) FROM entries WHERE drinkId = ?` — the delete guard.
    func testCountEntriesForDrink() throws {
        let pils = try addDrink("Pils")
        let wine = try addDrink("Wine")
        try addEntry(drinkId: pils, at: 1_000, on: "2026-01-01")
        try addEntry(drinkId: pils, at: 2_000, on: "2026-01-01")

        XCTAssertEqual(try drinks.countEntries(forDrink: pils), 2)
        XCTAssertEqual(try drinks.countEntries(forDrink: wine), 0)
    }

    /// `ON DELETE RESTRICT`: history is never silently erased.
    /// The other direction of the same foreign key. Deleting a referenced drink is
    /// refused; so is inserting an entry that references nothing. Untested until
    /// the CalendarModel suite tripped over it, having invented a `drinkId` of 1.
    func testAnEntryAgainstAnUnknownDrinkIsRefused() throws {
        XCTAssertThrowsError(
            try entries.add(
                ConsumptionEntry(
                    drinkId: 999_999, drinkName: "ghost", volumeMl: 500, alcoholPercent: 4.9,
                    gramsAlcohol: 19.3, timestampMillis: 1_000, logicalDate: "2026-01-01"
                )
            ),
            "an entry may not reference a drink that does not exist"
        )
        XCTAssertTrue(try entries.all().isEmpty, "and nothing is stored")
    }

    func testDeletingADrinkWithEntriesThrows() throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-01")

        XCTAssertThrowsError(
            try drinks.delete(DrinkDefinition(id: id, name: "Pils", volumeMl: 500, alcoholPercent: 4.9))
        )
    }

    /// Presets survive a REPLACE import; user-created drinks do not.
    func testDeleteUserCreatedDrinksKeepsPresets() async throws {
        try addDrink("Preset", preset: true)
        try addDrink("Mine")

        try drinks.deleteUserCreatedDrinks()

        let observed = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(observed.map(\.name), ["Preset"])
    }

    /// An unknown category string decays to `.other` rather than throwing, so a
    /// database written by a newer version still opens.
    func testUnknownCategoryDecaysToOther() throws {
        try database.write { db in
            var record = Drink(
                name: "Mystery", volumeMl: 100, alcoholPercent: 1.0, category: "CIDER"
            )
            try record.insert(db)
        }
        let stored = try database.read { db in try Drink.fetchAll(db) }
        XCTAssertEqual(stored.first?.domain.category, .other)
    }

    // ── Entries ──────────────────────────────────────────────────────────────

    /// `... WHERE logicalDate = ? ORDER BY timestampMillis ASC`
    func testEntriesForDateAreOldestFirstAndFilteredByLogicalDate() async throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 3_000, on: "2026-01-01")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-01")
        try addEntry(drinkId: id, at: 2_000, on: "2026-01-02")

        let observed = try await firstValue(entries.observeEntries(forDate: "2026-01-01"))
        XCTAssertEqual(observed.map(\.timestampMillis), [1_000, 3_000])
    }

    /// The GROUP BY summary query, the backbone of every statistic.
    func testDailySummariesGroupSumAndCount() async throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-01", grams: 10.0)
        try addEntry(drinkId: id, at: 2_000, on: "2026-01-01", grams: 5.5)
        try addEntry(drinkId: id, at: 3_000, on: "2026-01-03", grams: 7.0)

        let observed = try await firstValue(
            entries.observeDailySummaries(from: "2026-01-01", to: "2026-01-31")
        )
        XCTAssertEqual(observed.count, 2, "days without entries are absent, not zero rows")
        XCTAssertEqual(observed[0].date, "2026-01-01")
        XCTAssertEqual(observed[0].totalGrams, 15.5, accuracy: 1e-9)
        XCTAssertEqual(observed[0].entryCount, 2)
        XCTAssertEqual(observed[1].date, "2026-01-03")
    }

    /// The range bounds are inclusive, and the lexicographic comparison on
    /// `yyyy-MM-dd` is exactly chronological.
    func testDailySummaryRangeBoundsAreInclusive() async throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-01")
        try addEntry(drinkId: id, at: 2_000, on: "2026-01-05")
        try addEntry(drinkId: id, at: 3_000, on: "2026-01-06")

        let observed = try await firstValue(
            entries.observeDailySummaries(from: "2026-01-01", to: "2026-01-05")
        )
        XCTAssertEqual(observed.map(\.date), ["2026-01-01", "2026-01-05"])
    }

    func testAllDatesAreDistinctAndAscending() async throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-02")
        try addEntry(drinkId: id, at: 2_000, on: "2026-01-02")
        try addEntry(drinkId: id, at: 3_000, on: "2026-01-01")

        let observed = try await firstValue(entries.observeAllDates())
        XCTAssertEqual(observed, ["2026-01-01", "2026-01-02"])
    }

    /// Ordered by CONSUMPTION time, not by row id: a back-dated entry logged
    /// today must not become "the most recent drink".
    func testMostRecentEntryUsesTimestampNotInsertionOrder() async throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 5_000, on: "2026-01-05")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-01")  // back-dated, inserted last

        let observed = try await firstValue(entries.observeMostRecentEntry())
        XCTAssertEqual(observed?.timestampMillis, 5_000)
    }

    func testMostRecentEntryIsNilOnAnEmptyLog() async throws {
        let observed = try await firstValue(entries.observeMostRecentEntry())
        XCTAssertNil(observed)
    }

    /// The de-duplication guard for MERGE imports: timestamp plus drink.
    func testExistsDetectsADuplicateByTimestampAndDrink() throws {
        let pils = try addDrink("Pils")
        let wine = try addDrink("Wine")
        try addEntry(drinkId: pils, at: 1_000, on: "2026-01-01")

        XCTAssertTrue(try entries.exists(timestampMillis: 1_000, drinkId: pils))
        XCTAssertFalse(try entries.exists(timestampMillis: 1_000, drinkId: wine))
        XCTAssertFalse(try entries.exists(timestampMillis: 2_000, drinkId: pils))
    }

    func testDeleteAllEmptiesTheLogButKeepsDrinks() async throws {
        let id = try addDrink("Pils")
        try addEntry(drinkId: id, at: 1_000, on: "2026-01-01")

        try entries.deleteAll()

        XCTAssertTrue(try entries.all().isEmpty)
        let remaining = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(remaining.count, 1, "clearing the log must not clear the catalogue")
    }

    func testEntriesRoundTripEveryFieldIncludingTheNote() throws {
        let id = try addDrink("Pils")
        let entry = ConsumptionEntry(
            drinkId: id, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.3, timestampMillis: 1_748_142_000_000,
            logicalDate: "2025-05-24", note: "at the pub"
        )
        let newId = try entries.add(entry)

        let stored = try XCTUnwrap(try entries.all().first)
        XCTAssertEqual(stored.id, newId)
        XCTAssertEqual(stored.note, "at the pub")
        XCTAssertEqual(stored.gramsAlcohol, 19.3, accuracy: 1e-9)
        XCTAssertEqual(stored.logicalDate, "2025-05-24")
    }

    // ── Observation ──────────────────────────────────────────────────────────

    /// An observation must publish again after a committed write, which is what
    /// makes the SwiftUI views self-updating (the `Flow` contract on Android).
    func testObservationEmitsAgainAfterAWrite() async throws {
        try addDrink("First")

        var iterator = drinks.observeDrinks().makeAsyncIterator()
        let initial = try await iterator.next()
        XCTAssertEqual(initial?.count, 1)

        try addDrink("Second")

        let updated = try await iterator.next()
        XCTAssertEqual(updated?.count, 2, "a committed write must produce a new value")
    }
}
