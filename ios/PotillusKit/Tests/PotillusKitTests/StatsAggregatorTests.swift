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
// StatsAggregatorTests.swift
// =============================================================================
//
// These four aggregations are untested on Android, where they sit inside the view
// model. Here they are functions, and the tests state what each is FOR — which is
// how the distinction between nil and zero, or between a day and a drink, stops
// being an implementation detail.
// =============================================================================

final class StatsAggregatorTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    private func entry(
        drinkId: Int64 = 1, grams: Double, at millis: Int64, date: String = "2026-01-02"
    ) -> ConsumptionEntry {
        ConsumptionEntry(
            drinkId: drinkId, drinkName: "x", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: grams, timestampMillis: millis, logicalDate: date
        )
    }

    /// 2026-01-02, 00:00:00 UTC.
    private let midnight: Int64 = 1_767_312_000_000
    private let hour: Int64 = 3_600_000

    // ── Category breakdown ───────────────────────────────────────────────────

    func testCategoriesSumTheirEntriesGrams() {
        let drinks = [
            DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer),
            DrinkDefinition(id: 2, name: "Wine", volumeMl: 200, alcoholPercent: 13, category: .wine),
        ]
        let entries = [
            entry(drinkId: 1, grams: 19.3, at: midnight),
            entry(drinkId: 1, grams: 19.3, at: midnight),
            entry(drinkId: 2, grams: 20.5, at: midnight),
        ]

        let breakdown = StatsAggregator.categoryBreakdown(entries: entries, drinks: drinks)
        XCTAssertEqual(breakdown[.beer] ?? 0, 38.6, accuracy: 1e-9)
        XCTAssertEqual(breakdown[.wine] ?? 0, 20.5, accuracy: 1e-9)
        XCTAssertNil(breakdown[.spirits], "an empty category is not a slice")
    }

    /// The alcohol was still drunk, even if the drink has since been deleted.
    func testAnEntryWhoseDrinkIsGoneFallsToOther() {
        let breakdown = StatsAggregator.categoryBreakdown(
            entries: [entry(drinkId: 99, grams: 12.0, at: midnight)], drinks: []
        )
        XCTAssertEqual(breakdown[.other] ?? 0, 12.0, accuracy: 1e-9)
    }

    /// Zero-gram entries (alcohol-free beer) must not create an empty slice.
    func testACategoryTotallingZeroIsOmitted() {
        let drinks = [
            DrinkDefinition(id: 1, name: "Free", volumeMl: 500, alcoholPercent: 0, category: .beer)
        ]
        let breakdown = StatsAggregator.categoryBreakdown(
            entries: [entry(grams: 0.0, at: midnight)], drinks: drinks
        )
        XCTAssertTrue(breakdown.isEmpty)
    }

    // ── Time of day ──────────────────────────────────────────────────────────

    /// A drink at 01:00 counts towards the previous logical day, but it happened
    /// at one in the morning. The histogram must say so.
    func testTheHistogramBucketsByWallClockNotByLogicalDay() {
        let atOne = entry(grams: 10.0, at: midnight + hour, date: "2026-01-01")
        let hours = StatsAggregator.hourlyGrams(entries: [atOne], timeZone: utc)

        XCTAssertEqual(hours[1], 10.0, accuracy: 1e-9, "01:00, though the day is the 1st")
        XCTAssertEqual(hours.reduce(0, +), 10.0, accuracy: 1e-9)
    }

    func testTheEightBucketsCoverThreeHoursEach() {
        let entries = [
            entry(grams: 3.0, at: midnight),               // 00:00 → bucket 0
            entry(grams: 3.0, at: midnight + 2 * hour),    // 02:00 → bucket 0
            entry(grams: 6.0, at: midnight + 3 * hour),    // 03:00 → bucket 1
            entry(grams: 9.0, at: midnight + 23 * hour),   // 23:00 → bucket 7
        ]
        let buckets = StatsAggregator.hourBucketAverages(
            entries: entries, effectivePeriodDays: 1, timeZone: utc
        )
        XCTAssertEqual(buckets[0], 6.0, accuracy: 1e-9)
        XCTAssertEqual(buckets[1], 6.0, accuracy: 1e-9)
        XCTAssertEqual(buckets[7], 9.0, accuracy: 1e-9)
        XCTAssertEqual(buckets.count, 8)
    }

    /// The bars must sum to the overall average grams per day — that is why each
    /// is divided by the period's length, not by the days it appears on.
    func testTheBucketsSumToTheAveragePerDay() {
        let entries = [
            entry(grams: 20.0, at: midnight + 20 * hour),
            entry(grams: 10.0, at: midnight + 21 * hour),
        ]
        let periodDays = 7
        let buckets = StatsAggregator.hourBucketAverages(
            entries: entries, effectivePeriodDays: periodDays, timeZone: utc
        )
        let average = StatsAggregator.averagePerDay(totalGrams: 30.0, effectivePeriodDays: periodDays)

        XCTAssertEqual(buckets.reduce(0, +), average, accuracy: 1e-9)
    }

    func testAnEmptyPeriodYieldsZerosRatherThanADivisionByZero() {
        let buckets = StatsAggregator.hourBucketAverages(
            entries: [], effectivePeriodDays: 0, timeZone: utc
        )
        XCTAssertEqual(buckets, [Double](repeating: 0.0, count: 8))
    }

    /// The zone is a parameter: the same instant is 01:00 in UTC and 02:00 in
    /// Berlin, and the histogram belongs to the user's wall clock.
    func testTheZoneDecidesTheBucket() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let atOneUtc = entry(grams: 5.0, at: midnight + hour)

        XCTAssertEqual(StatsAggregator.hourlyGrams(entries: [atOneUtc], timeZone: utc)[1], 5.0)
        XCTAssertEqual(StatsAggregator.hourlyGrams(entries: [atOneUtc], timeZone: berlin)[2], 5.0)
    }

    // ── Weekday profile ──────────────────────────────────────────────────────

    func testWeekdayOrderRotatesToTheLocalesFirstDay() {
        XCTAssertEqual(StatsAggregator.weekdayOrder(firstDayOfWeekIso: 1), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(StatsAggregator.weekdayOrder(firstDayOfWeekIso: 7), [7, 1, 2, 3, 4, 5, 6])
    }

    /// It matches `MonthGrid`, which indexes its headers the same way. If these
    /// two ever disagree, the calendar and the profile label different columns.
    func testWeekdayOrderAgreesWithTheCalendarGrid() {
        for first in 1...7 {
            XCTAssertEqual(
                StatsAggregator.weekdayOrder(firstDayOfWeekIso: first),
                MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: first).weekdayOrder,
                "first day \(first)"
            )
        }
    }

    /// Averaged over DAYS, not entries: a day with six beers counts once.
    func testWeekdayAveragesAreTakenOverDays() {
        // 2026-01-01 is a Thursday, 2026-01-08 the next.
        let summaries = [
            DaySummary(date: "2026-01-01", totalGrams: 10.0, entryCount: 6),
            DaySummary(date: "2026-01-08", totalGrams: 20.0, entryCount: 1),
        ]
        let averages = StatsAggregator.weekdayAverages(summaries: summaries, firstDayOfWeekIso: 1)

        XCTAssertEqual(averages[3] ?? 0, 15.0, accuracy: 1e-9, "Thursday is column 3")
        XCTAssertEqual(averages.count, 7)
    }

    /// Nil is not zero. "No Tuesdays in this period" and "Tuesdays were dry" are
    /// different statements, and a bar chart must be able to draw both.
    func testAWeekdayWithNoDaysIsNilAndOneWithDryDaysIsZero() {
        let summaries = [
            DaySummary(date: "2026-01-01", totalGrams: 0.0, entryCount: 1)   // dry Thursday
        ]
        let averages = StatsAggregator.weekdayAverages(summaries: summaries, firstDayOfWeekIso: 1)

        XCTAssertEqual(averages[3], 0.0, "a dry Thursday averages zero")
        XCTAssertNil(averages[0], "no Mondays at all")
    }

    func testTheColumnFollowsTheLocalesFirstDay() {
        let thursday = [DaySummary(date: "2026-01-01", totalGrams: 10.0, entryCount: 1)]

        // Monday first: Thursday is column 3. Sunday first: column 4.
        XCTAssertEqual(
            StatsAggregator.weekdayAverages(summaries: thursday, firstDayOfWeekIso: 1)[3], 10.0
        )
        XCTAssertEqual(
            StatsAggregator.weekdayAverages(summaries: thursday, firstDayOfWeekIso: 7)[4], 10.0
        )
    }

    // ── Averages and trend ───────────────────────────────────────────────────

    func testAveragePerDayAndPerDrinkDayAnswerDifferentQuestions() {
        // 60 g over a 30-day month, drunk on 3 days.
        XCTAssertEqual(
            StatsAggregator.averagePerDay(totalGrams: 60.0, effectivePeriodDays: 30),
            2.0, accuracy: 1e-9
        )
        XCTAssertEqual(
            StatsAggregator.averagePerDrinkDay(totalGrams: 60.0, drinkDays: 3),
            20.0, accuracy: 1e-9
        )
    }

    func testTheAveragesGuardTheirDivisors() {
        XCTAssertEqual(StatsAggregator.averagePerDay(totalGrams: 60, effectivePeriodDays: 0), 0.0)
        XCTAssertEqual(StatsAggregator.averagePerDrinkDay(totalGrams: 60, drinkDays: 0), 0.0)
    }

    /// A rise from nothing has no meaningful percentage.
    func testTheTrendIsZeroWhenThePreviousPeriodWasDry() {
        XCTAssertEqual(
            StatsAggregator.trendPercent(currentAveragePerDay: 10, previousAveragePerDay: 0),
            0.0, accuracy: 1e-9
        )
    }

    func testTheTrendIsAPercentageOfThePreviousAverage() {
        XCTAssertEqual(
            StatsAggregator.trendPercent(currentAveragePerDay: 12, previousAveragePerDay: 10),
            20.0, accuracy: 1e-9
        )
        XCTAssertEqual(
            StatsAggregator.trendPercent(currentAveragePerDay: 5, previousAveragePerDay: 10),
            -50.0, accuracy: 1e-9
        )
    }

    /// The percentage and the arrow may disagree at the margin, and that is
    /// deliberate: `Trend.of` rounds to one decimal first, so the arrow is less
    /// twitchy than the number. Pinned, because it looks like a bug.
    func testThePercentageAndTheArrowMayDisagreeAtTheMargin() {
        let percent = StatsAggregator.trendPercent(
            currentAveragePerDay: 10.04, previousAveragePerDay: 10.00
        )
        XCTAssertEqual(percent, 0.4, accuracy: 1e-9)
        XCTAssertEqual(Trend.of(currentAvg: 10.04, prevAvg: 10.00), .flat)
    }
}
