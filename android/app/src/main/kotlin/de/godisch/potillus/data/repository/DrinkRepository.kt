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
package de.godisch.potillus.data.repository

import de.godisch.potillus.data.db.dao.DrinkDao
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

// =============================================================================
// DrinkRepository.kt – Repository for drink definitions
// =============================================================================
//
// REPOSITORY PATTERN:
//   A repository is a mediator between the data layer (Room DAO, DataStore,
//   network) and the domain/UI layer (ViewModels). Its responsibilities:
//     1. Translate between persistence types (DrinkEntity) and domain types
//        (DrinkDefinition) so the rest of the app never imports Room.
//     2. Combine multiple data sources if needed (here: only Room).
//     3. Provide a clean, stable API that ViewModels can depend on without
//        knowing anything about the database schema.
//
// EXTENSION FUNCTIONS (toDomain / toEntity):
//   Defined once in EntityMapping.kt as module-`internal` top-level extensions
//   rather than inside the repository class, because they logically belong to
//   the Entity/Domain types, not to the repository itself. `internal` keeps
//   them visible to every repository in this module while hiding them from the
//   domain and UI layers (see the detailed note lower in this file).
// =============================================================================

/**
 * Repository for [DrinkDefinition] persistence.
 *
 * All public methods accept and return domain model objects ([DrinkDefinition]).
 * [DrinkEntity] details are hidden inside this file.
 *
 * @param dao  The Room DAO injected by [de.godisch.potillus.PotillusApp].
 */
class DrinkRepository(private val dao: DrinkDao) : IDrinkRepository {

    /**
     * Reactive stream of all drinks: favourites first, then alphabetically.
     *
     * This is a [Flow] that re-emits whenever the `drinks` table changes.
     * ViewModels collect it via [kotlinx.coroutines.flow.stateIn] to expose
     * the current list as a [kotlinx.coroutines.flow.StateFlow].
     *
     * The [map] operator transforms the Room emission from List<DrinkEntity>
     * to List<DrinkDefinition> without collecting the Flow (it stays lazy).
     */
    override val drinks: Flow<List<DrinkDefinition>> = dao.getAll().map { list ->
        list.map { it.toDomain() }
    }

    /**
     * Inserts [drink] and returns its new database ID.
     *
     * Note: [drink.id] is ignored on insert (Room auto-generates the key).
     * Use the returned ID if you need to reference the newly created drink.
     */
    override suspend fun add(drink: DrinkDefinition): Long = dao.insert(drink.toEntity())

    /** Updates all fields of an existing drink. [drink.id] must match an existing row. */
    override suspend fun update(drink: DrinkDefinition) = dao.update(drink.toEntity())

    /**
     * Deletes [drink].
     *
     * Throws [android.database.sqlite.SQLiteConstraintException] if any
     * consumption entry still references this drink (FK RESTRICT constraint
     * on the `entries` table). This exception propagates to the caller –
     * Room does **not** swallow it.
     *
     * Always call [countEntriesForDrink] first and present a user-facing message
     * when the count is > 0. [de.godisch.potillus.ui.screen.DrinksViewModel.deleteDrink]
     * does this via [DrinksEvent.DeleteBlocked] so the raw constraint exception
     * never reaches the UI.
     */
    override suspend fun delete(drink: DrinkDefinition) = dao.delete(drink.toEntity())

    /**
     * Returns the number of consumption entries that reference [drinkId].
     *
     * Call this before [delete] to give users a meaningful error message
     * ("This drink has N entries and cannot be deleted") instead of exposing
     * a raw SQLite constraint violation.
     *
     * @param drinkId  Primary key of the drink to check.
     * @return Number of entries referencing the drink (0 = safe to delete).
     */
    override suspend fun countEntriesForDrink(drinkId: Long): Int = dao.countEntriesByDrinkId(drinkId)

    /**
     * Deletes all user-created (non-preset) drinks.
     *
     * Called during a REPLACE backup import to reset the drink catalogue
     * to the preset-only state before inserting the backup's drinks.
     * Built-in presets (isPreset = true) are preserved.
     *
     * IMPORTANT: call [de.godisch.potillus.data.repository.EntryRepository.deleteAll]
     * BEFORE this, otherwise the FK RESTRICT constraint will block the deletion.
     */
    override suspend fun deleteUserCreatedDrinks() = dao.deleteUserCreatedDrinks()
}

// ── Entity ↔ Domain conversion ───────────────────────────────────────────────
//
// The conversion helpers (toDomain / toEntity) for both DrinkEntity and
// EntryEntity are defined once in EntityMapping.kt as `internal` extension
// functions, accessible to all files within this Gradle module. They were
// previously declared as `private` here and duplicated in BackupRepository;
// centralising them in one file removes that DRY violation. No callers in this
// file need to change — Kotlin resolves the `internal` extensions in scope.
