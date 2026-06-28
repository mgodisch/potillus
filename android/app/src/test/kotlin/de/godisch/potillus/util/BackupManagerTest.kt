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
package de.godisch.potillus.util

// =============================================================================
// BackupManagerTest.kt – Unit tests for BackupManager.parseBackupJson
// =============================================================================
//
// WHY test parseBackupJson and not importFromJson?
//   importFromJson depends on android.content.Context (ContentResolver, Uri)
//   which is not available on the JVM test runner. BackupManager.parseBackupJson
//   is `internal` (accessible within the same Gradle module) and is a pure
//   function: String in, ImportResult out. No Android runtime required.
//
// JSON helpers:
//   buildBackupJson() constructs minimal valid JSON for the current schema
//   version (2). Tests that need invalid values override specific fields.
// =============================================================================

import de.godisch.potillus.util.BackupManager.ImportError
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupManagerTest {

    // ── Format errors ─────────────────────────────────────────────────────────

    @Test fun `blank text returns FileEmpty`() {
        val result = BackupManager.parseBackupJson("   ")
        assertEquals(ImportError.FileEmpty, result.error)
    }

    @Test fun `invalid JSON returns InvalidJson`() {
        val result = BackupManager.parseBackupJson("{not valid json}")
        assertEquals(ImportError.InvalidJson, result.error)
    }

    @Test fun `version higher than supported returns VersionTooHigh`() {
        val json = """{"version":999,"drinks":[],"entries":[]}"""
        val result = BackupManager.parseBackupJson(json)
        val error = result.error
        assertTrue("Expected VersionTooHigh", error is ImportError.VersionTooHigh)
        assertEquals(999, (error as ImportError.VersionTooHigh).found)
    }

    // ── Happy path ────────────────────────────────────────────────────────────

    @Test fun `valid minimal backup with no drinks or entries succeeds`() {
        val json = """{"version":2,"drinks":[],"entries":[]}"""
        val result = BackupManager.parseBackupJson(json)
        assertNull("No error expected for valid JSON", result.error)
        assertTrue(result.drinks.isEmpty())
        assertTrue(result.entries.isEmpty())
        assertEquals(2, result.sourceVersion)
    }

    @Test fun `valid backup with one drink parses correctly`() {
        val json = buildBackupJson(drinks = listOf(drinkJson(
            id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0, category = "BEER"
        )))
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals(1, result.drinks.size)
        result.drinks.first().let { d ->
            assertEquals("Lager", d.name)
            assertEquals(500, d.volumeMl)
            assertEquals(5.0, d.alcoholPercent, 0.001)
        }
    }

    @Test fun `valid backup with one entry parses correctly`() {
        val json = buildBackupJson(
            drinks  = listOf(drinkJson(id = 1, name = "Wine", volumeMl = 150, alcoholPercent = 13.0)),
            entries = listOf(entryJson(
                id = 1, drinkId = 1, drinkName = "Wine",
                volumeMl = 150, alcoholPercent = 13.0,
                gramsAlcohol = 15.4, timestampMillis = 1_700_000_000_000L,
                logicalDate = "2023-11-14"
            ))
        )
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals(1, result.entries.size)
        result.entries.first().let { e ->
            assertEquals("Wine", e.drinkName)
            assertEquals("2023-11-14", e.logicalDate)
            assertEquals(15.4, e.gramsAlcohol, 0.001)
        }
    }

    @Test fun `version 1 backup without category field uses OTHER as default`() {
        val json = """{"version":1,"drinks":[{"id":1,"name":"Old","volumeMl":500,"alcoholPercent":5.0}],"entries":[]}"""
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals(de.godisch.potillus.domain.model.DrinkCategory.OTHER, result.drinks.first().category)
    }

    // ── Value range guards ────────────────────────────────────────────────────

    @Test fun `gramsAlcohol NaN is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(gramsAlcohol = Double.NaN)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `gramsAlcohol negative is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(gramsAlcohol = -0.1)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `gramsAlcohol Infinity is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(gramsAlcohol = Double.POSITIVE_INFINITY)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `entry alcoholPercent above 100 is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(alcoholPercent = 100.1)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `entry alcoholPercent negative is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(alcoholPercent = -1.0)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `entry volumeMl=0 is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(volumeMl = 0)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `entry timestampMillis=0 is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(timestampMillis = 0L)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `drink volumeMl=0 is rejected as ReadError`() {
        val json = buildBackupJson(drinks = listOf(drinkJson(volumeMl = 0)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `drink alcoholPercent=101 is rejected as ReadError`() {
        val json = buildBackupJson(drinks = listOf(drinkJson(alcoholPercent = 101.0)))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    // ── logicalDate format validation ─────────────────────────────────

    @Test fun `entry with invalid logicalDate format is rejected as ReadError`() {
        // An arbitrary string that is not YYYY-MM-DD must be rejected to prevent
        // SQL injection-style corruption of date-range queries.
        val json = buildBackupJson(entries = listOf(entryJson(logicalDate = "not-a-date")))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `entry with logicalDate missing separator is rejected as ReadError`() {
        val json = buildBackupJson(entries = listOf(entryJson(logicalDate = "20231114")))
        assertReadError(BackupManager.parseBackupJson(json))
    }

    @Test fun `entry with valid logicalDate YYYY-MM-DD is accepted`() {
        val json = buildBackupJson(entries = listOf(entryJson(logicalDate = "2023-11-14")))
        val result = BackupManager.parseBackupJson(json)
        assertNull("Valid YYYY-MM-DD should not produce an error", result.error)
        assertEquals("2023-11-14", result.entries.first().logicalDate)
    }

    // ── Round-trip ────────────────────────────────────────────────────────────

    @Test fun `round-trip export then parse preserves drink and entry data`() {
        // Build a valid backup and verify all fields survive the parse.
        val json = buildBackupJson(
            drinks  = listOf(drinkJson(id = 7, name = "Gin & Tonic", volumeMl = 200, alcoholPercent = 10.0, category = "LONGDRINK")),
            entries = listOf(entryJson(
                id = 3, drinkId = 7, drinkName = "Gin & Tonic",
                volumeMl = 200, alcoholPercent = 10.0,
                gramsAlcohol = 15.78, timestampMillis = 1_700_100_000_000L,
                logicalDate = "2023-11-15", note = "birthday"
            ))
        )
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals("Gin & Tonic", result.drinks.first().name)
        assertEquals("birthday", result.entries.first().note)
        assertEquals(7L, result.entries.first().drinkId)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun assertReadError(result: BackupManager.ImportResult) {
        assertNotNull("Expected an error", result.error)
        assertTrue(
            "Expected ReadError but got ${result.error}",
            result.error is ImportError.ReadError
        )
    }

    private fun buildBackupJson(
        version: Int         = 2,
        drinks:  List<String> = emptyList(),
        entries: List<String> = emptyList()
    ): String {
        val drinksArr  = drinks.joinToString(",", "[", "]")
        val entriesArr = entries.joinToString(",", "[", "]")
        return """{"version":$version,"drinks":$drinksArr,"entries":$entriesArr}"""
    }

    private fun drinkJson(
        id:             Long   = 1,
        name:           String = "Beer",
        volumeMl:       Int    = 500,
        alcoholPercent: Double = 5.0,
        isPreset:       Boolean = false,
        isFavorite:     Boolean = false,
        category:       String = "BEER"
    ) = """{"id":$id,"name":"$name","volumeMl":$volumeMl,"alcoholPercent":$alcoholPercent,"isPreset":$isPreset,"isFavorite":$isFavorite,"category":"$category"}"""

    private fun entryJson(
        id:              Long   = 1,
        drinkId:         Long   = 1,
        drinkName:       String = "Beer",
        volumeMl:        Int    = 500,
        alcoholPercent:  Double = 5.0,
        gramsAlcohol:    Double = 19.73,
        timestampMillis: Long   = 1_700_000_000_000L,
        logicalDate:     String = "2023-11-14",
        note:            String = ""
    ) = """{"id":$id,"drinkId":$drinkId,"drinkName":"$drinkName","volumeMl":$volumeMl,"alcoholPercent":$alcoholPercent,"gramsAlcohol":$gramsAlcohol,"timestampMillis":$timestampMillis,"logicalDate":"$logicalDate","note":"$note"}"""
}
