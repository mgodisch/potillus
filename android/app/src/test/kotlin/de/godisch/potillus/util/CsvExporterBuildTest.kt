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
 *
 * UNIT TEST — CsvExporter.buildCsv
 *
 * WHY THIS FILE EXISTS (teaching note)
 *   CsvExporterTest already covers escapeField in isolation, but the full row
 *   assembly was previously untested — and that is exactly where a locale bug
 *   hid: the grams column was formatted with the default locale, so on a
 *   comma-decimal locale (de, fr, es, …) "19.6" became "19,60", whose comma split
 *   the value across two columns and corrupted the export. These tests run under
 *   Locale.GERMANY on purpose, so a regression to a locale-sensitive formatter
 *   would fail here. They also verify that a comma inside a (translator-supplied)
 *   header cell is quoted rather than adding a stray column.
 */
package de.godisch.potillus.util

import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.util.Locale

class CsvExporterBuildTest {

    /** The eight column captions, in the order [CsvExporter.buildCsv] emits them. */
    private val header = listOf(
        "date", "time", "drink", "category", "ml", "abv", "grams", "note"
    )

    private lateinit var originalLocale: Locale

    /**
     * Force a comma-decimal locale for the whole test class. This is the
     * environment under which the old `"%.2f".format(...)` would have produced a
     * comma and broken the CSV; the fix uses Locale.ROOT and must stay immune.
     */
    @Before fun setUp() {
        originalLocale = Locale.getDefault()
        Locale.setDefault(Locale.GERMANY)
    }

    @After fun tearDown() {
        Locale.setDefault(originalLocale)
    }

    private fun sampleDrink(id: Long) = DrinkDefinition(
        id = id, name = "Pilsner", volumeMl = 500, alcoholPercent = 4.9,
        category = DrinkCategory.BEER
    )

    private fun sampleEntry(drinkId: Long) = ConsumptionEntry(
        id = 1L, drinkId = drinkId, drinkName = "Pilsner", volumeMl = 500,
        alcoholPercent = 4.9, gramsAlcohol = 19.6,
        timestampMillis = 1_700_000_000_000L, logicalDate = "2026-05-29", note = ""
    )

    /** Non-empty lines (the CRLF terminator leaves a trailing empty element). */
    private fun lines(csv: String) = csv.split("\r\n").filter { it.isNotEmpty() }

    @Test fun `grams use a dot decimal separator regardless of locale`() {
        val csv  = CsvExporter.buildCsv(header, listOf(sampleEntry(10L)), listOf(sampleDrink(10L)))
        val cols = lines(csv)[1].split(",")
        // Column index 6 is "grams" (date,time,drink,category,ml,abv,grams,note).
        assertEquals("19.60", cols[6])
    }

    @Test fun `a data row has exactly eight columns under a comma-decimal locale`() {
        val csv  = CsvExporter.buildCsv(header, listOf(sampleEntry(10L)), listOf(sampleDrink(10L)))
        val cols = lines(csv)[1].split(",")
        // Would be 9 if the grams field were rendered as "19,60".
        assertEquals(8, cols.size)
    }

    @Test fun `header cell containing a comma is RFC4180-quoted`() {
        val csv = CsvExporter.buildCsv(listOf("Volume, ml"), emptyList(), emptyList())
        assertEquals("\"Volume, ml\"", lines(csv)[0])
    }

    @Test fun `output is CRLF-terminated`() {
        val csv = CsvExporter.buildCsv(header, emptyList(), emptyList())
        org.junit.Assert.assertTrue(csv.endsWith("\r\n"))
    }
}
