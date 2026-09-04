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

/// Drives `StatsAggregator.categoryBreakdown`, `hourlyGrams` and
/// `hourBucketAverages` from the shared `stats-aggregator.json` vectors — the
/// file Android's `StatsAggregatorVectorTest.kt` feeds to its new
/// `domain/StatsAggregator.kt`. Every vector entry carries `utcOffsetSeconds`,
/// which is now the only thing that decides an hour: the reader's zone is not a
/// parameter any more.
final class StatsAggregatorVectorTest: XCTestCase {

    func testTheThreeAggregationsMatchTheVectors() throws {
        let vectors = try TestVectors.load("stats-aggregator", as: StatsAggregatorVectors.self)
        for testCase in vectors.cases {
            let drinks = testCase.drinks.map { pair -> DrinkDefinition in
                DrinkDefinition(
                    id: pair.id, name: "drink \(pair.id)", volumeMl: 100, alcoholPercent: 5.0,
                    category: DrinkCategory.from(stored: pair.category)
                )
            }
            let entries = testCase.entries.map { entry -> ConsumptionEntry in
                ConsumptionEntry(
                    drinkId: entry.drinkId, drinkName: "drink \(entry.drinkId)", volumeMl: 100,
                    alcoholPercent: 5.0, gramsAlcohol: entry.gramsAlcohol,
                    timestampMillis: entry.timestampMillis, logicalDate: "2026-08-15",
                    utcOffsetSeconds: entry.utcOffsetSeconds
                )
            }

            let breakdown = StatsAggregator.categoryBreakdown(entries: entries, drinks: drinks)
            XCTAssertEqual(
                Set(breakdown.keys.map(\.rawValue)), Set(testCase.expected.categoryBreakdown.keys),
                "\(testCase.description): categories"
            )
            for (category, grams) in breakdown {
                XCTAssertEqual(
                    grams, testCase.expected.categoryBreakdown[category.rawValue] ?? -1, accuracy: 1e-9,
                    "\(testCase.description): \(category.rawValue)"
                )
            }
            assertDoubles(
                StatsAggregator.hourlyGrams(entries: entries),
                testCase.expected.hourlyGrams, "\(testCase.description): hourlyGrams"
            )
            assertDoubles(
                StatsAggregator.hourBucketAverages(
                    entries: entries, effectivePeriodDays: testCase.effectivePeriodDays
                ),
                testCase.expected.hourBucketAverages, "\(testCase.description): hourBucketAverages"
            )
        }
    }

    private func assertDoubles(_ actual: [Double], _ expected: [Double], _ message: String) {
        XCTAssertEqual(actual.count, expected.count, "\(message): size")
        for (index, value) in expected.enumerated() where index < actual.count {
            XCTAssertEqual(actual[index], value, accuracy: 1e-9, "\(message)[\(index)]")
        }
    }
}

/// `stats-aggregator.json` — the category breakdown, the 24-hour histogram and
/// the eight 3-hour buckets.
struct StatsAggregatorVectors: Decodable {
    let cases: [Case]

    struct Case: Decodable {
        let description: String
        /// Positional `[id, category]` pairs.
        let drinks: [DrinkPair]
        let entries: [Entry]
        let effectivePeriodDays: Int
        let expected: Expected
    }

    struct DrinkPair: Decodable {
        let id: Int64
        let category: String

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            id = try container.decode(Int64.self)
            category = try container.decode(String.self)
        }
    }

    struct Entry: Decodable {
        let drinkId: Int64
        let gramsAlcohol: Double
        let timestampMillis: Int64
        let utcOffsetSeconds: Int
    }

    struct Expected: Decodable {
        let categoryBreakdown: [String: Double]
        let hourlyGrams: [Double]
        let hourBucketAverages: [Double]
    }
}
