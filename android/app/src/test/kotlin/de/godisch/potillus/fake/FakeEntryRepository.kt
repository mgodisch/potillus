/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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

// =============================================================================
// FakeEntryRepository.kt – In-memory IEntryRepository for unit tests
// =============================================================================
//
// WHY a Fake instead of a Mock (Mockito / MockK)?
//   A Fake is a real implementation with simplified behaviour. It is:
//     - Self-contained: no mocking framework dependency, no annotation magic.
//     - Readable: the test reader sees exactly what the fake does.
//     - Reactive: it uses MutableStateFlow, so ViewModels that collect from
//       getEntriesForDate() / getDailySummaries() etc. actually receive updates
//       when the test calls add() or delete(). A mock would need to be
//       reconfigured after every state change.
//
// THREAD SAFETY:
//   MutableStateFlow.value assignments are atomic. The fake is suitable for
//   single-threaded test dispatchers (UnconfinedTestDispatcher).
// =============================================================================

import de.godisch.potillus.data.repository.IEntryRepository
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

class FakeEntryRepository : IEntryRepository {

    // Central in-memory store; tests can inspect this directly.
    private val _entries = MutableStateFlow<List<ConsumptionEntry>>(emptyList())
    private var nextId   = 1L

    // Convenience property for assertions in tests.
    val allEntries: List<ConsumptionEntry> get() = _entries.value

    // ── Reactive queries ──────────────────────────────────────────────────────

    override fun getEntriesForDate(date: String): Flow<List<ConsumptionEntry>> =
        _entries.map { it.filter { e -> e.logicalDate == date } }

    override fun getDailySummaries(from: String, to: String): Flow<List<DaySummary>> =
        _entries.map { list ->
            list.filter { it.logicalDate in from..to }
                .groupBy { it.logicalDate }
                .map { (date, es) -> DaySummary(date, es.sumOf { it.gramsAlcohol }, es.size) }
                .sortedBy { it.date }
        }

    override fun getAllDatesFlow(): Flow<List<String>> =
        _entries.map { it.map { e -> e.logicalDate }.distinct().sorted() }

    override fun getEntriesForPeriod(from: String, to: String): Flow<List<ConsumptionEntry>> =
        _entries.map { it.filter { e -> e.logicalDate in from..to } }

    override fun mostRecentEntry(): Flow<ConsumptionEntry?> =
        _entries.map { list -> list.maxByOrNull { it.timestampMillis } }

    // ── One-shot reads ────────────────────────────────────────────────────────

    override suspend fun getById(id: Long): ConsumptionEntry? =
        _entries.value.find { it.id == id }

    override suspend fun getAll(): List<ConsumptionEntry> = _entries.value

    override suspend fun getInRange(from: String, to: String): List<ConsumptionEntry> =
        _entries.value.filter { it.logicalDate in from..to }

    // ── Write operations ──────────────────────────────────────────────────────

    override suspend fun add(entry: ConsumptionEntry): Long {
        val id = nextId++
        _entries.value = _entries.value + entry.copy(id = id)
        return id
    }

    override suspend fun addFromDrink(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Long,
        note: String,
        settings: AppSettings
    ): Long {
        val logical = DayResolver.resolve(
            timestampMillis,
            settings.dayChangeHour,
            settings.dayChangeMinute
        )
        return add(ConsumptionEntry(
            drinkId         = drink.id,
            drinkName       = drink.name,
            volumeMl        = volumeMl,
            alcoholPercent  = drink.alcoholPercent,
            gramsAlcohol    = AlcoholCalculator.calculateGrams(volumeMl, drink.alcoholPercent),
            timestampMillis = timestampMillis,
            logicalDate     = logical,
            note            = note
        ))
    }

    override suspend fun addFromDrinkWithDate(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Long,
        note: String,
        logicalDate: String
    ): Long = add(ConsumptionEntry(
        drinkId         = drink.id,
        drinkName       = drink.name,
        volumeMl        = volumeMl,
        alcoholPercent  = drink.alcoholPercent,
        gramsAlcohol    = AlcoholCalculator.calculateGrams(volumeMl, drink.alcoholPercent),
        timestampMillis = timestampMillis,
        logicalDate     = logicalDate,
        note            = note
    ))

    override suspend fun updateEntry(entry: ConsumptionEntry, settings: AppSettings) {
        val newDate = DayResolver.resolve(
            entry.timestampMillis,
            settings.dayChangeHour,
            settings.dayChangeMinute
        )
        update(entry.copy(logicalDate = newDate))
    }

    override suspend fun update(entry: ConsumptionEntry) {
        _entries.value = _entries.value.map { if (it.id == entry.id) entry else it }
    }

    override suspend fun delete(entry: ConsumptionEntry) {
        _entries.value = _entries.value.filter { it.id != entry.id }
    }

    override suspend fun deleteAll() { _entries.value = emptyList() }

    override suspend fun isDuplicate(timestampMillis: Long, drinkId: Long): Boolean =
        _entries.value.any { it.timestampMillis == timestampMillis && it.drinkId == drinkId }
}
