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
// DrinkValidator.kt – the rules a drink definition must satisfy
// =============================================================================
//
// WHY THIS EXISTS
//   Before v0.81.0 these rules lived in two places with two different answers:
//   [de.godisch.potillus.ui.screen.DrinksViewModel] rejected a volume outside
//   1..10_000 ml and a name longer than 100 characters, while
//   [de.godisch.potillus.ui.component.AddEditDrinkDialog] enabled its Save button
//   for any volume in 1..5000 ml and never looked at the name's length.
//
//   The consequences were small and both were bugs. No user could ever create a
//   drink larger than 5000 ml, though the domain allowed twice that. And a
//   101-character name left the Save button enabled, after which the ViewModel
//   silently threw the input away and emitted an error event — a button that
//   lied about what it would do.
//
//   One definition, consulted by both, cannot disagree with itself.
//
// THE BOUNDS
//   Volume 1..5000 ml. Five litres is already beyond any single serving; the
//   limit exists to catch a typo (50000 for 500), not to express a belief about
//   drinking vessels. This is the narrower of the two former bounds, so nothing a
//   user could previously create becomes invalid.
//
//   Alcohol 0.0..100.0 %, and finite. Zero is legitimate: alcohol-free beer is a
//   drink one wants to log. NaN and the infinities are excluded explicitly,
//   because `Double.NaN in 0.0..100.0` is false but `!(NaN > 100.0)` is true, and
//   a range check alone would let a NaN through some phrasings.
//
//   Name non-blank after trimming, at most 100 characters after trimming. The
//   trim is applied before both checks, so "   " is blank rather than length 3,
//   and a name that only exceeds the limit through trailing spaces is accepted.
// =============================================================================

/**
 * Validates the three user-supplied fields of a [de.godisch.potillus.domain.model.DrinkDefinition].
 *
 * Used by the ViewModel to reject a bad write and by the dialog to disable its
 * Save button, so the two cannot drift apart.
 */
object DrinkValidator {

    /** Longest accepted drink name, measured after trimming. */
    const val MAX_NAME_LENGTH = 100

    /** Accepted serving size in millilitres. */
    val VOLUME_ML_RANGE = 1..5_000

    /** Accepted alcohol content in percent by volume. */
    val ALCOHOL_PERCENT_RANGE = 0.0..100.0

    /** Which field a [Violation] refers to. */
    enum class Field { NAME, VOLUME_ML, ALCOHOL_PERCENT }

    /** Why a field was rejected. */
    enum class Reason { BLANK, TOO_LONG, OUT_OF_RANGE, NOT_FINITE }

    /** A single rejected field. Only the first violation found is reported. */
    data class Violation(val field: Field, val reason: Reason)

    /**
     * The first rule [name], [volumeMl] and [alcoholPercent] break, or `null` when
     * the definition is acceptable.
     *
     * The checks run in field order — name, volume, alcohol — so the message the
     * user sees points at the first field they would fix, reading top to bottom.
     *
     * @param name Raw input; trimmed before checking.
     * @param volumeMl Serving size in millilitres.
     * @param alcoholPercent Alcohol content, percent by volume.
     */
    fun validate(name: String, volumeMl: Int, alcoholPercent: Double): Violation? {
        val trimmed = name.trim()

        if (trimmed.isEmpty()) return Violation(Field.NAME, Reason.BLANK)
        if (trimmed.length > MAX_NAME_LENGTH) return Violation(Field.NAME, Reason.TOO_LONG)
        if (volumeMl !in VOLUME_ML_RANGE) return Violation(Field.VOLUME_ML, Reason.OUT_OF_RANGE)

        // Explicitly before the range check: a NaN compares false against every
        // bound, so a range test alone cannot be trusted to reject it.
        if (!alcoholPercent.isFinite()) return Violation(Field.ALCOHOL_PERCENT, Reason.NOT_FINITE)
        if (alcoholPercent !in ALCOHOL_PERCENT_RANGE) {
            return Violation(Field.ALCOHOL_PERCENT, Reason.OUT_OF_RANGE)
        }

        return null
    }

    /** Whether the three fields form an acceptable drink definition. */
    fun isValid(name: String, volumeMl: Int, alcoholPercent: Double): Boolean =
        validate(name, volumeMl, alcoholPercent) == null
}
