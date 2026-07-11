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

import de.godisch.potillus.data.db.dao.DailySummaryRaw
import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.entity.EntryEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the empty-database branches of [EntryRepository]: in particular the
 * null path of [EntryRepository.mostRecentEntry] when the DAO reports no rows.
 */
class EntryRepositoryEmptyTest {

    private val repo = EntryRepository(EmptyEntryDao())

    @Test fun `mostRecentEntry maps a null row to null`() = runTest {
        assertNull(repo.mostRecentEntry().first())
    }

    @Test fun `reads over an empty database return empty results`() = runTest {
        assertTrue(repo.getAll().isEmpty())
        assertTrue(repo.getEntriesForDate("2026-01-01").first().isEmpty())
    }
}

/**
 * In-memory [EntryDao] that behaves like an empty database.
 */
private class EmptyEntryDao : EntryDao {
    override fun getByDate(date: String): Flow<List<EntryEntity>> = flowOf(emptyList())
    override fun getDailySummaries(from: String, to: String): Flow<List<DailySummaryRaw>> = flowOf(emptyList())
    override fun getAllDatesFlow(): Flow<List<String>> = flowOf(emptyList())
    override suspend fun insert(entry: EntryEntity): Long = 0L
    override suspend fun insertOrReplace(entry: EntryEntity): Long = 0L
    override suspend fun update(entry: EntryEntity) {}
    override suspend fun delete(entry: EntryEntity) {}
    override suspend fun getAll(): List<EntryEntity> = emptyList()
    override fun getMostRecent(): Flow<EntryEntity?> = flowOf(null)
    override suspend fun getInRange(from: String, to: String): List<EntryEntity> = emptyList()
    override suspend fun deleteAll() {}
    override suspend fun countByTimestampAndDrink(ts: Long, drinkId: Long): Int = 0
    override fun getEntriesForPeriodFlow(from: String, to: String): Flow<List<EntryEntity>> = flowOf(emptyList())
}
