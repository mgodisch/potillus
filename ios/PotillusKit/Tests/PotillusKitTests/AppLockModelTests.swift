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

import XCTest

@testable import PotillusKit

/// A stand-in sensor: it answers however the test tells it to, and counts how many
/// times it was asked, so a test can prove a prompt did or did not happen.
private final class FakeAuthenticator: BiometricAuthenticator, @unchecked Sendable {
    var capable = true
    var willSucceed = true
    private(set) var evaluateCount = 0

    func canEvaluate() -> Bool { capable }

    func evaluate(reason: String) async -> Bool {
        evaluateCount += 1
        return willSucceed
    }
}

/// A mutable clock the test can advance at will, held in a reference type so the
/// `@Sendable` `uptime` closure can read it. The model's `uptime` parameter is
/// `@Sendable`, so it cannot capture a `@MainActor`-isolated stored property of
/// the (main-actor) test case; a small reference box sidesteps that while keeping
/// the "advance the clock after the model is built" semantics the tests rely on.
/// `@unchecked Sendable` mirrors `FakeAuthenticator` above: the test drives it
/// serially on the main actor, so there is no real concurrent access to guard.
private final class TestClock: @unchecked Sendable {
    var now: TimeInterval = 1000
}

@MainActor
final class AppLockModelTests: XCTestCase {

    private var fake: FakeAuthenticator!
    private let clock = TestClock()

    private func makeModel() -> AppLockModel {
        AppLockModel(authenticator: fake, uptime: { [clock] in clock.now })
    }

    override func setUp() {
        super.setUp()
        fake = FakeAuthenticator()
        clock.now = 1000
    }

    // ── The lock off ─────────────────────────────────────────────────────────

    func testAnUnenabledLockNeverPrompts() async {
        let model = makeModel()
        await model.onLaunch()
        model.onBackground()
        clock.now += 10_000
        await model.onForeground()

        XCTAssertEqual(model.state, .unlocked)
        XCTAssertEqual(fake.evaluateCount, 0)
    }

    // ── Launch ───────────────────────────────────────────────────────────────

    func testAColdStartBehindTheLockShowsTheCover() async {
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()

        XCTAssertEqual(model.state, .unlocked, "a successful prompt clears the cover")
        XCTAssertEqual(fake.evaluateCount, 1)
    }

    func testAFailedLaunchPromptLeavesTheCoverUp() async {
        fake.willSucceed = false
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()

        XCTAssertEqual(model.state, .locked)
    }

    // ── The background threshold ─────────────────────────────────────────────

    func testABriefBackgroundDoesNotRelock() async {
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()

        model.onBackground()
        clock.now += 29                 // under 30
        await model.onForeground()

        XCTAssertEqual(model.state, .unlocked)
        XCTAssertEqual(fake.evaluateCount, 1, "no second prompt for a brief background")
    }

    func testALongBackgroundRelocks() async {
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()

        model.onBackground()
        clock.now += 30                 // exactly the threshold
        await model.onForeground()

        XCTAssertEqual(model.state, .unlocked, "re-auth succeeded")
        XCTAssertEqual(fake.evaluateCount, 2, "a second prompt was shown")
    }

    func testAFailedReauthKeepsTheCoverUp() async {
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()

        fake.willSucceed = false
        model.onBackground()
        clock.now += 60
        await model.onForeground()

        XCTAssertEqual(model.state, .locked)
    }

    // ── Retry ────────────────────────────────────────────────────────────────

    func testRetryReopensAfterAFailure() async {
        fake.willSucceed = false
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()
        XCTAssertEqual(model.state, .locked)

        fake.willSucceed = true
        await model.retry()
        XCTAssertEqual(model.state, .unlocked)
    }

    // ── Toggling the setting ─────────────────────────────────────────────────

    func testTurningTheLockOffUnlocksAtOnce() async {
        fake.willSucceed = false
        let model = makeModel()
        model.isEnabled = true
        await model.onLaunch()
        XCTAssertEqual(model.state, .locked)

        model.isEnabled = false
        XCTAssertEqual(model.state, .unlocked, "disabling the lock clears the cover")
    }

    func testDeviceCapabilityIsReported() {
        let model = makeModel()
        fake.capable = false
        XCTAssertFalse(model.deviceCanAuthenticate())
        fake.capable = true
        XCTAssertTrue(model.deviceCanAuthenticate())
    }

    // ── Manual lock (overflow menu "Lock app") ───────────────────────────────

    func testLockNowLocksAndPromptsWhenEnabled() async {
        fake.willSucceed = false  // keep the cover up so the lock is observable
        let model = makeModel()
        model.isEnabled = true
        await model.lockNow()

        XCTAssertEqual(model.state, .locked)
        XCTAssertEqual(fake.evaluateCount, 1, "manual lock prompts at once")
    }

    func testLockNowLocksEvenWithAutoLockOff() async {
        fake.willSucceed = false  // keep the cover up so the lock is observable
        let model = makeModel()  // isEnabled defaults to false
        await model.lockNow()

        XCTAssertEqual(model.state, .locked, "manual lock does not need auto-lock armed")
        XCTAssertEqual(fake.evaluateCount, 1, "manual lock prompts at once")
    }

    func testLockNowIsANoOpWithoutAnAuthenticator() async {
        fake.capable = false
        let model = makeModel()
        await model.lockNow()

        XCTAssertEqual(model.state, .unlocked, "no cover with nothing to dismiss it")
        XCTAssertEqual(fake.evaluateCount, 0)
    }

    func testAManualLockCanBeUnlockedWithAutoLockOff() async {
        let model = makeModel()  // isEnabled defaults to false
        fake.willSucceed = false
        await model.lockNow()
        XCTAssertEqual(model.state, .locked)

        // The retry path must clear the cover even though auto-lock is off, or the
        // manual lock would strand the user.
        fake.willSucceed = true
        await model.retry()
        XCTAssertEqual(model.state, .unlocked)
    }
}
