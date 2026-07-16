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
import GRDB
@testable import PotillusKit

// =============================================================================
// AppDatabaseSeedTests.swift – the catalogue is not empty after a fresh install
// =============================================================================
//
// WHAT WENT WRONG, AND WHY NO TEST SAW IT
//   The Swift port carried Room's SCHEMA across but not Room's `onCreate`
//   callback, so a fresh install came up with an empty drinks catalogue. Every
//   existing test builds its database with `AppDatabase(inMemory:)` and then
//   inserts the rows it needs, so an empty fresh database was exactly what they
//   all expected — the bug was invisible to the entire suite by construction.
//
//   These tests therefore exercise `openOrCreate` against a REAL FILE, because
//   the thing that was broken is the file-creation path itself, not the schema
//   and not the insert. A test that seeded by hand and then counted rows would
//   have passed against the broken code.
//
// WHY NOT COMPARE AGAINST A SHARED VECTOR
//   The preset list is a cross-platform contract, and the project pins such
//   contracts in `test-vectors/` so neither platform can drift alone (see
//   `test-vectors/README.md`). The preset catalogue is NOT pinned there yet —
//   that absence is what let this port lose the seed unnoticed. Until the vector
//   exists, these assertions are the Swift side's own guard: they pin the count,
//   the flags and one full row, so a silent truncation of the list fails here.
// =============================================================================

final class AppDatabaseSeedTests: XCTestCase {

    /// A unique path per test, inside the temp directory. Not created — the
    /// point is that `openOrCreate` finds it ABSENT.
    private var dbPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).sqlite")
            .path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: dbPath)
        dbPath = nil
        try super.tearDownWithError()
    }

    private func catalogue(_ database: AppDatabase) throws -> [Drink] {
        try database.read { db in
            try Drink.order(Column("id").asc).fetchAll(db)
        }
    }

    // ── The seed itself ──────────────────────────────────────────────────────

    /// The regression test for the reported bug: install, open, see drinks.
    func testAFreshDatabaseComesUpWithTheBuiltInPresets() throws {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: dbPath),
            "precondition: this must look like a first install"
        )

        let database = try AppDatabase.openOrCreate(path: dbPath)
        let drinks = try catalogue(database)

        XCTAssertEqual(drinks.count, 15, "the full preset set is inserted")
        XCTAssertTrue(drinks.allSatisfy(\.isPreset), "every seeded drink is a preset")
        XCTAssertTrue(drinks.allSatisfy { !$0.isFavorite }, "nothing is starred for the user")
    }

    /// Pins one row completely, so a mangled value in the list is caught rather
    /// than merely a mangled count.
    func testTheSeededRowsCarryTheirAndroidValues() throws {
        let database = try AppDatabase.openOrCreate(path: dbPath)
        let drinks = try catalogue(database)

        let pint = try XCTUnwrap(drinks.first { $0.name == "Lager (Pint)" })
        XCTAssertEqual(pint.volumeMl, 568)
        XCTAssertEqual(pint.alcoholPercent, 4.5)
        XCTAssertEqual(pint.category, DrinkCategory.beer.rawValue)

        // The categories the list actually uses. `other` is deliberately absent:
        // it is the fallback for an unknown stored string, not a seeded value.
        XCTAssertEqual(
            Set(drinks.map(\.category)),
            [
                DrinkCategory.beer.rawValue,
                DrinkCategory.wine.rawValue,
                DrinkCategory.spirits.rawValue,
                DrinkCategory.longdrink.rawValue,
                DrinkCategory.liqueur.rawValue,
            ]
        )
    }

    // ── The seed happens exactly once ────────────────────────────────────────

    /// Reopening an existing database must not seed again — otherwise every
    /// launch would pile on another fifteen rows.
    func testReopeningAnExistingDatabaseDoesNotSeedAgain() throws {
        _ = try AppDatabase.openOrCreate(path: dbPath)
        let reopened = try AppDatabase.openOrCreate(path: dbPath)

        XCTAssertEqual(try catalogue(reopened).count, 15, "the second open added nothing")
    }

    /// The user's deletions stick. This is the case the `fileExists` probe
    /// exists for: an empty catalogue on an EXISTING database is a state the
    /// user chose (a REPLACE import, or deleting the lot), and the next launch
    /// must respect it rather than undo it.
    func testAnEmptiedCatalogueStaysEmptyOnTheNextLaunch() throws {
        let database = try AppDatabase.openOrCreate(path: dbPath)
        try database.write { db in
            _ = try Drink.deleteAll(db)
        }

        let reopened = try AppDatabase.openOrCreate(path: dbPath)

        XCTAssertTrue(
            try catalogue(reopened).isEmpty,
            "a deliberately emptied catalogue must not be re-seeded"
        )
    }

    // ── The other entry points stay empty ────────────────────────────────────

    /// `init(inMemory:)` must NOT seed. The whole test suite, and the screenshot
    /// run, build their fixtures on the assumption that it comes up empty; this
    /// test states that assumption out loud so a future "seed from the migrator"
    /// refactor fails here instead of in thirty unrelated tests.
    func testAnInMemoryDatabaseIsStillEmpty() throws {
        let database = try AppDatabase(inMemory: true)

        XCTAssertTrue(try catalogue(database).isEmpty, "test databases seed themselves")
    }
}
