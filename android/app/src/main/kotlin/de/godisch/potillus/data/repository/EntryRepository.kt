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

import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Repository for [ConsumptionEntry] persistence.
 *
 * All public methods accept and return domain model objects. The Room entity
 * [EntryEntity] is an implementation detail hidden inside this file.
 *
 * @param dao  Room DAO injected by [de.godisch.potillus.PotillusApp].
 */
class EntryRepository(private val dao: EntryDao) : IEntryRepository {

    // ── Reactive queries ──────────────────────────────────────────────────────

    /**
     * Reactive stream of all entries for a single logical date, ordered by time.
     *
     * Re-emits automatically whenever an entry is added, edited, or deleted.
     * Used by [de.godisch.potillus.ui.screen.TodayViewModel] and
     * [de.godisch.potillus.ui.screen.CalendarViewModel].
     *
     * @param date  Logical date as "YYYY-MM-DD".
     */
    override fun getEntriesForDate(date: String): Flow<List<ConsumptionEntry>> = dao.getByDate(date).map { list -> list.map { it.toDomain() } }

    /**
     * Reactive stream of per-day totals for a date range.
     *
     * The aggregation is performed in SQLite (GROUP BY + SUM) for efficiency.
     * Only days with at least one entry appear; zero-gram days are omitted.
     *
     * @param from  Start date inclusive.
     * @param to    End date inclusive.
     */
    override fun getDailySummaries(from: String, to: String): Flow<List<DaySummary>> = dao.getDailySummaries(from, to).map { list ->
        list.map { raw -> DaySummary(date = raw.logicalDate, totalGrams = raw.totalGrams, entryCount = raw.entryCount) }
    }

    /**
     * Reactive stream of all distinct dates that have at least one entry.
     *
     * Used by [de.godisch.potillus.ui.screen.StatsViewModel] for streak calculation.
     * The returned list is always sorted ascending ("YYYY-MM-DD" lexicographic
     * order equals chronological order, so String comparison is correct).
     */
    override fun getAllDatesFlow(): Flow<List<String>> = dao.getAllDatesFlow()

    /**
     * Reactive stream of all entries in a logical date range.
     *
     * Used by [de.godisch.potillus.ui.screen.StatsViewModel] to compute per-category
     * totals ([de.godisch.potillus.domain.model.DrinkCategory] → grams).
     *
     * @param from  Start date inclusive.
     * @param to    End date inclusive.
     */
    override fun getEntriesForPeriod(from: String, to: String): Flow<List<ConsumptionEntry>> = dao.getEntriesForPeriodFlow(from, to).map { list -> list.map { it.toDomain() } }

    /**
     * Reactive stream of the most recently logged entry (by timestamp), or
     * `null` when no entries exist yet.
     *
     * Delegates to [EntryDao.getMostRecent], which uses `ORDER BY timestampMillis
     * DESC LIMIT 1` in SQL so only one row is ever read from the database.
     * Used by [de.godisch.potillus.ui.screen.TodayViewModel] to pre-select the
     * last-used drink in the add-entry dialog.
     */
    override fun mostRecentEntry(): Flow<ConsumptionEntry?> = dao.getMostRecent().map { it?.toDomain() }

    // ── Write operations ──────────────────────────────────────────────────────

    /**
     * Inserts [entry] and returns its new database ID.
     *
     * Low-level insert: the caller is responsible for populating all fields
     * correctly. Prefer [addFromDrink] or [addFromDrinkWithDate] for new entries.
     */
    override suspend fun add(entry: ConsumptionEntry): Long = dao.insert(entry.toEntity())

    /**
     * Creates and persists a new entry from a drink definition and a timestamp.
     *
     * This is the primary "log a drink now" path used by [de.godisch.potillus.ui.screen.TodayViewModel]:
     * - Calculates [ConsumptionEntry.gramsAlcohol] from the drink definition.
     * - Derives [ConsumptionEntry.logicalDate] from [timestampMillis] and the
     *   configured day-change time, so a drink logged at 02:30 AM is attributed
     *   to yesterday.
     *
     * @param drink            The drink template to log.
     * @param volumeMl         Actual volume consumed (may differ from the drink's default).
     * @param timestampMillis  Unix epoch milliseconds of the consumption event.
     * @param note             Optional free-text annotation.
     * @param settings         Current user settings (needed for the day-change time).
     * @return Database ID of the new entry.
     */
    override suspend fun addFromDrink(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Long,
        note: String,
        settings: AppSettings,
    ): Long {
        val logical = DayResolver.resolve(timestampMillis, settings.dayChangeHour, settings.dayChangeMinute)
        return add(
            ConsumptionEntry(
                drinkId = drink.id,
                drinkName = drink.name,
                volumeMl = volumeMl,
                alcoholPercent = drink.alcoholPercent,
                gramsAlcohol = AlcoholCalculator.calculateGrams(volumeMl, drink.alcoholPercent),
                timestampMillis = timestampMillis,
                logicalDate = logical,
                note = note,
            ),
        )
    }

    /**
     * Creates and persists a new entry with an explicit logical date.
     *
     * Used by [de.godisch.potillus.ui.screen.CalendarViewModel]: when the user
     * taps a past day in the calendar and adds an entry, the [logicalDate]
     * must be the selected calendar day (not derived from [timestampMillis]).
     * The timestamp stores the chosen wall-clock time of day, but the date
     * is overridden by the calendar selection.
     *
     * @param drink            The drink template to log.
     * @param volumeMl         Actual volume consumed.
     * @param timestampMillis  Wall-clock time of the consumption (for display).
     * @param note             Optional annotation.
     * @param logicalDate      The date to assign the entry to ("YYYY-MM-DD").
     * @return Database ID of the new entry.
     */
    override suspend fun addFromDrinkWithDate(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Long,
        note: String,
        logicalDate: String,
    ): Long = add(
        ConsumptionEntry(
            drinkId = drink.id,
            drinkName = drink.name,
            volumeMl = volumeMl,
            alcoholPercent = drink.alcoholPercent,
            gramsAlcohol = AlcoholCalculator.calculateGrams(volumeMl, drink.alcoholPercent),
            timestampMillis = timestampMillis,
            logicalDate = logicalDate,
            note = note,
        ),
    )

    /**
     * Updates an entry and **recalculates** [ConsumptionEntry.logicalDate] from the
     * (possibly new) timestamp and the day-change time.
     *
     * Used by [de.godisch.potillus.ui.screen.TodayViewModel.updateEntry] when the user
     * edits an entry on the Today screen and may have changed the time. Recalculating
     * [logicalDate] ensures that changing the time from 03:00 to 05:00 (crossing
     * the day boundary) correctly moves the entry to today.
     *
     * Contrast with [update] (below), which preserves [logicalDate] as-is.
     *
     * @param entry    The updated entry (must carry the correct [ConsumptionEntry.id]).
     * @param settings Current user settings (provides day-change hour/minute).
     */
    override suspend fun updateEntry(entry: ConsumptionEntry, settings: AppSettings) {
        val newLogicalDate = DayResolver.resolve(
            entry.timestampMillis,
            settings.dayChangeHour,
            settings.dayChangeMinute,
        )
        dao.update(entry.copy(logicalDate = newLogicalDate).toEntity())
    }

    /**
     * Updates an entry while **preserving** [ConsumptionEntry.logicalDate].
     *
     * Used by [de.godisch.potillus.ui.screen.CalendarViewModel.updateEntry] for
     * calendar entries: the user edits the time-of-day but the logical date
     * (the calendar day the entry belongs to) must remain unchanged, because
     * the user deliberately assigned it to that date.
     *
     * @param entry  The entry to persist. All fields including [logicalDate] are
     *               written as-is.
     */
    override suspend fun update(entry: ConsumptionEntry) = dao.update(entry.toEntity())

    /** Deletes [entry] from the database. */
    override suspend fun delete(entry: ConsumptionEntry) = dao.delete(entry.toEntity())

    /**
     * Returns all entries ordered chronologically.
     *
     * One-shot snapshot for export (CSV, PDF) and backup operations.
     */
    override suspend fun getAll(): List<ConsumptionEntry> = dao.getAll().map { it.toDomain() }

    /**
     * One-shot snapshot of entries within a logical date range.
     *
     * Delegates the WHERE clause to SQLite so the query planner can use the
     * `index_entries_logicalDate` index. Prefer this over [getAll] whenever
     * a date filter is known up-front (CSV and PDF exports).
     *
     * @param from  Start date inclusive ("YYYY-MM-DD").
     * @param to    End date inclusive ("YYYY-MM-DD").
     */
    override suspend fun getInRange(from: String, to: String): List<ConsumptionEntry> = dao.getInRange(from, to).map { it.toDomain() }

    /**
     * Deletes all entries. Called at the start of a REPLACE backup import.
     *
     * IMPORTANT: wrap this in a database transaction together with
     * [de.godisch.potillus.data.repository.DrinkRepository.deleteUserCreatedDrinks]
     * so the database is never left in a partially-cleared state.
     */
    override suspend fun deleteAll() = dao.deleteAll()
}

// ── Entity ↔ Domain conversion ───────────────────────────────────────────────
//
// The conversion helpers (toDomain / toEntity) for EntryEntity and
// ConsumptionEntry are defined once in EntityMapping.kt as `internal`
// extension functions. See EntityMapping.kt for the full rationale.
