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

// =============================================================================
// EntityMapping.swift – record <-> domain conversions
// =============================================================================
//
// The counterpart of Android's `data/repository/EntityMapping.kt`. It is the one
// place where a persistence detail (a category stored as text, an optional row
// id) becomes a domain value, and back.
//
// Keeping the two type families apart is deliberate: the domain layer must not
// know that GRDB, or SQLite, exists. That is what lets the shared test vectors
// exercise pure logic, and what would let the storage engine be replaced without
// touching a single calculation.
// =============================================================================

extension Drink {

    /// The domain view of this row.
    ///
    /// An unpersisted record (`id == nil`) becomes `id == 0`, matching the Kotlin
    /// default that marks "not yet in the database".
    var domain: DrinkDefinition {
        DrinkDefinition(
            id: id ?? 0,
            name: name,
            volumeMl: volumeMl,
            alcoholPercent: alcoholPercent,
            isPreset: isPreset,
            isFavorite: isFavorite,
            // An unknown category decays to `.other` instead of throwing, so a
            // database written by a newer version still opens.
            category: DrinkCategory.from(stored: category)
        )
    }

    /// The persistable record for `definition`.
    ///
    /// `id == 0` is translated back to `nil` so SQLite assigns a fresh row id.
    init(_ definition: DrinkDefinition) {
        self.init(
            id: definition.id == 0 ? nil : definition.id,
            name: definition.name,
            volumeMl: definition.volumeMl,
            alcoholPercent: definition.alcoholPercent,
            isPreset: definition.isPreset,
            isFavorite: definition.isFavorite,
            // Stored as the enum's raw string, never an ordinal.
            category: definition.category.rawValue
        )
    }
}

extension Entry {

    var domain: ConsumptionEntry {
        ConsumptionEntry(
            id: id ?? 0,
            drinkId: drinkId,
            drinkName: drinkName,
            volumeMl: volumeMl,
            alcoholPercent: alcoholPercent,
            gramsAlcohol: gramsAlcohol,
            timestampMillis: timestampMillis,
            logicalDate: logicalDate,
            note: note
        )
    }

    init(_ entry: ConsumptionEntry) {
        self.init(
            id: entry.id == 0 ? nil : entry.id,
            drinkId: entry.drinkId,
            drinkName: entry.drinkName,
            volumeMl: entry.volumeMl,
            alcoholPercent: entry.alcoholPercent,
            gramsAlcohol: entry.gramsAlcohol,
            timestampMillis: entry.timestampMillis,
            logicalDate: entry.logicalDate,
            note: entry.note
        )
    }
}
