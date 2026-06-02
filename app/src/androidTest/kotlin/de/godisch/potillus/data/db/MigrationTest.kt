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
 *
 * INSTRUMENTED MIGRATION TEST — AppDatabase (data-persistence freeze safeguard)
 *
 * WHY THIS FILE EXISTS
 *   The database schema is now considered "frozen": every future schema change
 *   must ship a Room Migration. This test turns the committed schema JSONs in
 *   app/schemas/ from passive documentation into an executable contract:
 *
 *     • createDatabase(name, N)              builds a real DB at the *old*
 *                                            schema version N from N.json,
 *     • runMigrationsAndValidate(name, N+1)  runs the Migration and then
 *                                            validates the resulting on-disk
 *                                            schema against (N+1).json — it
 *                                            THROWS if they differ.
 *
 *   So a broken or missing migration fails this test instead of crashing a
 *   user's app on first launch after an update.
 *
 * WHEN YOU ADD A NEW MIGRATION (e.g. v2 → v3)
 *   1. Bump AppDatabase.version and add a Migration(2, 3) (registered in
 *      Room.databaseBuilder().addMigrations(...)).
 *   2. Build once so Room exports app/schemas/.../3.json — commit it.
 *   3. Add a `migrate2To3_...()` test below following the same pattern.
 *
 * SQLCIPHER NOTE
 *   The production database is encrypted with SQLCipher, so the MigrationTestHelper
 *   is given a [SupportOpenHelperFactory] (with a throwaway test passphrase) as its
 *   open-helper factory; otherwise it could not open the encrypted test DB.
 *
 * RUNNING
 *   ./gradlew connectedDebugAndroidTest   (requires a device/emulator)
 */
package de.godisch.potillus.data.db

import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.IOException

/**
 * Validates the Room migrations registered in [AppDatabase] against the
 * committed schema snapshots in `app/schemas/`.
 */
@RunWith(AndroidJUnit4::class)
class MigrationTest {

    private companion object {
        const val TEST_DB = "migration-test.db"

        /**
         * Throwaway passphrase for the encrypted test database. This is NOT a
         * real secret — it only lets SQLCipher's [SupportOpenHelperFactory] open
         * the disposable migration-test DB created by the helper.
         */
        val TEST_PASSPHRASE: ByteArray = "migration-test-passphrase".toByteArray()

        init {
            // sqlcipher-android requires the native library to be loaded before
            // the encrypted database is opened. Doing it in the companion init
            // guarantees it runs before the @get:Rule helper field is initialised.
            System.loadLibrary("sqlcipher")
        }
    }

    /**
     * Creates/opens the historical schema versions from the exported JSONs.
     * The [SupportOpenHelperFactory] makes the helper open the (encrypted) test
     * DB the same way the production code does.
     */
    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        AppDatabase::class.java,
        emptyList(),
        // sqlcipher-android's SupportOpenHelperFactory has no clearPassphrase
        // toggle. The old SupportFactory zeroed the passphrase byte[] after the
        // first open by default (so the single-arg form broke reuse, and the test
        // had to pass clearPassphrase = false). The new library does not clear the
        // passphrase, so the single-argument constructor is safe across the
        // multiple opens this test performs: createDatabase() builds the DB at the
        // old version and closes it, then runMigrationsAndValidate() reopens it.
        // NOTE: the new 3-arg constructor's last Boolean is enableWriteAheadLogging,
        // NOT clearPassphrase — do not reintroduce a `false` here expecting the old
        // meaning.
        SupportOpenHelperFactory(TEST_PASSPHRASE)
    )

    /**
     * v1 → v2 adds an index on `entries.logicalDate` (see [MIGRATION_1_2]).
     *
     * Verifies that (a) the migrated schema matches `2.json`, (b) the new index
     * exists afterwards, and (c) pre-existing rows survive unchanged.
     */
    @Test
    @Throws(IOException::class)
    fun migrate1To2_addsLogicalDateIndex_andPreservesData() {
        // ── Arrange: create a v1 database and seed one drink + one entry ──────
        helper.createDatabase(TEST_DB, 1).apply {
            execSQL(
                "INSERT INTO drinks (id, name, volumeMl, alcoholPercent, isPreset, isFavorite, category) " +
                    "VALUES (1, 'Test Lager', 500, 5.0, 0, 0, 'BEER')"
            )
            execSQL(
                "INSERT INTO entries " +
                    "(id, drinkId, drinkName, volumeMl, alcoholPercent, gramsAlcohol, timestampMillis, logicalDate, note) " +
                    "VALUES (1, 1, 'Test Lager', 500, 5.0, 19.7, 1700000000000, '2026-05-30', '')"
            )
            close()
        }

        // ── Act: run the migration and validate against 2.json ────────────────
        // runMigrationsAndValidate throws if the resulting schema != 2.json.
        val db = helper.runMigrationsAndValidate(TEST_DB, 2, true, MIGRATION_1_2)

        // ── Assert: the index now exists … ────────────────────────────────────
        assertTrue(
            "v1→v2 should create index_entries_logicalDate",
            hasIndex(db, "entries", "index_entries_logicalDate")
        )

        // ── … and the seeded row is unchanged ─────────────────────────────────
        db.query("SELECT logicalDate FROM entries WHERE id = 1").use { c ->
            assertTrue("seeded entry must survive the migration", c.moveToFirst())
            assertEquals("2026-05-30", c.getString(0))
        }
        db.close()
    }

    /** Returns true if [table] has an index named [index] (via `PRAGMA index_list`). */
    private fun hasIndex(db: SupportSQLiteDatabase, table: String, index: String): Boolean =
        db.query("PRAGMA index_list($table)").use { c ->
            val nameCol = c.getColumnIndex("name")
            var found = false
            while (c.moveToNext()) {
                if (c.getString(nameCol) == index) { found = true; break }
            }
            found
        }
}
