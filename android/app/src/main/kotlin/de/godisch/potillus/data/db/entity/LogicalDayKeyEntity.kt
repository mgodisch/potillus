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
import androidx.room.PrimaryKey

// =============================================================================
// LogicalDayKeyEntity.kt – which day-change time `entries.logicalDate` holds
// =============================================================================
//
// WHAT A "KEY" IS HERE
//   `entries.logicalDate` is a derived column: it is what
//   `DayResolver.resolve(timestampMillis, utcOffsetSeconds, changeHour,
//   changeMinute)` returns. A derivation is only usable if the input it was made
//   with is known, and that input is the user's day-change time — a setting that
//   can move. This table records the day-change time the whole column was last
//   computed under. One row, always.
//
// WHY A TABLE AND NOT A PREFERENCE
//   The key must be written in the SAME TRANSACTION as the rows it describes.
//   A value in the encrypted preferences file could not be: the two stores
//   commit independently, so a process death between them would leave a key that
//   claims something about rows that were never rewritten. Inside SQLite the two
//   writes are one, which is the whole point — an interrupted realignment rolls
//   back, the key stays at its old value, and the next comparison starts over.
//
// WHY NULLABLE COLUMNS
//   NULL means "not computed yet", and it is the state a fresh migration and a
//   finished backup import both leave behind. It cannot be expressed by the
//   absence of the row, because "no row" and "a row full of NULLs" would then
//   both have to be handled by every reader; the migration creates the row once
//   and nothing ever deletes it. See `EntryRepository.realignDays` for the two
//   things that can happen when the key is read.
//
// WHY A SINGLE ROW WITH A FIXED PRIMARY KEY
//   The table is a variable, not a log. Pinning the key to [SINGLETON_ID] makes
//   a second row impossible: an insert with the same id either fails or replaces,
//   and both are better than two rows disagreeing about what the column means.
// =============================================================================

/**
 * The day-change time `entries.logicalDate` was last derived under.
 *
 * @param id            Always [SINGLETON_ID]; the table holds exactly one row.
 * @param changeHour    Hour of the day-change boundary the column was computed
 *                      with, or `null` when it has not been computed yet.
 * @param changeMinute  Minute of that boundary, `null` under the same condition.
 *                      The two are always both set or both `null`; they are
 *                      written together and read together.
 */
@Entity(tableName = "logical_day_key")
data class LogicalDayKeyEntity(
    @PrimaryKey
    val id: Int = SINGLETON_ID,
    val changeHour: Int? = null,
    val changeMinute: Int? = null,
) {
    companion object {
        /** The primary key of the one row this table is allowed to hold. */
        const val SINGLETON_ID = 1
    }
}
