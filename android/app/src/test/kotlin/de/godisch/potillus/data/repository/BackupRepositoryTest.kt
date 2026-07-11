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
// BackupRepositoryTest.kt – Unit tests for FakeBackupRepository
// =============================================================================
//
// WHAT IS TESTED HERE:
//   These tests verify the *contract* of IBackupRepository by testing
//   FakeBackupRepository — the same fake that SettingsViewModelTest uses.
//   This matters for a teaching app: the fake must faithfully reflect the
//   contract so that tests using it are meaningful.
//
//   A second set of tests verifies BackupManager.parseBackupJson (the pure-
//   Kotlin JSON parsing logic) independently of any Android runtime. These
//   are the most important correctness tests for backup import because:
//     1. parseBackupJson contains all the value guards (ranges, date format).
//     2. It is annotated @VisibleForTesting(PRIVATE) and accessible from the
//        test source set without a ContentResolver or file URI.
//
// WHY NOT TEST BackupRepository (the real implementation) HERE?
//   BackupRepository uses Room's withTransaction, which requires an actual
//   SQLite database. That makes it an instrumented test (androidTest), not a
//   JVM unit test. The real BackupRepository is covered by the Room-based
//   integration tests in the instrumented test suite.
// =============================================================================

import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.fake.FakeBackupRepository
import de.godisch.potillus.util.BackupManager
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupRepositoryTest {

    // ── FakeBackupRepository contract tests ───────────────────────────────────

    /**
     * importReplace returns the configured replaceResult and records the call arguments.
     *
     * SettingsViewModel checks the ImportStats to build the success message.
     * This test ensures the fake behaves like the real implementation would.
     */
    @Test fun `importReplace returns configured stats and records arguments`() = runTest {
        val fake = FakeBackupRepository().also {
            it.replaceResult = ImportStats(imported = 3, skipped = 0)
        }
        val drinks = listOf(drink(1))
        val entries = listOf(entry(1), entry(2), entry(3))

        val stats = fake.importReplace(drinks, entries)

        assertEquals(3, stats.imported)
        assertEquals(0, stats.skipped)
        assertEquals(drinks to entries, fake.lastReplaceCall)
    }

    /**
     * importMerge returns the configured mergeResult (imported + skipped) and records arguments.
     */
    @Test fun `importMerge returns configured stats and records arguments`() = runTest {
        val fake = FakeBackupRepository().also {
            it.mergeResult = ImportStats(imported = 2, skipped = 1)
        }
        val drinks = listOf(drink(1))
        val entries = listOf(entry(1), entry(2), entry(3))

        val stats = fake.importMerge(drinks, entries)

        assertEquals(2, stats.imported)
        assertEquals(1, stats.skipped)
        assertEquals(drinks to entries, fake.lastMergeCall)
    }

    /**
     * When throwOnImport is set, both import methods propagate the exception.
     *
     * SettingsViewModel wraps the call in try/catch and shows ExportStatus.Err.
     * This test ensures the fake correctly simulates the failure path.
     */
    @Test fun `throwOnImport causes importReplace to throw`() = runTest {
        val fake = FakeBackupRepository().also {
            it.throwOnImport = RuntimeException("simulated DB failure")
        }
        val result = runCatching { fake.importReplace(emptyList(), emptyList()) }
        assertTrue("Expected exception", result.isFailure)
        assertEquals("simulated DB failure", result.exceptionOrNull()?.message)
    }

    // ── BackupManager.parseBackupJson – value guard tests ─────────────────────

    /**
     * A well-formed version-2 backup parses successfully with the expected counts.
     *
     * This is the "happy path" test: confirms that a backup created by
     * BackupManager.exportToJson can be round-tripped through parseBackupJson.
     */
    @Test fun `valid JSON backup parses successfully`() {
        val json = """
            {
              "version": 2,
              "exportedAt": "2026-01-15T10:00:00Z",
              "drinks": [
                { "id": 1, "name": "Pils 0.5l", "volumeMl": 500, "alcoholPercent": 5.0,
                  "isPreset": false, "isFavorite": false, "category": "BEER" }
              ],
              "entries": [
                { "id": 1, "drinkId": 1, "drinkName": "Pils 0.5l", "volumeMl": 500,
                  "alcoholPercent": 5.0, "gramsAlcohol": 19.73, "timestampMillis": 1736935200000,
                  "logicalDate": "2026-01-15", "note": "" }
              ]
            }
        """.trimIndent()

        val result = BackupManager.parseBackupJson(json)
        assertNull("No error expected", result.error)
        assertEquals(1, result.drinks.size)
        assertEquals(1, result.entries.size)
        assertEquals("Pils 0.5l", result.drinks.first().name)
        assertEquals("2026-01-15", result.entries.first().logicalDate)
    }

    /**
     * A blank input returns ImportError.FileEmpty immediately.
     */
    @Test fun `blank text returns FileEmpty error`() {
        val result = BackupManager.parseBackupJson("   ")
        assertEquals(BackupManager.ImportError.FileEmpty, result.error)
    }

    /**
     * Malformed JSON (not valid JSON at all) returns ImportError.InvalidJson.
     */
    @Test fun `malformed JSON returns InvalidJson error`() {
        val result = BackupManager.parseBackupJson("{ this is not json }")
        assertEquals(BackupManager.ImportError.InvalidJson, result.error)
    }

    /**
     * A version number higher than the current BACKUP_VERSION returns VersionTooHigh.
     *
     * This prevents an older app build from silently truncating unknown fields
     * written by a newer version.
     */
    @Test fun `version higher than current returns VersionTooHigh error`() {
        val json = """{ "version": 999, "drinks": [], "entries": [] }"""
        val result = BackupManager.parseBackupJson(json)
        assertTrue(result.error is BackupManager.ImportError.VersionTooHigh)
        val err = result.error as BackupManager.ImportError.VersionTooHigh
        assertEquals(999, err.found)
    }

    /**
     * An entry with a volumeMl of 0 fails the Guard-3 range check.
     *
     * The ViewModel maps this to ImportError.ReadError and shows an error
     * banner rather than inserting a corrupt row.
     */
    @Test fun `entry with volumeMl=0 returns ReadError`() {
        val json = """
            {
              "version": 2,
              "drinks": [],
              "entries": [
                { "id": 1, "drinkId": 1, "drinkName": "X", "volumeMl": 0,
                  "alcoholPercent": 5.0, "gramsAlcohol": 10.0, "timestampMillis": 1000,
                  "logicalDate": "2026-01-10", "note": "" }
              ]
            }
        """.trimIndent()
        val result = BackupManager.parseBackupJson(json)
        assertTrue(result.error is BackupManager.ImportError.ReadError)
    }

    /**
     * An entry with an impossible calendar date ("2024-02-31") is now
     * rejected by the full LocalDate.parse() guard introduced in this release.
     *
     * Previously the shape-only regex \d{4}-\d{2}-\d{2} would have accepted
     * this value, silently creating an orphaned database row.
     */
    @Test fun `entry with impossible logicalDate returns ReadError`() {
        val json = """
            {
              "version": 2,
              "drinks": [],
              "entries": [
                { "id": 1, "drinkId": 1, "drinkName": "X", "volumeMl": 330,
                  "alcoholPercent": 5.0, "gramsAlcohol": 13.1, "timestampMillis": 1000,
                  "logicalDate": "2024-02-31", "note": "" }
              ]
            }
        """.trimIndent()
        val result = BackupManager.parseBackupJson(json)
        assertTrue(
            "Expected ReadError for impossible date 2024-02-31, got: ${result.error}",
            result.error is BackupManager.ImportError.ReadError,
        )
    }

    /**
     * An entry with a well-formed but far-future date ("9999-99-99")
     * is also rejected now (previously passed the regex guard).
     */
    @Test fun `entry with out-of-range logicalDate returns ReadError`() {
        val json = """
            {
              "version": 2,
              "drinks": [],
              "entries": [
                { "id": 1, "drinkId": 1, "drinkName": "X", "volumeMl": 330,
                  "alcoholPercent": 5.0, "gramsAlcohol": 13.1, "timestampMillis": 1000,
                  "logicalDate": "9999-99-99", "note": "" }
              ]
            }
        """.trimIndent()
        val result = BackupManager.parseBackupJson(json)
        assertTrue(
            "Expected ReadError for date 9999-99-99, got: ${result.error}",
            result.error is BackupManager.ImportError.ReadError,
        )
    }

    /**
     * A version-1 backup (no "category" field on drinks) is handled gracefully:
     * the missing field defaults to "OTHER" via optString().
     */
    @Test fun `version-1 backup without category field is parsed with OTHER fallback`() {
        val json = """
            {
              "version": 1,
              "drinks": [
                { "id": 1, "name": "OldDrink", "volumeMl": 330, "alcoholPercent": 4.8,
                  "isPreset": false, "isFavorite": false }
              ],
              "entries": []
            }
        """.trimIndent()
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals("OTHER", result.drinks.first().category.name)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private fun drink(id: Long) = DrinkDefinition(
        id = id,
        name = "Drink$id",
        volumeMl = 500,
        alcoholPercent = 5.0,
    )

    private fun entry(id: Long) = ConsumptionEntry(
        id = id,
        drinkId = 1,
        drinkName = "Drink1",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = 19.73,
        timestampMillis = 1_736_935_200_000L,
        logicalDate = "2026-01-15",
    )
}
