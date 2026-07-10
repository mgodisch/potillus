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
// PdfReportLangTest.kt — CJK glyph-orthography (document-language) guard
// =============================================================================
//
// WHAT THIS TEST GUARDS AGAINST
//   The PDF report is rendered by a WebView (Blink). Blink chooses the CJK glyph
//   ORTHOGRAPHY — Simplified vs Traditional Han, Japanese kanji, Korean hanja —
//   from the document's language. Han-unified code points are shared across
//   zh/ja/ko but prefer region-specific glyph shapes, so WITHOUT a language hint
//   Blink falls back to Simplified-Chinese forms: a Japanese, Korean or
//   Traditional-Chinese report would then show Chinese-style glyphs for those
//   shared characters (verified in the v0.79.0 QA review via `pdffonts` on the
//   committed sample reports, which embedded NotoSansCJK*SC* even for ja/ko/
//   zh-TW). The fix threads the per-app locale into the template's root element
//   as <html lang="{{REPORT_LANG}}">, filled by PdfReportBuilder.
//
//   Two things must therefore stay true, and this test pins BOTH:
//     1. INVARIANT — the template keeps the lang attribute wired to the
//        {{REPORT_LANG}} placeholder on its <html> root. (The placeholder⇄builder
//        SYNC — that PdfReportBuilder initialises REPORT_LANG — is already
//        enforced by PdfTemplatePlaceholderTest, which requires every template
//        placeholder to be initialised by the builder.)
//     2. BEHAVIOUR — SimpleTemplate.render substitutes a BCP-47 tag into that
//        attribute verbatim (no corruption, no escaping surprises), so the WebView
//        receives e.g. lang="zh-TW".
//
// PURE JVM (no Android runtime) — mirrors PdfTemplatePlaceholderTest / LocaleSyncTest:
//   the template asset is read from the source tree by relative path, and the
//   render step exercises SimpleTemplate directly (buildHtml itself needs a
//   Context and string resources and is covered by instrumented tests).
//
// FILE-PATH STRATEGY
//   Paths are relative to the Gradle unit-test working directory (the app/ module
//   root), like the sibling tests. Override with -Dpotillus.project.dir=<app>.
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class PdfReportLangTest {

    private companion object {
        private val MODULE_DIR: File = run {
            val override = System.getProperty("potillus.project.dir")
            if (override != null) File(override) else File(".")
        }

        // The template moved out of app/src/main/assets and up to the repository
        // root, so that the iOS report renderer reads the same file. MODULE_DIR is
        // android/app; the root is two levels above it.
        private val TEMPLATE: File = File(MODULE_DIR, "../../report/report_template.html")

        /**
         * The <html> opening tag with a lang attribute bound to the
         * {{REPORT_LANG}} placeholder. Tolerates attribute reordering and either
         * quote style, but requires the lang hint to be present and wired to the
         * placeholder (not hard-coded to a single language).
         */
        private val HTML_LANG_TAG =
            Regex("""<html\b[^>]*\blang\s*=\s*["']\{\{REPORT_LANG}}["'][^>]*>""", RegexOption.IGNORE_CASE)
    }

    @Test
    fun `template html root carries a lang hint wired to REPORT_LANG`() {
        assertTrue("Template not found at ${TEMPLATE.absolutePath}", TEMPLATE.exists())
        // Strip HTML comments so the documentation block that mentions the
        // placeholder cannot satisfy the check on its own — only live markup counts.
        val markup = Regex("""<!--.*?-->""", RegexOption.DOT_MATCHES_ALL).replace(TEMPLATE.readText(), "")
        assertTrue(
            "report_template.html must open its root element as " +
                "<html lang=\"{{REPORT_LANG}}\"> so the WebView selects the correct " +
                "CJK glyph orthography (Simplified/Traditional/JP/KR) for the report's " +
                "language; the lang attribute wired to {{REPORT_LANG}} was not found.",
            HTML_LANG_TAG.containsMatchIn(markup),
        )
    }

    @Test
    fun `render substitutes a BCP-47 tag into the lang attribute`() {
        // A minimal stand-in for the real template's root element. We assert the
        // engine drops the tag in unchanged for the Han-orthography-sensitive
        // locales (Traditional Chinese, Japanese, Korean) and for a Latin locale.
        val skeleton = """<html lang="{{REPORT_LANG}}"><head></head></html>"""
        for (tag in listOf("zh-TW", "zh-CN", "ja", "ko", "en-US", "de")) {
            val out = SimpleTemplate.render(skeleton, mapOf("REPORT_LANG" to tag))
            assertEquals(
                "REPORT_LANG did not render verbatim into the lang attribute for tag=$tag",
                """<html lang="$tag"><head></head></html>""",
                out,
            )
        }
    }
}
