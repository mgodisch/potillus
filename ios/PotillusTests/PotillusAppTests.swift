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

    // ── About screen ─────────────────────────────────────────────────────────
    //
    // COPYING.md requires the GRDB license to appear in the about screen verbatim.
    // These guard the text against a well-meaning edit that would quietly break the
    // one license obligation the app carries.

    func testGrdbLicenseCarriesTheCopyrightLine() {
        XCTAssertTrue(AppInfo.grdbLicense.hasPrefix("Copyright (C) 2015-2025 Gwendal Roué"))
    }

    func testGrdbLicenseCarriesThePermissionGrant() {
        XCTAssertTrue(
            AppInfo.grdbLicense.contains("Permission is hereby granted, free of charge")
        )
    }

    func testGrdbLicenseCarriesTheWarrantyDisclaimer() {
        XCTAssertTrue(AppInfo.grdbLicense.contains(#"THE SOFTWARE IS PROVIDED "AS IS""#))
        XCTAssertTrue(AppInfo.grdbLicense.contains("DEALINGS IN THE SOFTWARE."))
    }

    /// The line continuations that fold the license into source must not leave
    /// double spaces or broken words: the reproduced text has to read as the original.
    func testGrdbLicenseHasNoBrokenJoins() {
        XCTAssertFalse(AppInfo.grdbLicense.contains("  "))
    }

    /// The About screen renders the notice paragraph by paragraph so it can space
    /// them like its own prose. That must not cost a single character: what is
    /// reproduced has to be the license, not a rendering of it.
    func testGrdbLicenseParagraphsRejoinToTheLicense() {
        XCTAssertEqual(
            AppInfo.grdbLicenseParagraphs.joined(separator: "\n\n"),
            AppInfo.grdbLicense
        )
    }

    func testGrdbLicenseSplitsIntoItsFourParagraphs() {
        let paragraphs = AppInfo.grdbLicenseParagraphs
        XCTAssertEqual(paragraphs.count, 4)
        XCTAssertTrue(paragraphs[0].hasPrefix("Copyright (C)"), "the copyright line stands alone")
        XCTAssertTrue(paragraphs.allSatisfy { !$0.isEmpty }, "no empty paragraph to render")
        // The About screen's ForEach identifies them by their own text. Two equal
        // paragraphs would collapse into one row and quietly drop a piece of the
        // notice we are obliged to reproduce.
        XCTAssertEqual(Set(paragraphs).count, paragraphs.count, "each paragraph is its own text")
    }

    /// The version strips any build suffix, as the report footer does.
    func testVersionStripsBuildSuffix() {
        // AppInfo.version reads the bundle; in the test bundle it is well-formed.
        // The transformation itself is what matters: nothing after a hyphen.
        XCTAssertFalse(AppInfo.version.contains("-"))
    }

    func testAppNameIsTheLatinTitle() {
        XCTAssertEqual(AppInfo.name, "Libellus Potionis")
    }
}
