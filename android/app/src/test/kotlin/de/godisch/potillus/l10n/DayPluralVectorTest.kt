/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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
package de.godisch.potillus.l10n

// =============================================================================
// DayPluralVectorTest.kt – Android's <plurals name="days"> against the vector
// =============================================================================
//
// `test-vectors/plural-days.json` carries the report's day counts in every
// shipping language. The iOS suite has always asserted its catalogue against
// it (`DayPluralVectorTest.swift`); this side did not, so the vector was a copy
// of `strings.xml` taken on one day, and an edited Android plural would have
// left iOS on the old wording with nothing to say so. `check-l10n-parity.py`
// skips plurals on purpose. This test makes the vector the bridge: each
// `<item quantity="…">` of every locale, with the count filled in, must equal
// the vector's text for that category.
//
// What is NOT tested here is which CLDR category Android picks for a count —
// that is the platform's, and the vector's `category` field is iOS's business.
// =============================================================================

import de.godisch.potillus.domain.SharedTestVectors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class DayPluralVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("plural-days")

        /** The app module's resource root, resolved like LocaleSyncTest does. */
        val RES_DIR: File = run {
            val override = System.getProperty("potillus.project.dir")
            if (override != null) File(override, "src/main/res") else File("src/main/res")
        }

        /** Vector tag → resource directory; the three that are not a plain suffix. */
        val RES_QUALIFIER = mapOf("en" to "", "pt-BR" to "-pt-rBR", "zh-Hans" to "-zh-rCN", "zh-Hant" to "-zh-rTW")

        fun stringsFile(tag: String): File =
            File(RES_DIR, "values${RES_QUALIFIER[tag] ?: "-$tag"}/strings.xml")

        /** `quantity` → item text of `<plurals name="days">`, with Android's escapes undone. */
        fun daysPlural(file: File): Map<String, String> {
            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
            val plurals = doc.getElementsByTagName("plurals")
            val node = (0 until plurals.length).map { plurals.item(it) as Element }
                .firstOrNull { it.getAttribute("name") == "days" }
                ?: error("${file.path}: no <plurals name=\"days\">")
            val items = node.getElementsByTagName("item")
            return (0 until items.length).map { items.item(it) as Element }
                .associate { it.getAttribute("quantity") to it.textContent.replace("\\'", "'") }
        }
    }

    @Test
    fun `every locale's days plural matches the shared vectors`() {
        val cases = VECTORS.getJSONObject("cases")
        val tags = cases.keys().asSequence().toList()
        assertTrue("the vector should cover every shipping language", tags.size >= 21)
        tags.forEach { tag ->
            val file = stringsFile(tag)
            assertTrue("$tag: ${file.path} missing", file.isFile)
            val items = daysPlural(file)
            val list = cases.getJSONArray(tag)
            for (i in 0 until list.length()) {
                val case = list.getJSONObject(i)
                val category = case.getString("category")
                val template = items[category]
                    ?: error("$tag: strings.xml has no <item quantity=\"$category\"> but the vector expects one")
                val rendered = template.replace("%1\$d", case.getInt("count").toString())
                    .replace("%d", case.getInt("count").toString())
                assertEquals("$tag, count ${case.getInt("count")} ($category)", case.getString("expected"), rendered)
            }
        }
    }
}
