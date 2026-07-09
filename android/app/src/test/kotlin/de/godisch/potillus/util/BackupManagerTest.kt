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

import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ThemeMode
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
        val json = buildBackupJson(
            drinks = listOf(
                drinkJson(
                    id = 1,
                    name = "Lager",
                    volumeMl = 500,
                    alcoholPercent = 5.0,
                    category = "BEER",
                ),
            ),
        )
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
            drinks = listOf(drinkJson(id = 1, name = "Wine", volumeMl = 150, alcoholPercent = 13.0)),
            entries = listOf(
                entryJson(
                    id = 1,
                    drinkId = 1,
                    drinkName = "Wine",
                    volumeMl = 150,
                    alcoholPercent = 13.0,
                    gramsAlcohol = 15.4,
                    timestampMillis = 1_700_000_000_000L,
                    logicalDate = "2023-11-14",
                ),
            ),
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

    // ── Guard 5: referential integrity (v0.79.0 QA) ───────────────────────────

    /**
     * An entry whose drinkId points at no drink IN THE BACKUP must be rejected
     * at parse time. Before this guard, the dangling id slipped through to the
     * repository, where the REPLACE import's remap fallback kept the raw value:
     * colliding with a local preset id silently attached the entry to the wrong
     * drink; otherwise the FK aborted the whole transaction with only a generic
     * error.
     */
    @Test fun `entry referencing a drink absent from the backup is rejected as ReadError`() {
        val json = buildBackupJson(
            drinks = listOf(drinkJson(id = 1, name = "Wine", volumeMl = 150, alcoholPercent = 13.0)),
            entries = listOf(entryJson(id = 1, drinkId = 42, drinkName = "Wine")),
        )
        val result = BackupManager.parseBackupJson(json)
        assertReadError(result)
        // One explicit cast into a local; a second `as` after the smart cast
        // would draw kotlinc's "no cast needed" warning, which -Werror promotes
        // to a build failure.
        val error = result.error as ImportError.ReadError
        assertTrue(
            "detail should name the dangling id, got: ${error.detail}",
            error.detail?.contains("42") == true,
        )
    }

    /** The guard must not reject a valid multi-drink backup (ids matched as a set). */
    @Test fun `entries referencing any backup drink pass the referential guard`() {
        val json = buildBackupJson(
            drinks = listOf(
                drinkJson(id = 7, name = "Wine", volumeMl = 150, alcoholPercent = 13.0),
                drinkJson(id = 3, name = "Lager", volumeMl = 500, alcoholPercent = 5.0),
            ),
            entries = listOf(
                entryJson(id = 1, drinkId = 3, drinkName = "Lager"),
                entryJson(id = 2, drinkId = 7, drinkName = "Wine", timestampMillis = 1_700_000_100_000L),
            ),
        )
        val result = BackupManager.parseBackupJson(json)
        assertNull("valid references must not trip Guard 5", result.error)
        assertEquals(2, result.entries.size)
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
        // The matching drink keeps the fixture referentially valid (Guard 5): this
        // test's subject is the DATE guard, which must be the only one exercised.
        val json = buildBackupJson(
            drinks = listOf(drinkJson(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)),
            entries = listOf(entryJson(logicalDate = "2023-11-14")),
        )
        val result = BackupManager.parseBackupJson(json)
        assertNull("Valid YYYY-MM-DD should not produce an error", result.error)
        assertEquals("2023-11-14", result.entries.first().logicalDate)
    }

    // ── Round-trip ────────────────────────────────────────────────────────────

    @Test fun `round-trip export then parse preserves drink and entry data`() {
        // Build a valid backup and verify all fields survive the parse.
        val json = buildBackupJson(
            drinks = listOf(drinkJson(id = 7, name = "Gin & Tonic", volumeMl = 200, alcoholPercent = 10.0, category = "LONGDRINK")),
            entries = listOf(
                entryJson(
                    id = 3, drinkId = 7, drinkName = "Gin & Tonic",
                    volumeMl = 200, alcoholPercent = 10.0,
                    gramsAlcohol = 15.78, timestampMillis = 1_700_100_000_000L,
                    logicalDate = "2023-11-15", note = "birthday",
                ),
            ),
        )
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals("Gin & Tonic", result.drinks.first().name)
        assertEquals("birthday", result.entries.first().note)
        assertEquals(7L, result.entries.first().drinkId)
    }

    // ── Settings (backup format 3) ──────────────────────────────────────────────

    @Test fun `version 2 backup without settings yields null settings`() {
        val json = buildBackupJson(version = 2, drinks = listOf(drinkJson()), entries = listOf(entryJson()))
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertNull("Pre-v3 backups must not carry settings", result.settings)
        assertEquals(1, result.drinks.size)
    }

    @Test fun `version 3 settings round-trip preserves all fields`() {
        val json = buildBackupJson(version = 3, settings = settingsJson())
        val s = BackupManager.parseBackupJson(json).settings
        assertNotNull("v3 backup must parse a settings object", s)
        requireNotNull(s)
        assertEquals(ThemeMode.NIGHT, s.themeMode)
        assertEquals(6, s.dayChangeHour)
        assertEquals(30, s.dayChangeMinute)
        assertEquals(24.0, s.dailyLimitGrams, 0.0)
        assertEquals(120.0, s.weeklyLimitGrams, 0.0)
        assertEquals(3, s.maxDrinkDaysPerWeek)
        assertEquals("2024-01-15", s.statsFromDate)
        assertTrue(s.biometricEnabled)
        assertTrue(s.allowScreenshots)
        assertEquals("de", s.language)
        assertEquals(82.5, s.weightKg, 0.0)
        assertTrue(s.alternativeStatusSymbols)
    }

    @Test fun `version 3 backup without alternativeStatusSymbols key uses the default`() {
        // The field was added within format 3 as an OPTIONAL key (no version bump).
        // A format-3 backup written before it existed simply omits the key and must
        // fall back to the canonical default (now true) rather than failing to parse.
        val settingsWithoutKey =
            """{"themeMode":"NIGHT","dayChangeHour":6,"dayChangeMinute":30,""" +
                """"dailyLimitGrams":24.0,"weeklyLimitGrams":120.0,"maxDrinkDaysPerWeek":3,""" +
                """"statsFromDate":"2024-01-15","biometricEnabled":true,"allowScreenshots":true,""" +
                """"language":"de","weightKg":82.5}"""
        val json = buildBackupJson(version = 3, settings = settingsWithoutKey)
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals(AppSettings().alternativeStatusSymbols, s.alternativeStatusSymbols)
    }

    @Test fun `alternativeStatusSymbols false in backup is preserved`() {
        // An explicit false must survive the round-trip (not be masked by the default).
        val json = buildBackupJson(version = 3, settings = settingsJson(alternativeStatusSymbols = false))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals(false, s.alternativeStatusSymbols)
    }

    @Test fun `out-of-range numeric settings are clamped to the setter ranges`() {
        val json = buildBackupJson(
            version = 3,
            settings = settingsJson(
                dayChangeHour = 99,
                dayChangeMinute = 99,
                dailyLimitGrams = 9_999.0,
                weeklyLimitGrams = 99_999.0,
                maxDrinkDaysPerWeek = 99,
                weightKg = 9_999.0,
            ),
        )
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals(23, s.dayChangeHour)
        assertEquals(59, s.dayChangeMinute)
        assertEquals(500.0, s.dailyLimitGrams, 0.0)
        assertEquals(3_500.0, s.weeklyLimitGrams, 0.0)
        assertEquals(7, s.maxDrinkDaysPerWeek)
        assertEquals(500.0, s.weightKg, 0.0)
    }

    @Test fun `unknown theme falls back to SYSTEM`() {
        val json = buildBackupJson(version = 3, settings = settingsJson(themeMode = "TWILIGHT"))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals(ThemeMode.SYSTEM, s.themeMode)
    }

    @Test fun `weight zero stays the unset sentinel`() {
        val json = buildBackupJson(version = 3, settings = settingsJson(weightKg = 0.0))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals(0.0, s.weightKg, 0.0)
    }

    @Test fun `non-finite weight degrades to unset`() {
        val settings = """{"weightKg":1e309}"""
        val json = buildBackupJson(version = 3, settings = settings)
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals(0.0, s.weightKg, 0.0)
    }

    @Test fun `blank language stays the follow-system sentinel`() {
        val json = buildBackupJson(version = 3, settings = settingsJson(language = ""))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals("", s.language)
    }

    /**
     * An unsupported language tag degrades to the "" (follow system) sentinel
     * (v0.81.0 QA fix): the picker only ever stores tags from SupportedLocales,
     * so anything else must be a hand-edited or foreign file — accepting it
     * verbatim used to persist an arbitrary tag and even apply it via
     * AppCompatDelegate on a REPLACE restore.
     */
    @Test fun `unsupported language degrades to follow-system`() {
        val json = buildBackupJson(version = 3, settings = settingsJson(language = "xx-XX"))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals("", s.language)
    }

    /**
     * A supported tag written with non-canonical CASING is accepted and comes
     * back in the registry's canonical spelling — the case-insensitive lookup
     * restores exactly the value SupportedLocales (and the picker) uses.
     */
    @Test fun `language tag casing is canonicalised against SupportedLocales`() {
        val json = buildBackupJson(version = 3, settings = settingsJson(language = "PT-br"))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals("pt-BR", s.language)
    }

    @Test fun `non-canonical statsFromDate degrades to empty`() {
        val json = buildBackupJson(version = 3, settings = settingsJson(statsFromDate = "2024-02-31"))
        val s = requireNotNull(BackupManager.parseBackupJson(json).settings)
        assertEquals("", s.statsFromDate)
    }

    @Test fun `malformed settings block never aborts the drink and entry import`() {
        val settings = """{"dayChangeHour":"lots","weightKg":"heavy","themeMode":42}"""
        val json = buildBackupJson(
            version = 3,
            drinks = listOf(drinkJson(name = "Stout")),
            entries = listOf(entryJson(drinkName = "Stout")),
            settings = settings,
        )
        val result = BackupManager.parseBackupJson(json)
        assertNull("A bad settings block must not fail the whole import", result.error)
        assertEquals("Stout", result.drinks.first().name)
        val s = requireNotNull(result.settings)
        assertEquals(ThemeMode.SYSTEM, s.themeMode)
        assertEquals(4, s.dayChangeHour) // AppSettings default
        assertEquals(0.0, s.weightKg, 0.0)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun assertReadError(result: BackupManager.ImportResult) {
        assertNotNull("Expected an error", result.error)
        assertTrue(
            "Expected ReadError but got ${result.error}",
            result.error is ImportError.ReadError,
        )
    }

    private fun buildBackupJson(
        version: Int = 2,
        drinks: List<String> = emptyList(),
        entries: List<String> = emptyList(),
        settings: String? = null,
    ): String {
        val drinksArr = drinks.joinToString(",", "[", "]")
        val entriesArr = entries.joinToString(",", "[", "]")
        val settingsPart = if (settings != null) ""","settings":$settings""" else ""
        return """{"version":$version,"drinks":$drinksArr,"entries":$entriesArr$settingsPart}"""
    }

    /**
     * Builds a valid `"settings"` object string for a format-3 backup.
     *
     * Every field defaults to a distinctive, in-range value so a round-trip test
     * can assert that each one survived the parse. Individual tests override a
     * single field to exercise a clamp, an enum fallback or a sentinel.
     */
    private fun settingsJson(
        themeMode: String = "NIGHT",
        dayChangeHour: Int = 6,
        dayChangeMinute: Int = 30,
        dailyLimitGrams: Double = 24.0,
        weeklyLimitGrams: Double = 120.0,
        maxDrinkDaysPerWeek: Int = 3,
        statsFromDate: String = "2024-01-15",
        biometricEnabled: Boolean = true,
        allowScreenshots: Boolean = true,
        language: String = "de",
        weightKg: Double = 82.5,
        alternativeStatusSymbols: Boolean = true,
    ) = """{"themeMode":"$themeMode","dayChangeHour":$dayChangeHour,"dayChangeMinute":$dayChangeMinute,""" +
        """"dailyLimitGrams":$dailyLimitGrams,"weeklyLimitGrams":$weeklyLimitGrams,""" +
        """"maxDrinkDaysPerWeek":$maxDrinkDaysPerWeek,"statsFromDate":"$statsFromDate",""" +
        """"biometricEnabled":$biometricEnabled,"allowScreenshots":$allowScreenshots,""" +
        """"language":"$language","weightKg":$weightKg,"alternativeStatusSymbols":$alternativeStatusSymbols}"""

    private fun drinkJson(
        id: Long = 1,
        name: String = "Beer",
        volumeMl: Int = 500,
        alcoholPercent: Double = 5.0,
        isPreset: Boolean = false,
        isFavorite: Boolean = false,
        category: String = "BEER",
    ) = """{"id":$id,"name":"$name","volumeMl":$volumeMl,"alcoholPercent":$alcoholPercent,"isPreset":$isPreset,"isFavorite":$isFavorite,"category":"$category"}"""

    private fun entryJson(
        id: Long = 1,
        drinkId: Long = 1,
        drinkName: String = "Beer",
        volumeMl: Int = 500,
        alcoholPercent: Double = 5.0,
        gramsAlcohol: Double = 19.73,
        timestampMillis: Long = 1_700_000_000_000L,
        logicalDate: String = "2023-11-14",
        note: String = "",
    ) = """{"id":$id,"drinkId":$drinkId,"drinkName":"$drinkName","volumeMl":$volumeMl,"alcoholPercent":$alcoholPercent,"gramsAlcohol":$gramsAlcohol,"timestampMillis":$timestampMillis,"logicalDate":"$logicalDate","note":"$note"}"""
}
