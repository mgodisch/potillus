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

/// `DrinkCapacity` is a thin snapshot whose `status(forServing:)` forwards its
/// six fields to `AlcoholCalculator.trafficLight`. These tests lock that
/// forwarding: the calculator itself is covered by the shared vectors, so the
/// risk here is a mis-wired field (a daily/weekly swap, a dropped drink-day
/// gate), which the calculator's own tests cannot see.
final class DrinkCapacityTests: XCTestCase {

    /// The snapshot's answer equals the calculator's, called with the same six
    /// figures, across a spread of budgets and serving sizes.
    func testStatusAgreesWithTheCalculator() {
        let servings = [0.0, 8.0, 16.0, 24.0]
        for today in stride(from: 0.0, through: 40.0, by: 10.0) {
            for weekly in stride(from: 0.0, through: 120.0, by: 30.0) {
                for days in 0...5 {
                    let capacity = DrinkCapacity(
                        todayGrams: today,
                        dailyLimitGrams: 24.0,
                        weeklyTotalGrams: weekly,
                        weeklyLimitGrams: 120.0,
                        drinkDaysThisWeek: days,
                        maxDrinkDaysPerWeek: 5
                    )
                    for serving in servings {
                        XCTAssertEqual(
                            capacity.status(forServing: serving),
                            AlcoholCalculator.trafficLight(
                                gramsPerDrink: serving,
                                todayGrams: today,
                                dailyLimitGrams: 24.0,
                                weeklyTotalGrams: weekly,
                                weeklyLimitGrams: 120.0,
                                drinkDaysThisWeek: days,
                                maxDrinkDaysPerWeek: 5
                            ),
                            "serving=\(serving) today=\(today) weekly=\(weekly) days=\(days)"
                        )
                    }
                }
            }
        }
    }

    /// The daily and weekly budgets are NOT interchangeable: a serving that fits
    /// the daily budget many times over but exhausts the weekly one is yellow, and
    /// swapping the two fields would wrongly read green. This pins the field order.
    func testDailyAndWeeklyAreNotTransposed() {
        // Daily budget: 100 g free → 12 servings of 8 g fit.
        // Weekly budget: 8 g free → exactly one serving fits → the binding limit.
        let capacity = DrinkCapacity(
            todayGrams: 0,
            dailyLimitGrams: 100,
            weeklyTotalGrams: 112,
            weeklyLimitGrams: 120,
            drinkDaysThisWeek: 0,
            maxDrinkDaysPerWeek: 5
        )
        XCTAssertEqual(capacity.status(forServing: 8), .yellow)
    }

    /// The drink-day gate is carried through: at the allowance, with today not yet
    /// a drink day, any real serving is red however much gram budget remains.
    func testDrinkDayGateIsCarriedThrough() {
        let capacity = DrinkCapacity(
            todayGrams: 0,
            dailyLimitGrams: 100,
            weeklyTotalGrams: 0,
            weeklyLimitGrams: 500,
            drinkDaysThisWeek: 5,
            maxDrinkDaysPerWeek: 5
        )
        XCTAssertEqual(capacity.status(forServing: 8), .red)
    }

    /// An alcohol-free serving never spends budget and never trips the gate.
    func testZeroGramServingIsAlwaysGreen() {
        let capacity = DrinkCapacity(
            todayGrams: 200,
            dailyLimitGrams: 24,
            weeklyTotalGrams: 500,
            weeklyLimitGrams: 120,
            drinkDaysThisWeek: 5,
            maxDrinkDaysPerWeek: 5
        )
        XCTAssertEqual(capacity.status(forServing: 0), .green)
    }
}
