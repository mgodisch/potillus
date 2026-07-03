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
package de.godisch.potillus.data.db.dao

import androidx.room.*
import de.godisch.potillus.data.db.entity.DrinkEntity
import kotlinx.coroutines.flow.Flow

// =============================================================================
// DrinkDao.kt – Data Access Object for the "drinks" table
// =============================================================================
//
// ROOM DAO:
//   An interface annotated with @Dao. Room's annotation processor generates
//   the implementing class at compile time, so there is no hand-written SQL
//   execution code in the app.
//
// Flow vs suspend:
//   - Flow<T>   → a *reactive* stream; Room re-emits whenever the underlying
//                 table changes. Use for data that the UI must always see fresh.
//   - suspend   → a *one-shot* read; called from a coroutine, returns once,
//                 does not react to later changes. Use for background operations
//                 (insert, update, delete, count checks).
//
// KOTLIN IMPORT ALIAS:
//   "import androidx.room.*" imports all public declarations from the Room
//   package at once (wildcard import). Avoids one import line per annotation.
// =============================================================================

/**
 * Room Data Access Object for [DrinkEntity].
 *
 * All queries are exposed via the repository ([de.godisch.potillus.data.repository.DrinkRepository]),
 * which converts between [DrinkEntity] and the domain model [de.godisch.potillus.domain.model.DrinkDefinition].
 * ViewModels and the UI layer never interact with the DAO directly.
 */
@Dao
interface DrinkDao {

    /**
     * Reactive stream of all drinks, ordered favourites-first, then alphabetically.
     *
     * Returns a [Flow] so the UI recomposes automatically whenever a drink
     * is added, updated, or deleted. The [Flow] stays active as long as the
     * ViewModel's [kotlinx.coroutines.CoroutineScope] is alive.
     *
     * SQL ORDER BY: `isFavorite DESC` (1 before 0) then `name ASC`.
     */
    @Query("SELECT * FROM drinks ORDER BY isFavorite DESC, name ASC")
    fun getAll(): Flow<List<DrinkEntity>>

    /**
     * One-shot snapshot of all drinks, ordered favourites-first, then alphabetically.
     *
     * WHY a separate method alongside [getAll]?
     *   [getAll] returns a [Flow] – suitable for reactive UI updates but not
     *   callable inside a Room `withTransaction` block, because Flow collection
     *   requires a coroutine dispatcher that conflicts with the transaction's
     *   single-threaded executor. [getAllOnce] is a plain `suspend` one-shot
     *   query that is safe to call inside transactions.
     *
     * Used exclusively by [de.godisch.potillus.data.repository.BackupRepository]
     * to look up existing drink names before ID remapping.
     */
    @Query("SELECT * FROM drinks ORDER BY isFavorite DESC, name ASC")
    suspend fun getAllOnce(): List<DrinkEntity>

    /**
     * One-shot lookup of a single drink by its primary key.
     *
     * Returns `null` if no drink with [id] exists.
     *
     * NOTE: no production code calls this — its sole consumer is
     * BackupRepositoryInstrumentedTest, which uses it to verify that imported
     * entries were re-linked to the correct drink row. It is kept for that
     * white-box assertion; the repository layer deliberately does NOT expose it
     * (the former IDrinkRepository.getById was removed as dead API in the
     * v0.78.0 QA review).
     */
    @Query("SELECT * FROM drinks WHERE id = :id")
    suspend fun getById(id: Long): DrinkEntity?

    /**
     * Inserts a new drink and returns its auto-generated row ID.
     *
     * WHY [OnConflictStrategy.ABORT] (mirroring [EntryDao.insert])?
     *   Every caller inserts with `id = 0`, which Room treats as "unset" and
     *   replaces with the next auto-incremented primary key, so a primary-key
     *   collision cannot arise on the normal path:
     *     - [de.godisch.potillus.data.repository.DrinkRepository.add] builds a
     *       fresh [de.godisch.potillus.domain.model.DrinkDefinition] (its `id`
     *       defaults to 0); editing an existing drink goes through [update], not here.
     *     - [de.godisch.potillus.data.repository.BackupRepository] inserts backup
     *       drinks with `id = 0` — it deliberately remaps them to fresh local ids
     *       rather than preserving the backup's ids.
     *     - the preset pre-population
     *       ([de.godisch.potillus.data.db.AppDatabase]) inserts with `id = 0`.
     *   ABORT therefore never triggers in practice; it is chosen so that any FUTURE
     *   explicit-id insert that DID collide fails loudly instead of silently
     *   overwriting an existing row (the behaviour of the previous
     *   [OnConflictStrategy.REPLACE]).
     *
     *   NOTE: the `drinks` table has NO UNIQUE constraint on `name` (only the
     *   primary key on `id`; see the exported schema in `app/schemas/`), so REPLACE
     *   never served a name-uniqueness purpose — the earlier "re-insert presets
     *   without failing on the unique constraint" rationale did not apply. Name-based
     *   de-duplication for backup import is handled explicitly in
     *   [de.godisch.potillus.data.repository.BackupRepository] (`buildIdMap`).
     *
     * @return  The auto-generated row ID of the inserted drink.
     */
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(drink: DrinkEntity): Long

    /** Updates all columns of an existing drink row. */
    @Update
    suspend fun update(drink: DrinkEntity)

    /**
     * Deletes the given drink row.
     *
     * Will throw [android.database.sqlite.SQLiteConstraintException] if any
     * entry still references this drink (FK RESTRICT). Call
     * [countEntriesByDrinkId] first and handle the non-zero case in the UI.
     */
    @Delete
    suspend fun delete(drink: DrinkEntity)

    /**
     * Counts how many preset drinks exist in the table.
     *
     * Used by [de.godisch.potillus.data.db.AppDatabase.PrepopulateCallback] to
     * avoid re-inserting presets every time the app launches (the callback
     * fires only on database *creation*, but this guard provides an
     * additional safety net).
     */
    @Query("SELECT COUNT(*) FROM drinks WHERE isPreset = 1")
    suspend fun countPresets(): Int

    /**
     * Returns how many consumption entries reference [drinkId].
     *
     * The caller ([de.godisch.potillus.data.repository.DrinkRepository.countEntriesForDrink])
     * uses this to show a friendly error message instead of letting the
     * FK RESTRICT constraint surface as an uncaught exception.
     *
     * @param drinkId  Primary key of the drink to check.
     * @return         Number of entries that would be orphaned by a deletion.
     */
    @Query("SELECT COUNT(*) FROM entries WHERE drinkId = :drinkId")
    suspend fun countEntriesByDrinkId(drinkId: Long): Int

    /**
     * Deletes all non-preset (user-created) drinks.
     *
     * Called during a REPLACE backup import to clear the user's drink
     * catalogue before inserting the backup's drinks, while keeping
     * built-in presets untouched.
     *
     * Note: entries must be deleted BEFORE this runs because of the
     * FK RESTRICT constraint. The import transaction in SettingsViewModel
     * calls [de.godisch.potillus.data.db.dao.EntryDao.deleteAll] first.
     */
    @Query("DELETE FROM drinks WHERE isPreset = 0")
    suspend fun deleteUserCreatedDrinks()
}
