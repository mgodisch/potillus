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
// IDrinkRepository.kt – Contract for drink-definition persistence
// =============================================================================
//
// Same motivation as IEntryRepository: decouples ViewModels from Room so that
// unit tests can use FakeDrinkRepository without an Android environment.
// =============================================================================

import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow

/** Contract for all drink-definition persistence operations used by the ViewModel layer. */
interface IDrinkRepository {

    /** Reactive stream of all drinks: favourites first, then alphabetically. */
    val drinks: Flow<List<DrinkDefinition>>

    /** Returns the drink with [id], or `null` if it does not exist. */
    suspend fun getById(id: Long): DrinkDefinition?

    /** Inserts [drink] and returns its new database ID. */
    suspend fun add(drink: DrinkDefinition): Long

    /** Updates [drink] (name, volume, ABV, category, favourite flag). */
    suspend fun update(drink: DrinkDefinition)

    /** Deletes [drink]. Callers should first check [countEntriesForDrink]. */
    suspend fun delete(drink: DrinkDefinition)

    /** Returns how many consumption entries reference [drinkId] (delete guard). */
    suspend fun countEntriesForDrink(drinkId: Long): Int

    /** Deletes all user-created (non-preset) drinks. Used during REPLACE imports. */
    suspend fun deleteUserCreatedDrinks()
}
