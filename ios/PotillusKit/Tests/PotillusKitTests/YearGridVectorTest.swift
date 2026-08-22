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

import XCTest

@testable import PotillusKit

/// Drives `YearGrid.isDrawn` from the shared `year-grid.json` vectors, the same
/// file Android's `YearGridVectorTest.kt` loads for `isDrawn` in
/// `ui/component/CalendarComponents.kt`.
///
/// Complements `YearGridTests`, the unit suite these boundaries were harvested
/// from. That suite asserts the rule; this one asserts that the rule is the SAME
/// rule the other platform applies. Until 0.85.0 Android's half lived inside a
/// composable and could not be reached at all.
final class YearGridVectorTest: XCTestCase {

    func testTheDrawingWindowMatchesTheVectors() throws {
        let vectors = try TestVectors.load("year-grid", as: YearGridVectors.self)

        // A file that lost its cases in an edit would let this suite pass while
        // testing nothing.
        XCTAssertEqual(
            vectors.isDrawn.count, 13,
            "the vector file must carry its cases"
        )

        for testCase in vectors.isDrawn {
            // The vectors say `null` for "no floor"; the initialiser takes the
            // empty string, which is the app-wide sentinel (`AppSettings
            // .statsFromDate`) and is what a caller actually hands over. Going
            // through the initialiser rather than building the value directly
            // keeps that conversion inside the test's reach.
            let grid = YearGrid(
                year: 2026,
                firstDayOfWeekIso: 1,
                today: testCase.today,
                statsFrom: testCase.statsFrom ?? ""
            )

            XCTAssertEqual(
                grid.isDrawn(testCase.date),
                testCase.expected,
                testCase.description
            )
        }
    }
}
