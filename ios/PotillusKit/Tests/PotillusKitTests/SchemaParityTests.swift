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
import GRDB
@testable import PotillusKit

// =============================================================================
// SchemaParityTests.swift – the database schema is a cross-platform contract
// =============================================================================
//
// `test-vectors/db-schema.json` is generated from Android's authoritative Room
// schema export. This suite creates a real (in-memory) database with GRDB's
// migrator and INTROSPECTS it — PRAGMA table_info, index_list, index_info,
// foreign_key_list — asserting that what SQLite actually built matches the
// contract, column for column.
//
// Introspecting rather than comparing DDL strings is deliberate: Room and GRDB
// emit different (both valid) `CREATE TABLE` text for the same table. What must
// match is the resulting schema, not its spelling.
// =============================================================================

/// Root of `test-vectors/db-schema.json`.
struct DatabaseSchemaVectors: Decodable {
    let schemaVersion: Int
    let tables: [Table]

    struct Table: Decodable {
        let name: String
        let columns: [Column]
        let primaryKey: [String]
        let autoIncrement: Bool
        let indices: [Index]
        let foreignKeys: [ForeignKey]
    }

    struct Column: Decodable {
        let name: String
        /// Room's affinity: INTEGER, TEXT or REAL.
        let type: String
        let notNull: Bool
    }

    struct Index: Decodable {
        let name: String
        let unique: Bool
        let columns: [String]
    }

    struct ForeignKey: Decodable {
        let column: String
        let referencesTable: String
        let referencesColumn: String
        let onDelete: String
        let onUpdate: String
    }
}

final class SchemaParityTests: XCTestCase {

    private static var loadedVectors: DatabaseSchemaVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("db-schema", as: DatabaseSchemaVectors.self)
        } catch {
            XCTFail("Could not load the shared schema contract: \(error)")
        }
    }

    private var vectors: DatabaseSchemaVectors { Self.loadedVectors }

    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase(inMemory: true)
    }

    // ── Version ──────────────────────────────────────────────────────────────

    func testSchemaVersionMatchesTheContract() {
        XCTAssertEqual(AppDatabase.schemaVersion, vectors.schemaVersion)
    }

    // ── Tables and columns ───────────────────────────────────────────────────

    func testEveryContractTableExistsWithTheRightColumns() throws {
        let database = try makeDatabase()
        try database.read { db in
            for table in self.vectors.tables {
                XCTAssertTrue(try db.tableExists(table.name), "missing table: \(table.name)")

                let actual = try db.columns(in: table.name)
                let actualByName = Dictionary(uniqueKeysWithValues: actual.map { ($0.name, $0) })

                XCTAssertEqual(
                    actual.count, table.columns.count,
                    "\(table.name): column count differs — actual \(actual.map(\.name))"
                )

                for column in table.columns {
                    guard let info = actualByName[column.name] else {
                        XCTFail("\(table.name): missing column \(column.name)")
                        continue
                    }
                    // SQLite reports the declared type; GRDB's `.double` declares
                    // DOUBLE, whose affinity is REAL. Compare on affinity, which
                    // is what actually governs storage.
                    XCTAssertEqual(
                        affinity(ofDeclaredType: info.type), column.type,
                        "\(table.name).\(column.name): type affinity"
                    )
                    XCTAssertEqual(
                        info.isNotNull, column.notNull,
                        "\(table.name).\(column.name): notNull"
                    )
                }
            }
        }
    }

    // ── Primary keys ─────────────────────────────────────────────────────────

    func testPrimaryKeysMatchAndAutoIncrementIsHonoured() throws {
        let database = try makeDatabase()
        try database.read { db in
            for table in self.vectors.tables {
                let primaryKey = try db.primaryKey(table.name)
                XCTAssertEqual(
                    primaryKey.columns, table.primaryKey,
                    "\(table.name): primary key columns"
                )

                if table.autoIncrement {
                    // AUTOINCREMENT is not exposed by any PRAGMA; SQLite records
                    // it by creating the `sqlite_sequence` table and by putting
                    // the keyword into the stored DDL. Check the DDL directly.
                    let sql = try String.fetchOne(
                        db,
                        sql: "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
                        arguments: [table.name]
                    )
                    XCTAssertTrue(
                        sql?.uppercased().contains("AUTOINCREMENT") ?? false,
                        "\(table.name): expected AUTOINCREMENT, so row ids are never reused"
                    )
                }
            }
        }
    }

    // ── Indices ──────────────────────────────────────────────────────────────

    func testIndicesMatchTheContract() throws {
        let database = try makeDatabase()
        try database.read { db in
            for table in self.vectors.tables {
                let actual = try db.indexes(on: table.name)
                for index in table.indices {
                    guard let found = actual.first(where: { $0.name == index.name }) else {
                        XCTFail("\(table.name): missing index \(index.name)")
                        continue
                    }
                    XCTAssertEqual(found.columns, index.columns, "index \(index.name): columns")
                    XCTAssertEqual(found.isUnique, index.unique, "index \(index.name): unique")
                }
            }
        }
    }

    // ── Foreign keys ─────────────────────────────────────────────────────────

    func testForeignKeysMatchTheContract() throws {
        let database = try makeDatabase()
        try database.read { db in
            for table in self.vectors.tables where !table.foreignKeys.isEmpty {
                let rows = try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(\(table.name))")
                XCTAssertEqual(
                    rows.count, table.foreignKeys.count,
                    "\(table.name): foreign-key count"
                )

                for foreignKey in table.foreignKeys {
                    guard let row = rows.first(where: { $0["from"] == foreignKey.column }) else {
                        XCTFail("\(table.name): missing foreign key on \(foreignKey.column)")
                        continue
                    }
                    XCTAssertEqual(row["table"], foreignKey.referencesTable)
                    XCTAssertEqual(row["to"], foreignKey.referencesColumn)
                    XCTAssertEqual(row["on_delete"], foreignKey.onDelete)
                    XCTAssertEqual(row["on_update"], foreignKey.onUpdate)
                }
            }
        }
    }

    // ── Behavioural tests: the schema must actually protect the data ─────────

    /// `PRAGMA foreign_keys` is OFF by default in raw SQLite. GRDB turns it on,
    /// and this asserts the effect rather than the setting.
    func testDeletingAReferencedDrinkIsRefused() throws {
        let database = try makeDatabase()
        var drink = Drink(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: "beer")
        try database.write { db in try drink.insert(db) }

        let drinkId = try XCTUnwrap(drink.id)
        var entry = Entry(
            drinkId: drinkId, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.3, timestampMillis: 1_748_142_000_000, logicalDate: "2025-05-24"
        )
        try database.write { db in try entry.insert(db) }

        XCTAssertThrowsError(
            try database.write { db in try Drink.deleteOne(db, id: drinkId) },
            "ON DELETE RESTRICT must refuse to erase a drink that still has entries"
        )
    }

    /// AUTOINCREMENT means a deleted id is never handed out again, so a stale
    /// reference cannot silently resolve to a different drink.
    func testRowIdsAreNotReusedAfterDeletion() throws {
        let database = try makeDatabase()
        var first = Drink(name: "A", volumeMl: 100, alcoholPercent: 1.0, category: "beer")
        try database.write { db in try first.insert(db) }
        let firstId = try XCTUnwrap(first.id)

        try database.write { db in _ = try Drink.deleteOne(db, id: firstId) }

        var second = Drink(name: "B", volumeMl: 100, alcoholPercent: 1.0, category: "beer")
        try database.write { db in try second.insert(db) }

        XCTAssertNotEqual(second.id, firstId, "AUTOINCREMENT must not reuse the freed id")
    }

    /// A round trip through the database must preserve every field exactly.
    func testRecordsRoundTripThroughTheDatabase() throws {
        let database = try makeDatabase()
        var drink = Drink(
            name: "Whisky", volumeMl: 40, alcoholPercent: 40.0,
            isPreset: true, isFavorite: true, category: "spirits"
        )
        try database.write { db in try drink.insert(db) }

        let fetched = try database.read { db in try Drink.fetchOne(db, id: drink.id!) }
        XCTAssertEqual(fetched, drink)
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /// Maps a declared SQLite type onto its type affinity, per the SQLite rules
    /// (https://sqlite.org/datatype3.html#determination_of_column_affinity).
    /// Only the three affinities this schema uses are distinguished.
    private func affinity(ofDeclaredType declared: String) -> String {
        let type = declared.uppercased()
        if type.contains("INT") { return "INTEGER" }
        if type.contains("CHAR") || type.contains("CLOB") || type.contains("TEXT") { return "TEXT" }
        if type.contains("REAL") || type.contains("FLOA") || type.contains("DOUB") { return "REAL" }
        return type
    }
}
