/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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
// SimpleTemplate – a tiny, dependency-free string templating engine
// =============================================================================
//
// WHY DOES THIS EXIST?
//   The PDF report (see PdfReportBuilder) is authored as an HTML/CSS file in
//   app/src/main/assets/report_template.html so that its *layout* can be edited
//   by hand — column widths, fonts, spacing, section order, page breaks — WITHOUT
//   touching Kotlin code or recompiling the report logic. This engine is the glue
//   that injects the computed numbers and the localised labels into that template.
//
//   It is deliberately minimal: it is NOT a general-purpose template language
//   (no conditionals, no expressions, no nested loops). Two features are enough
//   for the report and keep the template readable for a non-programmer:
//
//     1. SCALAR PLACEHOLDERS:  {{KEY}}
//        Replaced by the matching value from the `scalars` map. Example:
//            <h1>{{TITLE}}</h1>            with scalars["TITLE"] = "Report"
//        becomes
//            <h1>Report</h1>
//
//     2. REPEAT BLOCKS:        <!-- repeat:NAME --> … <!-- end:NAME -->
//        The body between the markers is emitted once per row in
//        `repeats["NAME"]`, with the row's own scalars substituted inside it.
//        This is how the variable-length tables (monthly table, category table,
//        the trend bar chart) repeat a single, hand-editable row template:
//            <!-- repeat:MONTHS -->
//            <tr><td>{{MONTH}}</td><td>{{TOTAL}}</td></tr>
//            <!-- end:MONTHS -->
//        with repeats["MONTHS"] = listOf(
//            mapOf("MONTH" to "Jan 2026", "TOTAL" to "120.0"),
//            mapOf("MONTH" to "Feb 2026", "TOTAL" to "98.0"))
//        produces two <tr> rows. An empty list removes the block entirely, so the
//        caller can always pass every block name (with a possibly-empty list) and
//        never leave stray markers in the output.
//
// SAFETY:
//   Substituted values are HTML-escaped (& < > " ') so a category label such as
//   "Beer & Cider" cannot break the surrounding markup or inject elements. The
//   template text itself is trusted (it ships inside the APK) and is NOT escaped.
//
// UNKNOWN PLACEHOLDERS:
//   A {{KEY}} with no matching value is left verbatim in the output. This is a
//   deliberate aid for whoever edits the template: a typo'd placeholder shows up
//   literally in the generated PDF instead of silently vanishing.
// =============================================================================

object SimpleTemplate {

    /** Matches a scalar placeholder such as `{{TOTAL_GRAMS}}`. Group 1 is the key. */
    private val PLACEHOLDER = Regex("""\{\{(\w+)}}""")

    /**
     * Builds the regex for one named repeat block. [RegexOption.DOT_MATCHES_ALL]
     * lets the body span multiple lines; the lazy `(.*?)` stops at the first
     * matching `end` marker so adjacent blocks do not bleed into one another.
     */
    private fun repeatBlock(name: String): Regex =
        Regex(
            """<!--\s*repeat:${Regex.escape(name)}\s*-->(.*?)<!--\s*end:${Regex.escape(name)}\s*-->""",
            RegexOption.DOT_MATCHES_ALL
        )

    /**
     * Renders [template] by expanding every repeat block in [repeats] and then
     * substituting every scalar placeholder from [scalars].
     *
     * Order matters: repeat blocks are expanded FIRST (so per-row scalars are
     * applied inside each emitted copy of the row body), and the global [scalars]
     * pass runs LAST over the whole document. Because per-row keys are already
     * resolved during expansion, the final global pass only fills the remaining
     * document-level placeholders.
     *
     * @param template The raw template text (trusted; ships in the APK).
     * @param scalars  Document-level placeholder values, keyed by placeholder name.
     * @param repeats  Per-block row data; each row is its own scalar map. Pass an
     *                 empty list for a block that should collapse to nothing.
     * @return The fully expanded text with all known placeholders replaced.
     */
    fun render(
        template: String,
        scalars: Map<String, String>,
        repeats: Map<String, List<Map<String, String>>> = emptyMap()
    ): String {
        var out = template

        // 1) Expand repeat blocks. Each row substitutes its own scalars into the
        //    block body; the joined result replaces the whole <!-- repeat --> … block.
        for ((name, rows) in repeats) {
            out = repeatBlock(name).replace(out) { match ->
                val body = match.groupValues[1]
                rows.joinToString(separator = "") { row -> substitute(body, row) }
            }
        }

        // 2) Substitute document-level scalars over everything that remains.
        return substitute(out, scalars)
    }

    /** Replaces every `{{KEY}}` in [text] with the escaped value from [values]. */
    private fun substitute(text: String, values: Map<String, String>): String =
        PLACEHOLDER.replace(text) { match ->
            val key = match.groupValues[1]
            // Leave unknown placeholders verbatim (match.value) to surface typos.
            values[key]?.let(::escapeHtml) ?: match.value
        }

    /** Escapes the five characters that are significant in HTML text/attributes. */
    private fun escapeHtml(s: String): String = buildString(s.length) {
        for (c in s) when (c) {
            '&'  -> append("&amp;")
            '<'  -> append("&lt;")
            '>'  -> append("&gt;")
            '"'  -> append("&quot;")
            '\'' -> append("&#39;")
            else -> append(c)
        }
    }
}
