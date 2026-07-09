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

import de.godisch.potillus.data.db.dao.DailySummaryRaw
import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [EntryRepository]. The Room [EntryDao] is replaced by an
 * in-memory [FakeEntryDao] so the repository's mapping and delegation logic can
 * be exercised on the JVM without a database.
 */
class EntryRepositoryTest {

    private val dao = FakeEntryDao()
    private val repo = EntryRepository(dao)

    private fun sampleEntry() = ConsumptionEntry(
        drinkId = 2,
        drinkName = "Lager",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = 20.0,
        timestampMillis = 1L,
        logicalDate = "2026-01-01",
    )

    private fun sampleDrink() = DrinkDefinition(
        id = 2,
        name = "Lager",
        volumeMl = 500,
        alcoholPercent = 5.0,
    )

    @Test fun `flow reads map entities to domain models`() = runTest {
        assertEquals("Lager", repo.getEntriesForDate("2026-01-01").first().first().drinkName)
        assertEquals("2026-01-01", repo.getDailySummaries("a", "b").first().first().date)
        assertEquals(listOf("2026-01-01"), repo.getAllDatesFlow().first())
        assertEquals(1, repo.getEntriesForPeriod("a", "b").first().size)
        assertEquals("Lager", repo.mostRecentEntry().first()?.drinkName)
    }

    @Test fun `add maps the entry to an entity and returns the dao id`() = runTest {
        assertEquals(42L, repo.add(sampleEntry()))
        assertEquals("Lager", dao.lastInserted?.drinkName)
    }

    @Test fun `addFromDrink computes grams and a logical date`() = runTest {
        val id = repo.addFromDrink(sampleDrink(), 500, 1_700_000_000_000L, "", AppSettings())
        assertEquals(42L, id)
        assertTrue((dao.lastInserted?.gramsAlcohol ?: 0.0) > 0.0)
    }

    @Test fun `addFromDrinkWithDate keeps the supplied logical date`() = runTest {
        repo.addFromDrinkWithDate(sampleDrink(), 500, 1L, "", "2026-02-02")
        assertEquals("2026-02-02", dao.lastInserted?.logicalDate)
    }

    @Test fun `update variants and delete delegate to the dao`() = runTest {
        val entry = sampleEntry()
        repo.updateEntry(entry, AppSettings())
        repo.update(entry)
        repo.delete(entry)
        assertTrue(dao.updated)
        assertTrue(dao.deleted)
    }

    @Test fun `list reads and deleteAll delegate to the dao`() = runTest {
        assertEquals(1, repo.getAll().size)
        assertEquals(1, repo.getInRange("a", "b").size)
        repo.deleteAll()
        assertTrue(dao.clearedAll)
    }
}

/**
 * In-memory [EntryDao] returning fixed sample data, for [EntryRepositoryTest].
 */
private class FakeEntryDao : EntryDao {

    var lastInserted: EntryEntity? = null
    var updated = false
    var deleted = false
    var clearedAll = false

    private val sample = EntryEntity(
        id = 1,
        drinkId = 2,
        drinkName = "Lager",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = 20.0,
        timestampMillis = 1_700_000_000_000L,
        logicalDate = "2026-01-01",
        note = "n",
    )

    override fun getByDate(date: String): Flow<List<EntryEntity>> = flowOf(listOf(sample))

    override fun getDailySummaries(from: String, to: String): Flow<List<DailySummaryRaw>> = flowOf(listOf(DailySummaryRaw(logicalDate = "2026-01-01", totalGrams = 20.0, entryCount = 1)))

    override fun getAllDatesFlow(): Flow<List<String>> = flowOf(listOf("2026-01-01"))

    override suspend fun insert(entry: EntryEntity): Long {
        lastInserted = entry
        return 42L
    }

    override suspend fun insertOrReplace(entry: EntryEntity): Long {
        lastInserted = entry
        return 43L
    }

    override suspend fun update(entry: EntryEntity) {
        updated = true
    }

    override suspend fun delete(entry: EntryEntity) {
        deleted = true
    }

    override suspend fun getAll(): List<EntryEntity> = listOf(sample)

    override fun getMostRecent(): Flow<EntryEntity?> = flowOf(sample)

    override suspend fun getInRange(from: String, to: String): List<EntryEntity> = listOf(sample)

    override suspend fun deleteAll() {
        clearedAll = true
    }

    override suspend fun countByTimestampAndDrink(ts: Long, drinkId: Long): Int = 0

    override fun getEntriesForPeriodFlow(from: String, to: String): Flow<List<EntryEntity>> = flowOf(listOf(sample))
}
