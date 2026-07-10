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
package de.godisch.potillus.domain

// =============================================================================
// DrinkValidationVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts the JVM validator against `test-vectors/drink-validation.json`, the
// same file the iOS Swift suite loads. Complements DrinkValidatorTest.kt, the
// authoritative unit suite the vectors were harvested from.
//
// The vector file's `bounds` block is GENERATED from DrinkValidator.kt. Asserting
// it here closes the loop: narrowing a bound without regenerating the vectors
// fails on this side before it can fail silently on the other.
// =============================================================================

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DrinkValidationVectorTest {

    private companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("drink-validation")

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }

        /** JSON has no NaN or infinity literals; the vectors name them instead. */
        fun JSONObject.percent(): Double = when (optString("alcoholPercentSpecial", "")) {
            "NAN" -> Double.NaN
            "POSITIVE_INFINITY" -> Double.POSITIVE_INFINITY
            "NEGATIVE_INFINITY" -> Double.NEGATIVE_INFINITY
            else -> getDouble("alcoholPercent")
        }
    }

    @Test
    fun `the validator matches the shared vectors`() {
        VECTORS.getJSONArray("validate").objects().forEach { case ->
            val label = case.getString("description")
            val actual = DrinkValidator.validate(
                case.getString("name"),
                case.getInt("volumeMl"),
                case.percent(),
            )

            val expected = case.optJSONObject("expected")
            if (expected == null) {
                assertNull("expected acceptance: $label", actual)
            } else {
                val want = DrinkValidator.Violation(
                    DrinkValidator.Field.valueOf(expected.getString("field")),
                    DrinkValidator.Reason.valueOf(expected.getString("reason")),
                )
                assertEquals("violation: $label", want, actual)
            }
        }
    }

    /**
     * The bounds in the vector file are generated from this very source. Drift
     * here means the generator was not re-run after a bound changed.
     */
    @Test
    fun `the bounds match the shared vectors`() {
        val bounds = VECTORS.getJSONObject("bounds")
        assertEquals(bounds.getInt("maxNameLength"), DrinkValidator.MAX_NAME_LENGTH)
        assertEquals(bounds.getInt("volumeMlMin"), DrinkValidator.VOLUME_ML_RANGE.first)
        assertEquals(bounds.getInt("volumeMlMax"), DrinkValidator.VOLUME_ML_RANGE.last)
        assertEquals(
            bounds.getDouble("alcoholPercentMin"),
            DrinkValidator.ALCOHOL_PERCENT_RANGE.start,
            1e-9,
        )
        assertEquals(
            bounds.getDouble("alcoholPercentMax"),
            DrinkValidator.ALCOHOL_PERCENT_RANGE.endInclusive,
            1e-9,
        )
    }

    /**
     * The two string semantics the Swift port had to be corrected to match. Stated
     * here in Kotlin's own terms, so a future change to either side is caught by
     * whichever suite runs first.
     */
    @Test
    fun `the name length counts UTF-16 code units`() {
        val fiftyOneEmoji = "\uD83C\uDF7A".repeat(51) // 🍺, one surrogate pair each
        assertEquals(102, fiftyOneEmoji.length)
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.NAME, DrinkValidator.Reason.TOO_LONG),
            DrinkValidator.validate(fiftyOneEmoji, 500, 4.9),
        )
        assertNull(DrinkValidator.validate("\uD83C\uDF7A".repeat(50), 500, 4.9))
    }

    @Test
    fun `a non-breaking space is a character, not whitespace`() {
        assertNull(DrinkValidator.validate("\u00A0", 500, 4.9))
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.NAME, DrinkValidator.Reason.BLANK),
            DrinkValidator.validate(" \t\n ", 500, 4.9),
        )
    }
}
