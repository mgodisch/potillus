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
// PdfTemplatePlaceholderTest.kt — template ⇄ builder placeholder sync guard
// =============================================================================
//
// WHAT THIS TEST GUARDS AGAINST
//   The PDF report is assembled in two halves that must agree on a shared set of
//   names:
//     • assets/report_template.html USES placeholders, written as {{NAME}} tokens
//       and as repeat blocks whose row markup contains more {{NAME}} tokens.
//     • PdfReportBuilder.kt INITIALISES those names, either as document-level
//       scalars (scalars["NAME"] = …) or as per-row map entries ("NAME" to …,
//       including the KPI_* keys produced by the private kpi() helper).
//
//   If the template uses a placeholder the builder never fills, SimpleTemplate
//   leaves it in the output verbatim, so a raw "{{SOMETHING}}" appears in the
//   printed PDF. That is easy to miss until a user reports it. This test fails the
//   build the moment a placeholder is used without being initialised — e.g. after
//   renaming a key on only one side.
//
// HOW IT WORKS (pure JVM, no Android runtime — mirrors LocaleSyncTest)
//   1. Read the template, strip HTML comments (so the documentation block and the
//      inventory comment cannot contribute phantom tokens), and collect every
//      {{NAME}} token actually used in live markup.
//   2. Read the builder's Kotlin SOURCE (not its compiled output, which would need
//      a Context and string resources) and collect every name it initialises:
//        • scalars["NAME"]      → document-level scalar
//        • "NAME" to …          → repeat-row key (and the kpi() helper's keys)
//   3. Assert: every template token is in the initialised set. (The reverse — an
//      initialised-but-unused key — is reported as an informational message only;
//      a spare scalar is harmless, an unfilled placeholder is not.)
//
// FILE-PATH STRATEGY
//   Paths are relative to the Gradle unit-test working directory (the app/ module
//   root), exactly like LocaleSyncTest. Override with -Dpotillus.project.dir=<app>
//   if the test is ever run from a different directory.
// =============================================================================

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class PdfTemplatePlaceholderTest {

    private companion object {
        private val MODULE_DIR: File = run {
            val override = System.getProperty("potillus.project.dir")
            if (override != null) File(override) else File(".")
        }

        // The template moved out of app/src/main/assets and up to the repository
        // root, so that the iOS report renderer reads the same file. MODULE_DIR is
        // android/app; the root is two levels above it.
        private val TEMPLATE: File = File(MODULE_DIR, "../../report/report_template.html")
        private val BUILDER: File = File(MODULE_DIR, "src/main/kotlin/de/godisch/potillus/util/PdfReportBuilder.kt")

        /** A {{NAME}} placeholder token (NAME = upper-case letters, digits, underscore). */
        private val TOKEN = Regex("""\{\{([A-Z][A-Z0-9_]*)\}\}""")

        /** HTML comment, including multi-line ones, removed before token extraction. */
        private val HTML_COMMENT = Regex("""<!--.*?-->""", RegexOption.DOT_MATCHES_ALL)

        /** A document-level scalar assignment: scalars["NAME"]. */
        private val SCALAR_KEY = Regex("""scalars\["([A-Z][A-Z0-9_]*)"\]""")

        /** A map-entry key, e.g. "M_MONTH" to … — covers all repeat-row and KPI keys. */
        private val MAP_KEY = Regex(""""([A-Z][A-Z0-9_]*)"\s+to\b""")
    }

    /** Placeholders used in the template's live markup (comments stripped first). */
    private fun templateTokens(): Set<String> {
        assertTrue("Template not found at ${TEMPLATE.absolutePath}", TEMPLATE.exists())
        val markup = HTML_COMMENT.replace(TEMPLATE.readText(), "")
        return TOKEN.findAll(markup).map { it.groupValues[1] }.toSet()
    }

    /** Placeholder names the builder initialises (scalars + every map-entry key). */
    private fun initialisedKeys(): Set<String> {
        assertTrue("Builder not found at ${BUILDER.absolutePath}", BUILDER.exists())
        val src = BUILDER.readText()
        val scalars = SCALAR_KEY.findAll(src).map { it.groupValues[1] }
        val mapKeys = MAP_KEY.findAll(src).map { it.groupValues[1] }
        return (scalars + mapKeys).toSet()
    }

    @Test
    fun `every template placeholder is initialised by the builder`() {
        val used = templateTokens()
        val initialised = initialisedKeys()
        val missing = (used - initialised).sorted()

        assertTrue(
            "These placeholders appear in report_template.html but are never " +
                "initialised in PdfReportBuilder.kt (they would print as raw " +
                "{{...}} in the PDF): $missing",
            missing.isEmpty(),
        )
    }

    @Test
    fun `template actually uses a representative sample of placeholders`() {
        // Sanity guard: if the regex or file path silently broke, templateTokens()
        // could return an empty set and the main test would pass vacuously. Assert a
        // few stable, structural placeholders are present so a broken scan is caught.
        val used = templateTokens()
        listOf("TITLE", "FOOTER1", "FOOTER2", "SECTION_DAYTIME", "H_HEIGHT_PCT").forEach { key ->
            assertTrue("Expected placeholder {{$key}} not found — template scan looks broken", key in used)
        }
    }
}
