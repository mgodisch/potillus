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
package de.godisch.potillus.data.db.dao

import androidx.room.*
import de.godisch.potillus.data.db.entity.EntryEntity
import kotlinx.coroutines.flow.Flow

// =============================================================================
// EntryDao.kt – Data Access Object for the "entries" table
// =============================================================================
//
// ROOM PROJECTION ("partial entity"):
//   getDailySummaries() returns List<DailySummaryRaw>, not List<EntryEntity>.
//   Room can map a SELECT result to any class whose property names match the
//   column names in the query. DailySummaryRaw is defined at the bottom of
//   this file because it is tightly coupled to this specific query.
//
// MULTILINE SQL:
//   Kotlin's triple-quoted strings ("""…""") let you write readable,
//   indented SQL. Room strips leading whitespace and newlines at compile time.
// =============================================================================

/**
 * Room Data Access Object for [EntryEntity].
 *
 * All queries are exposed via [de.godisch.potillus.data.repository.EntryRepository],
 * which converts [EntryEntity] ↔ [de.godisch.potillus.domain.model.ConsumptionEntry].
 */
@Dao
interface EntryDao {

    // ── Date-scoped queries ───────────────────────────────────────────────────

    /**
     * Reactive stream of all entries for a single logical date, ordered by timestamp.
     *
     * Used by [TodayViewModel] and [CalendarViewModel] to keep the entry list
     * up-to-date as the user adds, edits, or deletes entries.
     *
     * @param date  ISO-8601 logical date ("YYYY-MM-DD").
     */
    @Query("SELECT * FROM entries WHERE logicalDate = :date ORDER BY timestampMillis ASC")
    fun getByDate(date: String): Flow<List<EntryEntity>>

    // ── Aggregate queries ─────────────────────────────────────────────────────

    /**
     * Reactive stream of per-day totals for a date range.
     *
     * The SQL aggregation (GROUP BY logicalDate + SUM/COUNT) runs inside
     * SQLite, which is far more efficient than loading all rows into memory
     * and summing in Kotlin. Only days that have at least one entry are
     * included (no zero-gram rows for days without consumption).
     *
     * Room maps each result row to a [DailySummaryRaw] object by matching
     * the SELECT column names/aliases to the class property names:
     *   logicalDate → [DailySummaryRaw.logicalDate]
     *   totalGrams  → [DailySummaryRaw.totalGrams]
     *   entryCount  → [DailySummaryRaw.entryCount]
     *
     * @param from  Start date inclusive ("YYYY-MM-DD").
     * @param to    End date inclusive ("YYYY-MM-DD").
     *              String comparison works correctly because ISO-8601 sorts
     *              lexicographically in the same order as chronologically.
     */
    @Query("""
        SELECT logicalDate,
               SUM(gramsAlcohol) AS totalGrams,
               COUNT(*) AS entryCount
        FROM entries
        WHERE logicalDate >= :from AND logicalDate <= :to
        GROUP BY logicalDate
        ORDER BY logicalDate ASC
    """)
    fun getDailySummaries(from: String, to: String): Flow<List<DailySummaryRaw>>

    /**
     * Reactive stream of all distinct logical dates that have at least one entry.
     *
     * Used by [de.godisch.potillus.ui.screen.StatsViewModel] to compute abstinence
     * streaks. The streak calculation only needs the dates, not the full entries,
     * so DISTINCT with no JOIN is the lightest possible query.
     */
    @Query("SELECT DISTINCT logicalDate FROM entries ORDER BY logicalDate ASC")
    fun getAllDatesFlow(): Flow<List<String>>

    // ── Single-row queries ────────────────────────────────────────────────────

    // getById(id) has been removed: no production code ever looked an entry up
    // by primary key (dead API found in the v0.78.0 QA review). Edits flow
    // through [update] with the already-loaded entity instead.

    // ── Write operations ──────────────────────────────────────────────────────

    /**
     * Inserts a new entry and returns its auto-generated row ID.
     *
     * WHY [OnConflictStrategy.ABORT] here?
     *   The previous strategy was [OnConflictStrategy.REPLACE], which silently
     *   overwrites an existing row when a primary-key collision occurs. For normal
     *   inserts this is never intended: new entries always carry `id = 0`, which
     *   Room treats as "unset" and replaces with the next auto-incremented value.
     *   Using ABORT makes a collision a hard error rather than a silent data loss.
     *
     *   Backup-import code that needs to re-insert entries with specific IDs
     *   should call [insertOrReplace] instead, which uses REPLACE explicitly and
     *   documents the intent at the call site.
     */
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(entry: EntryEntity): Long

    /**
     * Inserts or replaces an entry with the given primary key.
     *
     * Use this variant ONLY during backup restore operations where the
     * caller has deliberately chosen a specific entry ID and accepts the risk
     * of overwriting a conflicting row. For all other inserts, use [insert].
     *
     * @return  The row ID of the inserted or replaced entry.
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrReplace(entry: EntryEntity): Long

    /** Updates all columns of an existing entry. */
    @Update
    suspend fun update(entry: EntryEntity)

    /** Deletes the given entry row. */
    @Delete
    suspend fun delete(entry: EntryEntity)

    // ── Bulk queries ──────────────────────────────────────────────────────────

    /**
     * Returns all entries ordered chronologically.
     *
     * Used for CSV/PDF export and backup operations where the full history
     * is needed as a one-shot snapshot.
     */
    @Query("SELECT * FROM entries ORDER BY timestampMillis ASC")
    suspend fun getAll(): List<EntryEntity>

    /**
     * Reactive single most-recently-logged entry (by timestamp), or null if the
     * table is empty.
     *
     * Used to pre-select the "last used" drink in the add-entry dialog. The
     * `LIMIT 1` keeps this cheap regardless of history size — only one row is
     * ever read, not the whole table.
     */
    @Query("SELECT * FROM entries ORDER BY timestampMillis DESC LIMIT 1")
    fun getMostRecent(): Flow<EntryEntity?>

    /**
     * One-shot snapshot of all entries within a logical date range.
     *
     * WHY a dedicated range query instead of calling [getAll] and filtering
     * in Kotlin?
     *   [getAll] loads the entire entry history into the JVM heap before any
     *   filtering occurs. For a user with years of data that could be thousands
     *   of rows. Pushing the WHERE clause into SQLite lets the query planner
     *   use the `index_entries_logicalDate` index (added in migration 1→2) and
     *   returns only the rows that are actually needed for the export.
     *
     * WHY String comparison for dates?
     *   Logical dates are stored as "YYYY-MM-DD" (ISO-8601). That format sorts
     *   lexicographically in the same order as chronologically, so
     *   `>=` / `<=` comparisons in SQLite are correct without any date-parsing.
     *
     * @param from  Start date inclusive ("YYYY-MM-DD").
     * @param to    End date inclusive ("YYYY-MM-DD").
     */
    @Query("SELECT * FROM entries WHERE logicalDate >= :from AND logicalDate <= :to ORDER BY timestampMillis ASC")
    suspend fun getInRange(from: String, to: String): List<EntryEntity>

    /**
     * Deletes every row in the entries table.
     *
     * Called during a REPLACE backup import, inside a database transaction,
     * to clear the entire history before inserting the backup's entries.
     */
    @Query("DELETE FROM entries")
    suspend fun deleteAll()

    /**
     * Duplicate check for MERGE imports.
     *
     * Returns the number of entries with the given timestamp and drinkId
     * combination. A count > 0 means the entry already exists locally and
     * should be skipped to avoid duplicates.
     *
     * Uniqueness on (timestampMillis, drinkId) is a heuristic: two entries
     * for different drinks logged at the exact same millisecond could
     * theoretically clash, but this is negligible in practice.
     *
     * @param ts       Unix timestamp in milliseconds.
     * @param drinkId  Foreign key of the drink.
     */
    @Query("SELECT COUNT(*) FROM entries WHERE timestampMillis = :ts AND drinkId = :drinkId")
    suspend fun countByTimestampAndDrink(ts: Long, drinkId: Long): Int

    /**
     * Reactive stream of all entries in a date range.
     *
     * Used by [de.godisch.potillus.ui.screen.StatsViewModel] to compute per-category
     * breakdowns ([de.godisch.potillus.domain.model.DrinkCategory] → total grams).
     * Reacts to new entries in real time while the Stats screen is visible.
     *
     * @param from  Start date inclusive ("YYYY-MM-DD").
     * @param to    End date inclusive ("YYYY-MM-DD").
     */
    @Query("SELECT * FROM entries WHERE logicalDate >= :from AND logicalDate <= :to ORDER BY timestampMillis ASC")
    fun getEntriesForPeriodFlow(from: String, to: String): Flow<List<EntryEntity>>
}

// =============================================================================
// DailySummaryRaw – Room query projection
// =============================================================================
//
// This class lives in the DAO file because it is an implementation detail of
// the getDailySummaries() query. It is never used outside this package; the
// repository converts it to the domain model DaySummary before returning it.
//
// ROOM REQUIREMENT:
//   The property names must match the column names/aliases in the SELECT
//   statement exactly (case-sensitive). Room generates a RowMapper at compile
//   time based on these names.
// =============================================================================

/**
 * Raw aggregate row returned by [EntryDao.getDailySummaries].
 *
 * Not a domain model – converted to [de.godisch.potillus.domain.model.DaySummary]
 * by [de.godisch.potillus.data.repository.EntryRepository.getDailySummaries].
 *
 * @param logicalDate  ISO-8601 date string from the GROUP BY column.
 * @param totalGrams   SUM of gramsAlcohol for this date.
 * @param entryCount   COUNT(*) – number of individual entries for this date.
 */
data class DailySummaryRaw(
    val logicalDate: String,
    val totalGrams: Double,
    val entryCount: Int
)
