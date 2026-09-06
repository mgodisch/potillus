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

import GRDB
import XCTest

@testable import PotillusKit

// =============================================================================
// The v4 migration, pinned the way Android's `MigrationTest` pins `MIGRATION_3_4`
// =============================================================================
//
// `SchemaParityTests` proves that a FRESH database ends up with the contract's
// shape. This suite proves what happens to a database that already holds rows
// when it crosses `v4-entry-offset-not-null`: the offset is backfilled, the
// table is rebuilt with the constraint, the key table appears — and, the part
// that is easy to get wrong, `logicalDate` and the instant come through
// UNTOUCHED. The migration must not re-derive a single day: the first
// realignment in the repository does that, and it needs the old value to
// recognise a pre-0.85.0 calendar entry. A migration that helpfully recomputed
// the column here would destroy exactly that evidence.
//
// The backfilled offset is asserted as a RANGE rather than a number: it comes
// from the zone the test host happens to be in, which is the point of doing it
// in code rather than in SQL, and naming a value would tie the test to one
// machine.
// =============================================================================

final class MigrationTests: XCTestCase {

    /// A database migrated up to v3 and seeded with one drink and one entry that
    /// predates the offset column: no `utcOffsetSeconds`, and a `logicalDate`
    /// five days off the instant — the signature of a calendar entry booked
    /// before v0.85.0.
    private func databaseAtV3() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(queue, upTo: "v3-entry-utc-offset")
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO drinks (id, name, volumeMl, alcoholPercent, isPreset, isFavorite, category)
                VALUES (1, 'Test Lager', 500, 5.0, 0, 0, 'BEER')
                """)
            try db.execute(sql: """
                INSERT INTO entries
                    (id, drinkId, drinkName, volumeMl, alcoholPercent, gramsAlcohol,
                     timestampMillis, logicalDate, note)
                VALUES (1, 1, 'Test Lager', 500, 5.0, 19.7, 1773183600000, '2026-03-05', '')
                """)
        }
        return queue
    }

    func testMigrate3To4BackfillsTheOffsetAndLeavesTheDayAlone() throws {
        let queue = try databaseAtV3()

        try AppDatabase.migrator.migrate(queue)

        let row = try queue.read { db in
            try Row.fetchOne(
                db, sql: "SELECT utcOffsetSeconds, logicalDate, timestampMillis FROM entries WHERE id = 1"
            )
        }
        let migrated = try XCTUnwrap(row, "the seeded entry must survive the migration")
        let offset: Int? = migrated["utcOffsetSeconds"]
        let backfilled = try XCTUnwrap(offset, "every row carries a frame afterwards")
        XCTAssertTrue((-12 * 3600...14 * 3600).contains(backfilled), "and it is a real offset")
        XCTAssertEqual(migrated["logicalDate"] as String, "2026-03-05", "the stored day is not re-derived here")
        XCTAssertEqual(migrated["timestampMillis"] as Int64, 1_773_183_600_000, "nor is the instant moved here")
    }

    func testMigrate3To4LeavesTheKeyUnset() throws {
        let queue = try databaseAtV3()

        try AppDatabase.migrator.migrate(queue)

        let keys = try queue.read { db in try LogicalDayKey.fetchAll(db) }
        XCTAssertEqual(keys.count, 1, "the key table holds exactly one row")
        XCTAssertNil(keys.first?.changeHour, "and it says 'not derived yet'")
        XCTAssertNil(keys.first?.changeMinute)
    }

    func testMigrate3To4MakesTheOffsetNotNullAndRecreatesTheIndices() throws {
        let queue = try databaseAtV3()

        try AppDatabase.migrator.migrate(queue)

        try queue.read { db in
            let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(entries)")
            let offset = try XCTUnwrap(columns.first { $0["name"] as String == "utcOffsetSeconds" })
            XCTAssertEqual(offset["notnull"] as Int, 1, "the rebuilt column carries the constraint")

            // The indices are recreated after the table rebuild, not inherited.
            let indices = try Row.fetchAll(db, sql: "PRAGMA index_list(entries)").map { $0["name"] as String }
            XCTAssertTrue(indices.contains("index_entries_logicalDate"))
            XCTAssertTrue(indices.contains("index_entries_drinkId"))
        }
    }
}
