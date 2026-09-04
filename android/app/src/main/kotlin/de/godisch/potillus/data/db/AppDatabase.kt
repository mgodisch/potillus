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
package de.godisch.potillus.data.db

import android.content.Context
import androidx.room.*
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import de.godisch.potillus.data.db.dao.DrinkDao
import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.dao.LogicalDayKeyDao
import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.data.db.entity.LogicalDayKeyEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.time.Instant
import java.time.ZoneId

// =============================================================================
// AppDatabase.kt – Room database definition and singleton
// =============================================================================
//
// ROOM ARCHITECTURE:
//   Room is an abstraction layer over Android's built-in SQLite.
//   @Database declares the database with its table entities and schema version.
//   Room generates the concrete implementation class at compile time.
//
// SINGLETON PATTERN (double-checked locking):
//   Only one database connection is needed for the whole app lifetime.
//   The getInstance() method uses the classic "double-checked locking" idiom:
//     1. Fast path (no lock): if instance is non-null, return it immediately.
//     2. Slow path (with lock): enter a synchronized block, check again, and
//        create the instance if it is still null.
//   @Volatile ensures that writes to instance are immediately visible to all
//   threads, preventing a stale cached value from being read in step 1.
//
// SCHEMA EXPORT (exportSchema = true):
//   Room writes a JSON snapshot of the schema to app/schemas/ at build time.
//   This file can be committed to version control and used to write
//   migration tests. Never set exportSchema = false in production.
//
// PRE-POPULATION CALLBACK:
//   Room fires PrepopulateCallback.onCreate() once, when the database file is
//   first created on the device. This is where preset drinks are inserted.
//   The callback must NOT run on the main thread (database writes block I/O),
//   so it launches a coroutine on the application scope.
// =============================================================================

/**
 * Room database for Libellus Potionis.
 *
 * Contains two tables: `drinks` ([DrinkEntity]) and `entries` ([EntryEntity]).
 * Access via the singleton [getInstance]; do not call the constructor directly
 * (Room's generated class is not publicly instantiable anyway).
 */
// SCHEMA FREEZE: the database schema is frozen. Any change must
// bump `version`, add a `Migration`, commit the new app/schemas/<n>.json, and
// add a case to MigrationTest. See CONTRIBUTING.md §8.1. Never use
// fallbackToDestructiveMigration — it would wipe user data.
//
// BACKWARD-COMPATIBILITY FLOOR: since the first F-Droid release (v0.77.4) the
// database is guaranteed readable by every later version — migrations are
// forward-only and never destructive. See CONTRIBUTING.md §8 (compatibility
// guarantee) for the promise this upholds.
@Database(
    entities = [DrinkEntity::class, EntryEntity::class, LogicalDayKeyEntity::class],
    version = 4,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {

    /** Returns the DAO for drink-definition operations. */
    abstract fun drinkDao(): DrinkDao

    /** Returns the DAO for consumption-entry operations. */
    abstract fun entryDao(): EntryDao

    /**
     * Returns the DAO for the single row of `logical_day_key`.
     *
     * Separate from [entryDao] although it describes the `entries` table: the
     * two are written together but read by different callers, and a DAO per
     * table keeps Room's generated code and the fakes in the tests small.
     */
    abstract fun logicalDayKeyDao(): LogicalDayKeyDao

    companion object {

        /**
         * The single shared database instance.
         *
         * @Volatile: writes are immediately visible to all threads; prevents
         * the CPU from caching a stale reference in a thread-local register.
         */
        @Volatile
        private var instance: AppDatabase? = null

        /** File name of the Room database. */
        private const val DATABASE_NAME = "potillus.db"

        // ── Legacy SQLCipher artefacts (removed in v0.73.0) ───────────────────
        //   Until v0.73.0 the database was encrypted with SQLCipher: a random
        //   passphrase, sealed by a dedicated Android Keystore key and stored in a
        //   private SharedPreferences file, was handed to a SupportOpenHelperFactory.
        //   SQLCipher has been removed — the database now relies on Android's
        //   file-based storage encryption and the per-app sandbox — so those two
        //   artefacts are obsolete and are cleaned up once by
        //   [purgeLegacyEncryptedDatabase].
        private const val LEGACY_PASSPHRASE_PREFS = "potillus_db_key"
        private const val LEGACY_PASSPHRASE_PREFS_KEY = "passphrase"
        private const val LEGACY_PASSPHRASE_KEY_ALIAS = "potillus_db_passphrase_key"

        /**
         * One-shot clean break from the former SQLCipher-encrypted database.
         *
         * A plaintext SQLite engine cannot open the old SQLCipher file — it would
         * fail with "file is not a database" — and this release deliberately does
         * NOT migrate the encrypted data (a conscious clean break). The legacy
         * passphrase SharedPreferences file is the unambiguous marker of a
         * pre-removal install: it existed ONLY while SQLCipher was in use. When it
         * is present we delete the encrypted database (with its -wal/-shm/-journal
         * side files), the passphrase file, and the now-unused Keystore key, then
         * let Room create a fresh, empty plaintext database in its place.
         *
         * Idempotent and safe everywhere: removing the passphrase file clears the
         * marker, so this never runs a second time; a clean install never has the
         * marker at all, making the whole routine a no-op there. Every step is
         * best-effort so a missing artefact or a Keystore hiccup can never block
         * database creation.
         */
        private fun purgeLegacyEncryptedDatabase(context: Context) {
            val legacyPrefs =
                context.getSharedPreferences(LEGACY_PASSPHRASE_PREFS, Context.MODE_PRIVATE)
            // No sealed passphrase here means this is not a legacy install: nothing to do.
            if (legacyPrefs.getString(LEGACY_PASSPHRASE_PREFS_KEY, null) == null) return

            // 1. Drop the encrypted database file and its journal/WAL side files.
            context.deleteDatabase(DATABASE_NAME)

            // 2. Delete the passphrase SharedPreferences file outright. This removes
            //    the backing file together with its in-memory state (including the
            //    marker), so this routine never runs again. No edit()/clear() is
            //    needed — and an apply()/commit() would only race with the delete.
            context.deleteSharedPreferences(LEGACY_PASSPHRASE_PREFS)

            // 3. Delete the now-unused Android Keystore key that sealed the passphrase.
            try {
                KeyStore.getInstance("AndroidKeyStore")
                    .apply { load(null) }
                    .deleteEntry(LEGACY_PASSPHRASE_KEY_ALIAS)
            } catch (_: GeneralSecurityException) {
                // Keystore unavailable or entry already gone — nothing to clean up.
            } catch (_: IOException) {
                // Keystore failed to load — non-fatal for database creation.
            }
        }

        /**
         * Returns the singleton [AppDatabase] instance, creating it if necessary.
         *
         * Uses double-checked locking to avoid the cost of synchronization on
         * every call while remaining thread-safe on first creation.
         *
         * STORAGE SECURITY:
         *   The database is a plain (unencrypted) SQLite file in the app's private
         *   storage. At rest it is protected by Android's file-based storage
         *   encryption and the per-app sandbox; there is no application-level
         *   database encryption layer (SQLCipher was removed in v0.73.0). On the
         *   first open after upgrading from an encrypted build, any leftover
         *   SQLCipher artefacts are cleaned up by [purgeLegacyEncryptedDatabase].
         *
         * @param context          Application context – must be the application context
         *                         (not an Activity context) to avoid a memory leak.
         * @param applicationScope Long-lived [CoroutineScope] from [de.godisch.potillus.PotillusApp].
         */
        fun getInstance(context: Context, applicationScope: CoroutineScope): AppDatabase = instance ?: synchronized(this) {
            instance ?: run {
                val appContext = context.applicationContext
                // One-shot clean break from the former SQLCipher database (a no-op
                // on clean installs and on every start after the first upgrade).
                purgeLegacyEncryptedDatabase(appContext)

                Room.databaseBuilder(
                    appContext,
                    AppDatabase::class.java,
                    DATABASE_NAME,
                )
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4)
                    .addCallback(PrepopulateCallback(applicationScope))
                    .build()
                    .also { instance = it }
            }
        }
    }

    // ── Pre-population ────────────────────────────────────────────────────────

    /**
     * Inserts the built-in preset drinks the first time the database is created.
     *
     * Room calls [onCreate] once, immediately after the database file is first
     * opened and the schema has been created. At this point [instance] is
     * already set (see [getInstance]), so we can safely access the DAO.
     *
     * WHY [applicationScope] instead of `GlobalScope.launch`?
     *   GlobalScope is unstructured: its coroutines are never cancelled and
     *   their lifecycle is not tied to anything. Using the application's own
     *   scope means the coroutine is cancelled when the process ends, and
     *   any failures are handled by the scope's SupervisorJob.
     *
     * WHY check `countPresets() == 0`?
     *   The [onCreate] callback is guaranteed to fire only once (when the DB
     *   file is first created). The guard is a belt-and-suspenders check
     *   against any future code path that might trigger this callback again.
     */
    private class PrepopulateCallback(private val scope: CoroutineScope) : Callback() {
        override fun onCreate(db: SupportSQLiteDatabase) {
            super.onCreate(db)
            instance?.let { database ->
                // Dispatchers.IO explicitly: [PotillusApp.applicationScope]
                // deliberately carries NO default dispatcher (every launch site
                // must state its choice — see its KDoc). The preset insert is
                // database I/O; the suspend DAO would hop to Room's own executor
                // anyway, but stating IO here keeps this launch site consistent
                // with the documented convention instead of silently falling
                // back to Dispatchers.Default.
                scope.launch(Dispatchers.IO) {
                    val dao = database.drinkDao()
                    if (dao.countPresets() == 0) {
                        PRESET_DRINKS.forEach { dao.insert(it) }
                    }
                }
            }
        }
    }
}

// =============================================================================
// Database migration
// =============================================================================
//
// ROOM MIGRATIONS:
//   When the database schema changes between app versions, Room needs explicit
//   instructions for how to transform the existing on-device schema into the new
//   one. Without a migration object for each version step, Room either crashes
//   (default) or wipes the database (fallbackToDestructiveMigration – never use
//   in a personal-data app).
//
//   Each Migration(from, to) receives a raw SupportSQLiteDatabase and executes
//   plain SQL. Room validates the resulting schema against its auto-generated
//   expected hash at runtime; if they don't match, it throws an exception.
// =============================================================================

/**
 * v1 → v2: Add an index on `entries.logicalDate`.
 *
 * All date-scoped queries (getByDate, getDailySummaries, getEntriesForPeriodFlow)
 * filter or group by logicalDate. Without an index, each query performs a full
 * table scan. The index adds ~10 KB per 1 000 rows and cuts query time
 * from O(n) to O(log n).
 *
 * Plain `CREATE INDEX` is safe to run on an existing table with data – it does
 * not modify any row, and it is idempotent if re-run (IF NOT EXISTS).
 */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            "CREATE INDEX IF NOT EXISTS index_entries_logicalDate ON entries (logicalDate)",
        )
    }
}

/**
 * v2 → v3: Add `entries.utcOffsetSeconds`.
 *
 * The column records the UTC offset a drink was logged at, so its clock time can
 * be read back in the frame it was written in rather than in whatever frame the
 * device is in at read time. See
 * [de.godisch.potillus.domain.DayResolver.utcOffsetSeconds] for what is stored
 * and [de.godisch.potillus.domain.DayResolver.localDateTime] for how it is read.
 *
 * NULLABLE, AND EXISTING ROWS ARE LEFT NULL. A backfill would have to guess: the
 * only offset available at migration time is the one the device is in now, which
 * is right for someone who never travelled and wrong for someone who did — and
 * once written, the guess would be indistinguishable from a recorded fact. NULL
 * says "not recorded" and lets [DayResolver.localDateTime] derive the same
 * fallback on every read, which is exactly what the app did for every entry
 * before this column existed.
 *
 * `ALTER TABLE … ADD COLUMN` is safe on a table with data: SQLite rewrites no
 * row, and a nullable column needs no DEFAULT.
 *
 * SUPERSEDED BY [MIGRATION_3_4], which does backfill and drops the nullability.
 * The reasoning above still describes what was known in v0.83.0 and is left
 * standing as history; the weighing that overturned it — the second code path
 * costs more than the frozen estimate does — is written out there.
 */
val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE entries ADD COLUMN utcOffsetSeconds INTEGER")
    }
}

/**
 * v3 → v4: backfill `entries.utcOffsetSeconds`, make it `NOT NULL`, and add the
 * one-row `logical_day_key` table.
 *
 * TWO STEPS, IN THIS ORDER:
 *
 *  1. BACKFILL, in Kotlin. Every row still holding NULL gets the offset the
 *     device zone had AT THAT ROW'S INSTANT, through the zone's historical
 *     rules. This is exactly the value the readers computed on every read while
 *     the column was nullable, so the migration freezes what the app already
 *     showed rather than inventing a number. The step is Kotlin and not SQL
 *     because SQLite has no timezone database: `strftime('%s', …, 'localtime')`
 *     answers for the CURRENT rules, not for the rules in force in 2024.
 *
 *  2. REBUILD, in SQL. SQLite cannot add `NOT NULL` to an existing column, so
 *     the table is recreated with the constraint and the rows are copied. Column
 *     order matches [EntryEntity]'s declaration, and the foreign key is spelled
 *     as Room's own export spells it, so the schema validation at the end of the
 *     migration passes.
 *
 * WHY THE ZONE RULE IS PRIVATE TO THIS FILE AND NOT `DayResolver`'s
 *   A migration runs once per device and can never run again. If it borrowed
 *   [de.godisch.potillus.domain.DayResolver.utcOffsetSeconds], a later change
 *   there would silently redefine what an ALREADY MIGRATED database means
 *   against one still waiting to migrate. Reading the zone here, in six lines
 *   that nothing else calls, keeps the two apart.
 *
 * WHAT THIS MIGRATION DOES NOT DO
 *   It does not read the day-change time, and it does not touch `logicalDate`.
 *   `logical_day_key` is created holding NULLs, which every reader takes as "the
 *   column has not been derived yet". The first realignment in the repository
 *   then repairs the pre-0.85.0 calendar entries and recomputes the whole column
 *   under the setting it reads from the preferences. Keeping settings out of the
 *   migration is what lets the database open before the preferences are
 *   readable: a locked store delays the realignment, it no longer blocks the
 *   start.
 *
 * WHAT A USER SEES IF THIS IS INTERRUPTED
 *   Nothing, twice over: Room runs the whole migration in a transaction, and the
 *   key it leaves behind is NULL either way.
 */
val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        backfillUtcOffsets(db)
        rebuildEntriesWithNotNullOffset(db)
        createLogicalDayKey(db)
    }
}

/**
 * Step 1 of [MIGRATION_3_4]: writes an offset into every row that has none.
 *
 * Rows are read first and written afterwards rather than updated while the
 * cursor is open: SQLite allows the interleaving, but a cursor that walks a
 * table being written under it is a well-known way to read a row twice or not at
 * all. The row count here is the user's drink history, so holding the ids in
 * memory costs nothing worth optimising.
 */
private fun backfillUtcOffsets(db: SupportSQLiteDatabase) {
    val zone = ZoneId.systemDefault()
    val pending = mutableListOf<Pair<Long, Long>>() // id → timestampMillis
    db.query("SELECT id, timestampMillis FROM entries WHERE utcOffsetSeconds IS NULL").use { c ->
        while (c.moveToNext()) {
            pending += c.getLong(0) to c.getLong(1)
        }
    }
    pending.forEach { (id, timestampMillis) ->
        val offset = zone.rules.getOffset(Instant.ofEpochMilli(timestampMillis)).totalSeconds
        db.execSQL(
            "UPDATE entries SET utcOffsetSeconds = ? WHERE id = ?",
            arrayOf<Any>(offset, id),
        )
    }
}

/**
 * Step 2 of [MIGRATION_3_4]: the twelve-step table rebuild, minus the steps that
 * do not apply here.
 *
 * The order is the one SQLite's own documentation prescribes for altering a
 * table: create the replacement, copy, drop, rename, recreate the indices. The
 * foreign key survives the drop because it is declared ON the entries table, and
 * it is re-declared verbatim below.
 *
 * `PRAGMA foreign_keys` is deliberately not touched. Room turns foreign keys off
 * around a migration and runs `PRAGMA foreign_key_check` afterwards, so dropping
 * a table that is the CHILD of a key is safe here; toggling the pragma inside a
 * transaction is a no-op in SQLite anyway.
 */
private fun rebuildEntriesWithNotNullOffset(db: SupportSQLiteDatabase) {
    db.execSQL(
        """
        CREATE TABLE IF NOT EXISTS `entries_new` (
            `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            `drinkId` INTEGER NOT NULL,
            `drinkName` TEXT NOT NULL,
            `volumeMl` INTEGER NOT NULL,
            `alcoholPercent` REAL NOT NULL,
            `gramsAlcohol` REAL NOT NULL,
            `timestampMillis` INTEGER NOT NULL,
            `logicalDate` TEXT NOT NULL,
            `note` TEXT NOT NULL,
            `utcOffsetSeconds` INTEGER NOT NULL,
            FOREIGN KEY(`drinkId`) REFERENCES `drinks`(`id`)
                ON UPDATE NO ACTION ON DELETE RESTRICT
        )
        """.trimIndent(),
    )
    db.execSQL(
        """
        INSERT INTO `entries_new`
            (id, drinkId, drinkName, volumeMl, alcoholPercent, gramsAlcohol,
             timestampMillis, logicalDate, note, utcOffsetSeconds)
        SELECT id, drinkId, drinkName, volumeMl, alcoholPercent, gramsAlcohol,
               timestampMillis, logicalDate, note, utcOffsetSeconds
        FROM `entries`
        """.trimIndent(),
    )
    db.execSQL("DROP TABLE `entries`")
    db.execSQL("ALTER TABLE `entries_new` RENAME TO `entries`")
    db.execSQL("CREATE INDEX IF NOT EXISTS `index_entries_drinkId` ON `entries` (`drinkId`)")
    db.execSQL("CREATE INDEX IF NOT EXISTS `index_entries_logicalDate` ON `entries` (`logicalDate`)")
}

/**
 * Step 3 of [MIGRATION_3_4]: creates `logical_day_key` and puts its one row in.
 *
 * The row is inserted with NULL columns, which is the state
 * [LogicalDayKeyEntity] documents as "not computed yet". Inserting it here
 * rather than lazily means every reader can rely on the row existing.
 */
private fun createLogicalDayKey(db: SupportSQLiteDatabase) {
    db.execSQL(
        """
        CREATE TABLE IF NOT EXISTS `logical_day_key` (
            `id` INTEGER NOT NULL,
            `changeHour` INTEGER,
            `changeMinute` INTEGER,
            PRIMARY KEY(`id`)
        )
        """.trimIndent(),
    )
    db.execSQL(
        "INSERT OR REPLACE INTO `logical_day_key` (id, changeHour, changeMinute) VALUES (?, NULL, NULL)",
        arrayOf<Any>(LogicalDayKeyEntity.SINGLETON_ID),
    )
}

// =============================================================================
// Built-in preset drinks
// =============================================================================
//
// WHY outside the class?
//   Top-level private vals in Kotlin are file-private – they cannot be accessed
//   from other files, but they are not tied to a specific class instance.
//   Keeping the list here (rather than inside the companion object) avoids
//   loading it into memory before AppDatabase is first accessed.
// =============================================================================

/** Preset drinks inserted on first install. Users can add their own; these cannot be deleted. */
private val PRESET_DRINKS = listOf(
    DrinkEntity(name = "Lager (Pint)", volumeMl = 568, alcoholPercent = 4.5, isPreset = true, category = "BEER"),
    DrinkEntity(name = "Lager (Standard)", volumeMl = 500, alcoholPercent = 5.0, isPreset = true, category = "BEER"),
    DrinkEntity(name = "Lager (Small)", volumeMl = 330, alcoholPercent = 5.0, isPreset = true, category = "BEER"),
    DrinkEntity(name = "Shandy / Radler", volumeMl = 500, alcoholPercent = 2.5, isPreset = true, category = "BEER"),
    DrinkEntity(name = "White Wine (Small)", volumeMl = 125, alcoholPercent = 12.5, isPreset = true, category = "WINE"),
    DrinkEntity(name = "White Wine (Regular)", volumeMl = 150, alcoholPercent = 13.0, isPreset = true, category = "WINE"),
    DrinkEntity(name = "Red Wine (Regular)", volumeMl = 150, alcoholPercent = 13.5, isPreset = true, category = "WINE"),
    DrinkEntity(name = "Sparkling Wine / Prosecco", volumeMl = 125, alcoholPercent = 11.5, isPreset = true, category = "WINE"),
    DrinkEntity(name = "Gin & Tonic", volumeMl = 200, alcoholPercent = 10.0, isPreset = true, category = "LONGDRINK"),
    DrinkEntity(name = "Cuba Libre", volumeMl = 200, alcoholPercent = 10.0, isPreset = true, category = "LONGDRINK"),
    DrinkEntity(name = "Vodka Soda", volumeMl = 200, alcoholPercent = 10.0, isPreset = true, category = "LONGDRINK"),
    DrinkEntity(name = "Vodka Shot", volumeMl = 40, alcoholPercent = 40.0, isPreset = true, category = "SPIRITS"),
    DrinkEntity(name = "Vodka Shot (International)", volumeMl = 45, alcoholPercent = 40.0, isPreset = true, category = "SPIRITS"),
    DrinkEntity(name = "Whiskey (Neat/Rocks)", volumeMl = 45, alcoholPercent = 43.0, isPreset = true, category = "SPIRITS"),
    DrinkEntity(name = "Liqueur Shot", volumeMl = 40, alcoholPercent = 35.0, isPreset = true, category = "LIQUEUR"),
)
