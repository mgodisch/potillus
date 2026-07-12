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
//   Two REPLACE-import contracts that need a real Room/SQLite engine:
//   (1) Foreign keys: a backup drink whose name matched a deleted local drink
//       must be re-inserted (not mapped to a stale id) so its entry's
//       entries→drinks FK (RESTRICT) is satisfied instead of rolling the import
//       back. (2) All-inclusive replace: REPLACE wipes the ENTIRE catalogue,
//       presets included, and rebuilds it from the backup — a local preset absent
//       from the backup is removed, and a backup preset replaces (does not merge
//       onto) the local one. The earlier code deleted only user-created drinks and
//       matched backup drinks onto the surviving presets by name, which left the
//       presets in place and merely added the backup's drinks (the reported bug).
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
import org.junit.Assert.assertTrue
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

        // ── Assert: REPLACE wiped the local PRESET too. The local "Lager" preset
        //    was not in the backup, so after an all-inclusive replace the catalogue
        //    is exactly the backup's one drink — the preset must be gone. This is
        //    the bug fix: presets used to survive and be merged onto. ────────────
        val allDrinks = drinkDao.getAllOnce()
        assertEquals("catalogue must equal the backup (preset wiped)", 1, allDrinks.size)
        assertEquals("only the backup drink remains", "Mojito", allDrinks.first().name)
    }

    /**
     * A REPLACE import must restore the catalogue EXACTLY as it is in the backup,
     * presets included — a backup preset replaces the local preset rather than
     * being merged onto it, and a preset absent from the backup is removed.
     *
     * This is the direct regression test for the reported bug: on a fresh install
     * (which is pre-populated with presets), importing a backup with "replace"
     * left the local presets in place and merely added the backup's drinks.
     */
    @Test
    fun importReplace_replacesPresetsWithBackupCatalogue() = runBlocking {
        // ── Local state: two presets, as a fresh install would have. ───────────
        drinkDao.insert(
            DrinkEntity(name = "Local Beer", volumeMl = 500, alcoholPercent = 5.0, isPreset = true, category = "BEER"),
        )
        drinkDao.insert(
            DrinkEntity(name = "Local Wine", volumeMl = 200, alcoholPercent = 12.0, isPreset = true, category = "WINE"),
        )

        // ── Backup: one preset with the SAME name as a local preset ("Local
        //    Beer") plus one new preset the local install does not have. ────────
        val backupDrinks = listOf(
            DrinkDefinition(id = 1, name = "Local Beer", volumeMl = 330, alcoholPercent = 4.5, isPreset = true, category = DrinkCategory.BEER),
            DrinkDefinition(id = 2, name = "Backup Cider", volumeMl = 440, alcoholPercent = 6.0, isPreset = true, category = DrinkCategory.BEER),
        )

        val stats = repo.importReplace(backupDrinks, emptyList())

        assertEquals("no entries to import", 0, stats.imported)

        val allDrinks = drinkDao.getAllOnce().sortedBy { it.name }
        // Exactly the backup's two drinks — "Local Wine" (local-only preset) is
        // gone, and "Local Beer" is the BACKUP's version (330 ml / 4.5%), proving
        // the backup replaced the local preset instead of merging onto it.
        assertEquals("catalogue must equal the backup's two drinks", 2, allDrinks.size)
        assertEquals("Backup Cider", allDrinks[0].name)
        assertEquals("Local Beer", allDrinks[1].name)
        assertEquals("backup's Local Beer volume must win", 330, allDrinks[1].volumeMl)
        assertEquals("backup's Local Beer strength must win", 4.5, allDrinks[1].alcoholPercent, 0.0001)
        assertTrue("backup presets keep their preset flag", allDrinks.all { it.isPreset })
    }
}
