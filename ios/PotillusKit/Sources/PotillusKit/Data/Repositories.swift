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

    /// One-shot reads, for exports, backups, and screens that compute a snapshot
    /// rather than observe one.
    func all() throws -> [ConsumptionEntry]
    func inRange(from: String, to: String) throws -> [ConsumptionEntry]

    /// Per-day totals across an inclusive range, chronologically. The one-shot
    /// twin of `observeDailySummaries`, sharing its SQL so the two can never
    /// disagree about what a day's total is.
    func dailySummaries(from: String, to: String) throws -> [DaySummary]

    /// The entry written last, or nil when the log is empty. Drives the
    /// pre-selected drink in the entry sheet.
    ///
    /// By row id, not by timestamp. The two differ for anything logged onto
    /// another day: the sheet's picker offers a time, and an entry made for last
    /// Friday evening carries that evening's instant. Ordering by timestamp then
    /// answers "which drink was consumed latest", which is not what the question
    /// is — the sheet wants to offer what the user reached for a moment ago.
    /// (An `observeMostRecentEntry` ordered by timestamp, with the opposite
    /// argument, existed beside this until v0.86.0; nothing but its tests called
    /// it. Android's `EntryDao.getMostRecent` states the same rule as this one.)
    func lastEntry() throws -> ConsumptionEntry?

    /// Every logical date on which anything was logged, ascending and distinct.
    /// The one-shot twin of `observeAllDates`. Answers how far the statistics
    /// period navigation may page back — a day the user logged an alcohol-free
    /// drink on is a day worth reaching.
    func allDates() throws -> [String]

    /// The logical dates on which alcohol was consumed, ascending and distinct,
    /// i.e. the drink days as `AlcoholCalculator.isDrinkDay` defines them. The
    /// abstinence streaks and the drink-day counts read this one; days holding
    /// only alcohol-free entries are absent.
    func drinkDates() throws -> [String]

    /// Inserts `entry` with a freshly derived logical day and returns its new id.
    ///
    /// `entry.logicalDate` as handed in is IGNORED. Every insert path ends here,
    /// so this is the one place a row can be given a day, and a caller that could
    /// supply its own would eventually supply a wrong one. What the caller owns
    /// is the reading — the timestamp and the offset — and the day follows.
    func add(_ entry: ConsumptionEntry, settings: AppSettings) throws -> Int64

    /// Updates `entry`, deriving its logical day from the edited reading.
    ///
    /// The stored day does not survive an edit, and that is the point: an entry
    /// corrected from 23:00 to 02:00 moves to the previous logical day, because
    /// 02:00 is before the boundary and that is what the reading says.
    func update(_ entry: ConsumptionEntry, settings: AppSettings) throws

    func delete(_ entry: ConsumptionEntry) throws
    func deleteAll() throws

    /// Whether an entry with exactly this timestamp and drink already exists.
    /// The de-duplication guard for MERGE imports.
    func exists(timestampMillis: Int64, drinkId: Int64) throws -> Bool

    /// Rewrites `logicalDate` across the table when the day-change time in
    /// `settings` differs from the one the column was last derived under, and
    /// records the new one. A no-op when the two already agree.
    ///
    /// Called on every settings emission, from one place in the app. Safe beside
    /// ordinary writes: it runs in a single transaction.
    func realignDays(settings: AppSettings) throws
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
            try Self.checked(
                Entry
                    .filter(Column("logicalDate") == date)
                    .order(Column("timestampMillis").asc)
                    .fetchAll(db),
                db
            ).map(\.domain)
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

    /// The SQL transcription of `AlcoholCalculator.isDrinkDay`, day by day.
    ///
    /// `HAVING SUM(gramsAlcohol) > 0` rather than `WHERE gramsAlcohol > 0`: the
    /// predicate is defined on a DAY's total, and grouping first says exactly
    /// that. Grams are never negative, so both forms select the same dates; the
    /// grouped one stays correct if that ever changes. The Kotlin twin is
    /// `EntryDao.getDrinkDatesFlow`.
    private static func fetchDrinkDates(_ db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
            SELECT logicalDate
            FROM entries
            GROUP BY logicalDate
            HAVING SUM(gramsAlcohol) > 0
            ORDER BY logicalDate ASC
            """
        )
    }

    /// `SELECT DISTINCT logicalDate FROM entries ORDER BY logicalDate ASC`
    public func observeAllDates() -> AsyncThrowingStream<[String], Error> {
        observing(reader: database.reader) { db in try Self.fetchAllDates(db) }
    }

    public func observeEntries(from: String, to: String) -> AsyncThrowingStream<[ConsumptionEntry], Error> {
        observing(reader: database.reader) { db in
            try Self.checked(
                Entry
                    .filter(Column("logicalDate") >= from && Column("logicalDate") <= to)
                    .order(Column("timestampMillis").asc)
                    .fetchAll(db),
                db
            ).map(\.domain)
        }
    }

    public func all() throws -> [ConsumptionEntry] {
        try database.read { db in
            try Self.checked(Entry.order(Column("timestampMillis").asc).fetchAll(db), db).map(\.domain)
        }
    }

    public func inRange(from: String, to: String) throws -> [ConsumptionEntry] {
        try database.read { db in
            try Self.checked(
                Entry
                    .filter(Column("logicalDate") >= from && Column("logicalDate") <= to)
                    .order(Column("timestampMillis").asc)
                    .fetchAll(db),
                db
            ).map(\.domain)
        }
    }

    public func dailySummaries(from: String, to: String) throws -> [DaySummary] {
        try database.read { db in try Self.fetchDailySummaries(db, from: from, to: to) }
    }

    public func lastEntry() throws -> ConsumptionEntry? {
        try database.read { db in
            let row = try Entry.order(Column("id").desc).fetchOne(db)
            return Self.checked(row.map { [$0] } ?? [], db).first?.domain
        }
    }

    public func allDates() throws -> [String] {
        try database.read { db in try Self.fetchAllDates(db) }
    }

    public func drinkDates() throws -> [String] {
        try database.read { db in try Self.fetchDrinkDates(db) }
    }

    public func add(_ entry: ConsumptionEntry, settings: AppSettings) throws -> Int64 {
        try database.write { db in
            var record = Entry(entry)
            record.logicalDate = try Self.derivedDay(db, of: record, settings: settings)
            try record.insert(db)
            guard let id = record.id else {
                throw DatabaseError(message: "insert did not yield a row id")
            }
            return id
        }
    }

    public func update(_ entry: ConsumptionEntry, settings: AppSettings) throws {
        try database.write { db in
            var record = Entry(entry)
            record.logicalDate = try Self.derivedDay(db, of: record, settings: settings)
            try record.update(db)
        }
    }

    // ── The derived logical day ──────────────────────────────────────────────

    /// The rows, after checking the invariant `entries.logicalDate` is bound by.
    ///
    /// WHAT IT CATCHES, AND WHY IT IS WORTH A CHECK ON THE READ PATH. Making the
    /// column a derivation buys the app the ability to move every entry when the
    /// day-change time moves; what it risks is a row whose stored day and whose
    /// reading have come apart — a write that went round `add` and `update`, a
    /// realignment that half ran, a key written without the rows it describes.
    /// None of those is visible in the data itself: a wrong day looks exactly
    /// like a right one. So the equation is checked where every row passes, and
    /// the failure names the row instead of surfacing weeks later as a total
    /// nobody can account for.
    ///
    /// A NIL KEY IS NOT A VIOLATION. It means the column has not been derived yet
    /// — the state a fresh migration and a finished import both leave — and the
    /// rows legitimately hold whatever they were imported or migrated with until
    /// the next realignment.
    ///
    /// COSTS NOTHING IN A SHIPPED BUILD: `assert` takes its condition as an
    /// autoclosure and does not evaluate it when assertions are compiled out, so
    /// neither the key read nor the loop happens there. The rows are returned
    /// either way, which is what lets this sit inside the fetch expression.
    private static func checked(_ rows: [Entry], _ db: Database) -> [Entry] {
        assert(invariantHolds(rows, db))
        return rows
    }

    /// The condition `checked` asserts, spelled out so the assertion reads as one
    /// line and this can name what failed while debugging.
    private static func invariantHolds(_ rows: [Entry], _ db: Database) -> Bool {
        guard let key = try? LogicalDayKey.fetchOne(db),
              let hour = key.changeHour, let minute = key.changeMinute
        else { return true }
        return rows.allSatisfy { row in
            DayResolver.resolve(
                timestampMillis: row.timestampMillis,
                utcOffsetSeconds: row.utcOffsetSeconds,
                changeHour: hour,
                changeMinute: minute
            ) == row.logicalDate
        }
    }

    /// The logical day `record`'s own reading falls on.
    ///
    /// THE BOUNDARY COMES FROM THE KEY WHEN THERE IS ONE, and only from
    /// `settings` when there is not. That looks backwards — the settings are
    /// newer — and it is deliberate: the invariant on `entries` is stated against
    /// the KEY, so a row written under a boundary the key does not name would
    /// break it for as long as the realignment has not run. Deriving under the
    /// key keeps every row consistent with every other, and the realignment
    /// already on its way moves the new row along with the rest a moment later.
    private static func derivedDay(
        _ db: Database, of record: Entry, settings: AppSettings
    ) throws -> String {
        let key = try LogicalDayKey.fetchOne(db)
        // Both or neither: the two columns are written together and read
        // together, so a half-set key counts as no key rather than being mixed
        // with the settings into a boundary that was never in force anywhere.
        let hour: Int
        let minute: Int
        if let keyHour = key?.changeHour, let keyMinute = key?.changeMinute {
            hour = keyHour
            minute = keyMinute
        } else {
            hour = settings.dayChangeHour
            minute = settings.dayChangeMinute
        }
        return DayResolver.resolve(
            timestampMillis: record.timestampMillis,
            utcOffsetSeconds: record.utcOffsetSeconds,
            changeHour: hour,
            changeMinute: minute
        )
    }

    /// Brings `entries.logicalDate` in line with the day-change time in `settings`.
    ///
    /// WHAT IT COMPARES. The single row of `logical_day_key` says which boundary
    /// the column currently holds. Equal to the setting: nothing to do, and the
    /// common case — this runs on every settings emission, which includes every
    /// unrelated change the user makes. Different, or not set at all: one
    /// transaction that rewrites the column and records the new boundary.
    ///
    /// WHAT RUNS FIRST WHEN THE KEY IS UNSET. A nil key means the column has
    /// never been derived — the state a fresh v4 migration and a finished backup
    /// import both leave. That is also the only moment at which the stored
    /// `logicalDate` still carries the user's ORIGINAL intent for the entries
    /// damaged by the pre-0.85.0 calendar path, so `LegacyDayRepair` gets its
    /// turn before the recomputation overwrites them. The order is not a
    /// preference; it is the difference between repairing those rows and losing
    /// what they meant.
    ///
    /// WHY IT IS SAFE TO INTERRUPT. Everything happens inside one transaction. An
    /// abort rolls back the rewrite AND the key, so the next emission finds the
    /// old key, disagrees with the setting again, and starts over. There is no
    /// half-converted state to detect, because there is no state between the two.
    ///
    /// WHAT THE SCREENS DO. Nothing, until the transaction commits; then GRDB
    /// reports `entries` as changed and every observation re-emits by itself. In
    /// the window between the setting being written and the commit, the screens
    /// show the old days — what the app showed permanently before this existed.
    public func realignDays(settings: AppSettings) throws {
        try database.write { db in
            let key = try LogicalDayKey.fetchOne(db)
            let isUnset = key?.changeHour == nil || key?.changeMinute == nil
            if !isUnset,
               key?.changeHour == settings.dayChangeHour,
               key?.changeMinute == settings.dayChangeMinute {
                return
            }

            for row in try Entry.fetchAll(db) {
                let repaired = isUnset ? Self.repairedOrSame(row, settings: settings) : row
                var rewritten = repaired
                rewritten.logicalDate = DayResolver.resolve(
                    timestampMillis: repaired.timestampMillis,
                    utcOffsetSeconds: repaired.utcOffsetSeconds,
                    changeHour: settings.dayChangeHour,
                    changeMinute: settings.dayChangeMinute
                )
                // Only the rows that actually moved. A no-op update is still a
                // write, and on the first run after an upgrade nearly every row
                // is one: the previous release placed timestamps so that they
                // resolve to the day it stored beside them.
                if rewritten != row {
                    try rewritten.update(db)
                }
            }

            // `save`, not `update`: the migration puts the row in, but `update`
            // would throw if it were ever absent, and failing a realignment over
            // a missing bookkeeping row would be the wrong trade — `save` writes
            // it either way.
            try LogicalDayKey(
                changeHour: settings.dayChangeHour,
                changeMinute: settings.dayChangeMinute
            ).save(db)
        }
    }

    /// `row` with its pre-0.85.0 calendar damage undone, or `row` unchanged.
    ///
    /// Split out so `realignDays` reads as the decisions it makes rather than as
    /// the mechanics of one of them. See `LegacyDayRepair` for how a damaged row
    /// is recognised and why the rule lives there and not in `DayResolver`.
    private static func repairedOrSame(_ row: Entry, settings: AppSettings) -> Entry {
        guard let fixed = LegacyDayRepair.repair(
            timestampMillis: row.timestampMillis,
            utcOffsetSeconds: row.utcOffsetSeconds,
            logicalDate: row.logicalDate,
            changeHour: settings.dayChangeHour,
            changeMinute: settings.dayChangeMinute
        ) else { return row }
        var repaired = row
        repaired.timestampMillis = fixed.timestampMillis
        repaired.utcOffsetSeconds = fixed.utcOffsetSeconds
        return repaired
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
