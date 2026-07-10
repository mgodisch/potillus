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
// DrinkValidatorTest.kt
// =============================================================================
//
// The rules the ViewModel enforces and the dialog's Save button obeys. They were
// two rule sets until v0.81.0; these tests exist so they stay one.
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DrinkValidatorTest {

    private fun violation(name: String = "Pils", volumeMl: Int = 500, percent: Double = 4.9) =
        DrinkValidator.validate(name, volumeMl, percent)

    @Test
    fun `an ordinary drink is accepted`() {
        assertNull(violation())
        assertTrue(DrinkValidator.isValid("Pils", 500, 4.9))
    }

    // ── Name ─────────────────────────────────────────────────────────────────

    @Test
    fun `a blank name is rejected`() {
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.NAME, DrinkValidator.Reason.BLANK),
            violation(name = ""),
        )
    }

    /** Whitespace only is blank, not a three-character name. */
    @Test
    fun `a whitespace-only name is blank`() {
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.NAME, DrinkValidator.Reason.BLANK),
            violation(name = "   "),
        )
    }

    @Test
    fun `a name at the length limit is accepted`() {
        assertNull(violation(name = "x".repeat(DrinkValidator.MAX_NAME_LENGTH)))
    }

    @Test
    fun `a name beyond the length limit is rejected`() {
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.NAME, DrinkValidator.Reason.TOO_LONG),
            violation(name = "x".repeat(DrinkValidator.MAX_NAME_LENGTH + 1)),
        )
    }

    /** Trailing spaces must not push an otherwise legal name over the limit. */
    @Test
    fun `the length is measured after trimming`() {
        val name = "x".repeat(DrinkValidator.MAX_NAME_LENGTH) + "   "
        assertNull(violation(name = name))
    }

    // ── Volume ───────────────────────────────────────────────────────────────

    @Test
    fun `the volume bounds are inclusive`() {
        assertNull(violation(volumeMl = 1))
        assertNull(violation(volumeMl = 5_000))
    }

    @Test
    fun `a volume outside the bounds is rejected`() {
        val expected = DrinkValidator.Violation(
            DrinkValidator.Field.VOLUME_ML,
            DrinkValidator.Reason.OUT_OF_RANGE,
        )
        assertEquals(expected, violation(volumeMl = 0))
        assertEquals(expected, violation(volumeMl = -1))
        assertEquals(expected, violation(volumeMl = 5_001))
        // The typo the bound exists to catch: 50000 for 500.
        assertEquals(expected, violation(volumeMl = 50_000))
    }

    // ── Alcohol ──────────────────────────────────────────────────────────────

    /** Alcohol-free beer is a drink one wants to log. */
    @Test
    fun `zero percent is accepted`() {
        assertNull(violation(percent = 0.0))
    }

    @Test
    fun `the alcohol bounds are inclusive`() {
        assertNull(violation(percent = 100.0))
    }

    @Test
    fun `an alcohol percentage outside the bounds is rejected`() {
        val expected = DrinkValidator.Violation(
            DrinkValidator.Field.ALCOHOL_PERCENT,
            DrinkValidator.Reason.OUT_OF_RANGE,
        )
        assertEquals(expected, violation(percent = -0.1))
        assertEquals(expected, violation(percent = 100.1))
    }

    /**
     * NaN compares false against every bound, so a range check alone cannot
     * reject it. The validator tests finiteness first, and says so.
     */
    @Test
    fun `NaN and the infinities are rejected as not finite`() {
        val expected = DrinkValidator.Violation(
            DrinkValidator.Field.ALCOHOL_PERCENT,
            DrinkValidator.Reason.NOT_FINITE,
        )
        assertEquals(expected, violation(percent = Double.NaN))
        assertEquals(expected, violation(percent = Double.POSITIVE_INFINITY))
        assertEquals(expected, violation(percent = Double.NEGATIVE_INFINITY))
        assertFalse(DrinkValidator.isValid("Pils", 500, Double.NaN))
    }

    // ── Order ────────────────────────────────────────────────────────────────

    /**
     * Only the first violation is reported, in field order, so the message points
     * at the first field the user would fix reading top to bottom.
     */
    @Test
    fun `the first violation in field order wins`() {
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.NAME, DrinkValidator.Reason.BLANK),
            DrinkValidator.validate("", 0, Double.NaN),
        )
        assertEquals(
            DrinkValidator.Violation(DrinkValidator.Field.VOLUME_ML, DrinkValidator.Reason.OUT_OF_RANGE),
            DrinkValidator.validate("Pils", 0, Double.NaN),
        )
    }
}
