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
package de.godisch.potillus.fake

import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

// See FakeEntryRepository.kt for the rationale behind Fake vs Mock.

class FakeDrinkRepository(
    initialDrinks: List<DrinkDefinition> = emptyList(),
) : IDrinkRepository {

    private val _drinks = MutableStateFlow(initialDrinks)
    override val drinks: Flow<List<DrinkDefinition>> = _drinks

    private var nextId = (initialDrinks.maxOfOrNull { it.id } ?: 0L) + 1

    /**
     * Configures how many consumption entries each drink ID has.
     * Used by tests for [deleteDrink] / [countEntriesForDrink] scenarios.
     */
    var entryCounts: Map<Long, Int> = emptyMap()

    // ── IDrinkRepository ─────────────────────────────────────────────────────

    override suspend fun add(drink: DrinkDefinition): Long {
        val id = nextId++
        _drinks.value = _drinks.value + drink.copy(id = id)
        return id
    }

    override suspend fun update(drink: DrinkDefinition) {
        _drinks.value = _drinks.value.map { if (it.id == drink.id) drink else it }
    }

    override suspend fun delete(drink: DrinkDefinition) {
        _drinks.value = _drinks.value.filter { it.id != drink.id }
    }

    override suspend fun countEntriesForDrink(drinkId: Long): Int = entryCounts[drinkId] ?: 0

    override suspend fun deleteUserCreatedDrinks() {
        _drinks.value = _drinks.value.filter { it.isPreset }
    }
}
