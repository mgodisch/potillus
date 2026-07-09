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
import GRDB

// =============================================================================
// AppDatabase.swift – schema definition and migrations
// =============================================================================
//
// The iOS counterpart to Android's Room `AppDatabase`. It creates exactly the
// same two tables, with the same columns, keys, indices and foreign-key action.
// That shape is a written contract: `test-vectors/db-schema.json` is generated
// from Room's authoritative schema export, and BOTH platforms assert against it,
// so neither can drift.
//
// WHAT "SHARED SCHEMA" DOES AND DOES NOT MEAN
//   It means the tables mean the same thing on both platforms, so the domain
//   logic and the queries are transferable and the JSON backup maps cleanly onto
//   rows. It does NOT mean a database FILE can be copied between an Android
//   phone and an iPhone: Room keeps its own bookkeeping (a `room_master_table`
//   holding an identity hash, plus `user_version`), and GRDB keeps a
//   `grdb_migrations` table instead. Neither would accept the other's file. The
//   supported interchange path is the JSON backup — see docs/IOS_MIGRATION.md.
//
// MIGRATIONS
//   `DatabaseMigrator` is GRDB's answer to Room's migrations: named steps, run
//   once, in registration order, each inside a transaction. Android reached its
//   current schema (version 2) through a 1 -> 2 migration; iOS has no installed
//   base to migrate, so it bootstraps straight to the version 2 shape in a single
//   step. From here on, every schema change must be added as a new step on BOTH
//   platforms, and `test-vectors/db-schema.json` regenerated in the same commit.
// =============================================================================

/// Owns the database connection and its schema.
public final class AppDatabase: Sendable {

    /// The schema version this code expects, mirroring Room's `version = 2`.
    ///
    /// Kept as a plain constant for the parity test to assert against; GRDB
    /// itself tracks applied steps by name in `grdb_migrations`.
    public static let schemaVersion = 2

    /// The write-serialising connection. A queue (not a pool) because the app is
    /// single-user and offline: correctness and simplicity beat read concurrency.
    private let writer: any DatabaseWriter

    /// Read-only access for callers that only observe or query.
    public var reader: any DatabaseReader { writer }

    /// Opens (and migrates) the database at `path`.
    public init(path: String) throws {
        writer = try DatabaseQueue(path: path)
        try Self.migrator.migrate(writer)
    }

    /// An empty in-memory database, for tests. Never touches the file system.
    public init(inMemory: Bool) throws {
        precondition(inMemory, "Use init(path:) for on-disk databases")
        writer = try DatabaseQueue()
        try Self.migrator.migrate(writer)
    }

    /// Runs `updates` inside a write transaction.
    public func write<T>(_ updates: @Sendable (Database) throws -> T) throws -> T {
        try writer.write(updates)
    }

    /// Runs `value` against a consistent read-only snapshot.
    public func read<T>(_ value: @Sendable (Database) throws -> T) throws -> T {
        try writer.read(value)
    }

    // ── Schema ───────────────────────────────────────────────────────────────

    /// The ordered migration steps. Registered names are permanent: renaming one
    /// would make GRDB believe an applied step is missing.
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Never wipe a user's data to resolve a schema mismatch. GRDB offers
        // `eraseDatabaseOnSchemaChange` as a development convenience; for an app
        // whose database is the only copy of the user's history (no cloud, no
        // sync), silently erasing it would be the worst possible failure mode.
        // A mismatch must surface as an error instead.
        migrator.eraseDatabaseOnSchemaChange = false

        // Note on foreign keys: GRDB enables `PRAGMA foreign_keys` on every
        // connection by default, so ON DELETE RESTRICT is enforced. Raw SQLite
        // defaults it OFF — one of the sharp edges GRDB files down for us.

        migrator.registerMigration("v2-initial-schema") { db in
            // `drinks`: the catalogue of loggable drinks.
            try db.create(table: "drinks") { table in
                // INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, matching Room's
                // autoGenerate. AUTOINCREMENT (rather than a bare rowid alias)
                // guarantees ids are never reused after a delete, so a stale
                // reference can never silently resolve to a different drink.
                //
                // The explicit `.notNull()` looks redundant — an INTEGER PRIMARY
                // KEY is a rowid alias and can never hold NULL — but it is not
                // cosmetic here. SQLite only reports a column as NOT NULL in
                // `PRAGMA table_info` when the constraint was DECLARED, and Room
                // declares it. Omitting it makes the two schemas differ on paper
                // while behaving identically, which the shared schema-parity test
                // rightly rejects. Behaviour is unchanged either way: inserting a
                // NULL id still lets SQLite assign the next value.
                table.autoIncrementedPrimaryKey("id").notNull()
                table.column("name", .text).notNull()
                table.column("volumeMl", .integer).notNull()
                table.column("alcoholPercent", .double).notNull()
                table.column("isPreset", .integer).notNull()
                table.column("isFavorite", .integer).notNull()
                table.column("category", .text).notNull()
            }

            // `entries`: the log. Drink attributes are denormalised (see Entry).
            try db.create(table: "entries") { table in
                // See the note on `drinks.id` for why `.notNull()` is spelled out.
                table.autoIncrementedPrimaryKey("id").notNull()
                // RESTRICT, not CASCADE: deleting a drink that still has entries
                // must fail loudly rather than erase the user's history.
                table.column("drinkId", .integer)
                    .notNull()
                    .references("drinks", column: "id", onDelete: .restrict)
                table.column("drinkName", .text).notNull()
                table.column("volumeMl", .integer).notNull()
                table.column("alcoholPercent", .double).notNull()
                table.column("gramsAlcohol", .double).notNull()
                table.column("timestampMillis", .integer).notNull()
                table.column("logicalDate", .text).notNull()
                table.column("note", .text).notNull()
            }

            // Index names match Room's generated ones, so the shared schema
            // contract can compare them literally.
            try db.create(
                index: "index_entries_drinkId",
                on: "entries",
                columns: ["drinkId"]
            )
            // The hot path: every statistics query filters or groups by the
            // logical day.
            try db.create(
                index: "index_entries_logicalDate",
                on: "entries",
                columns: ["logicalDate"]
            )
        }

        return migrator
    }
}
