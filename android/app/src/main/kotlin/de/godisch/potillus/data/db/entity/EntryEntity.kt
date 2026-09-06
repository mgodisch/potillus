/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
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
//
// WHY `logicalDate` IS A STORED COLUMN AND NOT DERIVED AT READ TIME
//   The column is a derivation (see the invariant at the field), and the
//   obvious simplification is to drop it: derive the day in code whenever a
//   row is read, and the realignment that keeps it in step with the day-change
//   setting disappears. That was the design of this feature for most of its
//   drafting, and it was given up on a measurement, not on taste. Without the
//   column every date-scoped query becomes a range over `timestampMillis`
//   with a two-day margin and a grouping in code, and the query behind the
//   calendar's drink-day dots becomes a projection over the whole table.
//   Measured with SQLite 3.45 on a desktop, ten thousand rows: the indexed
//   query on this column, about a thousand rows delivered, 2.0 ms; the
//   projection, ten thousand rows, 5.5 ms; with the grouping, 8.2 ms. At fifty
//   thousand rows 7.6 against 41.2 ms, linear. The index covers the projection,
//   as expected; what the expectation missed is the transport across the
//   driver boundary, paid per row, and Room and GRDB with their object mapping
//   do not make it cheaper than the bare `sqlite3` of the measurement. Grouping
//   in SQL instead would cost 2.9 ms and is ruled out for a different reason —
//   see `EntryDao`, "the logical day is never expressed in SQL". So the column
//   stays, the reads keep their index, and the writes pay for it once, in the
//   realignment.
// =============================================================================

/**
 * Persisted representation of a single consumption event.
 *
 * Maps to the `entries` table in the Room database.
 * Converted to/from [de.godisch.potillus.domain.model.ConsumptionEntry] by the
 * `internal` `toDomain` / `toEntity` extension functions in `EntityMapping.kt`.
 *
 * @param id              Auto-generated primary key (0 = unsaved).
 * @param drinkId         FK → [DrinkEntity.id], RESTRICT on delete.
 * @param drinkName       Snapshot of the drink name at log time.
 * @param volumeMl        Actual volume consumed in ml.
 * @param alcoholPercent  ABV snapshot at log time.
 * @param gramsAlcohol    Pre-calculated pure alcohol in grams (avoids re-computing
 *                        in SQL aggregate queries like SUM).
 * @param timestampMillis Unix epoch milliseconds (UTC) of the consumption.
 * @param utcOffsetSeconds UTC offset the entry was logged at. NOT NULL since
 *                        schema 4: `MIGRATION_3_4` backfilled every row that
 *                        predated the column and rebuilt the table with the
 *                        constraint, so no reader needs a fallback any more.
 * @param logicalDate     ISO-8601 "YYYY-MM-DD", DERIVED from the two columns
 *                        above. See the invariant below.
 * @param note            Optional free-text annotation.
 */
@Entity(
    tableName = "entries",
    foreignKeys = [
        ForeignKey(
            entity = DrinkEntity::class,
            parentColumns = ["id"],
            childColumns = ["drinkId"],
            onDelete = ForeignKey.RESTRICT,
        ),
    ],
    indices = [Index(value = ["drinkId"]), Index(value = ["logicalDate"])],
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
    // THE INVARIANT THIS COLUMN IS BOUND BY
    //   `logicalDate` is not an independent fact. Whenever the key row in
    //   `logical_day_key` is set, every row of this table satisfies
    //
    //       logicalDate == DayResolver.resolve(
    //           timestampMillis, utcOffsetSeconds, key.changeHour, key.changeMinute)
    //
    //   The key records WHICH day-change time the column was last computed
    //   under, so a half-finished rewrite is recognisable instead of silent, and
    //   a changed setting can be answered by recomputing rather than by guessing.
    //   A NULL key means "not computed yet" and is what a migration or an import
    //   leaves behind; the next realignment picks it up. See
    //   [de.godisch.potillus.data.repository.EntryRepository.realignDays].
    val logicalDate: String,
    val note: String = "",
    // LAST, still, but no longer for the original reason: that one appealed to
    // `ALTER TABLE … ADD COLUMN` appending, which made a migrated table differ
    // from a freshly created one unless the declaration matched. `MIGRATION_3_4`
    // rebuilds the table, so both are now created the same way and the order is
    // free. It is left untouched because moving it would churn the schema export
    // and the shared contract for nothing.
    val utcOffsetSeconds: Int,
)
