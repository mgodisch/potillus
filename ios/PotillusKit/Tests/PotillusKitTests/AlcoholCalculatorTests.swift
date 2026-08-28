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

// =============================================================================
// AlcoholCalculatorTests.swift – cross-platform parity suite
// =============================================================================
//
// Every case here is driven by `test-vectors/alcohol-calculator.json`, the same
// file the Android JVM suite loads. The Swift port cannot drift away from the
// Kotlin original without one of the two suites failing.
//
// A handful of structural tests (constants, clamping) are asserted directly,
// because they concern the API shape rather than numeric behaviour.
// =============================================================================

final class AlcoholCalculatorTests: XCTestCase {

    /// Absolute tolerance for gram and BAC comparisons, matching the Android
    /// suite's `assertEquals(expected, actual, 0.001)`.
    private static let epsilon = 0.001

    /// Loaded once for the whole suite; a failure here is fatal by design.
    private static var loadedVectors: AlcoholCalculatorVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("alcohol-calculator", as: AlcoholCalculatorVectors.self)
        } catch {
            XCTFail("Could not load shared test vectors: \(error)")
        }
    }

    private var vectors: AlcoholCalculatorVectors { Self.loadedVectors }

    // ── Constants ────────────────────────────────────────────────────────────
    //
    // The vector file restates the constants. Asserting them here catches a
    // whole class of silent divergence: if someone changes the ethanol density
    // or the binge threshold on one platform only, this fails immediately.

    func testConstantsMatchTheSharedVectors() {
        XCTAssertEqual(AlcoholCalculator.ethanolDensity, vectors.constants.ethanolDensity, accuracy: 1e-12)
        XCTAssertEqual(AlcoholCalculator.bingeThreshold, vectors.constants.bingeThreshold, accuracy: 1e-12)
        XCTAssertEqual(AlcoholCalculator.windowDays, vectors.constants.windowDays)
    }

    // ── calculateGrams ───────────────────────────────────────────────────────

    func testCalculateGramsAgainstSharedVectors() {
        for testCase in vectors.calculateGrams {
            let actual = AlcoholCalculator.calculateGrams(
                volumeMl: testCase.volumeMl,
                alcoholPercent: testCase.alcoholPercent
            )
            XCTAssertEqual(
                actual, testCase.expected, accuracy: Self.epsilon,
                "calculateGrams: \(testCase.description)"
            )
        }
    }

    /// Every gram value must carry at most one decimal place, so that what the
    /// UI shows is exactly what the limit comparison uses.
    func testCalculateGramsAlwaysRoundsToOneDecimal() {
        for testCase in vectors.calculateGrams {
            let actual = AlcoholCalculator.calculateGrams(
                volumeMl: testCase.volumeMl,
                alcoholPercent: testCase.alcoholPercent
            )
            let reRounded = (actual * 10.0).rounded() / 10.0
            XCTAssertEqual(actual, reRounded, accuracy: 1e-12, "Value has >1 decimal: \(actual)")
        }
    }

    // ── calculateBAC ─────────────────────────────────────────────────────────

    /// 2026-01-01T18:00Z, the instant the shared vectors are anchored to.
    private static let anchor: Int64 = 1_767_290_400_000

    private static func hours(_ count: Double) -> Int64 {
        Int64(count * AlcoholCalculator.millisPerHour)
    }

    func testCalculateBACAgainstSharedVectors() {
        for testCase in vectors.calculateBAC {
            let actual = AlcoholCalculator.calculateBAC(
                doses: testCase.doses.map {
                    AlcoholDose(timestampMillis: $0.timestampMillis, gramsAlcohol: $0.gramsAlcohol)
                },
                weightKg: testCase.weightKg,
                nowMillis: testCase.nowMillis
            )
            XCTAssertEqual(
                actual, testCase.expected, accuracy: Self.epsilon,
                "calculateBAC: \(testCase.description)"
            )
        }
    }

    /// The Widmark model eliminates alcohol over time, so the estimate must be
    /// monotonically non-increasing as the asking instant moves on, and never
    /// negative.
    func testCalculateBACDecaysAndNeverGoesNegative() {
        let doses = [AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 40.0)]
        var previous = Double.greatestFiniteMagnitude
        for hour in 0...12 {
            let bac = AlcoholCalculator.calculateBAC(
                doses: doses, weightKg: 75.0, nowMillis: Self.anchor + Self.hours(Double(hour))
            )
            XCTAssertGreaterThanOrEqual(bac, 0.0, "BAC must never be negative")
            XCTAssertLessThanOrEqual(bac, previous, "BAC must not rise as time passes")
            previous = bac
        }
    }

    // ── limitPercent ─────────────────────────────────────────────────────────

    func testLimitPercentAgainstSharedVectors() {
        for testCase in vectors.limitPercent {
            let actual = AlcoholCalculator.limitPercent(
                totalGrams: testCase.totalGrams,
                limitGrams: testCase.limitGrams
            )
            XCTAssertEqual(
                actual, testCase.expected, accuracy: Self.epsilon,
                "limitPercent: \(testCase.description)"
            )
        }
    }

    // ── isOverLimit ──────────────────────────────────────────────────────────
    //
    // The tolerance is the fix for a real bug: 0.1-g values summed as binary
    // doubles can drift above an exactly-met limit, and a strict `>` then reports
    // an exceedance the user cannot see.

    func testIsOverLimitAgainstSharedVectors() {
        for testCase in vectors.isOverLimit {
            let actual = AlcoholCalculator.isOverLimit(
                totalGrams: testCase.totalGrams,
                limitGrams: testCase.limitGrams
            )
            XCTAssertEqual(actual, testCase.expected, "isOverLimit: \(testCase.description)")
        }
    }

    // ── isDrinkDay ───────────────────────────────────────────────────────────
    //
    // The predicate every drink-day count, every abstinent-day count and both
    // abstinence streaks read on both platforms. A day of alcohol-free entries
    // sums to zero and must stay a dry day.

    func testIsDrinkDayAgainstSharedVectors() {
        for testCase in vectors.isDrinkDay {
            let actual = AlcoholCalculator.isDrinkDay(totalGrams: testCase.totalGrams)
            XCTAssertEqual(actual, testCase.expected, "isDrinkDay: \(testCase.description)")
        }
    }

    /// `drinkDates` is `isDrinkDay` over a list, and keeps the dates ascending
    /// however the summaries arrive — the streak calculators require that order.
    func testDrinkDatesKeepsOnlyDrinkDaysAndSortsThem() {
        let summaries = [
            DaySummary(date: "2026-03-03", totalGrams: 12.0, entryCount: 1),
            DaySummary(date: "2026-03-01", totalGrams: 0.0, entryCount: 2),
            DaySummary(date: "2026-03-02", totalGrams: 0.1, entryCount: 1)
        ]
        XCTAssertEqual(
            AlcoholCalculator.drinkDates(summaries: summaries),
            ["2026-03-02", "2026-03-03"]
        )
    }

    /// The tolerance must never be large enough to swallow a real exceedance. The
    /// smallest one representable on the 0.1 g data grid is 0.1 g.
    func testToleranceCannotAbsorbTheSmallestRealExceedance() {
        XCTAssertTrue(AlcoholCalculator.isOverLimit(totalGrams: 20.1, limitGrams: 20.0))
        XCTAssertLessThan(vectors.constants.limitEpsilon, 0.1 / 1000.0)
    }

    /// Reproduces the drift the tolerance exists for: summing these three
    /// 0.1-g-grid values yields 190.60000000000002 against a 190.6 g limit.
    func testFloatingPointDriftIsNotAnExceedance() {
        let drifted = 44.5 + 80.9 + 65.2
        XCTAssertGreaterThan(drifted, 190.6, "Precondition: the sum really does drift")
        XCTAssertFalse(AlcoholCalculator.isOverLimit(totalGrams: drifted, limitGrams: 190.6))
    }

    // ── trafficLight ─────────────────────────────────────────────────────────

    func testTrafficLightAgainstSharedVectors() {
        for testCase in vectors.trafficLight {
            let actual = AlcoholCalculator.trafficLight(
                gramsPerDrink: testCase.gramsPerDrink,
                todayGrams: testCase.todayGrams,
                dailyLimitGrams: testCase.dailyLimitGrams,
                weeklyTotalGrams: testCase.weeklyTotalGrams,
                weeklyLimitGrams: testCase.weeklyLimitGrams,
                drinkDaysThisWeek: testCase.drinkDaysThisWeek,
                maxDrinkDaysPerWeek: testCase.maxDrinkDaysPerWeek
            )
            XCTAssertEqual(actual, testCase.expected, "trafficLight: \(testCase.description)")
        }
    }

    // ── drinkDayLimitReached ─────────────────────────────────────────────────
    //
    // The drink-day gate is consumed twice per platform (traffic light and
    // drink-day bar), so the predicate itself is pinned, not only trafficLight's
    // use of it. See the predicate's documentation for the two 5/5 cases.

    func testDrinkDayLimitReachedAgainstSharedVectors() {
        for testCase in vectors.drinkDayLimitReached {
            let actual = AlcoholCalculator.drinkDayLimitReached(
                drinkDaysThisWeek: testCase.drinkDaysThisWeek,
                maxDrinkDaysPerWeek: testCase.maxDrinkDaysPerWeek,
                todayIsDrinkDay: testCase.todayIsDrinkDay
            )
            XCTAssertEqual(actual, testCase.expected, "drinkDayLimitReached: \(testCase.description)")
        }
    }

    // ── countLimitViolations ─────────────────────────────────────────────────

    func testCountLimitViolationsAgainstSharedVectors() throws {
        for testCase in vectors.countLimitViolations {
            let actual = AlcoholCalculator.countLimitViolations(
                summaries: try testCase.daySummaries(),
                dailyLimitGrams: testCase.dailyLimitGrams,
                weeklyLimitGrams: testCase.weeklyLimitGrams,
                maxDrinkDaysPerWeek: testCase.maxDrinkDaysPerWeek
            )
            let expected = testCase.expected
            XCTAssertEqual(
                actual.daysOverDailyLimit, expected.daysOverDailyLimit,
                "daysOverDailyLimit: \(testCase.description)"
            )
            XCTAssertEqual(
                actual.daysOverWeeklyLimit, expected.daysOverWeeklyLimit,
                "daysOverWeeklyLimit: \(testCase.description)"
            )
            XCTAssertEqual(
                actual.daysOverDrinkDayLimit, expected.daysOverDrinkDayLimit,
                "daysOverDrinkDayLimit: \(testCase.description)"
            )
        }
    }

    /// Summaries arrive in arbitrary order from the database, so the sliding
    /// window must sort them itself. Feeding the vectors in reverse must not
    /// change any count.
    func testCountLimitViolationsIsOrderIndependent() throws {
        for testCase in vectors.countLimitViolations {
            let summaries = try testCase.daySummaries()
            let forward = AlcoholCalculator.countLimitViolations(
                summaries: summaries,
                dailyLimitGrams: testCase.dailyLimitGrams,
                weeklyLimitGrams: testCase.weeklyLimitGrams,
                maxDrinkDaysPerWeek: testCase.maxDrinkDaysPerWeek
            )
            let reversed = AlcoholCalculator.countLimitViolations(
                summaries: summaries.reversed(),
                dailyLimitGrams: testCase.dailyLimitGrams,
                weeklyLimitGrams: testCase.weeklyLimitGrams,
                maxDrinkDaysPerWeek: testCase.maxDrinkDaysPerWeek
            )
            XCTAssertEqual(forward, reversed, "Order dependence: \(testCase.description)")
        }
    }

    // ── getLimitInfo (structural, not vector-driven) ─────────────────────────

    func testGetLimitInfoMapsSettings() {
        let settings = AppSettings(dailyLimitGrams: 25.0, weeklyLimitGrams: 120.0, maxDrinkDaysPerWeek: 4)
        let info = AlcoholCalculator.getLimitInfo(settings)
        XCTAssertEqual(info.limitGrams, 25.0, accuracy: 1e-12)
        XCTAssertEqual(info.weeklyLimitGrams, 120.0, accuracy: 1e-12)
        XCTAssertEqual(info.maxDrinkDaysPerWeek, 4)
    }

    func testGetLimitInfoClampsDrinkDaysIntoOneToSeven() {
        XCTAssertEqual(AlcoholCalculator.getLimitInfo(AppSettings(maxDrinkDaysPerWeek: 0)).maxDrinkDaysPerWeek, 1)
        XCTAssertEqual(AlcoholCalculator.getLimitInfo(AppSettings(maxDrinkDaysPerWeek: 99)).maxDrinkDaysPerWeek, 7)
    }

    // ── IsoDay (timezone trap) ───────────────────────────────────────────────
    //
    // The seven-day window must be a pure calendar-day computation. If it were
    // sensitive to the device time zone or to DST, a backup exported on Android
    // could be evaluated differently on iOS — the exact failure the shared data
    // contract must prevent.

    func testWindowArithmeticSurvivesDaylightSavingTransitions() {
        // In most of Europe, DST begins on 2026-03-29 and ends on 2026-10-25.
        // Seven days before/after must still land on the expected calendar day.
        let springForward = IsoDay.parse("2026-03-30")!
        XCTAssertEqual(IsoDay.addingDays(-6, to: springForward), IsoDay.parse("2026-03-24")!)

        let fallBack = IsoDay.parse("2026-10-26")!
        XCTAssertEqual(IsoDay.addingDays(-6, to: fallBack), IsoDay.parse("2026-10-20")!)
    }

    func testIsoDayRejectsMalformedDates() {
        XCTAssertNil(IsoDay.parse("2026-01"))
        XCTAssertNil(IsoDay.parse("not-a-date"))
        XCTAssertNil(IsoDay.parse(""))
    }
}

// =============================================================================
// The dose-by-dose properties
// =============================================================================
//
// In an extension so `type_body_length` stays inside SwiftLint's limit; these
// belong to the same suite and run with it.

extension AlcoholCalculatorTests {

    /// The point of walking dose by dose: 40 g at the anchor is eliminated well
    /// before ten hours on, so the deficit must not be carried into the second
    /// round. The
    /// lumped shorthand reported 0.25 per mille here where the second round alone
    /// stands at 0.8.
    func testCalculateBACClampsEliminationAcrossADryGap() {
        let split = [
            AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 40.0),
            AlcoholDose(timestampMillis: Self.anchor + Self.hours(10), gramsAlcohol: 40.0)
        ]
        let secondAlone = [AlcoholDose(timestampMillis: Self.anchor + Self.hours(10), gramsAlcohol: 40.0)]
        let now = Self.anchor + Self.hours(11)
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(doses: split, weightKg: 70.0, nowMillis: now),
            0.8, accuracy: Self.epsilon
        )
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(doses: split, weightKg: 70.0, nowMillis: now),
            AlcoholCalculator.calculateBAC(doses: secondAlone, weightKg: 70.0, nowMillis: now),
            accuracy: 0.0,
            "with the first dose eliminated, the estimate is the second round's"
        )
    }

    /// Without a gap the walk and the textbook shorthand agree: two doses an hour
    /// apart never let the level reach zero, so 80 / 42 - 0.15 * 2 still holds.
    func testCalculateBACMatchesTheLumpedFormWithoutAGap() {
        let doses = [
            AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 40.0),
            AlcoholDose(timestampMillis: Self.anchor + Self.hours(1), gramsAlcohol: 40.0)
        ]
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(
                doses: doses, weightKg: 70.0, nowMillis: Self.anchor + Self.hours(2)
            ),
            1.6, accuracy: Self.epsilon
        )
    }

    /// An alcohol-free drink contributes nothing and, above all, does not anchor
    /// the elimination at its own timestamp.
    func testCalculateBACIgnoresAlcoholFreeDoses() {
        let withFree = [
            AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 0.0),
            AlcoholDose(timestampMillis: Self.anchor + Self.hours(4), gramsAlcohol: 20.0)
        ]
        let alone = [AlcoholDose(timestampMillis: Self.anchor + Self.hours(4), gramsAlcohol: 20.0)]
        let now = Self.anchor + Self.hours(4)
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(doses: withFree, weightKg: 80.0, nowMillis: now),
            AlcoholCalculator.calculateBAC(doses: alone, weightKg: 80.0, nowMillis: now),
            accuracy: 0.0
        )
    }

    /// A drink entered for later in the evening has not been drunk yet.
    func testCalculateBACIgnoresDosesInTheFuture() {
        let doses = [
            AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 40.0),
            AlcoholDose(timestampMillis: Self.anchor + Self.hours(3), gramsAlcohol: 40.0)
        ]
        let now = Self.anchor + Self.hours(1)
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(doses: doses, weightKg: 75.0, nowMillis: now),
            AlcoholCalculator.calculateBAC(
                doses: [AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 40.0)],
                weightKg: 75.0, nowMillis: now
            ),
            accuracy: 0.0
        )
    }

    /// No weight on record, or no dose at all: the caller gets zero and turns it
    /// into an absent row.
    func testCalculateBACReturnsZeroWithoutWeightOrDoses() {
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(
                doses: [AlcoholDose(timestampMillis: Self.anchor, gramsAlcohol: 20.0)],
                weightKg: 0.0, nowMillis: Self.anchor
            ),
            0.0, accuracy: 0.0
        )
        XCTAssertEqual(
            AlcoholCalculator.calculateBAC(doses: [], weightKg: 80.0, nowMillis: Self.anchor),
            0.0, accuracy: 0.0
        )
    }
}
