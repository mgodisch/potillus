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
//   supported interchange path is the JSON backup.
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

    /// The schema version this code expects, mirroring Room's `version = 4`.
    ///
    /// Kept as a plain constant for the parity test to assert against; GRDB
    /// itself tracks applied steps by name in `grdb_migrations`.
    public static let schemaVersion = 4

    /// The write-serialising connection. A queue (not a pool) because the app is
    /// single-user and offline: correctness and simplicity beat read concurrency.
    private let writer: any DatabaseWriter

    /// Read-only access for callers that only observe or query.
    public var reader: any DatabaseReader { writer }

    /// The on-disk path, or `nil` for an in-memory database. Exposed so the
    /// iCloud-backup exclusion can be read and set on the file (see BackupExclusion).
    public let path: String?

    /// Opens (and migrates) the database at `path`.
    public init(path: String) throws {
        self.path = path
        writer = try DatabaseQueue(path: path)
        try Self.migrator.migrate(writer)
    }

    /// The database at the app's standard location,
    /// `Application Support/potillus.sqlite`.
    ///
    /// Application Support, not Documents: the file is app-managed state, not a
    /// user-visible document, and Documents is exposed by the Files app when
    /// `UIFileSharingEnabled` is set. The user's export path is the JSON backup.
    public static func makeDefault() throws -> AppDatabase {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dbPath = directory.appendingPathComponent("potillus.sqlite").path
        let database = try openOrCreate(path: dbPath)
        // Re-assert the device-backup exclusion at every launch. A file write can
        // reset the attribute, so it must be renewed; the stored preference (default:
        // excluded, matching Android's allowBackup="false") is the durable record.
        try? BackupExclusion.applyPreference(databasePath: dbPath)
        return database
    }

    /// An empty in-memory database, for tests. Never touches the file system.
    public init(inMemory: Bool) throws {
        precondition(inMemory, "Use init(path:) for on-disk databases")
        self.path = nil
        writer = try DatabaseQueue()
        try Self.migrator.migrate(writer)
    }

    // ── Pre-population ───────────────────────────────────────────────────────

    /// Opens the database at `path`, inserting the built-in preset drinks when
    /// the file did not exist yet.
    ///
    /// The iOS counterpart of Android's `AppDatabase.PrepopulateCallback`, which
    /// Room invokes from `onCreate` — once, when the database file is first
    /// created. Without this the drinks catalogue was empty after a fresh
    /// install: the port carried the schema over but not the seed (fixed in
    /// 0.83.0).
    ///
    /// WHY NOT SEED FROM THE MIGRATION
    ///   A migration step would seem the natural "runs once per database" hook,
    ///   but `migrator` is shared by `init(inMemory:)`, which every test and the
    ///   screenshot run use. Seeding there would push fifteen rows into every
    ///   test fixture and make "a fresh database is empty" false across the
    ///   suite. Android draws the same line: the callback is attached by the
    ///   production builder in `getInstance`, not by the schema, so its own
    ///   test databases come up empty too.
    ///
    /// WHY `fileExists` AND NOT "the catalogue is empty"
    ///   "Empty catalogue" is a legitimate state — a REPLACE import of a backup
    ///   whose drink list is empty produces it, and so does deleting every
    ///   user-created drink after a REPLACE has removed the presets. Re-seeding
    ///   on that condition would resurrect drinks the user deliberately got rid
    ///   of, at the next launch. The file's absence, by contrast, means exactly
    ///   one thing: there is no history yet, because this is a first install or
    ///   a storage reset.
    ///
    /// WHY THE `countPresets` GUARD SURVIVES ANYWAY
    ///   It mirrors the belt-and-braces check in Android's callback. Between the
    ///   `fileExists` probe and the write, nothing else can have opened this
    ///   path — the app is single-process and this runs before the composition
    ///   root hands the database to anything. The guard costs one `COUNT(*)` on
    ///   an empty table and removes any chance of a double seed should a future
    ///   caller reach this differently.
    public static func openOrCreate(path: String) throws -> AppDatabase {
        let isNewDatabase = !FileManager.default.fileExists(atPath: path)
        let database = try AppDatabase(path: path)
        if isNewDatabase {
            try database.write { db in
                if try Drink.filter(Column("isPreset") == true).fetchCount(db) == 0 {
                    try seedPresets(db)
                }
            }
        }
        return database
    }

    /// Inserts every entry of `presetDrinks`.
    ///
    /// `insert` needs a `var` because `didInsert` writes the assigned row id
    /// back into the record; the copy is discarded, since nothing here needs the
    /// ids.
    private static func seedPresets(_ db: Database) throws {
        for preset in presetDrinks {
            var record = preset
            try record.insert(db)
        }
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

        // The twin of Room's MIGRATION_2_3. The column records the UTC offset a
        // drink was logged at, so its clock time can be read back in the frame it
        // was written in rather than in whatever frame the device is in at read
        // time. See `DayResolver.utcOffsetSeconds` for what is stored and
        // `DayResolver.displayTimeZone` for how it is read.
        //
        // NULLABLE, AND EXISTING ROWS ARE LEFT NULL. A backfill would have to
        // guess: the only offset available at migration time is the one the
        // device is in now, which is right for someone who never travelled and
        // wrong for someone who did — and once written, the guess would be
        // indistinguishable from a recorded fact. NULL says "not recorded" and
        // lets every read derive the same fallback, which is exactly what the app
        // did for every entry before this column existed.
        migrator.registerMigration("v3-entry-utc-offset") { db in
            try db.alter(table: "entries") { table in
                table.add(column: "utcOffsetSeconds", .integer)
            }
        }

        // The twin of Room's MIGRATION_3_4, in three steps.
        //
        // SUPERSEDES THE REASONING ABOVE. The step before this one left existing
        // rows without an offset and every reader derived a replacement from the
        // device zone, on every read. That replacement is written into the rows
        // here, once, and the column becomes NOT NULL — which removes a second
        // code path from four places rather than carrying it into the first
        // production release. What is given up is the self-healing property of a
        // per-read guess: someone who installs this update while abroad freezes
        // their pre-0.86.0 history at the wrong offset. That needs entries from
        // before the column AND an update taken while travelling, and it is
        // accepted.
        //
        // 1. BACKFILL, in Swift and not in SQL, because SQLite carries no
        //    timezone database: its `localtime` modifier answers for the CURRENT
        //    rules, not for the rules in force when the row was written.
        //
        // 2. REBUILD. SQLite cannot add NOT NULL to an existing column, so the
        //    table is recreated with the constraint and the rows are copied. The
        //    column order, the index names and the foreign key match Room's own
        //    output, because `test-vectors/db-schema.json` compares both sides
        //    literally.
        //
        // 3. THE KEY TABLE, created holding nil, i.e. "the logical day has not
        //    been derived yet". This migration deliberately does NOT read the
        //    day-change setting and does NOT touch `logicalDate`: everything that
        //    needs the setting happens in the first realignment, which is what
        //    lets the database open before the preferences are readable.
        //
        // The zone is read through a private helper rather than through
        // `DayResolver`, so a later change there cannot reinterpret a database
        // that has already migrated against one that has not.
        migrator.registerMigration("v4-entry-offset-not-null") { db in
            try backfillUtcOffsets(db)
            try rebuildEntriesWithNotNullOffset(db)
            try createLogicalDayKey(db)
        }

        return migrator
    }
}

// =============================================================================
// The v4 migration, step by step
// =============================================================================
//
// FILE-SCOPE FUNCTIONS, NOT METHODS. They are called from the `migrator` static
// property and from nowhere else, and keeping them out of the type body is also
// what `check-swift-length` wants: an extension or file scope is not counted
// against SwiftLint's `type_body_length`.
// =============================================================================

/// Step 1: writes an offset into every row that has none.
///
/// Rows are read first and written afterwards rather than updated while a cursor
/// is open. SQLite permits the interleaving, but walking a table that is being
/// written under you is a well-known way to see a row twice or not at all. The
/// row count here is one person's drink history, so holding the ids in memory
/// costs nothing worth optimising.
private func backfillUtcOffsets(_ db: Database) throws {
    let zone = TimeZone.current
    let rows = try Row.fetchAll(
        db, sql: "SELECT id, timestampMillis FROM entries WHERE utcOffsetSeconds IS NULL"
    )
    for row in rows {
        let id: Int64 = row["id"]
        let timestampMillis: Int64 = row["timestampMillis"]
        let offset = zone.secondsFromGMT(
            for: Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
        )
        try db.execute(
            sql: "UPDATE entries SET utcOffsetSeconds = ? WHERE id = ?",
            arguments: [offset, id]
        )
    }
}

/// Step 2: the table rebuild SQLite requires for a new NOT NULL constraint.
///
/// The order is the one SQLite's own documentation prescribes: create the
/// replacement, copy, drop, rename, recreate the indices. The foreign key lives
/// on `entries` and is re-declared verbatim below.
///
/// GRDB runs each migration step inside a transaction and, by default, defers
/// foreign-key checking to its end, so dropping the child table mid-step is
/// safe. Raw SQL is used rather than the query builder because the statements
/// have to match Room's output character for character where the parity test
/// looks — column order, index names, and the `ON UPDATE NO ACTION` the Room
/// export spells out even though it is the default.
private func rebuildEntriesWithNotNullOffset(_ db: Database) throws {
    try db.execute(sql: """
        CREATE TABLE IF NOT EXISTS "entries_new" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            "drinkId" INTEGER NOT NULL
                REFERENCES "drinks"("id") ON UPDATE NO ACTION ON DELETE RESTRICT,
            "drinkName" TEXT NOT NULL,
            "volumeMl" INTEGER NOT NULL,
            "alcoholPercent" DOUBLE NOT NULL,
            "gramsAlcohol" DOUBLE NOT NULL,
            "timestampMillis" INTEGER NOT NULL,
            "logicalDate" TEXT NOT NULL,
            "note" TEXT NOT NULL,
            "utcOffsetSeconds" INTEGER NOT NULL
        )
        """)
    try db.execute(sql: """
        INSERT INTO "entries_new"
            (id, drinkId, drinkName, volumeMl, alcoholPercent, gramsAlcohol,
             timestampMillis, logicalDate, note, utcOffsetSeconds)
        SELECT id, drinkId, drinkName, volumeMl, alcoholPercent, gramsAlcohol,
               timestampMillis, logicalDate, note, utcOffsetSeconds
        FROM "entries"
        """)
    try db.execute(sql: "DROP TABLE \"entries\"")
    try db.execute(sql: "ALTER TABLE \"entries_new\" RENAME TO \"entries\"")
    try db.create(index: "index_entries_drinkId", on: "entries", columns: ["drinkId"])
    try db.create(index: "index_entries_logicalDate", on: "entries", columns: ["logicalDate"])
}

/// Step 3: creates `logical_day_key` and puts its one row in, holding nil.
///
/// Inserting the row here rather than lazily means every reader can rely on it
/// existing, and "no row" never has to mean anything of its own.
private func createLogicalDayKey(_ db: Database) throws {
    try db.create(table: "logical_day_key") { table in
        // See the note on `drinks.id` in the initial schema for why `.notNull()`
        // is spelled out beside a primary key: SQLite reports the constraint in
        // `PRAGMA table_info` only when it was declared, and Room declares it.
        table.primaryKey("id", .integer).notNull()
        table.column("changeHour", .integer)
        table.column("changeMinute", .integer)
    }
    try LogicalDayKey().insert(db)
}

// =============================================================================
// Built-in preset drinks
// =============================================================================
//
// WHY OUTSIDE THE TYPE
//   A `private let` at file scope is visible to this file only, and is not tied
//   to an instance. Android places its `PRESET_DRINKS` outside `AppDatabase` for
//   the same reason, with the same comment.
//
// WHY THE NAMES ARE ENGLISH AND NOT LOCALISED
//   A preset is a ROW the user owns from the moment it is created: they can
//   rename it, restyle it, star it, and it is carried verbatim through the JSON
//   backup to the other platform. Localising the seed would make a backup's
//   drink names depend on the language the app happened to be in at install
//   time, and a rename would then fight the translation. Android seeds the same
//   English names for the same reason.
//
// THIS LIST IS A CROSS-PLATFORM CONTRACT
//   It must stay byte-for-byte equivalent to `PRESET_DRINKS` in Android's
//   `AppDatabase.kt`. Nothing enforces that yet — see the note in
//   `AppDatabaseSeedTests`.
// =============================================================================

/// The drinks inserted the first time the database is created.
private let presetDrinks: [Drink] = [
    Drink(name: "Lager (Pint)", volumeMl: 568, alcoholPercent: 4.5,
          isPreset: true, category: DrinkCategory.beer.rawValue),
    Drink(name: "Lager (Standard)", volumeMl: 500, alcoholPercent: 5.0,
          isPreset: true, category: DrinkCategory.beer.rawValue),
    Drink(name: "Lager (Small)", volumeMl: 330, alcoholPercent: 5.0,
          isPreset: true, category: DrinkCategory.beer.rawValue),
    Drink(name: "Shandy / Radler", volumeMl: 500, alcoholPercent: 2.5,
          isPreset: true, category: DrinkCategory.beer.rawValue),
    Drink(name: "White Wine (Small)", volumeMl: 125, alcoholPercent: 12.5,
          isPreset: true, category: DrinkCategory.wine.rawValue),
    Drink(name: "White Wine (Regular)", volumeMl: 150, alcoholPercent: 13.0,
          isPreset: true, category: DrinkCategory.wine.rawValue),
    Drink(name: "Red Wine (Regular)", volumeMl: 150, alcoholPercent: 13.5,
          isPreset: true, category: DrinkCategory.wine.rawValue),
    Drink(name: "Sparkling Wine / Prosecco", volumeMl: 125, alcoholPercent: 11.5,
          isPreset: true, category: DrinkCategory.wine.rawValue),
    Drink(name: "Gin & Tonic", volumeMl: 200, alcoholPercent: 10.0,
          isPreset: true, category: DrinkCategory.longdrink.rawValue),
    Drink(name: "Cuba Libre", volumeMl: 200, alcoholPercent: 10.0,
          isPreset: true, category: DrinkCategory.longdrink.rawValue),
    Drink(name: "Vodka Soda", volumeMl: 200, alcoholPercent: 10.0,
          isPreset: true, category: DrinkCategory.longdrink.rawValue),
    Drink(name: "Vodka Shot", volumeMl: 40, alcoholPercent: 40.0,
          isPreset: true, category: DrinkCategory.spirits.rawValue),
    Drink(name: "Vodka Shot (International)", volumeMl: 45, alcoholPercent: 40.0,
          isPreset: true, category: DrinkCategory.spirits.rawValue),
    Drink(name: "Whiskey (Neat/Rocks)", volumeMl: 45, alcoholPercent: 43.0,
          isPreset: true, category: DrinkCategory.spirits.rawValue),
    Drink(name: "Liqueur Shot", volumeMl: 40, alcoholPercent: 35.0,
          isPreset: true, category: DrinkCategory.liqueur.rawValue),
]
