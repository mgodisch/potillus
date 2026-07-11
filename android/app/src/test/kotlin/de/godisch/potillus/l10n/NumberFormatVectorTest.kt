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

import de.godisch.potillus.domain.SharedTestVectors
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

// =============================================================================
// NumberFormatVectorTest – the numbers the report prints
// =============================================================================
//
// The same vectors drive Swift's ReportFormattingTests, where they matter far
// more: `String.format(locale, "%.1f", x)` rounds HALF UP, while C's printf —
// which Swift's `String(format:)` calls — rounds ties to even. The two disagree
// about 0.25, 2.5, 20.5 and 12.35.
//
// On this side the test is a guard rather than a fix. If a future Kotlin change
// alters how a gram figure is printed, the vectors fail here first, and the iOS
// port learns of it before the two reports drift apart.
// =============================================================================

class NumberFormatVectorTest {

    companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("report-format")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }
    }

    @Test
    fun `fmt1 and fmt0 match the shared vectors`() {
        VECTORS.getJSONArray("cases").objects().forEach { case ->
            val locale = Locale.forLanguageTag(case.getString("locale"))
            val value = case.getDouble("value")
            val label = "${case.getString("locale")} $value"

            assertEquals("one decimal, $label", case.getString("fmt1"), value.fmt1(locale))
            assertEquals("no decimals, $label", case.getString("fmt0"), value.fmt0(locale))
        }
    }

    /**
     * The four values where Java's HALF_UP parts company with C's ties-to-even.
     * Spelled out so the reason the vectors exist survives in the source, not only
     * in a JSON comment.
     */
    @Test
    fun `ties round half up`() {
        val english = Locale.forLanguageTag("en")
        assertEquals("3", 2.5.fmt0(english))
        assertEquals("21", 20.5.fmt0(english))
        assertEquals("0.3", 0.25.fmt1(english))
        assertEquals("12.4", 12.35.fmt1(english))
    }
}
