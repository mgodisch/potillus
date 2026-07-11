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

import Foundation

// =============================================================================
// AppLock – the biometric gate, decided without a device
// =============================================================================
//
// Android locks the app behind a biometric prompt (strong biometric OR device
// credential). Unlock lasts the process session; after the app has been in the
// background longer than a threshold, it re-authenticates on return. The
// threshold is measured with `elapsedRealtime`, which keeps counting in deep
// sleep and ignores wall-clock changes, so an overnight lock holds.
//
// This file is the part of that with no UIKit and no LocalAuthentication in it:
// the state machine and the one arithmetic decision — has enough background time
// passed to require another prompt? Everything that needs a screen, a sensor, or
// a run loop lives in the app shell (BiometricAuthenticator, AppLockController).
//
// ON THE MONOTONIC CLOCK
//   The re-auth window is measured against a MONOTONIC source, never the wall
//   clock. `Clock` in this kit reads `Date`, which a time-zone change or an NTP
//   correction can move backwards; a lock timer built on it could be defeated by
//   changing the device date, or could fire early after a correction. The shell
//   supplies `ProcessInfo.processInfo.systemUptime`, the iOS counterpart to
//   Android's `elapsedRealtime`. This type never reads a clock itself; it is
//   handed two uptime readings and subtracts them.
// =============================================================================

/// Performs a biometric or device-credential check.
///
/// A protocol so the state machine can be tested without a sensor. The real
/// implementation wraps `LAContext` in the app shell; a fake stands in for it in
/// the tests. `canEvaluate` is separate from `evaluate` because the app asks the
/// first when the user tries to ENABLE the lock — refusing to arm a lock the
/// device cannot satisfy is what keeps someone from locking themselves out.
public protocol BiometricAuthenticator: Sendable {

    /// Whether the device can authenticate at all — biometrics enrolled, or a
    /// passcode set. Checked before the lock is switched on.
    func canEvaluate() -> Bool

    /// Prompts, and reports whether the user got through. A cancel or a failure is
    /// `false`; there is no third outcome the caller acts on differently.
    func evaluate(reason: String) async -> Bool
}

/// Where the gate stands right now.
public enum AppLockState: Equatable, Sendable {
    /// The lock is off, or the session is authenticated and fresh.
    case unlocked
    /// A prompt is on screen.
    case authenticating
    /// The cover is up and the app is waiting for a successful prompt.
    case locked
}

public enum AppLock {

    /// Re-authenticate after this many seconds in the background.
    ///
    /// 30 seconds, the value Android uses and a common default for health and
    /// finance apps: long enough to survive a pocket-lock or a glance at a
    /// notification, short enough to deter casual snooping.
    public static let reauthAfterSeconds: TimeInterval = 30

    /// Whether returning to the foreground now requires another prompt.
    ///
    /// - Parameters:
    ///   - backgroundedAtUptime: the monotonic uptime recorded when the app last
    ///     went to the background, or `nil` if it never did this session.
    ///   - nowUptime: the monotonic uptime on return.
    /// - Returns: `true` when the gap meets or exceeds the threshold.
    ///
    /// Two uptime readings, one subtraction, no clock. A `nil` background time
    /// means the app has not been backgrounded since it unlocked, so nothing has
    /// expired. A negative gap — which a monotonic source should never produce —
    /// is treated as "no time passed" rather than trusted, because the only way to
    /// get one is a bug or a tampered reading, and neither should unlock anything.
    public static func requiresReauth(
        backgroundedAtUptime: TimeInterval?,
        nowUptime: TimeInterval
    ) -> Bool {
        guard let backgrounded = backgroundedAtUptime else { return false }
        let elapsed = nowUptime - backgrounded
        guard elapsed >= 0 else { return false }
        return elapsed >= reauthAfterSeconds
    }
}
