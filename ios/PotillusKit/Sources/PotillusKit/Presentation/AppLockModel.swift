// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
import Observation

// =============================================================================
// AppLockModel – the gate's state machine
// =============================================================================
//
// Holds `AppLockState` and runs the transitions Android's MainActivity runs:
//
//   • unlock lasts the session; a successful prompt sets `.unlocked`
//   • going to the background records a monotonic timestamp
//   • returning re-locks only if `AppLock.requiresReauth` says the gap was long
//     enough — otherwise a glance at a notification does not force Face ID
//   • a cancelled or failed prompt leaves the cover up, with a way to retry
//
// It talks to the sensor through `BiometricAuthenticator`, so every path here is
// testable with a fake. The monotonic clock is injected as a closure for the same
// reason: the tests advance time by hand rather than sleeping.
//
// `@MainActor` because SwiftUI observes it and because the authenticator prompt
// must be driven from the main thread.
// =============================================================================

@MainActor
@Observable
public final class AppLockModel {

    public private(set) var state: AppLockState = .unlocked

    /// Whether the user has switched the lock on. Mirrors `AppSettings`, kept in
    /// step by the shell's settings observation.
    public var isEnabled: Bool = false {
        didSet { enabledChanged(from: oldValue) }
    }

    private let authenticator: any BiometricAuthenticator
    private let uptime: @Sendable () -> TimeInterval
    private let reason: String

    /// The monotonic reading taken when the app last went to the background, or
    /// `nil` if it has not since it unlocked.
    private var backgroundedAtUptime: TimeInterval?

    public init(
        authenticator: any BiometricAuthenticator,
        reason: String = "Unlock Libellus Potionis",
        uptime: @escaping @Sendable () -> TimeInterval
    ) {
        self.authenticator = authenticator
        self.reason = reason
        self.uptime = uptime
    }

    /// Whether the device can satisfy a lock at all. The settings screen asks this
    /// before offering the toggle, so a lock is never armed on a device with no
    /// biometrics and no passcode — which would lock the owner out for good.
    public func deviceCanAuthenticate() -> Bool {
        authenticator.canEvaluate()
    }

    // ── Lifecycle, driven by the shell's scene phase ─────────────────────────

    /// Called once when the app becomes active for the first time. Locks if the
    /// setting is on, so a cold start behind an enabled lock shows the cover.
    public func onLaunch() async {
        guard isEnabled else { return }
        state = .locked
        await authenticate()
    }

    /// The app went to the background. Record when, so the return can measure the
    /// gap. Recorded even when unlocked; the value is only consulted on return.
    public func onBackground() {
        backgroundedAtUptime = uptime()
    }

    /// The app came back. Re-lock only if enough background time passed.
    public func onForeground() async {
        guard isEnabled, state == .unlocked else {
            // Already locked or authenticating: leave it. A return while the prompt
            // is up must not start a second prompt.
            if isEnabled, state == .locked { await authenticate() }
            return
        }
        if AppLock.requiresReauth(
            backgroundedAtUptime: backgroundedAtUptime, nowUptime: uptime()
        ) {
            state = .locked
            await authenticate()
        }
    }

    /// Retry from the cover's button after a cancel or failure.
    public func retry() async {
        guard isEnabled, state == .locked else { return }
        await authenticate()
    }

    // ── The prompt ───────────────────────────────────────────────────────────

    private func authenticate() async {
        state = .authenticating
        let passed = await authenticator.evaluate(reason: reason)
        // A cancel or failure leaves the cover up. The user gets a retry, not a way
        // past: an alcohol diary behind a lock the owner asked for should not open
        // because Face ID was dismissed.
        state = passed ? .unlocked : .locked
        if passed { backgroundedAtUptime = nil }
    }

    private func enabledChanged(from wasEnabled: Bool) {
        guard wasEnabled != isEnabled else { return }
        if isEnabled {
            // Turning the lock on mid-session does not slam the cover down on the
            // screen the user is looking at; it takes effect on the next background
            // return, as on Android. Turning it off unlocks immediately.
        } else {
            state = .unlocked
            backgroundedAtUptime = nil
        }
    }
}
