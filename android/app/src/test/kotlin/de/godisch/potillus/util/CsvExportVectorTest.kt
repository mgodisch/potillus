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
// CsvExportVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts the JVM implementation against `test-vectors/csv-export.json`, the
// same file the iOS Swift suite loads. Complements — does not replace —
// CsvExporterTest.kt and CsvExporterBuildTest.kt, the authoritative unit suites
// the vectors were harvested from.
//
// WHY THE DEFAULT TIME ZONE IS SET HERE
//   `buildCsv` reads `ZoneId.systemDefault()` for the HH:mm column, so its
//   output depends on the machine running the test. A shared vector cannot
//   assert a clock time under that condition. The test therefore pins the
//   default zone to the one the vector names, and restores it afterwards. (The
//   Swift port takes the zone as a parameter instead; same behaviour in the app,
//   testable without a global.)
// =============================================================================

import de.godisch.potillus.domain.SharedTestVectors
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.TimeZone

class CsvExportVectorTest {

    private companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("csv-export")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }
    }

    private val originalZone: TimeZone = TimeZone.getDefault()

    @After
    fun restoreDefaultTimeZone() {
        TimeZone.setDefault(originalZone)
    }

    // ── escapeField ──────────────────────────────────────────────────────────

    @Test
    fun `escapeField matches the shared vectors`() {
        VECTORS.getJSONArray("escapeField").objects().forEach { case ->
            assertEquals(
                "escapeField: ${case.getString("description")}",
                case.getString("expected"),
                CsvExporter.escapeField(case.getString("input")),
            )
        }
    }

    // ── buildCsv ─────────────────────────────────────────────────────────────

    @Test
    fun `buildCsv matches the shared vectors`() {
        VECTORS.getJSONArray("buildCsv").objects().forEach { case ->
            TimeZone.setDefault(TimeZone.getTimeZone(case.getString("zoneId")))

            val actual = CsvExporter.buildCsv(
                headerCells = case.getJSONArray("headers").strings(),
                entries = case.entries(),
                drinks = case.drinks(),
            )
            assertEquals(
                "buildCsv: ${case.getString("description")}",
                case.getString("expected"),
                actual,
            )
        }
    }

    private fun JSONObject.entries(): List<ConsumptionEntry> =
        getJSONArray("entries").objects().map { obj ->
            ConsumptionEntry(
                drinkId = obj.getLong("drinkId"),
                drinkName = obj.getString("drinkName"),
                volumeMl = obj.getInt("volumeMl"),
                alcoholPercent = obj.getDouble("alcoholPercent"),
                gramsAlcohol = obj.getDouble("gramsAlcohol"),
                timestampMillis = obj.getLong("timestampMillis"),
                logicalDate = obj.getString("logicalDate"),
                note = obj.getString("note"),
            )
        }.toList()

    /**
     * The vector drinks carry only the fields buildCsv reads (id, category); the
     * remaining ones are filled with harmless placeholders.
     */
    private fun JSONObject.drinks(): List<DrinkDefinition> =
        getJSONArray("drinks").objects().map { obj ->
            DrinkDefinition(
                id = obj.getLong("id"),
                name = "",
                volumeMl = 0,
                alcoholPercent = 0.0,
                category = runCatching { DrinkCategory.valueOf(obj.getString("category")) }
                    .getOrDefault(DrinkCategory.OTHER),
            )
        }.toList()
}
