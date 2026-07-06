/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * =============================================================================
 */
package de.godisch.potillus.data.repository

// =============================================================================
// EntityMapping.kt – Shared entity ↔ domain conversions for the repository layer
// =============================================================================
//
// WHY THIS FILE EXISTS (C-01 fix)
//   DrinkRepository and EntryRepository each declared their conversion helpers
//   as file-private (`private fun`) extension functions. BackupRepository
//   needed identical conversions but could not reuse them, so it redeclared
//   the same bodies as class-private members. That triplication is a DRY
//   violation: changing the schema (adding a field, renaming a property) would
//   require updates in three places.
//
//   Moving the four helpers here with `internal` visibility makes them available
//   to the entire `:app` Gradle module (i.e. every file in `data.repository`)
//   while keeping them invisible to the domain and UI layers. The callers in
//   DrinkRepository, EntryRepository, and BackupRepository are updated to use
//   these shared functions; their previously duplicated code is removed.
//
// VISIBILITY CONTRACT:
//   All four functions are `internal` – accessible within the same Gradle module
//   but invisible to any future separate module (e.g. a `:domain` module).
//   They are NOT part of any public API.
//
// TESTING:
//   The conversions are now testable in a single place (if ever needed), but
//   they are so simple that they are currently covered implicitly by the
//   repository-level tests (BackupRepositoryTest, etc.).
// =============================================================================

import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition

// ── Drink conversions ────────────────────────────────────────────────────────

/**
 * Converts a [DrinkEntity] to a [DrinkDefinition].
 *
 * The [DrinkEntity.category] string (stored as an enum name, e.g. `"BEER"`) is
 * parsed back to a [DrinkCategory] enum. [runCatching] handles unknown or
 * misspelled category strings in old backups gracefully, defaulting to
 * [DrinkCategory.OTHER].
 */
internal fun DrinkEntity.toDomain() = DrinkDefinition(
    id = id,
    name = name,
    volumeMl = volumeMl,
    alcoholPercent = alcoholPercent,
    isPreset = isPreset,
    isFavorite = isFavorite,
    category = runCatching { DrinkCategory.valueOf(category) }.getOrDefault(DrinkCategory.OTHER),
)

/**
 * Converts a [DrinkDefinition] to a [DrinkEntity] for Room persistence.
 *
 * [DrinkDefinition.category] is stored as the enum's [Enum.name] string so
 * that reordering the enum constants in a future version does not corrupt
 * existing data.
 */
internal fun DrinkDefinition.toEntity() = DrinkEntity(
    id = id,
    name = name,
    volumeMl = volumeMl,
    alcoholPercent = alcoholPercent,
    isPreset = isPreset,
    isFavorite = isFavorite,
    category = category.name,
)

// ── Entry conversions ────────────────────────────────────────────────────────

/**
 * Converts an [EntryEntity] to a [ConsumptionEntry]. All fields are mapped 1-to-1.
 */
internal fun EntryEntity.toDomain() = ConsumptionEntry(
    id = id,
    drinkId = drinkId,
    drinkName = drinkName,
    volumeMl = volumeMl,
    alcoholPercent = alcoholPercent,
    gramsAlcohol = gramsAlcohol,
    timestampMillis = timestampMillis,
    logicalDate = logicalDate,
    note = note,
)

/**
 * Converts a [ConsumptionEntry] to an [EntryEntity] for Room persistence.
 * All fields are mapped 1-to-1.
 */
internal fun ConsumptionEntry.toEntity() = EntryEntity(
    id = id,
    drinkId = drinkId,
    drinkName = drinkName,
    volumeMl = volumeMl,
    alcoholPercent = alcoholPercent,
    gramsAlcohol = gramsAlcohol,
    timestampMillis = timestampMillis,
    logicalDate = logicalDate,
    note = note,
)
