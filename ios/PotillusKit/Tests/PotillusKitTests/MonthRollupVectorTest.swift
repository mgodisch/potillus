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

/// Drives `MonthRollup` from the shared `month-rollup.json` vectors.
///
/// The cap exists so a report over a long period still fits its sheet. The summary
/// row's average is the summed grams over the summed days; a reimplementation that
/// averages the monthly averages instead gets a different number for every period
/// whose months differ in length, which is all of them.
final class MonthRollupVectorTest: XCTestCase {

    private func vectors() throws -> MonthRollupVectors {
        try TestVectors.load("month-rollup", as: MonthRollupVectors.self)
    }

    func testTheKeptCountMatchesTheVectors() throws {
        XCTAssertEqual(try vectors().keep, MonthRollup.keep)
    }

    func testCappedMatchesTheVectors() throws {
        for testCase in try vectors().cases {
            let actual = MonthRollup.capped(testCase.months.map(\.asMonthStat))
            let expected = testCase.expected.map(\.asMonthStat)

            XCTAssertEqual(actual.count, expected.count, "\(testCase.description): row count")
            for (index, pair) in zip(expected, actual).enumerated() {
                let (want, got) = pair
                let what = "\(testCase.description): row \(index)"
                XCTAssertEqual(got.monthKey, want.monthKey, "\(what) monthKey")
                XCTAssertEqual(got.rollupFromKey, want.rollupFromKey, "\(what) rollupFromKey")
                XCTAssertEqual(got.drinkDays, want.drinkDays, "\(what) drinkDays")
                XCTAssertEqual(got.totalGrams, want.totalGrams, accuracy: 1e-6, "\(what) totalGrams")
                XCTAssertEqual(
                    got.avgPerCalendarDay, want.avgPerCalendarDay, accuracy: 1e-6, "\(what) average"
                )
                XCTAssertEqual(got.daysOverDailyLimit, want.daysOverDailyLimit, "\(what) over")
                XCTAssertEqual(got.effectiveDays, want.effectiveDays, "\(what) effectiveDays")
            }
        }
    }

    /// The table never grows past one summary plus the kept months, whatever the
    /// period. The property the cap exists for, asserted as a property rather than
    /// only through the vector's particular lengths.
    func testTheTableNeverExceedsTheKeptCountPlusOne() {
        for size in 1...40 {
            let months = (1...size).map { index in
                MonthStat(
                    monthKey: String(format: "2025-%02d", (index - 1) % 12 + 1),
                    drinkDays: 1, totalGrams: 10, avgPerCalendarDay: 1,
                    daysOverDailyLimit: 0, effectiveDays: 30
                )
            }
            XCTAssertEqual(
                MonthRollup.capped(months).count, min(size, MonthRollup.keep + 1),
                "a \(size)-month period must not print more than \(MonthRollup.keep + 1) rows"
            )
        }
    }

    /// A table that is not capped carries no summary row.
    func testAShortTableHasNoSummaryRow() {
        let month = MonthStat(
            monthKey: "2025-01", drinkDays: 1, totalGrams: 10, avgPerCalendarDay: 1,
            daysOverDailyLimit: 0, effectiveDays: 30
        )
        for row in MonthRollup.capped(Array(repeating: month, count: MonthRollup.keep + 1)) {
            XCTAssertNil(row.rollupFromKey, "no row may be a span while nothing is folded")
        }
    }
}
