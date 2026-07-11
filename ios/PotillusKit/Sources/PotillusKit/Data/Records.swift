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
// Records.swift – persistent record types
// =============================================================================
//
// The iOS counterparts of the Android Room entities `DrinkEntity` and
// `EntryEntity`. They map one-to-one onto the same two tables, because the
// SQLite schema is a shared contract between the platforms (see
// `test-vectors/db-schema.json` and docs/IOS_MIGRATION.md).
//
// WHY STRUCTS AND NOT CLASSES
//   GRDB 7 discourages the old `Record` base class. A plain `struct` conforming
//   to `Codable` + `FetchableRecord` + `MutablePersistableRecord` gives value
//   semantics, `Sendable` for free, and lets the compiler synthesise the whole
//   row mapping from the property names. Property names therefore MUST equal the
//   column names, exactly as on the Android side.
// =============================================================================

/// A drink the user can log: either a built-in preset or one they defined.
///
/// Mirrors Android's `DrinkEntity`.
public struct Drink: Codable, Sendable, Equatable, Identifiable {

    /// Row id. `nil` before the row is inserted; SQLite assigns it.
    public var id: Int64?

    /// Display name, e.g. "Pils 0.5 l".
    public var name: String

    /// Serving volume in millilitres.
    public var volumeMl: Int

    /// Alcohol by volume, as a percentage (e.g. `4.9`).
    public var alcoholPercent: Double

    /// True for the drinks shipped with the app.
    ///
    /// Presets may be hidden but never deleted, so an old entry can always
    /// resolve the drink it referenced.
    public var isPreset: Bool

    /// True when the user pinned this drink to the top of the picker.
    public var isFavorite: Bool

    /// Free-form grouping key (beer, wine, spirits, …), stored as text so a new
    /// category never needs a schema migration.
    public var category: String

    public init(
        id: Int64? = nil,
        name: String,
        volumeMl: Int,
        alcoholPercent: Double,
        isPreset: Bool = false,
        isFavorite: Bool = false,
        category: String
    ) {
        self.id = id
        self.name = name
        self.volumeMl = volumeMl
        self.alcoholPercent = alcoholPercent
        self.isPreset = isPreset
        self.isFavorite = isFavorite
        self.category = category
    }
}

extension Drink: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "drinks"

    /// GRDB hands back the row id SQLite assigned, so the in-memory value stays
    /// in step with the row it now represents.
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// One logged consumption event.
///
/// Mirrors Android's `EntryEntity`. Several drink attributes are DENORMALISED
/// into the entry on purpose: renaming a drink, or correcting its ABV, must not
/// retroactively rewrite history. What the user drank last year stays what they
/// drank last year.
public struct Entry: Codable, Sendable, Equatable, Identifiable {

    /// Row id. `nil` before insertion.
    public var id: Int64?

    /// The drink this entry was created from. `ON DELETE RESTRICT` keeps the
    /// referenced drink alive for as long as any entry points at it.
    public var drinkId: Int64

    /// Snapshot of the drink's name at logging time (denormalised).
    public var drinkName: String

    /// Snapshot of the volume actually consumed (denormalised; the user may
    /// override the drink's default serving).
    public var volumeMl: Int

    /// Snapshot of the ABV at logging time (denormalised).
    public var alcoholPercent: Double

    /// Pure ethanol in grams, rounded to 0.1 g by `AlcoholCalculator`.
    ///
    /// Stored rather than recomputed so that the number the user saw when they
    /// logged the drink is the number every later screen and export shows.
    public var gramsAlcohol: Double

    /// The wall-clock instant of consumption, in milliseconds since the epoch.
    public var timestampMillis: Int64

    /// The LOGICAL day this entry belongs to (`yyyy-MM-dd`), as decided by
    /// `DayResolver`. Stored, not derived, because the user may move the
    /// day-change time later and history must not silently re-bucket.
    public var logicalDate: String

    /// Optional user note. Empty string, never NULL, so `notNull` holds and
    /// queries need no `COALESCE`.
    public var note: String

    public init(
        id: Int64? = nil,
        drinkId: Int64,
        drinkName: String,
        volumeMl: Int,
        alcoholPercent: Double,
        gramsAlcohol: Double,
        timestampMillis: Int64,
        logicalDate: String,
        note: String = ""
    ) {
        self.id = id
        self.drinkId = drinkId
        self.drinkName = drinkName
        self.volumeMl = volumeMl
        self.alcoholPercent = alcoholPercent
        self.gramsAlcohol = gramsAlcohol
        self.timestampMillis = timestampMillis
        self.logicalDate = logicalDate
        self.note = note
    }
}

extension Entry: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "entries"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
