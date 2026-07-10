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

import XCTest

@testable import Potillus
import PotillusKit

/// Smoke tests for the app target.
///
/// The substantive domain tests live in the `PotillusKit` package, where they
/// run natively via `swift test` without a simulator. This target exists so the
/// app scheme has a test action (`Cmd+U`) and so app-level integration tests
/// have a home once the UI is built.
final class PotillusAppTests: XCTestCase {

    func testKitIsLinkedIntoTheApp() {
        XCTAssertFalse(PotillusKit.about().isEmpty)
    }

    // ── The app-switcher privacy cover ───────────────────────────────────────
    //
    // The cover has no arithmetic, but its VISIBILITY RULE is a truth table, and a
    // truth table can be got wrong. Secure by default (Android's stance): covered
    // whenever the app is not active, unless the user opted out.

    func testCoveredWhenBackgroundedAndScreenshotsDisallowed() {
        XCTAssertTrue(
            PrivacyCoverDecision.isCovered(isActive: false, allowScreenshots: false)
        )
    }

    func testNotCoveredWhileActive() {
        XCTAssertFalse(
            PrivacyCoverDecision.isCovered(isActive: true, allowScreenshots: false),
            "the cover must never hide the app the user is using"
        )
    }

    func testNotCoveredWhenScreenshotsAllowed() {
        XCTAssertFalse(
            PrivacyCoverDecision.isCovered(isActive: false, allowScreenshots: true)
        )
    }

    /// Allowing screenshots wins even while active — the app is simply never hidden.
    func testAllowedAndActiveIsNotCovered() {
        XCTAssertFalse(
            PrivacyCoverDecision.isCovered(isActive: true, allowScreenshots: true)
        )
    }
}
