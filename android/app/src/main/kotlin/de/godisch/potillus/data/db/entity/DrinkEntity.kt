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
package de.godisch.potillus.data.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

// =============================================================================
// DrinkEntity.kt – Room database entity for drink definitions
// =============================================================================
//
// WHY A SEPARATE ENTITY CLASS?
//   Room requires classes annotated with @Entity to map to database tables.
//   The domain model (DrinkDefinition) deliberately has no Room annotations
//   so it stays free of Android dependencies and is easily testable.
//   DrinkEntity is the persistence-layer representation; the repository
//   converts between the two via toDomain() / toEntity() extension functions.
//
// ROOM @Entity ANNOTATION:
//   tableName: the SQL table name in the SQLite database.
//   If omitted, Room uses the class name as the table name.
//
// @PrimaryKey(autoGenerate = true):
//   Room generates a unique integer ID for each new row.
//   A default value of 0 signals "not yet persisted" (Room ignores 0 on INSERT).
// =============================================================================

/**
 * Persisted representation of a drink definition.
 *
 * Maps to the `drinks` table in the Room database.
 * Converted to/from [de.godisch.potillus.domain.model.DrinkDefinition] by the
 * `internal` `toDomain` / `toEntity` extension functions in `EntityMapping.kt`.
 *
 * @param id             Auto-generated primary key (0 = unsaved).
 * @param name           Display name.
 * @param volumeMl       Default serving size in ml.
 * @param alcoholPercent ABV as a percentage (0.0–100.0).
 * @param isPreset       True for built-in drinks that cannot be deleted.
 * @param isFavorite     True when the user has starred the drink.
 * @param category       [de.godisch.potillus.domain.model.DrinkCategory] stored as
 *                       its [Enum.name] string (e.g. "BEER").
 *
 *                       WHY String instead of the enum itself?
 *                       Room does not know how to store a Kotlin enum directly.
 *                       Storing the name (e.g. "BEER") is more portable than
 *                       storing the ordinal integer (e.g. 0): if enum constants
 *                       are ever reordered, name-based storage stays correct,
 *                       whereas ordinal-based storage would silently misread
 *                       existing data. The conversion back to the enum is done
 *                       defensively with runCatching { … }.getOrDefault(OTHER).
 */
@Entity(tableName = "drinks")
data class DrinkEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val volumeMl: Int,
    val alcoholPercent: Double,
    val isPreset: Boolean   = false,
    val isFavorite: Boolean = false,
    val category: String    = "OTHER"   // DrinkCategory.name()
)
