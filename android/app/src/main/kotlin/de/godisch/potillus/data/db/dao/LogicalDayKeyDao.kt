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
package de.godisch.potillus.data.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import de.godisch.potillus.data.db.entity.LogicalDayKeyEntity

// =============================================================================
// LogicalDayKeyDao.kt – Data Access Object for the one-row `logical_day_key`
// =============================================================================
//
// Three operations, and every one of them is meant to run INSIDE the same
// transaction as the `entries` rows it talks about. Reading the key outside a
// transaction and acting on the answer afterwards would be a check that another
// writer can invalidate before the write lands.
// =============================================================================

/** Reads and writes the single row of `logical_day_key`. */
@Dao
interface LogicalDayKeyDao {

    /**
     * The stored key, or `null` when the row is somehow absent.
     *
     * A row with two `null` columns and a missing row mean the same thing to
     * every caller — "the column has not been computed yet" — so callers should
     * treat both alike rather than distinguishing them. The migration creates
     * the row and nothing deletes it, so the `null` return is a belt-and-braces
     * case, not a state the app produces.
     */
    @Query("SELECT * FROM logical_day_key LIMIT 1")
    suspend fun get(): LogicalDayKeyEntity?

    /**
     * Writes the key, replacing whatever was there.
     *
     * REPLACE rather than `@Update`: `@Update` matches on the primary key and
     * silently does nothing when no row matches, which would leave the key
     * unwritten after the rows had already been rewritten — the one outcome this
     * table exists to prevent.
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun put(key: LogicalDayKeyEntity)

    /**
     * Sets the key back to "not computed yet".
     *
     * Called by every write path that puts rows into `entries` WITHOUT deriving
     * their logical day — the backup import today, anything similar later. The
     * next realignment then rebuilds the whole column instead of trusting rows
     * whose day came from somewhere else.
     */
    @Query("UPDATE logical_day_key SET changeHour = NULL, changeMinute = NULL")
    suspend fun invalidate()
}
