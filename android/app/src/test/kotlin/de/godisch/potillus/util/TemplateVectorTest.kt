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

import de.godisch.potillus.domain.SharedTestVectors
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// =============================================================================
// TemplateVectorTest – SimpleTemplate against the shared golden vectors
// =============================================================================
//
// The same file, test-vectors/template-render.json, drives Swift's TemplateTests.
// Both engines fill report/report_template.html, so a difference between them is
// a difference between the two PDFs. This test is where such a difference stops.
//
// The vectors encode CURRENT behaviour, bugs included. Changing one means
// changing both platforms, deliberately, in the same commit.
// =============================================================================

class TemplateVectorTest {

    companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("template-render")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        /** Reads a JSON object of strings into a Kotlin map. */
        fun JSONObject.stringMap(): Map<String, String> =
            keys().asSequence().associateWith { getString(it) }

        /** Reads `{"NAME": [ {..row..}, … ]}` into the shape `render` expects. */
        fun JSONObject.repeats(): Map<String, List<Map<String, String>>> =
            keys().asSequence().associateWith { name ->
                getJSONArray(name).objects().map { it.stringMap() }.toList()
            }
    }

    @Test
    fun `render matches the shared vectors`() {
        VECTORS.getJSONArray("render").objects().forEach { case ->
            val actual = SimpleTemplate.render(
                template = case.getString("template"),
                scalars = case.getJSONObject("scalars").stringMap(),
                repeats = case.getJSONObject("repeats").repeats(),
            )
            assertEquals(
                "render: ${case.getString("description")}",
                case.getString("expected"),
                actual,
            )
        }
    }

    /**
     * A vector file that lost its cases would let both platforms pass while
     * checking nothing. Guard the count, not merely the contents.
     */
    @Test
    fun `the vector file is not empty`() {
        assertTrue(VECTORS.getJSONArray("render").length() >= 20)
    }
}
