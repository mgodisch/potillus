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
// ReportDataTests
// =============================================================================
//
// The shared vectors cover every figure that does not depend on a time zone, a
// locale or a clock — Android reads all three from the device, so a file cannot
// pin them there. The tests below cover the rest, which Swift can inject.
// =============================================================================

final class ReportDataTests: XCTestCase {

    private static var loadedVectors: ReportDataVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("report-data", as: ReportDataVectors.self)
        } catch {
            XCTFail("Could not load the shared report vectors: \(error)")
        }
    }

    private var vectors: ReportDataVectors { Self.loadedVectors }

    private static let epsilon = 1e-6

    // ── Helpers ──────────────────────────────────────────────────────────────

    private func settings(
        daily: Double, weekly: Double, drinkDays: Int, weight: Double = 80
    ) -> AppSettings {
        var value = AppSettings()
        value.dailyLimitGrams = daily
        value.weeklyLimitGrams = weekly
        value.maxDrinkDaysPerWeek = drinkDays
        value.weightKg = weight
        return value
    }

    private func entry(
        _ id: Int64, drink: Int64, date: String, grams: Double, millis: Int64 = 0
    ) -> ConsumptionEntry {
        ConsumptionEntry(
            id: id, drinkId: drink, drinkName: "x", volumeMl: 500, alcoholPercent: 5,
            gramsAlcohol: grams, timestampMillis: millis, logicalDate: date, note: ""
        )
    }

    private func drink(_ id: Int64, _ category: DrinkCategory) -> DrinkDefinition {
        DrinkDefinition(
            id: id, name: "d\(id)", volumeMl: 500, alcoholPercent: 5,
            isPreset: false, isFavorite: false, category: category
        )
    }

    // ── The shared contract ──────────────────────────────────────────────────

    func testAgainstSharedVectors() throws {
        for testCase in vectors.cases {
            let entries = testCase.entries.map {
                entry($0.id, drink: $0.drinkId, date: $0.logicalDate, grams: $0.gramsAlcohol)
            }
            let drinks = testCase.drinks.map {
                drink($0.id, DrinkCategory.from(stored: $0.category))
            }
            let data = try XCTUnwrap(
                ReportData.make(
                    entries: entries,
                    drinks: drinks,
                    settings: settings(
                        daily: testCase.dailyLimitGrams,
                        weekly: testCase.weeklyLimitGrams,
                        drinkDays: testCase.maxDrinkDaysPerWeek
                    ),
                    periodStart: testCase.periodStart,
                    periodEnd: testCase.periodEnd,
                    today: testCase.today ?? "2026-12-31",
                    timeZone: TimeZone(identifier: "UTC")!
                )
            )

            let expected = testCase.expected
            let label = testCase.description

            XCTAssertEqual(data.firstDate, expected.firstDate, label)
            XCTAssertEqual(data.lastDate, expected.lastDate, label)
            XCTAssertEqual(data.totalDays, expected.totalDays, label)
            XCTAssertEqual(data.drinkDays, expected.drinkDays, label)
            XCTAssertEqual(data.abstinentDays, expected.abstinentDays, label)
            XCTAssertEqual(data.bingeDays, expected.bingeDays, label)
            XCTAssertEqual(
                data.violations.daysOverDailyLimit, expected.daysOverDailyLimit, label
            )
            XCTAssertEqual(data.totalGrams, expected.totalGrams, accuracy: Self.epsilon, label)
            XCTAssertEqual(data.avgPerDay, expected.avgPerDay, accuracy: Self.epsilon, label)
            XCTAssertEqual(
                data.avgPerDrinkDay, expected.avgPerDrinkDay, accuracy: Self.epsilon, label
            )
            XCTAssertEqual(
                data.medianPerDay, expected.medianPerDay, accuracy: Self.epsilon, label
            )
            XCTAssertEqual(
                data.medianPerDrinkDay, expected.medianPerDrinkDay,
                accuracy: Self.epsilon, label
            )
            XCTAssertEqual(
                data.avgDrinkDaysPerMonth, expected.avgDrinkDaysPerMonth,
                accuracy: Self.epsilon, label
            )
            XCTAssertEqual(
                data.medianDrinkDaysPerMonth, expected.medianDrinkDaysPerMonth,
                accuracy: Self.epsilon, label
            )
            XCTAssertEqual(data.maxPerDay, expected.maxPerDay, accuracy: Self.epsilon, label)
            XCTAssertEqual(data.maxPer7Days, expected.maxPer7Days, accuracy: Self.epsilon, label)

            XCTAssertEqual(data.months.count, expected.months.count, label)
            for (actual, want) in zip(data.months, expected.months) {
                XCTAssertEqual(actual.monthKey, want.monthKey, label)
                XCTAssertEqual(actual.drinkDays, want.drinkDays, label)
                XCTAssertEqual(actual.daysOverDailyLimit, want.daysOverDailyLimit, label)
                XCTAssertEqual(actual.totalGrams, want.totalGrams, accuracy: Self.epsilon, label)
                XCTAssertEqual(
                    actual.avgPerCalendarDay, want.avgPerCalendarDay,
                    accuracy: Self.epsilon, label
                )
            }

            XCTAssertEqual(data.categories.count, expected.categories.count, label)
            for (actual, want) in zip(data.categories, expected.categories) {
                XCTAssertEqual(actual.categoryName, want.categoryName, label)
                XCTAssertEqual(actual.percent, want.percent, label)
                XCTAssertEqual(actual.grams, want.grams, accuracy: Self.epsilon, label)
            }
        }
    }

    func testTheVectorFileIsNotEmpty() {
        XCTAssertGreaterThanOrEqual(vectors.cases.count, 8)
    }

    // ── What the vectors cannot reach ────────────────────────────────────────

    func testAnEmptyPeriodYieldsNoReportRatherThanABlankOne() {
        XCTAssertNil(
            ReportData.make(entries: [], drinks: [], settings: settings(
                daily: 24, weekly: 168, drinkDays: 5
            ), today: "2026-03-01")
        )
    }

    /// The hour comes from the WALL CLOCK, not from the logical day.
    func testTheHourlyProfileFollowsTheGivenZone() {
        // 2026-03-02T00:30:00Z — half past midnight in UTC, half past one in Berlin.
        let millis: Int64 = 1_772_411_400_000
        let entries = [entry(1, drink: 1, date: "2026-03-01", grams: 10, millis: millis)]

        let utc = ReportData.hourlyGrams(entries: entries, timeZone: TimeZone(identifier: "UTC")!)
        let berlin = ReportData.hourlyGrams(
            entries: entries, timeZone: TimeZone(identifier: "Europe/Berlin")!
        )

        XCTAssertEqual(utc[0], 10, accuracy: Self.epsilon, "00:30 UTC lands in hour 0")
        XCTAssertEqual(berlin[1], 10, accuracy: Self.epsilon, "01:30 in Berlin lands in hour 1")
        XCTAssertEqual(utc.count, 24)
        XCTAssertEqual(utc.reduce(0, +), berlin.reduce(0, +), accuracy: Self.epsilon)
    }

    /// A day the app books to yesterday still bucketed by the clock it was drunk at.
    func testAnEntryAfterMidnightBucketsByItsRealHour() {
        let millis: Int64 = 1_772_411_400_000  // 00:30 UTC
        let hours = ReportData.hourlyGrams(
            entries: [entry(1, drink: 1, date: "2026-03-01", grams: 5, millis: millis)],
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertEqual(hours[0], 5, accuracy: Self.epsilon)
        XCTAssertEqual(hours[20], 0, accuracy: Self.epsilon)
    }

    // ── Streak anchoring: the v0.81.0 lesson ─────────────────────────────────

    /// A report over a HISTORICAL range anchors at the day after it ends.
    ///
    /// Anchored at the real today, the streak would count days outside the report —
    /// including days on which the user drank — as abstinent.
    func testAHistoricalRangeAnchorsAtItsOwnEnd() {
        XCTAssertEqual(
            ReportData.streakAnchor(periodEnd: "2026-03-31", today: "2026-06-01"),
            "2026-04-01"
        )
    }

    /// A range ending today keeps the real anchor, so report and screen agree
    /// about the day in progress.
    func testARangeEndingTodayKeepsTheRealAnchor() {
        XCTAssertEqual(
            ReportData.streakAnchor(periodEnd: "2026-06-01", today: "2026-06-01"),
            "2026-06-01"
        )
        XCTAssertEqual(ReportData.streakAnchor(periodEnd: nil, today: "2026-06-01"), "2026-06-01")
    }

    /// The bug the anchor exists to prevent: current abstinence exceeding longest.
    func testCurrentAbstinenceNeverExceedsTheLongest() throws {
        let entries = [
            entry(1, drink: 1, date: "2026-03-01", grams: 10),
            entry(2, drink: 1, date: "2026-03-10", grams: 10),
        ]
        let report = try XCTUnwrap(
            ReportData.make(
                entries: entries, drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                periodEnd: "2026-03-31", today: "2026-09-01",
                timeZone: TimeZone(identifier: "UTC")!
            )
        )
        XCTAssertLessThanOrEqual(
            report.currentAbstinence, report.longestAbstinence,
            "an ongoing streak cannot be longer than the longest one"
        )
    }

    // ── Alcohol-free days ────────────────────────────────────────────────────

    /// A day of alcohol-free entries belongs to the period but is not a drink
    /// day: abstinent, out of the drink-day divisor, and no break in a run.
    ///
    /// The day carries entries, so it has a summary row and every figure here
    /// used to read it as drinking (v0.85.0). The dry day sits inside the gap
    /// from 1 to 11 March, which the old reading split in two.
    func testADayOfAlcoholFreeEntriesIsAbstinent() throws {
        let entries = [
            entry(1, drink: 1, date: "2026-03-01", grams: 10),
            entry(2, drink: 1, date: "2026-03-06", grams: 0),
            entry(3, drink: 1, date: "2026-03-11", grams: 30),
        ]
        let report = try XCTUnwrap(
            ReportData.make(
                entries: entries, drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                periodEnd: "2026-03-11", today: "2026-03-12",
                timeZone: TimeZone(identifier: "UTC")!
            )
        )
        XCTAssertEqual(report.drinkDays, 2, "the 0.0 g day is not a drink day")
        XCTAssertEqual(report.abstinentDays, report.totalDays - report.drinkDays)
        XCTAssertEqual(report.avgPerDrinkDay, 20.0, accuracy: 0.001)
        // Nine dry days between the two drink days, not two runs of four.
        XCTAssertEqual(report.longestAbstinence, 9)
    }

    // ── The weekday profile follows the locale ───────────────────────────────

    func testWeekdayOrderStartsAtTheLocalesFirstDay() throws {
        let entries = [entry(1, drink: 1, date: "2026-03-02", grams: 10)]  // a Monday
        let monday = try XCTUnwrap(
            ReportData.make(
                entries: entries, drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                today: "2026-03-02", timeZone: TimeZone(identifier: "UTC")!,
                locale: Locale(identifier: "de_DE")
            )
        )
        let sunday = try XCTUnwrap(
            ReportData.make(
                entries: entries, drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                today: "2026-03-02", timeZone: TimeZone(identifier: "UTC")!,
                locale: Locale(identifier: "en_US")
            )
        )

        XCTAssertEqual(monday.weekdayOrder.first, 1, "Germany starts the week on Monday")
        XCTAssertEqual(sunday.weekdayOrder.first, 7, "the United States starts it on Sunday")

        // The Monday column holds the value in both, wherever it sits.
        let mondayColumn = try XCTUnwrap(monday.weekdayOrder.firstIndex(of: 1))
        let sundayColumn = try XCTUnwrap(sunday.weekdayOrder.firstIndex(of: 1))
        XCTAssertEqual(monday.weekdayAverages[mondayColumn], 10)
        XCTAssertEqual(sunday.weekdayAverages[sundayColumn], 10)
    }

    /// A weekday that never occurred is `nil`, not zero: an average of nothing is
    /// not zero, and the chart must draw the difference.
    func testAWeekdayThatNeverOccurredIsNil() throws {
        let data = try XCTUnwrap(
            ReportData.make(
                entries: [entry(1, drink: 1, date: "2026-03-02", grams: 10)],
                drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                today: "2026-03-02", timeZone: TimeZone(identifier: "UTC")!,
                locale: Locale(identifier: "de_DE")
            )
        )
        XCTAssertEqual(data.weekdayAverages.compactMap { $0 }.count, 1)
        XCTAssertEqual(data.weekdayAverages.filter { $0 == nil }.count, 6)
    }

    // ── Median and the rolling window, directly ──────────────────────────────

    func testMedianOfNothingIsZeroNotACrash() {
        XCTAssertEqual(ReportData.median([]), 0.0)
    }

    func testMedianAveragesTheMiddlePairOfAnEvenCount() {
        XCTAssertEqual(ReportData.median([1, 2, 3, 4]), 2.5, accuracy: Self.epsilon)
        XCTAssertEqual(ReportData.median([3, 1, 2]), 2.0, accuracy: Self.epsilon)
    }

    /// A period of seven days or fewer has no full window, so the total stands in.
    func testAShortPeriodUsesItsWholeTotalAsTheSevenDayPeak() {
        XCTAssertEqual(ReportData.maxRollingSevenDays([1, 2, 3]), 6.0, accuracy: Self.epsilon)
        XCTAssertEqual(
            ReportData.maxRollingSevenDays([1, 1, 1, 1, 1, 1, 1]), 7.0, accuracy: Self.epsilon
        )
    }

    func testTheWindowSlidesRatherThanSplittingThePeriod() {
        // Eight days: the best window is days 2..8.
        XCTAssertEqual(
            ReportData.maxRollingSevenDays([0, 1, 1, 1, 1, 1, 1, 1]), 7.0, accuracy: Self.epsilon
        )
    }
}

// =============================================================================
// The reporting window
// =============================================================================
//
// An extension because SwiftLint caps a type body at 250 lines and does not
// count extensions. The shared vectors pin the arithmetic of a window; these
// cover what a file cannot reach — the agreement with DayResolver.windowDays,
// and the shapes a user can still ask for that leave the window degenerate.

extension ReportDataTests {

    private func windowed(
        _ entries: [ConsumptionEntry], from: String, to: String, today: String
    ) throws -> ReportData {
        try XCTUnwrap(
            ReportData.make(
                entries: entries, drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                periodStart: from, periodEnd: to, today: today,
                timeZone: TimeZone(identifier: "UTC")!
            )
        )
    }

    /// A window is exactly as long as the Statistics screen's, day for day.
    ///
    /// The report holds the window as a pair of dates and the screen as a count,
    /// so the two could drift apart without either looking wrong alone.
    func testTotalDaysEqualsTheSharedWindowRule() throws {
        let entries = [
            entry(1, drink: 1, date: "2026-01-10", grams: 20),
            entry(2, drink: 1, date: "2026-02-05", grams: 10),
        ]
        // No entry falls on 2026-03-01, so the running day is dry throughout.
        for (from, to) in [
            ("2026-01-01", "2026-02-28"),
            ("2026-01-01", "2026-03-01"),
            ("2026-02-01", "2026-02-05"),
        ] {
            let report = try windowed(entries, from: from, to: to, today: "2026-03-01")
            XCTAssertEqual(
                report.totalDays,
                DayResolver.windowDays(
                    from: from, to: to, today: "2026-03-01", todayIsDrinkDay: false
                ),
                "\(from) … \(to)"
            )
        }
    }

    /// The running day counts once alcohol is on it and waits while it is dry.
    func testAWindowEndingTodayWaitsForTheRunningDay() throws {
        let base = [entry(1, drink: 1, date: "2026-02-01", grams: 20)]
        let dry = try windowed(base, from: "2026-02-01", to: "2026-02-06", today: "2026-02-06")
        XCTAssertEqual(dry.lastDate, "2026-02-05")
        XCTAssertEqual(dry.totalDays, 5)

        let wet = try windowed(
            base + [entry(2, drink: 1, date: "2026-02-06", grams: 8)],
            from: "2026-02-01", to: "2026-02-06", today: "2026-02-06"
        )
        XCTAssertEqual(wet.lastDate, "2026-02-06")
        XCTAssertEqual(wet.totalDays, 6)
    }

    /// "Today only", before the first drink of the day: dropping the running day
    /// would leave no days at all, and a report over nothing states nothing.
    func testAOneDayWindowOnADryTodayKeepsThatDay() throws {
        let report = try windowed(
            [entry(1, drink: 1, date: "2026-02-05", grams: 0)],
            from: "2026-02-05", to: "2026-02-05", today: "2026-02-05"
        )
        XCTAssertEqual(report.firstDate, "2026-02-05")
        XCTAssertEqual(report.lastDate, "2026-02-05")
        XCTAssertEqual(report.totalDays, 1)
    }

    /// One bound is not a window: `periodEnd` alone, as the historical streak
    /// anchor passed it before the window existed, leaves the entry span.
    func testPeriodEndAloneLeavesTheEntrySpanInPlace() throws {
        let report = try XCTUnwrap(
            ReportData.make(
                entries: [
                    entry(1, drink: 1, date: "2026-01-10", grams: 20),
                    entry(2, drink: 1, date: "2026-02-05", grams: 10),
                ],
                drinks: [drink(1, .beer)],
                settings: settings(daily: 24, weekly: 168, drinkDays: 5),
                periodEnd: "2026-02-28", today: "2026-06-30",
                timeZone: TimeZone(identifier: "UTC")!
            )
        )
        XCTAssertEqual(report.firstDate, "2026-01-10")
        XCTAssertEqual(report.lastDate, "2026-02-05")
    }

    /// Every month the period covers is a row, the dry ones included: the table
    /// has to add up to the period printed above it.
    func testAMonthWithoutEntriesKeepsItsRow() throws {
        let report = try windowed(
            [
                entry(1, drink: 1, date: "2026-01-10", grams: 20),
                entry(2, drink: 1, date: "2026-02-05", grams: 10),
            ],
            from: "2026-01-01", to: "2026-04-30", today: "2026-06-30"
        )
        XCTAssertEqual(report.months.map(\.monthKey), ["2026-01", "2026-02", "2026-03", "2026-04"])
        let march = try XCTUnwrap(report.months.first { $0.monthKey == "2026-03" })
        XCTAssertEqual(march.drinkDays, 0)
        XCTAssertEqual(march.totalGrams, 0, accuracy: Self.epsilon)
        XCTAssertEqual(march.effectiveDays, 31)
    }

    func testMonthKeysCoverEveryMonthThePeriodTouches() {
        XCTAssertEqual(
            ReportData.monthKeys(from: "2026-11-20", to: "2027-02-03"),
            ["2026-11", "2026-12", "2027-01", "2027-02"]
        )
        XCTAssertEqual(ReportData.monthKeys(from: "2026-05-02", to: "2026-05-30"), ["2026-05"])
        XCTAssertEqual(ReportData.monthKeys(from: "2026-05-30", to: "2026-05-02"), [])
    }
}
