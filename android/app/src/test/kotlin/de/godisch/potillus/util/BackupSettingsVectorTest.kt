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
// BackupSettingsVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts the JVM settings sanitiser against `test-vectors/backup-settings.json`,
// the same file the iOS Swift suite loads.
//
// The vectors go through the real `parseBackupJson`, which is already
// `internal` + @VisibleForTesting, so this needs no change to production
// visibility. That also means the test exercises the whole restore path — the
// reader's defaulting AND the clamping — exactly as iOS does.
//
// The `localeTags` array in the vector file is GENERATED from
// l10n/SupportedLocales.kt. Asserting it here closes the loop: if a translator
// adds a language and the vector is not regenerated, this test fails before the
// Swift one can silently degrade a restored `language` to "follow the system".
// =============================================================================

import de.godisch.potillus.domain.SharedTestVectors
import de.godisch.potillus.domain.model.ThemeMode
import de.godisch.potillus.l10n.SupportedLocales
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class BackupSettingsVectorTest {

    private companion object {
        const val EPS = 1e-9
        val VECTORS: JSONObject = SharedTestVectors.load("backup-settings")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }
    }

    /**
     * Wraps a raw settings object in the smallest valid format 3 backup and runs
     * it through the real reader, exactly as a restore would.
     */
    private fun sanitize(raw: JSONObject) = BackupManager.parseBackupJson(
        JSONObject()
            .put("version", 3)
            .put("exportedAt", "2026-07-09T12:00:00Z")
            .put("drinks", JSONArray())
            .put("entries", JSONArray())
            .put("settings", raw)
            .toString(),
    ).settings

    @Test
    fun `settings sanitiser matches the shared vectors`() {
        VECTORS.getJSONArray("sanitize").objects().forEach { case ->
            val label = case.getString("description")
            val actual = sanitize(case.getJSONObject("input"))
            assertNotNull("a format 3 file must carry settings: $label", actual)
            requireNotNull(actual)

            val want = case.getJSONObject("expected")
            assertEquals("themeMode: $label", ThemeMode.valueOf(want.getString("themeMode")), actual.themeMode)
            assertEquals("dayChangeHour: $label", want.getInt("dayChangeHour"), actual.dayChangeHour)
            assertEquals("dayChangeMinute: $label", want.getInt("dayChangeMinute"), actual.dayChangeMinute)
            assertEquals(
                "dailyLimitGrams: $label",
                want.getDouble("dailyLimitGrams"),
                actual.dailyLimitGrams,
                EPS,
            )
            assertEquals(
                "weeklyLimitGrams: $label",
                want.getDouble("weeklyLimitGrams"),
                actual.weeklyLimitGrams,
                EPS,
            )
            assertEquals(
                "maxDrinkDaysPerWeek: $label",
                want.getInt("maxDrinkDaysPerWeek"),
                actual.maxDrinkDaysPerWeek,
            )
            assertEquals("statsFromDate: $label", want.getString("statsFromDate"), actual.statsFromDate)
            assertEquals(
                "biometricEnabled: $label",
                want.getBoolean("biometricEnabled"),
                actual.biometricEnabled,
            )
            assertEquals(
                "allowScreenshots: $label",
                want.getBoolean("allowScreenshots"),
                actual.allowScreenshots,
            )
            assertEquals(
                "alternativeStatusSymbols: $label",
                want.getBoolean("alternativeStatusSymbols"),
                actual.alternativeStatusSymbols,
            )
            assertEquals("language: $label", want.getString("language"), actual.language)
            assertEquals("weightKg: $label", want.getDouble("weightKg"), actual.weightKg, EPS)
        }
    }

    /**
     * The vector's tag list is generated from SupportedLocales.kt; drift here
     * means the generator was not re-run after a translation was added.
     */
    @Test
    fun `locale catalogue matches the shared vectors`() {
        assertEquals(
            VECTORS.getJSONArray("localeTags").strings(),
            SupportedLocales.ALL.map { it.tag },
        )
    }
}
