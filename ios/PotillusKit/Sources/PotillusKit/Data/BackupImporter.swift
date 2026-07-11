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
// BackupImporter.swift – applying a parsed backup to the live database
// =============================================================================
//
// The counterpart of Android's `BackupRepository.importReplace/importMerge`, and
// the step that finally closes the gap left open in the backup port: the
// `settings` block is now applied, not merely carried through.
//
// WHY IDS ARE REMAPPED, NOT TRUSTED
//   A backup's `drinkId` values are row ids from the DEVICE THAT WROTE IT. On the
//   importing device those ids belong to different drinks, or to none. Copying
//   them across would silently re-attribute history: an entry logged as "Pils"
//   would reappear as "Whisky".
//
//   The join is therefore made on the drink NAME, which is what the user sees and
//   what carries meaning across devices. A backup drink whose name already exists
//   locally maps onto the local row; one that does not is inserted, and the new id
//   is remembered. Every entry is then rewritten to point at the local id.
//
// THE TWO MODES
//   REPLACE wipes the log and every user-created drink, then imports. Presets
//   survive, because an old entry must always be able to resolve its drink.
//   MERGE keeps what is there and skips entries that already exist, identified by
//   timestamp plus drink — the natural key. Importing the same file twice must
//   not double the history.
//
// ATOMICITY
//   Drinks and entries move inside ONE write transaction. A failure halfway
//   through must leave the database exactly as it was; a half-imported history is
//   worse than none, because the user cannot tell which half is missing.
//   Settings are applied afterwards, outside the transaction: they live in a
//   different store, and a settings failure must not roll back a good import.
// =============================================================================

/// How an import treats the data already on the device.
public enum ImportMode: String, Sendable, Equatable {
    /// Erase the log and user-created drinks first. Presets are kept.
    case replace = "REPLACE"
    /// Keep existing data; skip entries that are already present.
    case merge = "MERGE"
}

/// What an import did, for the confirmation the user sees.
public struct ImportStats: Sendable, Equatable {
    /// Entries written to the database.
    public let imported: Int
    /// Entries recognised as duplicates and skipped. Always 0 for REPLACE.
    public let skipped: Int

    public init(imported: Int, skipped: Int) {
        self.imported = imported
        self.skipped = skipped
    }
}

/// Failures that abort an import.
public enum ImportError: Error, Equatable, CustomStringConvertible {
    /// An entry references a drink the backup does not contain. The file is
    /// internally inconsistent; importing it would orphan the entry.
    case unmappedDrink(backupDrinkId: Int64)

    public var description: String {
        switch self {
        case .unmappedDrink(let id):
            return "The backup has an entry for drink \(id), which the backup does not define."
        }
    }
}

/// Applies a parsed `BackupFile` to the database and the preferences.
public struct BackupImporter: Sendable {

    private let database: AppDatabase
    private let preferences: (any PreferencesStoring)?

    /// - Parameters:
    ///   - database: The live database.
    ///   - preferences: Where a restored `settings` block lands. Pass `nil` to
    ///     import data only — the behaviour of a pre-v3 backup.
    public init(database: AppDatabase, preferences: (any PreferencesStoring)? = nil) {
        self.database = database
        self.preferences = preferences
    }

    /// Restores `backup`, returning what it did.
    ///
    /// Data first, in one transaction; settings after. Restoring a backup that
    /// carries no settings block leaves the local preferences untouched.
    ///
    /// Named `restore` rather than `import`: the latter is a Swift keyword, and a
    /// call site full of backticks reads worse than a synonym.
    @discardableResult
    public func restore(_ backup: BackupFile, mode: ImportMode) async throws -> ImportStats {
        let stats = try importData(backup, mode: mode)
        try await applySettings(backup)
        return stats
    }

    // ── Data ─────────────────────────────────────────────────────────────────

    private func importData(_ backup: BackupFile, mode: ImportMode) throws -> ImportStats {
        try database.write { db in
            if mode == .replace {
                _ = try Entry.deleteAll(db)
                // Presets are never deleted: an entry that survived a REPLACE in
                // an earlier import may still reference one.
                _ = try Drink.filter(Column("isPreset") == false).deleteAll(db)
            }

            let idMap = try Self.buildIdMap(db, backupDrinks: backup.drinks)

            var imported = 0
            var skipped = 0

            for entry in backup.entries {
                guard let localDrinkId = idMap[entry.drinkId] else {
                    // Thrown inside the transaction, so nothing is committed.
                    throw ImportError.unmappedDrink(backupDrinkId: entry.drinkId)
                }

                if mode == .merge, try Self.entryExists(db, entry, drinkId: localDrinkId) {
                    skipped += 1
                    continue
                }

                var record = Entry(entry)
                record.id = nil              // let SQLite assign a fresh row id
                record.drinkId = localDrinkId
                try record.insert(db)
                imported += 1
            }

            return ImportStats(imported: imported, skipped: skipped)
        }
    }

    /// Maps each backup drink id onto a local one, inserting drinks that are new.
    ///
    /// The map is built from the drink NAME, the only identifier that means the
    /// same thing on both devices. Names encountered during this loop are added
    /// to the lookup, so a backup listing the same name twice maps both to one
    /// local row rather than inserting a duplicate.
    private static func buildIdMap(
        _ db: Database, backupDrinks: [DrinkDefinition]
    ) throws -> [Int64: Int64] {
        var nameToLocalId: [String: Int64] = [:]
        for drink in try Drink.fetchAll(db) {
            if let id = drink.id { nameToLocalId[drink.name] = id }
        }

        var idMap: [Int64: Int64] = [:]
        for backupDrink in backupDrinks {
            let localId: Int64
            if let existing = nameToLocalId[backupDrink.name] {
                localId = existing
            } else {
                var record = Drink(backupDrink)
                record.id = nil
                try record.insert(db)
                guard let newId = record.id else {
                    throw DatabaseError(message: "insert did not yield a row id")
                }
                localId = newId
                nameToLocalId[backupDrink.name] = newId
            }
            idMap[backupDrink.id] = localId
        }
        return idMap
    }

    /// The MERGE de-duplication key: same instant, same drink.
    private static func entryExists(
        _ db: Database, _ entry: ConsumptionEntry, drinkId: Int64
    ) throws -> Bool {
        try Entry
            .filter(Column("timestampMillis") == entry.timestampMillis && Column("drinkId") == drinkId)
            .fetchCount(db) > 0
    }

    // ── Settings ─────────────────────────────────────────────────────────────

    /// Sanitises and stores the backup's settings, if it has any.
    ///
    /// A backup is user-editable JSON, so every value passes through
    /// `SettingsSanitizer` before it can influence the alcohol maths. `replace`
    /// rather than a merge: the file describes a complete settings state, and
    /// mixing it with the local one would produce a state neither device ever had.
    private func applySettings(_ backup: BackupFile) async throws {
        guard let preferences, let raw = backup.settings else { return }
        try await preferences.replace(with: SettingsSanitizer.sanitize(raw))
    }
}
