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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.data.repository

import de.godisch.potillus.data.db.dao.DrinkDao
import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [DrinkRepository]. The Room [DrinkDao] is replaced by an
 * in-memory [FakeDrinkDao] so the repository's mapping and delegation logic can
 * be exercised on the JVM without a database.
 */
class DrinkRepositoryTest {

    private val dao = FakeDrinkDao()
    private val repo = DrinkRepository(dao)

    @Test fun `drinks flow maps entities to domain and defaults unknown category`() = runTest {
        val drinks = repo.drinks.first()
        assertEquals(2, drinks.size)
        assertEquals(DrinkCategory.BEER, drinks[0].category)
        // "BOGUS" is not a valid DrinkCategory, so it must fall back to OTHER.
        assertEquals(DrinkCategory.OTHER, drinks[1].category)
    }

    @Test fun `add maps to an entity and returns the dao id`() = runTest {
        val id = repo.add(DrinkDefinition(name = "Stout", volumeMl = 440, alcoholPercent = 4.5))
        assertEquals(7L, id)
        assertEquals("Stout", dao.lastInserted?.name)
    }

    @Test fun `update and delete delegate to the dao`() = runTest {
        val drink = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        repo.update(drink)
        repo.delete(drink)
        assertTrue(dao.updated)
        assertTrue(dao.deleted)
    }

    @Test fun `count and bulk delete delegate to the dao`() = runTest {
        assertEquals(3, repo.countEntriesForDrink(1))
        repo.deleteUserCreatedDrinks()
        assertTrue(dao.clearedUserCreated)
    }
}

/**
 * In-memory [DrinkDao] returning fixed sample data, for [DrinkRepositoryTest].
 */
private class FakeDrinkDao : DrinkDao {

    var lastInserted: DrinkEntity? = null
    var updated = false
    var deleted = false
    var clearedUserCreated = false

    private val samples = listOf(
        DrinkEntity(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0, category = "BEER"),
        DrinkEntity(id = 2, name = "Mystery", volumeMl = 40, alcoholPercent = 40.0, category = "BOGUS"),
    )

    override fun getAll(): Flow<List<DrinkEntity>> = flowOf(samples)

    override suspend fun getAllOnce(): List<DrinkEntity> = samples

    override suspend fun getById(id: Long): DrinkEntity? = samples.firstOrNull { it.id == id }

    override suspend fun insert(drink: DrinkEntity): Long {
        lastInserted = drink
        return 7L
    }

    override suspend fun update(drink: DrinkEntity) {
        updated = true
    }

    override suspend fun delete(drink: DrinkEntity) {
        deleted = true
    }

    override suspend fun countEntriesByDrinkId(drinkId: Long): Int = 3

    override suspend fun countPresets(): Int = 1

    override suspend fun deleteUserCreatedDrinks() {
        clearedUserCreated = true
    }
}
