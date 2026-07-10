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
// Repositories.swift – protocol seams over the database
// =============================================================================
//
// The iOS counterparts of Android's `IDrinkRepository` and `IEntryRepository`,
// with the same operations and the same query semantics. Every SQL statement
// here is the literal twin of the Room DAO query it mirrors; the comments name
// the ordering guarantees, because callers depend on them.
//
// WHY PROTOCOLS
//   GRDB lives only inside the implementations. The rest of the app depends on
//   the protocol, so the storage engine can be swapped, and screens can be
//   driven by an in-memory fake in tests, without touching a single call site.
//   This mirrors the layering Android already has.
//
// FLOW -> ASYNCTHROWINGSTREAM
//   Room returns `Flow` for observable queries; the SwiftUI equivalent is GRDB's
//   `ValueObservation`. Both deliver an initial value and then a new one after
//   every committed change touching the observed tables.
//
//   The protocols deliberately do NOT expose GRDB's `AsyncValueObservation`.
//   Publishing a library type through the seam would defeat the seam: every
//   caller would import GRDB, and replacing the storage engine would ripple
//   through the whole app. `AsyncThrowingStream` is a standard-library type that
//   says exactly what a caller needs to know — values arrive over time, and the
//   sequence can fail. `observing(_:)` below does the bridging in one place.
// =============================================================================

/// Reads and writes the catalogue of drinks.
public protocol DrinkRepositoryProtocol: Sendable {

    /// Observable stream of all drinks: favourites first, then alphabetically.
    func observeDrinks() -> AsyncThrowingStream<[DrinkDefinition], Error>

    /// The catalogue, read once. For screens that compute a snapshot rather than
    /// observe one, and for the importer's name lookup.
    func allOnce() throws -> [DrinkDefinition]

    /// Inserts `drink` and returns its new database id.
    func add(_ drink: DrinkDefinition) throws -> Int64

    /// Updates name, volume, ABV, category and favourite flag.
    func update(_ drink: DrinkDefinition) throws

    /// Deletes `drink`. Callers should first check `countEntries(forDrink:)`;
    /// the foreign key refuses the delete otherwise.
    func delete(_ drink: DrinkDefinition) throws

    /// How many consumption entries reference `drinkId` (the delete guard).
    func countEntries(forDrink drinkId: Int64) throws -> Int

    /// Deletes every user-created (non-preset) drink. Used by REPLACE imports.
    func deleteUserCreatedDrinks() throws
}

/// Reads and writes the consumption log.
public protocol EntryRepositoryProtocol: Sendable {

    /// Entries of one logical day, oldest first.
    func observeEntries(forDate date: String) -> AsyncThrowingStream<[ConsumptionEntry], Error>

    /// Per-day totals across an inclusive date range, chronologically.
    func observeDailySummaries(from: String, to: String) -> AsyncThrowingStream<[DaySummary], Error>

    /// Every logical date that has at least one entry, ascending.
    func observeAllDates() -> AsyncThrowingStream<[String], Error>

    /// Entries in an inclusive range, oldest first.
    func observeEntries(from: String, to: String) -> AsyncThrowingStream<[ConsumptionEntry], Error>

    /// The most recently *consumed* entry, or nil when the log is empty.
    func observeMostRecentEntry() -> AsyncThrowingStream<ConsumptionEntry?, Error>

    /// One-shot reads, for exports, backups, and screens that compute a snapshot
    /// rather than observe one.
    func all() throws -> [ConsumptionEntry]
    func inRange(from: String, to: String) throws -> [ConsumptionEntry]

    /// Per-day totals across an inclusive range, chronologically. The one-shot
    /// twin of `observeDailySummaries`, sharing its SQL so the two can never
    /// disagree about what a day's total is.
    func dailySummaries(from: String, to: String) throws -> [DaySummary]

    /// The most recently logged entry, by timestamp, or nil when the log is empty.
    /// Drives the pre-selected drink in the entry sheet.
    func lastEntry() throws -> ConsumptionEntry?

    /// Every logical date on which anything was logged, ascending and distinct.
    /// The one-shot twin of `observeAllDates`, for the abstinence streaks.
    func allDates() throws -> [String]

    /// Inserts `entry` and returns its new database id.
    func add(_ entry: ConsumptionEntry) throws -> Int64

    func update(_ entry: ConsumptionEntry) throws
    func delete(_ entry: ConsumptionEntry) throws
    func deleteAll() throws

    /// Whether an entry with exactly this timestamp and drink already exists.
    /// The de-duplication guard for MERGE imports.
    func exists(timestampMillis: Int64, drinkId: Int64) throws -> Bool
}

// =============================================================================
// GRDB implementations
// =============================================================================

/// Bridges a GRDB `ValueObservation` into a standard-library async stream.
///
/// Cancelling the consuming task tears the observation down, so an off-screen
/// view stops observing the database.
private func observing<Value: Sendable>(
    reader: any DatabaseReader,
    _ fetch: @escaping @Sendable (Database) throws -> Value
) -> AsyncThrowingStream<Value, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for try await value in ValueObservation.tracking(fetch).values(in: reader) {
                    continuation.yield(value)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// GRDB-backed `DrinkRepositoryProtocol`.
public struct DrinkRepository: DrinkRepositoryProtocol {

    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// `SELECT * FROM drinks ORDER BY isFavorite DESC, name ASC`
    ///
    /// Favourites first, then alphabetical — the ordering the picker relies on.
    /// Sorting in SQL, not in Swift, keeps it identical to Android and lets the
    /// database do it once per change rather than once per render.
    public func observeDrinks() -> AsyncThrowingStream<[DrinkDefinition], Error> {
        observing(reader: database.reader) { db in
            try Drink
                .order(Column("isFavorite").desc, Column("name").asc)
                .fetchAll(db)
                .map(\.domain)
        }
    }

    public func allOnce() throws -> [DrinkDefinition] {
        try database.read { db in
            // The SAME ordering as `observeDrinks`: favourites first, then by
            // name. A snapshot that ordered differently from the stream would
            // reshuffle the list the moment a screen switched between them.
            try Drink
                .order(Column("isFavorite").desc, Column("name").asc)
                .fetchAll(db)
                .map(\.domain)
        }
    }

    public func add(_ drink: DrinkDefinition) throws -> Int64 {
        try database.write { db in
            var record = Drink(drink)
            try record.insert(db)
            // `didInsert` filled this in; a nil here would mean SQLite did not
            // assign a row id, which cannot happen for an AUTOINCREMENT key.
            guard let id = record.id else {
                throw DatabaseError(message: "insert did not yield a row id")
            }
            return id
        }
    }

    public func update(_ drink: DrinkDefinition) throws {
        try database.write { db in try Drink(drink).update(db) }
    }

    /// Deleting a drink that still has entries is refused by `ON DELETE RESTRICT`
    /// and surfaces as a thrown `DatabaseError`, not as silent data loss.
    public func delete(_ drink: DrinkDefinition) throws {
        try database.write { db in _ = try Drink(drink).delete(db) }
    }

    /// `SELECT COUNT(*) FROM entries WHERE drinkId = ?`
    public func countEntries(forDrink drinkId: Int64) throws -> Int {
        try database.read { db in
            try Entry.filter(Column("drinkId") == drinkId).fetchCount(db)
        }
    }

    /// Presets are never deleted, only user-created drinks — an old entry must
    /// always be able to resolve the drink it referenced.
    public func deleteUserCreatedDrinks() throws {
        try database.write { db in
            _ = try Drink.filter(Column("isPreset") == false).deleteAll(db)
        }
    }
}

/// GRDB-backed `EntryRepositoryProtocol`.
public struct EntryRepository: EntryRepositoryProtocol {

    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// `SELECT * FROM entries WHERE logicalDate = ? ORDER BY timestampMillis ASC`
    public func observeEntries(forDate date: String) -> AsyncThrowingStream<[ConsumptionEntry], Error> {
        observing(reader: database.reader) { db in
            try Entry
                .filter(Column("logicalDate") == date)
                .order(Column("timestampMillis").asc)
                .fetchAll(db)
                .map(\.domain)
        }
    }

    /// ```sql
    /// SELECT logicalDate, SUM(gramsAlcohol) AS totalGrams, COUNT(*) AS entryCount
    /// FROM entries WHERE logicalDate >= ? AND logicalDate <= ?
    /// GROUP BY logicalDate ORDER BY logicalDate ASC
    /// ```
    ///
    /// The range comparison is lexicographic on `yyyy-MM-dd`, which for that
    /// format is exactly chronological order — the reason the column is TEXT.
    /// Days without entries are simply absent; `ChartBucketing` fills the gaps.
    public func observeDailySummaries(from: String, to: String) -> AsyncThrowingStream<[DaySummary], Error> {
        observing(reader: database.reader) { db in
            try Self.fetchDailySummaries(db, from: from, to: to)
        }
    }

    /// The single definition of the summary query, used by both the observing and
    /// the one-shot reader above. Two copies would eventually disagree.
    private static func fetchDailySummaries(
        _ db: Database, from: String, to: String
    ) throws -> [DaySummary] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT logicalDate,
                       SUM(gramsAlcohol) AS totalGrams,
                       COUNT(*) AS entryCount
                FROM entries
                WHERE logicalDate >= ? AND logicalDate <= ?
                GROUP BY logicalDate
                ORDER BY logicalDate ASC
                """,
            arguments: [from, to]
        )
        .map { row in
            DaySummary(
                date: row["logicalDate"],
                totalGrams: row["totalGrams"],
                entryCount: row["entryCount"]
            )
        }
    }

    /// The single definition of the distinct-dates query, shared by the observing
    /// and one-shot readers, so a streak cannot be computed over a different set of
    /// days than the one the chart draws.
    private static func fetchAllDates(_ db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: "SELECT DISTINCT logicalDate FROM entries ORDER BY logicalDate ASC"
        )
    }

    /// `SELECT DISTINCT logicalDate FROM entries ORDER BY logicalDate ASC`
    public func observeAllDates() -> AsyncThrowingStream<[String], Error> {
        observing(reader: database.reader) { db in try Self.fetchAllDates(db) }
    }

    public func observeEntries(from: String, to: String) -> AsyncThrowingStream<[ConsumptionEntry], Error> {
        observing(reader: database.reader) { db in
            try Entry
                .filter(Column("logicalDate") >= from && Column("logicalDate") <= to)
                .order(Column("timestampMillis").asc)
                .fetchAll(db)
                .map(\.domain)
        }
    }

    /// `SELECT * FROM entries ORDER BY timestampMillis DESC LIMIT 1`
    ///
    /// Ordered by CONSUMPTION time, not by row id: a back-dated entry added today
    /// must not become "the most recent drink".
    public func observeMostRecentEntry() -> AsyncThrowingStream<ConsumptionEntry?, Error> {
        observing(reader: database.reader) { db in
            try Entry
                .order(Column("timestampMillis").desc)
                .fetchOne(db)?
                .domain
        }
    }

    public func all() throws -> [ConsumptionEntry] {
        try database.read { db in
            try Entry.order(Column("timestampMillis").asc).fetchAll(db).map(\.domain)
        }
    }

    public func inRange(from: String, to: String) throws -> [ConsumptionEntry] {
        try database.read { db in
            try Entry
                .filter(Column("logicalDate") >= from && Column("logicalDate") <= to)
                .order(Column("timestampMillis").asc)
                .fetchAll(db)
                .map(\.domain)
        }
    }

    public func dailySummaries(from: String, to: String) throws -> [DaySummary] {
        try database.read { db in try Self.fetchDailySummaries(db, from: from, to: to) }
    }

    public func lastEntry() throws -> ConsumptionEntry? {
        try database.read { db in
            try Entry.order(Column("timestampMillis").desc).fetchOne(db)?.domain
        }
    }

    public func allDates() throws -> [String] {
        try database.read { db in try Self.fetchAllDates(db) }
    }

    public func add(_ entry: ConsumptionEntry) throws -> Int64 {
        try database.write { db in
            var record = Entry(entry)
            try record.insert(db)
            guard let id = record.id else {
                throw DatabaseError(message: "insert did not yield a row id")
            }
            return id
        }
    }

    public func update(_ entry: ConsumptionEntry) throws {
        try database.write { db in try Entry(entry).update(db) }
    }

    public func delete(_ entry: ConsumptionEntry) throws {
        try database.write { db in _ = try Entry(entry).delete(db) }
    }

    public func deleteAll() throws {
        try database.write { db in _ = try Entry.deleteAll(db) }
    }

    /// `SELECT COUNT(*) FROM entries WHERE timestampMillis = ? AND drinkId = ?`
    ///
    /// Importing the same backup twice must not double every entry. Timestamp
    /// plus drink is the natural key the MERGE import de-duplicates on.
    public func exists(timestampMillis: Int64, drinkId: Int64) throws -> Bool {
        try database.read { db in
            try Entry
                .filter(Column("timestampMillis") == timestampMillis && Column("drinkId") == drinkId)
                .fetchCount(db) > 0
        }
    }
}
