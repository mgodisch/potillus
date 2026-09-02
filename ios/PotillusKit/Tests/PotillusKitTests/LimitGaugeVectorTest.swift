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

/// Drives `LimitGauge` from the shared `limit-gauge.json` vectors — the file
/// Android's `LimitGaugeVectorTest.kt` feeds to its new `domain/LimitGauge.kt`,
/// the twin that replaced the rules inline in `LimitBar` and `DrinkDaysBar`.
/// `LimitGaugeTests` next door reasons about the rules; this file only checks
/// that both ports give one answer.
final class LimitGaugeVectorTest: XCTestCase {

    func testTheGramBarMatchesTheVectors() throws {
        let vectors = try TestVectors.load("limit-gauge", as: LimitGaugeVectors.self)
        for testCase in vectors.grams {
            XCTAssertEqual(
                LimitGauge.fillFraction(totalGrams: testCase.totalGrams, limitGrams: testCase.limitGrams),
                testCase.fill, accuracy: 1e-6, "\(testCase.description): fill"
            )
            XCTAssertEqual(
                LimitGauge.emphasis(totalGrams: testCase.totalGrams, limitGrams: testCase.limitGrams).rawValue,
                testCase.emphasis, "\(testCase.description): emphasis"
            )
        }
    }

    func testTheDrinkDayBarMatchesTheVectors() throws {
        let vectors = try TestVectors.load("limit-gauge", as: LimitGaugeVectors.self)
        for testCase in vectors.drinkDays {
            XCTAssertEqual(
                LimitGauge.drinkDaysFillFraction(drinkDays: testCase.drinkDays, maxDrinkDays: testCase.maxDrinkDays),
                testCase.fill, accuracy: 1e-6, "\(testCase.description): fill"
            )
            XCTAssertEqual(
                LimitGauge.drinkDaysEmphasis(
                    drinkDays: testCase.drinkDays, maxDrinkDays: testCase.maxDrinkDays,
                    todayIsDrinkDay: testCase.todayIsDrinkDay
                ).rawValue,
                testCase.emphasis, "\(testCase.description): emphasis"
            )
        }
    }
}

/// `limit-gauge.json` — fill and emphasis of the two Today-screen bars.
struct LimitGaugeVectors: Decodable {
    let grams: [GramCase]
    let drinkDays: [DrinkDayCase]

    struct GramCase: Decodable {
        let description: String
        let totalGrams: Double
        let limitGrams: Double
        let fill: Double
        /// `Emphasis.rawValue`: CALM, WARNING or DANGER.
        let emphasis: String
    }

    struct DrinkDayCase: Decodable {
        let description: String
        let drinkDays: Int
        let maxDrinkDays: Int
        let todayIsDrinkDay: Bool
        let fill: Double
        let emphasis: String
    }
}
