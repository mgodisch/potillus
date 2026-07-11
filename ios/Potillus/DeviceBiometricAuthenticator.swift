// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import LocalAuthentication
import PotillusKit

// =============================================================================
// DeviceBiometricAuthenticator – the real sensor behind the lock
// =============================================================================
//
// The `LAContext` side of `BiometricAuthenticator`. It is the only file in the
// app that imports LocalAuthentication; the state machine in the kit never sees
// it, which is what lets the kit be tested without a device.
//
// POLICY: `.deviceOwnerAuthentication`, not `.deviceOwnerAuthenticationWithBiometrics`.
//   The first accepts Face ID, Touch ID, a paired Apple Watch, OR the device
//   passcode; the second is biometrics only. Android's lock is
//   `BIOMETRIC_STRONG or DEVICE_CREDENTIAL` — biometric OR passcode — so the first
//   matches it. It is also the only choice that lets a user with no enrolled
//   biometrics (passcode only) use the lock at all.
//
// A FRESH CONTEXT PER PROMPT.
//   An `LAContext` that has already evaluated successfully will pass a second
//   `evaluatePolicy` automatically, without re-checking — a documented behaviour,
//   and exactly wrong for a lock that must re-authenticate. So each `evaluate`
//   builds its own context and lets it die afterwards.
// =============================================================================

struct DeviceBiometricAuthenticator: BiometricAuthenticator {

    /// Biometrics enrolled, or a passcode set. `.deviceOwnerAuthentication` is the
    /// policy the lock actually uses, so it is the policy asked about here — asking
    /// about the biometrics-only policy would wrongly refuse a passcode-only device.
    func canEvaluate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func evaluate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: reason
            )
        } catch {
            // Every failure — cancel, fallback exhausted, lockout — is "not through".
            // The model treats them identically: the cover stays up with a retry.
            return false
        }
    }
}
