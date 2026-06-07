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
package de.godisch.potillus.data.db

import android.content.Context
import androidx.core.content.edit
import android.util.Base64
import androidx.room.*
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import de.godisch.potillus.data.db.dao.DrinkDao
import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.data.security.KeystoreSecretStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory
import java.security.GeneralSecurityException
import java.security.SecureRandom

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
//     1. Fast path (no lock): if INSTANCE is non-null, return it immediately.
//     2. Slow path (with lock): enter a synchronized block, check again, and
//        create the instance if it is still null.
//   @Volatile ensures that writes to INSTANCE are immediately visible to all
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
// add a case to MigrationTest. See CONTRIBUTING.md §7.1. Never use
// fallbackToDestructiveMigration — it would wipe user data.
@Database(
    entities     = [DrinkEntity::class, EntryEntity::class],
    version      = 2,
    exportSchema = true
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
        private var INSTANCE: AppDatabase? = null

        /** File name of the SharedPreferences that stores the sealed DB passphrase. */
        private const val PASSPHRASE_PREFS = "potillus_db_key"

        /** Key under which the Base64-encoded *sealed* passphrase blob is stored. */
        private const val PASSPHRASE_KEY   = "passphrase"

        /** Dedicated Android Keystore alias for the passphrase-sealing key. */
        private const val PASSPHRASE_KEY_ALIAS = "potillus_db_passphrase_key"

        /**
         * Envelope-encryption helper for the DB passphrase.
         *
         * Replaces the former `MasterKey` + `EncryptedSharedPreferences` from the
         * deprecated `androidx.security:security-crypto` library with the app's own
         * Keystore-backed primitive. See [KeystoreSecretStore].
         */
        private val passphraseStore = KeystoreSecretStore(PASSPHRASE_KEY_ALIAS)

        /**
         * Whether a sealed passphrase envelope is currently persisted.
         *
         * `false` means none has ever been written — i.e. a genuine first install
         * (or freshly cleared data). `true` means a previous run, or an Android
         * backup/device-transfer restore, left an envelope behind.
         *
         * Read-only: this never generates, seals, or persists anything.
         */
        fun hasSealedPassphrase(context: Context): Boolean =
            context.getSharedPreferences(PASSPHRASE_PREFS, Context.MODE_PRIVATE)
                .getString(PASSPHRASE_KEY, null) != null

        /**
         * Whether the persisted passphrase envelope can actually be decrypted with
         * this device's Keystore key.
         *
         * Returns `false` when there is no envelope (first install) OR when an
         * envelope exists but cannot be opened. The latter is the signature of a
         * device transfer where the hardware-bound Keystore key did not migrate:
         * the SharedPreferences envelope was restored from backup, but the key to
         * open it is gone, so [KeystoreSecretStore.open] throws.
         *
         * Combined with [hasSealedPassphrase], the caller can distinguish the two
         * `false` cases — see [PotillusApp.shouldWarnDeviceTransfer].
         *
         * Read-only probe: the decrypted bytes are zeroed immediately and nothing
         * is persisted. (Opening does lazily create the Keystore key if it is
         * absent, exactly as the normal open path does; this has no observable
         * effect on the stored envelope.)
         */
        fun canOpenSealedPassphrase(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PASSPHRASE_PREFS, Context.MODE_PRIVATE)
            val storedB64 = prefs.getString(PASSPHRASE_KEY, null) ?: return false
            return try {
                passphraseStore.open(Base64.decode(storedB64, Base64.NO_WRAP)).fill(0)
                true
            } catch (_: GeneralSecurityException) {
                false   // envelope present but undecryptable → Keystore key did not migrate
            } catch (_: IllegalArgumentException) {
                false   // malformed/truncated envelope (e.g. a partial restore)
            }
        }

        /**
         * Retrieves the database passphrase, generating and persisting a new
         * 32-byte random value (sealed by the Android Keystore) if none exists.
         *
         * SECURITY MODEL:
         *   The passphrase is a cryptographically random 32-byte value, Base64-encoded
         *   to text. That text (its UTF-8 bytes) is what SQLCipher consumes as the key.
         *   For storage, the passphrase bytes are SEALED via [KeystoreSecretStore]
         *   (AES-256-GCM under a Keystore key that never leaves the secure hardware),
         *   and the resulting `IV || ciphertext+tag` blob is itself Base64-encoded and
         *   kept in a plain [android.content.SharedPreferences] file. The stored value
         *   is therefore useless without the device's Keystore key.
         *
         * WHY DIRECT KEYSTORE (not EncryptedSharedPreferences)?
         *   `androidx.security:security-crypto` was deprecated by Google in April 2025
         *   in favour of using platform APIs / the Android Keystore directly. The app
         *   already used the Keystore directly for its encrypted DataStore, so unifying
         *   on one primitive ([KeystoreSecretStore]) removes the deprecated dependency
         *   and leaves a single, auditable crypto path. The on-device protection is
         *   equivalent: a Keystore-held AES-256-GCM key guards the secret either way.
         *
         * FAILURE MODE:
         *   If the Keystore key is lost (e.g. a device-transfer that did not migrate
         *   Keystore entries), [KeystoreSecretStore.open] throws and the
         *   database cannot be opened. This matches the previous behaviour; recovery is
         *   via Settings → Restore Backup (JSON), which is device-independent.
         *
         * MEMORY HYGIENE:
         *   The returned [ByteArray] is zeroed by the caller immediately after
         *   [SupportOpenHelperFactory] has consumed it, so the plaintext passphrase has the
         *   shortest possible lifetime in the JVM heap.
         */
        private fun getOrCreatePassphrase(context: Context): ByteArray {
            val prefs = context.getSharedPreferences(PASSPHRASE_PREFS, Context.MODE_PRIVATE)

            val storedB64 = prefs.getString(PASSPHRASE_KEY, null)
            if (storedB64 != null) {
                // Decode the persisted envelope and ask the Keystore to open it.
                val sealed = Base64.decode(storedB64, Base64.NO_WRAP)
                return passphraseStore.open(sealed)   // == the passphrase bytes SQLCipher needs
            }

            // ── First run: generate, seal, persist ────────────────────────────
            val raw        = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val passphrase = Base64.encodeToString(raw, Base64.NO_WRAP).toByteArray(Charsets.UTF_8)
            raw.fill(0)    // zero the raw entropy immediately; we keep only the text form

            val sealed = passphraseStore.seal(passphrase)

            // Use commit() instead of apply() here.
            //
            // apply() schedules an asynchronous write and returns immediately. If two
            // threads both reach this branch during cold start, the race looks like:
            //   Thread A: getString → null → generates+seals key-A → apply() (scheduled)
            //   Thread B: getString → null (apply not flushed) → generates+seals key-B → apply()
            // Result: key-A was already used to open the database, but key-B overwrites
            // it in prefs → the next open uses key-B → SQLCipher throws "file is not a
            // database". commit() writes synchronously under a file lock, so the second
            // thread blocks, then reads the persisted value and skips generation.
            //
            // Performance: commit() runs at most once per install (key creation); every
            // later call takes the early-return path above with no synchronous write.
            // edit(commit = true) is the KTX form of a SYNCHRONOUS commit (see the
            // race rationale above): the block runs and the write is flushed under a
            // file lock before returning. Using it resolves the UseKtx and
            // ApplySharedPref lint hints without weakening the required blocking write
            // (apply() would be asynchronous and reintroduce the race).
            prefs.edit(commit = true) {
                putString(PASSPHRASE_KEY, Base64.encodeToString(sealed, Base64.NO_WRAP))
            }

            return passphrase
        }

        /**
         * Returns the singleton [AppDatabase] instance, creating it if necessary.
         *
         * Uses double-checked locking to avoid the cost of synchronization on
         * every call while remaining thread-safe on first creation.
         *
         * ENCRYPTION:
         *   A [SupportOpenHelperFactory] is constructed from the Keystore-backed passphrase
         *   and passed to [Room.databaseBuilder]. Every read and write from that
         *   point is transparently encrypted with SQLCipher (AES-256-CBC + HMAC-SHA1
         *   page authentication). The passphrase byte array is zeroed immediately
         *   after [SupportOpenHelperFactory] receives it.
         *
         * @param context          Application context – must be the application context
         *                         (not an Activity context) to avoid a memory leak.
         * @param applicationScope Long-lived [CoroutineScope] from [de.godisch.potillus.PotillusApp].
         */
        fun getInstance(context: Context, applicationScope: CoroutineScope): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: run {
                    val passphrase = getOrCreatePassphrase(context.applicationContext)
                    // sqlcipher-android requires the native library to be loaded
                    // explicitly before first use (the old android-database-sqlcipher
                    // did this implicitly). System.loadLibrary is idempotent, and
                    // getInstance's run{} block executes only once for the singleton.
                    System.loadLibrary("sqlcipher")
                    val factory    = SupportOpenHelperFactory(passphrase)
                    passphrase.fill(0)   // zero our copy; the factory holds its own

                    Room.databaseBuilder(
                        context.applicationContext,
                        AppDatabase::class.java,
                        "potillus.db"
                    )
                        .openHelperFactory(factory)
                        .addMigrations(MIGRATION_1_2)
                        .addCallback(PrepopulateCallback(applicationScope))
                        .build()
                        .also { INSTANCE = it }
                }
            }
        }
    }

    // ── Pre-population ────────────────────────────────────────────────────────

    /**
     * Inserts the built-in preset drinks the first time the database is created.
     *
     * Room calls [onCreate] once, immediately after the database file is first
     * opened and the schema has been created. At this point [INSTANCE] is
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
            INSTANCE?.let { database ->
                scope.launch {
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
            "CREATE INDEX IF NOT EXISTS index_entries_logicalDate ON entries (logicalDate)"
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
    DrinkEntity(name = "Lager (Pint)",               volumeMl = 568, alcoholPercent =  4.5, isPreset = true, category = "BEER"),
    DrinkEntity(name = "Lager (Standard)",           volumeMl = 500, alcoholPercent =  5.0, isPreset = true, category = "BEER"),
    DrinkEntity(name = "Lager (Small)",              volumeMl = 330, alcoholPercent =  5.0, isPreset = true, category = "BEER"),
    DrinkEntity(name = "Shandy / Radler",            volumeMl = 500, alcoholPercent =  2.5, isPreset = true, category = "BEER"),
    DrinkEntity(name = "White Wine (Small)",         volumeMl = 125, alcoholPercent = 12.5, isPreset = true, category = "WINE"),
    DrinkEntity(name = "White Wine (Regular)",       volumeMl = 150, alcoholPercent = 13.0, isPreset = true, category = "WINE"),
    DrinkEntity(name = "Red Wine (Regular)",         volumeMl = 150, alcoholPercent = 13.5, isPreset = true, category = "WINE"),
    DrinkEntity(name = "Sparkling Wine / Prosecco",  volumeMl = 125, alcoholPercent = 11.5, isPreset = true, category = "WINE"),
    DrinkEntity(name = "Gin & Tonic",                volumeMl = 200, alcoholPercent = 10.0, isPreset = true, category = "LONGDRINK"),
    DrinkEntity(name = "Cuba Libre",                 volumeMl = 200, alcoholPercent = 10.0, isPreset = true, category = "LONGDRINK"),
    DrinkEntity(name = "Vodka Soda",                 volumeMl = 200, alcoholPercent = 10.0, isPreset = true, category = "LONGDRINK"),
    DrinkEntity(name = "Vodka Shot",                 volumeMl =  40, alcoholPercent = 40.0, isPreset = true, category = "SPIRITS"),
    DrinkEntity(name = "Vodka Shot (International)", volumeMl =  45, alcoholPercent = 40.0, isPreset = true, category = "SPIRITS"),
    DrinkEntity(name = "Whiskey (Neat/Rocks)",       volumeMl =  45, alcoholPercent = 43.0, isPreset = true, category = "SPIRITS"),
    DrinkEntity(name = "Liqueur Shot",               volumeMl =  40, alcoholPercent = 35.0, isPreset = true, category = "LIQUEUR"),
)
