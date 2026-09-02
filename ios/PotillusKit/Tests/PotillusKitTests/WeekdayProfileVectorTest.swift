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

/// Drives `StatsAggregator.weekdayAverages` and `weekdayOrder` from the shared
/// `weekday-profile.json` vectors — the file Android's `WeekdayProfileVectorTest.kt`
/// feeds to `domain/WeekdayProfile.kt`. The Kotlin twin had no test at all before
/// the v0.86.0 review; `StatsAggregatorTests` covers the same ground for this side,
/// but only this file makes the two ports answer one question sheet.
final class WeekdayProfileVectorTest: XCTestCase {

    func testOrderMatchesTheVectors() throws {
        let vectors = try TestVectors.load("weekday-profile", as: WeekdayProfileVectors.self)
        for testCase in vectors.order {
            XCTAssertEqual(
                StatsAggregator.weekdayOrder(firstDayOfWeekIso: testCase.firstDayOfWeekIso),
                testCase.expected,
                "order for first day \(testCase.firstDayOfWeekIso)"
            )
        }
    }

    func testAveragesMatchTheVectors() throws {
        let vectors = try TestVectors.load("weekday-profile", as: WeekdayProfileVectors.self)
        for testCase in vectors.averages {
            let actual = StatsAggregator.weekdayAverages(
                summaries: testCase.daySummaries(),
                from: testCase.from, to: testCase.to,
                firstDayOfWeekIso: testCase.firstDayOfWeekIso
            )
            XCTAssertEqual(actual.count, testCase.expected.count, "\(testCase.description): column count")
            for (column, expected) in testCase.expected.enumerated() {
                switch (expected, actual[column]) {
                case (nil, nil):
                    break
                case let (expected?, value?):
                    XCTAssertEqual(value, expected, accuracy: 1e-9, "\(testCase.description): column \(column)")
                default:
                    XCTFail(
                        "\(testCase.description): column \(column) expected "
                            + "\(String(describing: expected)), got \(String(describing: actual[column]))"
                    )
                }
            }
        }
    }
}

/// `weekday-profile.json` — the seven-column weekday chart.
struct WeekdayProfileVectors: Decodable {
    let order: [OrderCase]
    let averages: [AveragesCase]

    struct OrderCase: Decodable {
        let firstDayOfWeekIso: Int
        let expected: [Int]
    }

    struct AveragesCase: Decodable {
        let description: String
        /// Positional `[isoDate, grams]` pairs, as in chart-bucketing.json.
        let summaries: [[DayField]]
        let from: String
        let to: String
        let firstDayOfWeekIso: Int
        /// `null` marks a weekday the range does not contain.
        let expected: [Double?]

        enum DayField: Decodable {
            case date(String)
            case grams(Double)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .date(string)
                } else {
                    self = .grams(try container.decode(Double.self))
                }
            }
        }

        func daySummaries() -> [DaySummary] {
            summaries.compactMap { pair in
                guard pair.count == 2,
                      case let .date(date) = pair[0],
                      case let .grams(grams) = pair[1]
                else { return nil }
                return DaySummary(date: date, totalGrams: grams)
            }
        }
    }
}
