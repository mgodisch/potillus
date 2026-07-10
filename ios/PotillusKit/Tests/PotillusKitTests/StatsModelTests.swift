// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
// StatsModelTests.swift – the assembly, not the arithmetic
// =============================================================================
//
// The pieces are tested elsewhere. What must be shown here is that the model
// hands them the right inputs: the floored window, the effective period length,
// the baseline that may not exist.
// =============================================================================

@MainActor
final class StatsModelTests: XCTestCase {

    private var environment: AppEnvironment!
    private var drinkId: Int64 = 0

    /// 2026-01-15, 12:00 UTC.
    private let midJanuary: Int64 = 1_768_478_400_000
    private let utc = TimeZone(identifier: "UTC")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
        drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer)
        )
    }

    private func makeModel() -> StatsModel {
        StatsModel(
            entries: environment.entries, drinks: environment.drinks,
            preferences: environment.preferences,
            clock: FixedClock(millis: midJanuary), timeZone: utc, firstDayOfWeekIso: 1
        )
    }

    /// Noon on `date`, so the wall-clock hour is unambiguous.
    @discardableResult
    private func log(_ date: String, grams: Double, hour: Int = 12) throws -> Int64 {
        let day = try XCTUnwrap(DayResolver.parseDate(date))
        let millis = Int64(day.timeIntervalSince1970 * 1000) + Int64(hour) * 3_600_000
        return try environment.entries.add(
            ConsumptionEntry(
                drinkId: drinkId, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: grams, timestampMillis: millis, logicalDate: date
            )
        )
    }

    // ── The window reaches the repositories ──────────────────────────────────

    func testTheMonthPeriodCoversTheMonthSoFar() async throws {
        try log("2025-12-31", grams: 99.0)   // before the period
        try log("2026-01-02", grams: 10.0)
        try log("2026-01-15", grams: 20.0)   // today

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.from, "2026-01-01")
        XCTAssertEqual(model.state.to, "2026-01-15")
        XCTAssertEqual(model.state.totalGrams, 30.0, accuracy: 1e-9)
        XCTAssertNil(model.failure)
    }

    func testTheWeekPeriodCoversTheSevenDaysEndingToday() async throws {
        try log("2026-01-08", grams: 50.0)   // eight days back: outside
        try log("2026-01-09", grams: 10.0)   // seven days back: inside
        try log("2026-01-15", grams: 5.0)

        let model = makeModel()
        await model.setPeriod(.week)

        XCTAssertEqual(model.state.from, "2026-01-09")
        XCTAssertEqual(model.state.totalGrams, 15.0, accuracy: 1e-9)
    }

    // ── The averages ─────────────────────────────────────────────────────────

    /// Fifteen days into January, two of them drink days. Per day and per drink
    /// day answer different questions.
    func testTheTwoAveragesUseDifferentDivisors() async throws {
        try log("2026-01-02", grams: 30.0)
        try log("2026-01-03", grams: 30.0)

        let model = makeModel()
        await model.setPeriod(.month)

        // Today is dry and unfinished, so it does not count: 14 days.
        XCTAssertEqual(model.state.averagePerDay, 60.0 / 14.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.averagePerDrinkDay, 30.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.abstinentDays, 12)
    }

    /// Once today has a drink, it joins the period, and the divisor grows.
    func testTodayCountsOnceItIsADrinkDay() async throws {
        try log("2026-01-02", grams: 30.0)
        try log("2026-01-15", grams: 30.0)

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.averagePerDay, 60.0 / 15.0, accuracy: 1e-9)
    }

    // ── The baseline ─────────────────────────────────────────────────────────

    /// December is the whole previous month; the comparison is per day, so a
    /// half-finished January is still comparable.
    func testTheTrendComparesGramsPerDayAgainstThePreviousMonth() async throws {
        // December: 31 g over 31 days = 1.0 g/day.
        for day in 1...31 {
            try log(String(format: "2025-12-%02d", day), grams: 1.0)
        }
        // January so far: 2 g/day on each of 15 days.
        for day in 1...15 {
            try log(String(format: "2026-01-%02d", day), grams: 2.0)
        }

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertTrue(model.state.hasBaseline)
        XCTAssertEqual(model.state.averagePerDay, 2.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.trendPercent, 100.0, accuracy: 1e-9, "doubled")
        XCTAssertEqual(model.state.trend, .up)
    }

    /// A floor inside the current period removes the baseline entirely. Zero
    /// percent then means "no comparison", not "no change" — `hasBaseline` says so.
    func testAFloorInsideTheCurrentPeriodLeavesNoBaseline() async throws {
        try log("2025-12-10", grams: 100.0)
        try log("2026-01-12", grams: 10.0)
        try await environment.preferences.update { $0.statsFromDate = "2026-01-10" }

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.from, "2026-01-10", "the floor raised the start")
        XCTAssertFalse(model.state.hasBaseline)
        XCTAssertEqual(model.state.trendPercent, 0.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.trend, .flat)
        XCTAssertEqual(model.state.totalGrams, 10.0, accuracy: 1e-9, "December is excluded")
    }

    /// A floor before everything changes nothing.
    func testAFloorBeforeTheHistoryIsInert() async throws {
        try log("2026-01-02", grams: 10.0)
        try await environment.preferences.update { $0.statsFromDate = "2020-01-01" }

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.from, "2026-01-01")
        XCTAssertTrue(model.state.hasBaseline)
    }

    // ── Streaks span the history, not the period ─────────────────────────────

    /// A dry streak that began in December is still a streak in January.
    func testStreaksLookBeyondThePeriod() async throws {
        try log("2025-12-20", grams: 10.0)   // the last drink

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertGreaterThan(model.state.currentStreak, 15, "dry since 20 December")
    }

    /// The floor also cuts the streak history: drinking before it never happened.
    func testTheFloorAlsoAppliesToStreaks() async throws {
        try log("2025-12-20", grams: 10.0)
        try await environment.preferences.update { $0.statsFromDate = "2026-01-01" }

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.currentStreak, 15, "the whole floored period is dry")
    }

    // ── The chart and the aggregations are wired through ─────────────────────

    func testTheYearPeriodBucketsByMonth() async throws {
        try log("2026-01-05", grams: 10.0)

        let model = makeModel()
        await model.setPeriod(.year)

        XCTAssertEqual(model.state.chartGranularity, .monthly)
        XCTAssertFalse(model.state.chartBuckets.isEmpty)
    }

    func testTheMonthPeriodBucketsByDay() async throws {
        try log("2026-01-05", grams: 10.0)

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.chartGranularity, .daily)
        XCTAssertEqual(model.state.chartBuckets.count, 15, "one per day of the period")
    }

    func testTheAggregationsReachTheState() async throws {
        try log("2026-01-05", grams: 12.0, hour: 20)

        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.categoryBreakdown[.beer] ?? 0, 12.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.hourBucketAverages.count, 8)
        XCTAssertGreaterThan(model.state.hourBucketAverages[6], 0.0, "20:00 is bucket 6")
        XCTAssertEqual(model.state.weekdayOrder, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(model.state.weekdayAverages.count, 7)
    }

    func testAnEmptyLogProducesZerosAndNoFailure() async {
        let model = makeModel()
        await model.setPeriod(.month)

        XCTAssertEqual(model.state.totalGrams, 0.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.averagePerDay, 0.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.averagePerDrinkDay, 0.0, accuracy: 1e-9)
        XCTAssertEqual(model.state.trend, .flat)
        XCTAssertNil(model.failure)
    }
}
