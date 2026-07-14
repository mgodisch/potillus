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

// =============================================================================
// BackupRepositoryInstrumentedTest.kt — backup-import FK-collision regression test
// =============================================================================
//
// WHY INSTRUMENTED (androidTest) AND NOT A PLAIN JVM UNIT TEST?
//   The bug this test guards against is a SQLite FOREIGN KEY violation
//   during a REPLACE import. It can only surface against a real Room/SQLite
//   engine that enforces foreign keys — the JVM `FakeBackupRepository` used by
//   the pure-JVM BackupRepositoryTest has no FK enforcement and therefore cannot
//   reproduce it. We use an in-memory Room database (no application-level encryption is
//   involved — the FK constraint is independent of storage), which keeps the test fast
//   and self-contained while still exercising the real DAO/transaction path.
//
// WHAT THIS GUARDS AGAINST
//   importReplace() captured the drinks' name→id map BEFORE deleting the user
//   drinks. A backup drink whose name matched a now-deleted user drink was then
//   mapped to that drink's OLD (deleted) id instead of being re-inserted, so the
//   backup entry referenced a missing parent row and tripped the entries→drinks
//   FK (RESTRICT) constraint, rolling back the entire import. The fix moves the
//   map fetch INSIDE the transaction, AFTER the deletes.
//
// HOW TO RUN
//   ./gradlew connectedDebugAndroidTest   (or `make test-device`)
//   Requires a connected device/emulator (API 35+). Not executed in a headless
//   CI without a device.
// =============================================================================

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import de.godisch.potillus.data.db.AppDatabase
import de.godisch.potillus.data.db.dao.DrinkDao
import de.godisch.potillus.data.db.dao.EntryDao
import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BackupRepositoryInstrumentedTest {

    private lateinit var db: AppDatabase
    private lateinit var drinkDao: DrinkDao
    private lateinit var entryDao: EntryDao
    private lateinit var repo: BackupRepository

    /**
     * Builds a fresh in-memory [AppDatabase] (schema v2, FK enforcement on) for
     * each test. We bypass [AppDatabase.getInstance] on purpose so the test uses a
     * plain database without the singleton/clean-up machinery and
     * without the preset pre-population callback — the test seeds its own rows.
     */
    @Before
    fun setUp() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(ctx, AppDatabase::class.java).build()
        drinkDao = db.drinkDao()
        entryDao = db.entryDao()
        repo = BackupRepository(entryDao, drinkDao, db)
    }

    @After
    fun tearDown() {
        db.close()
    }

    /**
     * Regression test: a REPLACE import of a backup whose drink name collides
     * with an existing **user-created** drink must succeed (relinking the entry to
     * a freshly inserted drink), not fail with a foreign-key violation.
     *
     * Before the fix this threw `SQLiteConstraintException` and rolled the whole
     * import back; the assertions below would never be reached.
     */
    @Test
    fun importReplace_relinksEntryWhenBackupDrinkNameCollidesWithDeletedUserDrink() = runBlocking {
        // ── Local state: one preset + one user-created drink with the SAME name
        //    that the backup will also contain ("Mojito"). ─────────────────────
        drinkDao.insert(
            DrinkEntity(name = "Lager", volumeMl = 500, alcoholPercent = 5.0, isPreset = true, category = "BEER"),
        )
        val localMojitoId = drinkDao.insert(
            DrinkEntity(name = "Mojito", volumeMl = 200, alcoholPercent = 10.0, isPreset = false, category = "LONGDRINK"),
        )
        // A pre-existing local entry (will be wiped by the REPLACE import).
        entryDao.insert(
            EntryEntity(
                drinkId = localMojitoId,
                drinkName = "Mojito",
                volumeMl = 200,
                alcoholPercent = 10.0,
                gramsAlcohol = 15.78,
                timestampMillis = 500L,
                logicalDate = "2024-12-31",
                note = "",
            ),
        )

        // ── Backup payload: the same "Mojito" drink (its backup id is irrelevant
        //    once remapped) plus one entry that references it. ──────────────────
        val backupDrinks = listOf(
            DrinkDefinition(
                id = 99,
                name = "Mojito",
                volumeMl = 200,
                alcoholPercent = 10.0,
                isPreset = false,
                category = DrinkCategory.LONGDRINK,
            ),
        )
        val backupEntries = listOf(
            ConsumptionEntry(
                id = 0, drinkId = 99, drinkName = "Mojito", volumeMl = 200, alcoholPercent = 10.0,
                gramsAlcohol = 15.78, timestampMillis = 1_000L, logicalDate = "2025-01-01", note = "",
            ),
        )

        // ── Act: this must NOT throw an FK constraint exception. ───────────────
        val stats = repo.importReplace(backupDrinks, backupEntries)

        // ── Assert: the entry was imported and points at a real drink row. ─────
        assertEquals("one backup entry should be imported", 1, stats.imported)
        assertEquals("REPLACE never skips", 0, stats.skipped)

        val entries = entryDao.getAll()
        assertEquals("exactly the backup entry should remain", 1, entries.size)

        val relinkedDrink = drinkDao.getById(entries.first().drinkId)
        assertNotNull("the entry's drinkId must reference an existing drink", relinkedDrink)
        assertEquals("Mojito", relinkedDrink!!.name)
    }

    /**
     * Regression test (v0.83.0): after a REPLACE import the drink catalogue must
     * equal the backup's drink list EXACTLY.
     *
     * This pins the reported bug: on a fresh install (or after "clear storage")
     * the pre-population callback seeds the full preset set; importing a backup
     * with REPLACE then left those presets in place, so they showed up ALONGSIDE
     * the backup's drinks instead of being replaced. The fix wipes every drink —
     * presets included — before re-inserting the backup, so:
     *   - a preset the backup does NOT contain ("Lager" here) is dropped, and
     *   - a preset the backup DOES contain ("Pils") is recreated with its
     *     `isPreset` flag intact.
     */
    @Test
    fun importReplace_replacesPresetsToMatchTheBackupExactly() = runBlocking {
        // ── Local state mimicking a fresh install: two seeded presets. ─────────
        drinkDao.insert(
            DrinkEntity(name = "Lager", volumeMl = 500, alcoholPercent = 5.0, isPreset = true, category = "BEER"),
        )
        drinkDao.insert(
            DrinkEntity(name = "Pils", volumeMl = 500, alcoholPercent = 4.8, isPreset = true, category = "BEER"),
        )

        // ── Backup payload: one of the presets ("Pils") plus one custom drink. ─
        val backupDrinks = listOf(
            DrinkDefinition(
                id = 1, name = "Pils", volumeMl = 500, alcoholPercent = 4.8,
                isPreset = true, category = DrinkCategory.BEER,
            ),
            DrinkDefinition(
                id = 2, name = "Cider", volumeMl = 330, alcoholPercent = 4.5,
                isPreset = false, category = DrinkCategory.OTHER,
            ),
        )

        repo.importReplace(backupDrinks, backupEntries = emptyList())

        // ── Assert: exactly the backup's drinks remain; "Lager" is gone. ───────
        val remaining = drinkDao.getAllOnce()
        assertEquals(
            "catalogue must equal the backup exactly",
            setOf("Pils", "Cider"),
            remaining.map { it.name }.toSet(),
        )
        val pils = remaining.first { it.name == "Pils" }
        assertEquals("a preset in the backup keeps its isPreset flag", true, pils.isPreset)
    }
}
