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
//   REPLACE wipes the log and EVERY drink (presets included), then imports, so
//   the catalogue afterwards is exactly the backup's drink list — a preset the
//   backup does not carry is dropped. Presets the backup contains are recreated
//   from it, `isPreset` flag and all.
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
    /// Erase the log and ALL drinks (presets included) first, so the catalogue
    /// ends up identical to the backup.
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
    /// `true` when the backup asked for the biometric lock and it was NOT
    /// applied because the device cannot authenticate (see `restore`). The
    /// caller tells the user; silently dropping it would leave them believing
    /// the backup's lock is on.
    public let lockNotRestored: Bool

    public init(imported: Int, skipped: Int, lockNotRestored: Bool = false) {
        self.imported = imported
        self.skipped = skipped
        self.lockNotRestored = lockNotRestored
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
    /// Settings follow the MODE, and only `.replace` applies them. `.merge` means
    /// "add this history to mine", and someone merging a friend's or an old export
    /// does not thereby ask for their daily limit, day-change time, theme and
    /// language to be overwritten — least of all the limits, which decide what the
    /// app then tells them about their drinking. Android states this contract in
    /// `BackupManager.kt` and has always honoured it; this side applied the block in
    /// both modes until the 0.84.0 review.
    ///
    /// Named `restore` rather than `import`: the latter is a Swift keyword, and a
    /// call site full of backticks reads worse than a synonym.
    ///
    /// - Parameter deviceCanAuthenticate: Whether the device can satisfy the
    ///   biometric lock right now (`BiometricAuthenticator.canEvaluate`). The
    ///   lock fails closed (`AppLockModel`), so a restored `biometricEnabled`
    ///   is applied only when this is `true`; otherwise it is left off and
    ///   `ImportStats.lockNotRestored` says so. The kit cannot probe the device
    ///   itself — LocalAuthentication lives in the app shell — hence the
    ///   parameter. Android's `SettingsViewModel.applyImportedSettings` applies
    ///   the same rule.
    @discardableResult
    public func restore(
        _ backup: BackupFile, mode: ImportMode, deviceCanAuthenticate: Bool = true
    ) async throws -> ImportStats {
        let stats = try importData(backup, mode: mode)
        guard mode == .replace else { return stats }
        let lockNotRestored = try await applySettings(
            backup, deviceCanAuthenticate: deviceCanAuthenticate
        )
        return ImportStats(
            imported: stats.imported, skipped: stats.skipped, lockNotRestored: lockNotRestored
        )
    }

    // ── Data ─────────────────────────────────────────────────────────────────

    private func importData(_ backup: BackupFile, mode: ImportMode) throws -> ImportStats {
        try database.write { db in
            if mode == .replace {
                _ = try Entry.deleteAll(db)
                // Wipe EVERY drink, presets included. The log was just cleared,
                // so no entry references any drink and the foreign key cannot
                // trip. REPLACE means "the catalogue becomes exactly the backup":
                // a preset the backup does not contain must NOT survive. Keeping
                // presets here was the reported bug — right after a fresh install
                // (or a storage reset), where the preset set seeded by
                // `AppDatabase.openOrCreate` was still present, they lingered
                // ALONGSIDE the imported drinks instead of being replaced.
                // Presets the backup DOES carry are re-inserted below with their
                // `isPreset` flag intact.
                _ = try Drink.deleteAll(db)
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
    /// Called only for `.replace`; see `restore(_:mode:)` for why.
    ///
    /// A backup is user-editable JSON, so every value passes through
    /// `SettingsSanitizer` before it can influence the alcohol maths. The result
    /// REPLACES the local settings — with three exceptions, and one refusal,
    /// that Android's `SettingsViewModel.applyImportedSettings` makes as well
    /// (aligned in the v0.86.0 review; until then this side replaced wholesale, on
    /// the argument that mixing two states yields one neither device ever had):
    ///
    ///   - `language == ""`, `weightKg == 0` and `statsFromDate == ""` are not
    ///     values but the ABSENCE of one — "follow the system", "not set", "no
    ///     floor". Writing them would discard a real local value for nothing,
    ///     and an empty `statsFromDate` would even erase the floor this store
    ///     seeded at first launch. They leave the local value standing.
    ///   - `biometricEnabled == true` is applied only if the device can
    ///     authenticate: the lock fails closed, so arming it without a
    ///     credential would lock the user out at the next start.
    ///
    /// - Returns: `true` when the lock was asked for and not applied.
    private func applySettings(
        _ backup: BackupFile, deviceCanAuthenticate: Bool
    ) async throws -> Bool {
        guard let preferences, let raw = backup.settings else { return false }
        let current = await preferences.load()
        var merged = SettingsSanitizer.sanitize(raw)
        if merged.language.isEmpty { merged.language = current.language }
        if merged.weightKg <= 0.0 { merged.weightKg = current.weightKg }
        if merged.statsFromDate.isEmpty { merged.statsFromDate = current.statsFromDate }
        let lockNotRestored = merged.biometricEnabled && !deviceCanAuthenticate
        if lockNotRestored { merged.biometricEnabled = false }
        try await preferences.replace(with: merged)
        return lockNotRestored
    }
}
