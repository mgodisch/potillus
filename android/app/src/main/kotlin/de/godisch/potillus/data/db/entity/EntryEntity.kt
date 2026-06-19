/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

// =============================================================================
// EntryEntity.kt – Room database entity for consumption events
// =============================================================================
//
// FOREIGN KEY AND RESTRICT SEMANTICS:
//   [drinkId] references DrinkEntity.id with ON DELETE RESTRICT.
//   RESTRICT means: SQLite refuses to delete a drink row if any entry still
//   references it, throwing SQLiteConstraintException.
//   The app handles this gracefully: DrinksViewModel calls
//   DrinkRepository.countEntriesForDrink() BEFORE attempting a delete and
//   shows a user-friendly message if count > 0. The RESTRICT constraint is
//   a safety net, not the primary guard.
//
// INDEX on drinkId:
//   Without an index, every query that filters or joins on drinkId would
//   require a full table scan. Room adds a compile-time warning if you
//   declare a FK without a corresponding index, so the @Index here both
//   silences the warning and improves query performance.
//
// INDEX on logicalDate:
//   logicalDate appears in WHERE and GROUP BY clauses of several queries
//   (getByDate, getDailySummaries, getEntriesForPeriodFlow). An index lets
//   SQLite use a B-tree lookup instead of a full scan, which scales well
//   as the entries table grows over months of use.
//   NOTE: adding this index requires a Room schema migration from version 1
//   to version 2 (see AppDatabase.MIGRATION_1_2).
//
// DENORMALISED COLUMNS (drinkName, volumeMl, alcoholPercent, gramsAlcohol):
//   See Models.kt / ConsumptionEntry for the rationale.
//   Short version: historical records must not change if the drink definition
//   is later edited; denormalisation ensures data stability over time.
// =============================================================================

/**
 * Persisted representation of a single consumption event.
 *
 * Maps to the `entries` table in the Room database.
 * Converted to/from [de.godisch.potillus.domain.model.ConsumptionEntry] by the
 * extension functions in [de.godisch.potillus.data.repository.EntryRepository].
 *
 * @param id              Auto-generated primary key (0 = unsaved).
 * @param drinkId         FK → [DrinkEntity.id], RESTRICT on delete.
 * @param drinkName       Snapshot of the drink name at log time.
 * @param volumeMl        Actual volume consumed in ml.
 * @param alcoholPercent  ABV snapshot at log time.
 * @param gramsAlcohol    Pre-calculated pure alcohol in grams (avoids re-computing
 *                        in SQL aggregate queries like SUM).
 * @param timestampMillis Unix epoch milliseconds (UTC) of the consumption.
 * @param logicalDate     ISO-8601 "YYYY-MM-DD" as resolved by [de.godisch.potillus.domain.DayResolver].
 * @param note            Optional free-text annotation.
 */
@Entity(
    tableName = "entries",
    foreignKeys = [ForeignKey(
        entity        = DrinkEntity::class,
        parentColumns = ["id"],
        childColumns  = ["drinkId"],
        onDelete      = ForeignKey.RESTRICT
    )],
    indices = [Index(value = ["drinkId"]), Index(value = ["logicalDate"])]
)
data class EntryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val drinkId: Long,
    val drinkName: String,
    val volumeMl: Int,
    val alcoholPercent: Double,
    val gramsAlcohol: Double,
    val timestampMillis: Long,
    val logicalDate: String,
    val note: String = ""
)
