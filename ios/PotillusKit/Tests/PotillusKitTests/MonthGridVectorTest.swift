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

/// Drives `MonthGrid` from the shared `month-grid.json` vectors — the file
/// Android's `MonthGridVectorTest.kt` feeds to `domain/MonthGrid.kt`, the Kotlin
/// twin that replaced two inline computations in the v0.86.0 review.
final class MonthGridVectorTest: XCTestCase {

    func testTheGridMatchesTheVectors() throws {
        let vectors = try TestVectors.load("month-grid", as: MonthGridVectors.self)
        for testCase in vectors.cases {
            let grid = MonthGrid(
                year: testCase.year, month: testCase.month,
                firstDayOfWeekIso: testCase.firstDayOfWeekIso
            )
            XCTAssertEqual(
                grid.leadingBlanks, testCase.expected.leadingBlanks,
                "\(testCase.description): leadingBlanks"
            )
            XCTAssertEqual(grid.days.count, testCase.expected.dayCount, "\(testCase.description): dayCount")
            XCTAssertEqual(grid.cellCount, testCase.expected.cellCount, "\(testCase.description): cellCount")
        }
    }
}

/// `month-grid.json` — the alignment of a month in a seven-column grid.
struct MonthGridVectors: Decodable {
    let cases: [Case]

    struct Case: Decodable {
        let description: String
        let year: Int
        let month: Int
        let firstDayOfWeekIso: Int
        let expected: Expected

        struct Expected: Decodable {
            let leadingBlanks: Int
            let dayCount: Int
            let cellCount: Int
        }
    }
}
