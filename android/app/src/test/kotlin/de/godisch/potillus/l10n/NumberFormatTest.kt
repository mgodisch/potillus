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

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

/**
 * Unit tests for the locale-aware number formatters in `NumberFormat.kt`.
 *
 * The whole point of these helpers is that the decimal separator follows the
 * *passed* locale rather than [Locale.getDefault]. The tests therefore pin two
 * locales with different decimal separators (en-US → '.', de-DE → ',') and
 * assert the separator switches with the argument, independent of the JVM
 * default the tests happen to run under.
 */
class NumberFormatTest {

    @Test
    fun fmt1_usesDotForEnglishLocale() {
        assertEquals("19.6", 19.6.fmt1(Locale.US))
    }

    @Test
    fun fmt1_usesCommaForGermanLocale() {
        assertEquals("19,6", 19.6.fmt1(Locale.GERMANY))
    }

    @Test
    fun fmt0_roundsHalfUpAndDropsDecimals() {
        // 19.6 → "20" under HALF_UP; separator is irrelevant at zero decimals.
        assertEquals("20", 19.6.fmt0(Locale.US))
        assertEquals("20", 19.6.fmt0(Locale.GERMANY))
    }

    @Test
    fun fmt2_followsTheRequestedLocale() {
        assertEquals("0.42", 0.42.fmt2(Locale.US))
        assertEquals("0,42", 0.42.fmt2(Locale.GERMANY))
    }
}
