/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for [SimpleTemplate], the report's HTML templating engine.
 * Pure JVM — no Android dependencies.
 */
class SimpleTemplateTest {

    @Test fun `scalar placeholder is substituted`() {
        val out = SimpleTemplate.render("<h1>{{TITLE}}</h1>", mapOf("TITLE" to "Report"))
        assertEquals("<h1>Report</h1>", out)
    }

    @Test fun `unknown placeholder is left verbatim`() {
        val out = SimpleTemplate.render("a {{MISSING}} b", emptyMap())
        assertEquals("a {{MISSING}} b", out)
    }

    @Test fun `values are html-escaped`() {
        val out = SimpleTemplate.render("{{X}}", mapOf("X" to "Beer & <Cider>"))
        assertEquals("Beer &amp; &lt;Cider&gt;", out)
    }

    @Test fun `repeat block emits one copy per row with per-row scalars`() {
        val template = "<ul><!-- repeat:ITEMS --><li>{{NAME}}</li><!-- end:ITEMS --></ul>"
        val out = SimpleTemplate.render(
            template,
            scalars = emptyMap(),
            repeats = mapOf("ITEMS" to listOf(mapOf("NAME" to "a"), mapOf("NAME" to "b")))
        )
        assertEquals("<ul><li>a</li><li>b</li></ul>", out)
    }

    @Test fun `empty repeat list collapses the block to nothing`() {
        val template = "X<!-- repeat:R -->row<!-- end:R -->Y"
        val out = SimpleTemplate.render(template, emptyMap(), mapOf("R" to emptyList()))
        assertEquals("XY", out)
    }

    @Test fun `document scalars apply after repeat expansion`() {
        val template = "<!-- repeat:R --><td>{{V}}</td><!-- end:R -->{{FOOT}}"
        val out = SimpleTemplate.render(
            template,
            scalars = mapOf("FOOT" to "end"),
            repeats = mapOf("R" to listOf(mapOf("V" to "1"), mapOf("V" to "2")))
        )
        assertEquals("<td>1</td><td>2</td>end", out)
    }

    @Test fun `multiline repeat body is supported`() {
        val template = "<!-- repeat:R -->\n  <tr>{{V}}</tr>\n<!-- end:R -->"
        val out = SimpleTemplate.render(
            template, emptyMap(),
            mapOf("R" to listOf(mapOf("V" to "x")))
        )
        assertEquals("\n  <tr>x</tr>\n", out)
    }
}
