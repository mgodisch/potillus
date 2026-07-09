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

// =============================================================================
// IEntryRepository.kt – Contract for entry persistence
// =============================================================================
//
// WHY AN INTERFACE?
//   ViewModels previously depended on the concrete EntryRepository class,
//   which in turn required a Room DAO and therefore an Android runtime to
//   instantiate. Introducing this interface lets tests pass a lightweight
//   in-memory Fake implementation without spinning up a real database, and
//   without Robolectric.
//
// WELLE 5 NOTE:
//   Once SettingsViewModel no longer holds a direct AppDatabase reference,
//   every ViewModel in the codebase will depend solely on this interface.
// =============================================================================

import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow

/** Contract for all entry persistence operations used by the ViewModel layer. */
interface IEntryRepository {

    // ── Reactive queries ──────────────────────────────────────────────────────

    /** Emits the entries for a single logical day [date] ("YYYY-MM-DD"), updating on change. */
    fun getEntriesForDate(date: String): Flow<List<ConsumptionEntry>>

    /** Emits per-day gram summaries for the inclusive range [[from], [to]]. */
    fun getDailySummaries(from: String, to: String): Flow<List<DaySummary>>

    /** Emits the sorted list of all logical dates that have at least one entry. */
    fun getAllDatesFlow(): Flow<List<String>>

    /** Emits all entries whose logicalDate is within the inclusive range [[from], [to]]. */
    fun getEntriesForPeriod(from: String, to: String): Flow<List<ConsumptionEntry>>

    /** Emits the most recently logged entry (by timestamp), or `null` if there are none. */
    fun mostRecentEntry(): Flow<ConsumptionEntry?>

    // ── One-shot reads ────────────────────────────────────────────────────────

    /** Returns every entry (used by full JSON backup export). */
    suspend fun getAll(): List<ConsumptionEntry>

    /** Returns entries within the inclusive date range [[from], [to]] (index-backed query). */
    suspend fun getInRange(from: String, to: String): List<ConsumptionEntry>

    // ── Write operations ──────────────────────────────────────────────────────

    /** Inserts [entry] and returns its new row id. */
    suspend fun add(entry: ConsumptionEntry): Long

    /**
     * Creates and inserts an entry from a [drink] selection, deriving grams and
     * the logical date from [settings]. Returns the new row id.
     */
    suspend fun addFromDrink(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Long,
        note: String,
        settings: AppSettings,
    ): Long

    /**
     * Like [addFromDrink] but assigns an explicit [logicalDate] (used by the
     * calendar, where the target day is chosen by the user, not derived).
     */
    suspend fun addFromDrinkWithDate(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Long,
        note: String,
        logicalDate: String,
    ): Long

    /** Updates [entry], recomputing derived values (grams, logicalDate) from [settings]. */
    suspend fun updateEntry(entry: ConsumptionEntry, settings: AppSettings)

    /** Updates [entry] as-is, preserving its existing logicalDate (calendar edits). */
    suspend fun update(entry: ConsumptionEntry)

    /** Deletes [entry]. */
    suspend fun delete(entry: ConsumptionEntry)

    /** Deletes every entry (used by backup REPLACE import). */
    suspend fun deleteAll()
}
