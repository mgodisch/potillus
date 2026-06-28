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
 * =============================================================================
 */
package de.godisch.potillus

// =============================================================================
// PotillusAppHeuristicTest.kt — device-transfer decision (pure JVM)
// =============================================================================
//
// These tests exercise the pure decision function PotillusApp.shouldWarnDeviceTransfer,
// extracted for testability. It is side-effect-free boolean logic over two flags,
// so it needs no Android Context and no Application instance and runs in the fast
// JVM unit-test executor (./gradlew :app:test).
//
// WHAT IT GUARDS
//   The warning must fire ONLY for a real device transfer in which the Keystore
//   key did not migrate: a sealed passphrase envelope is present (restored from
//   backup) but cannot be decrypted. It must NOT fire on a genuine first install
//   (no envelope at all) — the previous install-age/default-values heuristic did,
//   producing a spurious "Settings not restored?" on every fresh install. These
//   tests lock in the truth table so that regression cannot return.
//   The two input flags are produced at runtime by AppDatabase.hasSealedPassphrase
//   and AppDatabase.canOpenSealedPassphrase.
// =============================================================================

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PotillusAppHeuristicTest {

    @Test
    fun `warns when an envelope is present but cannot be decrypted`() {
        // Device transfer: SharedPreferences envelope restored, Keystore key gone.
        assertTrue(
            PotillusApp.shouldWarnDeviceTransfer(
                sealedEnvelopePresent = true, passphraseDecryptable = false
            )
        )
    }

    @Test
    fun `does not warn on a genuine first install (no envelope)`() {
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                sealedEnvelopePresent = false, passphraseDecryptable = false
            )
        )
    }

    @Test
    fun `does not warn in the normal case (envelope present and decryptable)`() {
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                sealedEnvelopePresent = true, passphraseDecryptable = true
            )
        )
    }

    @Test
    fun `does not warn for the impossible absent-but-decryptable state`() {
        // Cannot occur in practice (nothing to decrypt when absent), but the pure
        // function must still be safe: absence dominates.
        assertFalse(
            PotillusApp.shouldWarnDeviceTransfer(
                sealedEnvelopePresent = false, passphraseDecryptable = true
            )
        )
    }
}
