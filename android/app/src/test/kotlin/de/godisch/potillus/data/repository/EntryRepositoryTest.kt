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
import de.godisch.potillus.data.db.entity.LogicalDayKeyEntity
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.fake.DirectTransactor
import de.godisch.potillus.fake.FakeLogicalDayKeyDao
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
    private val keyDao = FakeLogicalDayKeyDao()
    private val repo = EntryRepository(dao, keyDao, DirectTransactor())

    private fun sampleEntry() = ConsumptionEntry(
        drinkId = 2,
        drinkName = "Lager",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = 20.0,
        timestampMillis = 1L,
        logicalDate = "2026-01-01",
        utcOffsetSeconds = 0,
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
        assertEquals(listOf("2026-01-01"), repo.getDrinkDatesFlow().first())
        assertEquals(1, repo.getEntriesForPeriod("a", "b").first().size)
        assertEquals("Lager", repo.mostRecentEntry().first()?.drinkName)
    }

    @Test fun `add maps the entry to an entity and returns the dao id`() = runTest {
        assertEquals(42L, repo.add(sampleEntry(), AppSettings()))
        assertEquals("Lager", dao.lastInserted?.drinkName)
    }

    @Test fun `addFromDrink computes grams and a logical date`() = runTest {
        val id = repo.addFromDrink(sampleDrink(), 500, 1_700_000_000_000L, "", AppSettings())
        assertEquals(42L, id)
        assertTrue((dao.lastInserted?.gramsAlcohol ?: 0.0) > 0.0)
    }

    @Test fun `add derives the day rather than storing what it was handed`() = runTest {
        // 01:00 read at +00:00, boundary 04:00: before the boundary, so the entry
        // counts for the previous day — and the claim on the object is discarded.
        repo.add(
            sampleEntry().copy(timestampMillis = 3_600_000L, logicalDate = "1999-12-31"),
            AppSettings(),
        )
        assertEquals("1969-12-31", dao.lastInserted?.logicalDate)
    }

    @Test fun `update and delete delegate to the dao`() = runTest {
        val entry = sampleEntry()
        repo.update(entry, AppSettings())
        repo.delete(entry)
        assertTrue(dao.updated)
        assertTrue(dao.deleted)
    }

    // ── Realignment and the key ───────────────────────────────────────────────

    @Test fun `realignDays rewrites every day and records the new boundary`() = runTest {
        dao.rows = listOf(rowAt(millis = MARCH_10_2300, day = "2026-03-10"))

        repo.realignDays(AppSettings(dayChangeHour = 4, dayChangeMinute = 0))

        assertEquals(4, keyDao.get()?.changeHour)
        assertEquals(0, keyDao.get()?.changeMinute)
        assertEquals("2026-03-10", dao.rows.single().logicalDate)

        // 23:00 is before a 23:30 boundary, so the same reading now counts for
        // the previous day. Nothing about the row itself changed.
        repo.realignDays(AppSettings(dayChangeHour = 23, dayChangeMinute = 30))

        assertEquals(23, keyDao.get()?.changeHour)
        assertEquals("2026-03-09", dao.rows.single().logicalDate)
        assertEquals(MARCH_10_2300, dao.rows.single().timestampMillis)
    }

    @Test fun `realignDays does nothing when the key already matches`() = runTest {
        keyDao.put(LogicalDayKeyEntity(changeHour = 4, changeMinute = 0))
        dao.rows = listOf(rowAt(millis = MARCH_10_2300, day = "whatever-was-there"))

        repo.realignDays(AppSettings(dayChangeHour = 4, dayChangeMinute = 0))

        assertEquals(
            "an untouched key means an untouched table",
            "whatever-was-there",
            dao.rows.single().logicalDate,
        )
    }

    @Test fun `the first realignment repairs a pre-0_85_0 calendar entry`() = runTest {
        // Filed under 5 March, but the reading says 10 March: the old calendar
        // path stored the instant of the day it was booked ON.
        dao.rows = listOf(rowAt(millis = MARCH_10_2300, day = "2026-03-05"))

        repo.realignDays(AppSettings(dayChangeHour = 4, dayChangeMinute = 0))

        assertEquals("2026-03-05", dao.rows.single().logicalDate)
        assertTrue(
            "the instant moves back to the day the user chose",
            dao.rows.single().timestampMillis < MARCH_10_2300,
        )
    }

    @Test fun `a one-day gap is left alone`() = runTest {
        // 01:00 on the calendar 11th, filed under the logical 10th: what a 04:00
        // boundary produces every night, and not damage.
        val afterMidnight = 1_773_190_800_000L // 2026-03-11T01:00Z
        dao.rows = listOf(rowAt(millis = afterMidnight, day = "2026-03-10"))

        repo.realignDays(AppSettings(dayChangeHour = 4, dayChangeMinute = 0))

        assertEquals(afterMidnight, dao.rows.single().timestampMillis)
        assertEquals("2026-03-10", dao.rows.single().logicalDate)
    }

    @Test fun `a repaired row is derived under the key it was repaired with`() = runTest {
        dao.rows = listOf(rowAt(millis = MARCH_10_2300, day = "2026-03-05"))
        repo.realignDays(AppSettings())

        val row = dao.rows.single()
        assertEquals(
            DayResolver.resolve(row.timestampMillis, row.utcOffsetSeconds, 4, 0),
            row.logicalDate,
        )
    }

    @Test fun `list reads and deleteAll delegate to the dao`() = runTest {
        assertEquals(1, repo.getAll().size)
        assertEquals(1, repo.getInRange("a", "b").size)
        repo.deleteAll()
        assertTrue(dao.clearedAll)
    }

    /** A row read at +00:00, so every expectation above is fixed by the file. */
    private fun rowAt(millis: Long, day: String) = EntryEntity(
        id = 7,
        drinkId = 2,
        drinkName = "Lager",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = 20.0,
        timestampMillis = millis,
        logicalDate = day,
        note = "",
        utcOffsetSeconds = 0,
    )

    private companion object {
        /** 2026-03-10T23:00Z, i.e. 23:00 read at +00:00. */
        const val MARCH_10_2300 = 1_773_183_600_000L
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
        utcOffsetSeconds = 0,
    )

    /**
     * The table, as far as the realignment can see it.
     *
     * The reads above answer from a fixed sample and ignore this; a realignment
     * case sets it and then reads it back. Keeping the two apart leaves the older
     * delegation tests exactly as they were.
     */
    var rows: List<EntryEntity> = listOf(sample)

    override fun getByDate(date: String): Flow<List<EntryEntity>> = flowOf(listOf(sample))

    override fun getDailySummaries(from: String, to: String): Flow<List<DailySummaryRaw>> = flowOf(listOf(DailySummaryRaw(logicalDate = "2026-01-01", totalGrams = 20.0, entryCount = 1)))

    override fun getAllDatesFlow(): Flow<List<String>> = flowOf(listOf("2026-01-01"))

    override fun getDrinkDatesFlow(): Flow<List<String>> = flowOf(listOf("2026-01-01"))

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

    /** Writes the changed rows back, matching on the primary key, as Room does. */
    override suspend fun updateAll(entries: List<EntryEntity>) {
        val byId = entries.associateBy { it.id }
        rows = rows.map { byId[it.id] ?: it }
    }

    override suspend fun delete(entry: EntryEntity) {
        deleted = true
    }

    override suspend fun getAll(): List<EntryEntity> = rows

    override fun getMostRecent(): Flow<EntryEntity?> = flowOf(sample)

    override suspend fun getInRange(from: String, to: String): List<EntryEntity> = listOf(sample)

    override suspend fun deleteAll() {
        clearedAll = true
    }

    override suspend fun countByTimestampAndDrink(ts: Long, drinkId: Long): Int = 0

    override fun getEntriesForPeriodFlow(from: String, to: String): Flow<List<EntryEntity>> = flowOf(listOf(sample))
}
