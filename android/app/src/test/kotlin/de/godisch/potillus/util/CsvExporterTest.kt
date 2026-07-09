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
 *
 * UNIT TEST — CsvExporter.escapeField
 *
 * These tests pin down the two responsibilities of [CsvExporter.escapeField]:
 *
 *   1. Formula-injection neutralisation (OWASP "CSV Injection"): any field whose
 *      first character could trigger spreadsheet formula evaluation
 *      (= + - @ TAB CR) is prefixed with a single quote (').
 *   2. RFC 4180 quoting: commas, double-quotes and line breaks (LF or CR) force
 *      the field to be wrapped in double quotes, with embedded quotes doubled.
 *
 * They run on the plain JVM (no Android Context) because escapeField is pure.
 */
package de.godisch.potillus.util

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Verifies the CSV formula-injection sanitisation logic.
 */
class CsvExporterTest {

    // ── Formula-injection neutralisation ──────────────────────────────────────

    /**
     * A leading '=' is neutralised with a single quote; because this value also
     * contains double-quotes, RFC 4180 quoting then wraps it and doubles the
     * inner quotes. Asserting the fully-escaped form documents the real output.
     */
    @Test
    fun equalsPrefixHyperlink_isNeutralisedAndQuoted() {
        assertEquals(
            "\"'=HYPERLINK(\"\"x\"\")\"",
            CsvExporter.escapeField("=HYPERLINK(\"x\")"),
        )
    }

    /** Every documented trigger character must be neutralised. */
    @Test
    fun allTriggerCharacters_areNeutralised() {
        // These contain no comma/quote/line-break, so the ONLY change is the
        // guard. (CR is also a trigger but additionally forces RFC 4180 quoting,
        // so it is asserted in carriageReturn_forcesQuoting below, not here.)
        assertEquals("'=1+1", CsvExporter.escapeField("=1+1"))
        assertEquals("'+1", CsvExporter.escapeField("+1"))
        assertEquals("'-1", CsvExporter.escapeField("-1"))
        assertEquals("'@SUM", CsvExporter.escapeField("@SUM"))
        assertEquals("'\tx", CsvExporter.escapeField("\tx"))
    }

    /** A trigger character that is NOT the first character must be left alone. */
    @Test
    fun triggerCharacterMidString_isNotNeutralised() {
        assertEquals("a=b", CsvExporter.escapeField("a=b"))
        assertEquals("1-2", CsvExporter.escapeField("1-2"))
    }

    /** An ordinary value with no special characters passes through unchanged. */
    @Test
    fun plainValue_isUnchanged() {
        assertEquals("Pilsner", CsvExporter.escapeField("Pilsner"))
    }

    /** An empty string has no first character and is returned unchanged. */
    @Test
    fun emptyValue_isUnchanged() {
        assertEquals("", CsvExporter.escapeField(""))
    }

    // ── RFC 4180 quoting ──────────────────────────────────────────────────────

    /** A comma forces RFC 4180 quoting. */
    @Test
    fun comma_isQuoted() {
        assertEquals("\"a,b\"", CsvExporter.escapeField("a,b"))
    }

    /** An embedded double-quote is doubled and the field is wrapped. */
    @Test
    fun doubleQuote_isEscapedAndQuoted() {
        assertEquals("\"say \"\"hi\"\"\"", CsvExporter.escapeField("say \"hi\""))
    }

    /** A newline forces RFC 4180 quoting. */
    @Test
    fun newline_isQuoted() {
        assertEquals("\"line1\nline2\"", CsvExporter.escapeField("line1\nline2"))
    }

    /**
     * A carriage return forces RFC 4180 quoting even without an accompanying LF.
     * A CR in the MIDDLE of a field (first char is ordinary, so no formula guard)
     * would otherwise pass through unquoted and split the record; a LEADING CR is
     * both a formula trigger and a line break, so it is guarded first and then
     * wrapped.
     */
    @Test
    fun carriageReturn_forcesQuoting() {
        assertEquals("\"a\rb\"", CsvExporter.escapeField("a\rb"))
        assertEquals("\"'\rx\"", CsvExporter.escapeField("\rx"))
    }

    // ── Composition of both steps ─────────────────────────────────────────────

    /**
     * The dangerous case: a value that is BOTH a formula AND contains a comma.
     * The guard quote is added first, then RFC 4180 quoting wraps the whole
     * value — so the result starts with `"'` and the comma is safely contained.
     */
    @Test
    fun formulaWithComma_isGuardedThenQuoted() {
        assertEquals("\"'=1,2\"", CsvExporter.escapeField("=1,2"))
    }
}
