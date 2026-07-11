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

/// Drives `AppLock.requiresReauth` from the shared `app-lock.json` vectors, so the
/// re-auth threshold is the same arithmetic the Android side can adopt.
final class AppLockVectorTest: XCTestCase {

    func testRequiresReauthMatchesTheVectors() throws {
        let vectors = try TestVectors.load("app-lock", as: AppLockVectors.self)

        // The constant is carried in the file so a change on one platform surfaces
        // as a mismatch on the other rather than passing silently.
        XCTAssertEqual(
            AppLock.reauthAfterSeconds, vectors.thresholdSeconds,
            "the Swift threshold and the vector threshold have drifted apart"
        )

        for testCase in vectors.requiresReauth {
            XCTAssertEqual(
                AppLock.requiresReauth(
                    backgroundedAtUptime: testCase.backgroundedAt,
                    nowUptime: testCase.now
                ),
                testCase.expected,
                testCase.description
            )
        }
    }
}
