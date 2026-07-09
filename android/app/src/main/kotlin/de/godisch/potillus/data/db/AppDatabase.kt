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
package de.godisch.potillus.data.db

import android.content.Context
import androidx.room.*
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import de.godisch.potillus.data.db.dao.DrinkDao
import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.data.db.entity.EntryEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.KeyStore

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
    entities = [DrinkEntity::class, EntryEntity::class],
    version = 2,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {

    /** Returns the DAO for drink-definition operations. */
    abstract fun drinkDao(): DrinkDao

    /** Returns the DAO for consumption-entry operations. */
    abstract fun entryDao(): EntryDao

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
                    .addMigrations(MIGRATION_1_2)
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
