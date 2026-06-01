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
package de.godisch.potillus

// =============================================================================
// PotillusAppHeuristicTest.kt — device-transfer heuristic (pure JVM)
// =============================================================================
//
// These tests exercise the pure decision function PotillusApp.shouldWarnDeviceTransfer
// extracted for testability. Because the function is side-effect-free arithmetic over a
// Long/Long/String/Double, it needs no Android Context and no Application instance,
// so it runs in the fast JVM unit-test executor (./gradlew :app:test).
//
// WHAT IT GUARDS
//   The combined condition (recent install AND empty language AND unset weight)
//   used to be evaluated AFTER applyLanguageOnFirstLaunch() had already written a
//   language, so language.isEmpty() was effectively always false and the warning
//   never fired. The fix reads the settings snapshot before that write; these tests
//   lock in the truth table so the heuristic cannot silently regress again.
// =============================================================================

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PotillusAppHeuristicTest {

    private val window = 15L * 60 * 1_000   // mirror INSTALL_RECENCY_MS (15 min)

    @Test
    fun `warns when install is recent and DataStore is at defaults`() {
        assertTrue(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = 60_000L, recencyWindowMs = window, language = "", weightKg = 0.0
            )
        )
    }

    @Test
    fun `does not warn when a language has already been chosen`() {
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = 60_000L, recencyWindowMs = window, language = "de", weightKg = 0.0
            )
        )
    }

    @Test
    fun `does not warn when a body weight has been set`() {
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = 60_000L, recencyWindowMs = window, language = "", weightKg = 72.0
            )
        )
    }

    @Test
    fun `does not warn when the install is older than the recency window`() {
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = window + 1, recencyWindowMs = window, language = "", weightKg = 0.0
            )
        )
    }

    @Test
    fun `does not warn on a negative install age (clock skew)`() {
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = -1L, recencyWindowMs = window, language = "", weightKg = 0.0
            )
        )
    }

    @Test
    fun `warns at the exact window boundary and at age zero`() {
        assertTrue(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = window, recencyWindowMs = window, language = "", weightKg = 0.0
            )
        )
        assertTrue(
            PotillusApp.shouldWarnDeviceTransfer(
                installAgeMs = 0L, recencyWindowMs = window, language = "", weightKg = 0.0
            )
        )
    }
}
