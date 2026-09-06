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

import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.dao.LogicalDayKeyDao
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.data.db.entity.LogicalDayKeyEntity
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
 * WHERE THE LOGICAL DAY COMES FROM
 *   Since schema 4 this class OWNS the derivation of `logicalDate`. Nothing
 *   above it supplies one: `add` and `update` compute it from the entry's
 *   timestamp and recorded offset, and [realignDays] recomputes the whole column
 *   when the day-change setting moves. The `logical_day_key` table records which
 *   boundary the column currently holds, so the two can never silently disagree.
 *
 * @param dao         Room DAO injected by [de.godisch.potillus.PotillusApp].
 * @param keyDao      DAO for the one-row `logical_day_key` table.
 * @param transactor  Runs every write that reads the key — [add], [update] and
 *                    the realignment — as one atomic unit; see [Transactor].
 */
class EntryRepository(
    private val dao: EntryDao,
    private val keyDao: LogicalDayKeyDao,
    private val transactor: Transactor,
) : IEntryRepository {

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
    override fun getEntriesForDate(date: String): Flow<List<ConsumptionEntry>> = dao.getByDate(date).map { list -> list.checked().map { it.toDomain() } }

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
     * Used by [de.godisch.potillus.ui.screen.StatsViewModel] to decide how far the
     * period navigation may page back. The returned list is always sorted ascending
     * ("YYYY-MM-DD" lexicographic order equals chronological order, so String
     * comparison is correct).
     */
    override fun getAllDatesFlow(): Flow<List<String>> = dao.getAllDatesFlow()

    /**
     * Reactive stream of the distinct dates on which alcohol was consumed.
     *
     * Feeds the abstinence streaks on the Today and Statistics screens. Sorted
     * ascending like [getAllDatesFlow], and narrower than it by exactly the days
     * that hold only alcohol-free entries — see
     * [de.godisch.potillus.domain.AlcoholCalculator.isDrinkDay].
     */
    override fun getDrinkDatesFlow(): Flow<List<String>> = dao.getDrinkDatesFlow()

    /**
     * Reactive stream of all entries in a logical date range.
     *
     * Used by [de.godisch.potillus.ui.screen.StatsViewModel] to compute per-category
     * totals ([de.godisch.potillus.domain.model.DrinkCategory] → grams).
     *
     * @param from  Start date inclusive.
     * @param to    End date inclusive.
     */
    override fun getEntriesForPeriod(from: String, to: String): Flow<List<ConsumptionEntry>> = dao.getEntriesForPeriodFlow(from, to).map { list -> list.checked().map { it.toDomain() } }

    /**
     * Reactive stream of the entry written last, or `null` when no entries exist
     * yet.
     *
     * Delegates to [EntryDao.getMostRecent], which uses `ORDER BY id DESC LIMIT 1`
     * in SQL so only one row is ever read from the database. See there for why the
     * row id decides this and not the timestamp. Used by
     * [de.godisch.potillus.ui.screen.TodayViewModel] to pre-select the last-used
     * drink in the add-entry dialog.
     */
    override fun mostRecentEntry(): Flow<ConsumptionEntry?> = dao.getMostRecent().map { row -> listOfNotNull(row).checked().firstOrNull()?.toDomain() }

    // ── Write operations ──────────────────────────────────────────────────────

    /**
     * Inserts [entry] with a freshly derived logical day and returns its new ID.
     *
     * [ConsumptionEntry.logicalDate] as handed in is IGNORED. Every insert path
     * ends here, so this is the one place where a row can be given a day, and a
     * caller that could supply its own would eventually supply a wrong one. What
     * the caller does own is the reading — the timestamp and the offset — and the
     * day follows from it.
     *
     * IN ONE TRANSACTION WITH THE KEY READ. [withDerivedDay] reads the key row to
     * learn which boundary to derive under, and the insert must land before that
     * answer can go stale: a realignment committing between the two would leave
     * this row derived under a boundary the key no longer names. `Repositories.swift`
     * makes the same pair atomic through `database.write`.
     *
     * @param entry     The entry to store; its `logicalDate` is overwritten.
     * @param settings  Current user settings, for the day-change boundary.
     */
    override suspend fun add(entry: ConsumptionEntry, settings: AppSettings): Long = transactor.inTransaction {
        dao.insert(withDerivedDay(entry, settings).toEntity())
    }

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
        // One reading, used twice: the offset recorded on the entry is the frame
        // its logical date is derived in, so the two cannot disagree.
        val offsetSeconds = DayResolver.utcOffsetSeconds(timestampMillis)
        return add(
            ConsumptionEntry(
                drinkId = drink.id,
                drinkName = drink.name,
                volumeMl = volumeMl,
                alcoholPercent = drink.alcoholPercent,
                gramsAlcohol = AlcoholCalculator.calculateGrams(volumeMl, drink.alcoholPercent),
                timestampMillis = timestampMillis,
                // The local frame is recorded here because it is a FACT about
                // where the drink was logged, and it does not survive being
                // re-derived later. The logical day is not a fact and is not
                // recorded here: [add] derives it from this reading.
                utcOffsetSeconds = offsetSeconds,
                logicalDate = "",
                note = note,
            ),
            settings,
        )
    }

    /**
     * Updates an entry, deriving its logical day from the edited reading.
     *
     * THE DATE NO LONGER SURVIVES AN EDIT, and that is the point of schema 4. An
     * entry corrected from 23:00 to 02:00 moves to the previous logical day,
     * because 02:00 is before the boundary and that is what the reading says.
     * Until v0.86.0 this method preserved the stored date and the view models
     * moved the timestamp to fit it, which meant a correction of the time
     * silently changed the calendar day the entry sat on instead.
     *
     * THE FRAME IS THE CALLER'S, and is written as handed in. It used to be
     * re-read here from the device zone, which was right while the sheet could
     * only change the time — every edit was then a fresh reading in the present
     * frame. With a date beside the time the two cases part company: correcting a
     * time INSIDE a recorded reading must keep that reading's frame, or the row
     * would come back at an hour nobody typed, while moving the date to another
     * day is a new reading and takes the frame the user is in now. Only the sheet
     * knows which of the two happened, so only the sheet can decide.
     *
     * @param entry     The entry to persist; its `logicalDate` is overwritten.
     * @param settings  Current user settings, for the day-change boundary.
     */
    override suspend fun update(entry: ConsumptionEntry, settings: AppSettings) {
        // Same transaction as [add], for the same reason.
        transactor.inTransaction {
            dao.update(withDerivedDay(entry, settings).toEntity())
        }
    }

    /** Deletes [entry] from the database. */
    override suspend fun delete(entry: ConsumptionEntry) = dao.delete(entry.toEntity())

    /**
     * Returns all entries ordered chronologically.
     *
     * One-shot snapshot for export (CSV, PDF) and backup operations.
     */
    override suspend fun getAll(): List<ConsumptionEntry> = dao.getAll().checked().map { it.toDomain() }

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
    override suspend fun getInRange(from: String, to: String): List<ConsumptionEntry> = dao.getInRange(from, to).checked().map { it.toDomain() }

    /**
     * Deletes all entries.
     *
     * The REPLACE backup import does not call this: it runs its own
     * `entryDao.deleteAll()` and `drinkDao.deleteAllDrinks()` inside one Room
     * transaction ([BackupRepository.importReplace]), so the database is never
     * left half-cleared. Any other caller that clears drinks afterwards needs the
     * same transaction, because of the FK RESTRICT on `entries.drinkId`.
     */
    override suspend fun deleteAll() = dao.deleteAll()

    // ── Realignment ───────────────────────────────────────────────────────────

    /**
     * Brings `entries.logicalDate` in line with the day-change time in [settings].
     *
     * WHAT IT COMPARES. The key row in `logical_day_key` says which boundary the
     * column currently holds. Equal to the setting: nothing to do, and the common
     * case — this runs on every settings emission, which includes every unrelated
     * change the user makes. Different, or not set at all: one transaction that
     * rewrites the column and records the new boundary.
     *
     * WHAT RUNS FIRST WHEN THE KEY IS UNSET. A key of NULL means the column has
     * never been derived — the state a fresh `MIGRATION_3_4` and a finished
     * backup import both leave. That is also the only moment at which the stored
     * `logicalDate` still carries the user's ORIGINAL intent for the entries
     * damaged by the pre-0.85.0 calendar path, so [LegacyDayRepair] gets its turn
     * before the recomputation overwrites them. The order is not a preference; it
     * is the difference between repairing those rows and losing what they meant.
     *
     * WHY IT IS SAFE TO INTERRUPT. Everything happens inside one transaction. An
     * abort rolls back the rewrite AND the key, so the next emission finds the
     * old key, disagrees with the setting again, and starts over. There is no
     * half-converted state to detect, because there is no state between the two.
     *
     * WHAT THE SCREENS DO. Nothing, until the transaction commits; then Room
     * reports `entries` as changed and every observing query re-emits by itself.
     * In the window between the setting being written and the commit, the screens
     * show the old days — which is what the app showed permanently before this
     * existed.
     *
     * THREAD. The caller decides; nothing here touches the main thread on its
     * own. `PotillusApp` collects the settings on `Dispatchers.IO`.
     *
     * HOW LONG IT TAKES IS NOT MEASURED. The working estimate is that ten
     * thousand rows are a fraction of a second, and it is an estimate: this is
     * a write transaction over every row, with two indices to maintain and a
     * growing WAL, and writes depend on the device more than reads do. The
     * requirement is therefore stated so that it does not depend on the
     * number — off the main thread, the settings screen stays usable, the
     * screens refresh when the commit lands. Whatever the duration turns out
     * to be on a given phone, it is a matter of comfort, not of correctness.
     */
    override suspend fun realignDays(settings: AppSettings) {
        transactor.inTransaction {
            val key = keyDao.get()
            val storedHour = key?.changeHour
            val storedMinute = key?.changeMinute
            val isUnset = storedHour == null || storedMinute == null
            val isCurrent = !isUnset &&
                storedHour == settings.dayChangeHour &&
                storedMinute == settings.dayChangeMinute
            if (isCurrent) return@inTransaction

            val changed = dao.getAll().mapNotNull { row ->
                val repaired = if (isUnset) repairedOrSame(row, settings) else row
                val rewritten = repaired.copy(
                    logicalDate = DayResolver.resolve(
                        repaired.timestampMillis,
                        repaired.utcOffsetSeconds,
                        settings.dayChangeHour,
                        settings.dayChangeMinute,
                    ),
                )
                // Only the rows that actually moved. A no-op update is still a
                // write, and on the first run after an upgrade nearly every row
                // is a no-op: the previous release placed timestamps so that they
                // resolve to the day it stored beside them.
                rewritten.takeIf { it != row }
            }
            dao.updateAll(changed)
            keyDao.put(
                LogicalDayKeyEntity(
                    changeHour = settings.dayChangeHour,
                    changeMinute = settings.dayChangeMinute,
                ),
            )
        }
    }

    /**
     * The row with its pre-0.85.0 calendar damage undone, or the row unchanged.
     *
     * Split out so [realignDays] reads as the three decisions it makes rather
     * than as the mechanics of one of them. See [LegacyDayRepair] for how a
     * damaged row is recognised and why the rule lives there and not in
     * `DayResolver`.
     */
    private fun repairedOrSame(row: EntryEntity, settings: AppSettings): EntryEntity {
        val repaired = LegacyDayRepair.repair(
            timestampMillis = row.timestampMillis,
            utcOffsetSeconds = row.utcOffsetSeconds,
            logicalDate = row.logicalDate,
            changeHour = settings.dayChangeHour,
            changeMinute = settings.dayChangeMinute,
        ) ?: return row
        return row.copy(
            timestampMillis = repaired.timestampMillis,
            utcOffsetSeconds = repaired.utcOffsetSeconds,
        )
    }

    /**
     * Whether assertions are on, decided once.
     *
     * [checked] reads a row of `logical_day_key` it would otherwise not need, so
     * it must not run in a shipped build. Kotlin's `assert` is inline and
     * evaluates its argument at the call site, so wrapping the whole check in
     * `assert { … }` would still cost that read. This is the standard idiom for
     * asking the JVM the same question `-ea` answers.
     */
    private val assertionsEnabled: Boolean = javaClass.desiredAssertionStatus()

    /**
     * The rows, after checking the invariant `entries.logicalDate` is bound by.
     *
     * WHAT IT CATCHES, AND WHY IT IS WORTH A CHECK ON THE READ PATH. Making the
     * column a derivation buys the app the ability to move every entry when the
     * day-change time moves; what it risks is a row whose stored day and whose
     * reading have come apart — a write that went round [add] and [update], a
     * realignment that half ran, a key written without the rows it describes.
     * None of those is visible in the data itself: a wrong day looks exactly like
     * a right one. So the equation is checked where every row passes, and the
     * failure names the row instead of surfacing weeks later as a total nobody
     * can account for.
     *
     * A NULL KEY IS NOT A VIOLATION. It means the column has not been derived
     * yet — the state a fresh migration and a finished import both leave — and
     * the rows legitimately hold whatever they were imported or migrated with
     * until the next realignment. The check has nothing to compare against and
     * says nothing.
     *
     * COSTS NOTHING IN A SHIPPED BUILD: with assertions off, [assertionsEnabled]
     * is false and neither the key read nor the loop happens.
     */
    private suspend fun List<EntryEntity>.checked(): List<EntryEntity> {
        if (!assertionsEnabled) return this
        val key = keyDao.get()
        val hour = key?.changeHour ?: return this
        val minute = key.changeMinute ?: return this
        forEach { row ->
            val derived = DayResolver.resolve(row.timestampMillis, row.utcOffsetSeconds, hour, minute)
            assert(derived == row.logicalDate) {
                "entry ${row.id}: stored logicalDate ${row.logicalDate}, but the reading " +
                    "(${row.timestampMillis} at ${row.utcOffsetSeconds}s) resolves to $derived " +
                    "under the key $hour:$minute the column was last computed with"
            }
        }
        return this
    }

    /**
     * [entry] with `logicalDate` derived from its own reading.
     *
     * THE BOUNDARY COMES FROM THE KEY WHEN THERE IS ONE, and only from [settings]
     * when there is not. That looks backwards — the settings are newer — and it
     * is deliberate: the invariant on `entries` is stated against the KEY, so a
     * row written under a boundary the key does not name would break it for as
     * long as the realignment has not run. Deriving under the key keeps every row
     * in the table consistent with every other, and the realignment that is
     * already on its way moves the new row along with the rest a moment later.
     *
     * Called inside the caller's transaction only; see [add].
     */
    private suspend fun withDerivedDay(entry: ConsumptionEntry, settings: AppSettings): ConsumptionEntry {
        val key = keyDao.get()
        val keyHour = key?.changeHour
        val keyMinute = key?.changeMinute
        // Both or neither: the two columns are written together and read
        // together, so a half-set key is treated as no key rather than mixed
        // with the settings into a boundary that was never in force anywhere.
        val hour = if (keyHour != null && keyMinute != null) keyHour else settings.dayChangeHour
        val minute = if (keyHour != null && keyMinute != null) keyMinute else settings.dayChangeMinute
        return entry.copy(
            logicalDate = DayResolver.resolve(
                entry.timestampMillis,
                entry.utcOffsetSeconds,
                hour,
                minute,
            ),
        )
    }
}

// ── Entity ↔ Domain conversion ───────────────────────────────────────────────
//
// The conversion helpers (toDomain / toEntity) for EntryEntity and
// ConsumptionEntry are defined once in EntityMapping.kt as `internal`
// extension functions. See EntityMapping.kt for the full rationale.
