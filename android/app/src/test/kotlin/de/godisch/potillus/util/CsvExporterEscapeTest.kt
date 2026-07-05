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

import de.godisch.potillus.domain.model.ConsumptionEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [CsvExporter]'s pure escaping logic: CSV formula-injection
 * neutralisation and RFC 4180 quoting. These paths are security-relevant (a
 * malicious drink name or note must not become an executable spreadsheet
 * formula) and are fully testable on the JVM without Android.
 */
class CsvExporterEscapeTest {

    @Test fun `formula trigger characters are neutralised with a leading apostrophe`() {
        for (payload in listOf("=SUM(A1)", "+1", "-1", "@cmd", "\tx", "\rx")) {
            assertTrue(
                "payload '$payload' must be neutralised",
                CsvExporter.escapeField(payload).contains("'")
            )
        }
    }

    @Test fun `plain text is returned unchanged`() {
        assertEquals("hello", CsvExporter.escapeField("hello"))
    }

    @Test fun `a comma triggers RFC 4180 quoting`() {
        assertEquals("\"a,b\"", CsvExporter.escapeField("a,b"))
    }

    @Test fun `an embedded double quote is doubled and wrapped`() {
        assertEquals("\"a\"\"b\"", CsvExporter.escapeField("a\"b"))
    }

    @Test fun `a newline triggers quoting`() {
        assertEquals("\"a\nb\"", CsvExporter.escapeField("a\nb"))
    }

    @Test fun `a formula payload containing a comma is both neutralised and quoted`() {
        assertEquals("\"'=a,b\"", CsvExporter.escapeField("=a,b"))
    }

    @Test fun `buildCsv falls back to OTHER category for an unknown drink id and ends with CRLF`() {
        val entry = ConsumptionEntry(
            drinkId = 99,
            drinkName = "Whisky, neat",
            volumeMl = 40,
            alcoholPercent = 40.0,
            gramsAlcohol = 12.6,
            timestampMillis = 1_700_000_000_000L,
            logicalDate = "2026-01-01",
            note = "=danger"
        )
        val header = listOf("d", "t", "drink", "cat", "v", "a", "g", "n")
        val csv = CsvExporter.buildCsv(header, listOf(entry), emptyList())

        assertTrue("must end with CRLF", csv.endsWith("\r\n"))
        assertTrue("unknown drink id falls back to OTHER", csv.contains("OTHER"))
        // The comma in the drink name must be quoted, the formula note neutralised.
        assertTrue("comma field must be quoted", csv.contains("\"Whisky, neat\""))
        assertTrue("formula note must be neutralised", csv.contains("'=danger"))
    }
}
