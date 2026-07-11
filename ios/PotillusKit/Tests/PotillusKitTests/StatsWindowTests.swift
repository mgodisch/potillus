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
// StatsWindowTests.swift
// =============================================================================
//
// Every boundary here is a chance to be off by one: the day a month begins, the
// day the previous period ends, the leap day, and the user's floor. Expected
// values were computed independently, not read back from the implementation.
// =============================================================================

final class StatsWindowTests: XCTestCase {

    private func window(_ period: StatsPeriod, _ today: String) throws -> StatsWindow {
        try XCTUnwrap(StatsWindows.window(period: period, today: today))
    }

    // ── The three periods ────────────────────────────────────────────────────

    /// Seven days ending today, against the seven immediately before.
    func testTheWeekIsARollingWindowOfSevenDays() throws {
        let week = try window(.week, "2026-01-15")
        XCTAssertEqual(week.from, "2026-01-09")
        XCTAssertEqual(week.to, "2026-01-15")
        XCTAssertEqual(week.previousFrom, "2026-01-02")
        XCTAssertEqual(week.previousTo, "2026-01-08")
    }

    /// The month so far, against the WHOLE previous calendar month. The lengths
    /// differ on purpose: the trend compares grams per day, not totals.
    func testTheMonthRunsFromTheFirstAndComparesAgainstTheWholePreviousMonth() throws {
        let month = try window(.month, "2026-01-15")
        XCTAssertEqual(month.from, "2026-01-01")
        XCTAssertEqual(month.to, "2026-01-15")
        XCTAssertEqual(month.previousFrom, "2025-12-01")
        XCTAssertEqual(month.previousTo, "2025-12-31")
    }

    func testTheYearRunsFromJanuaryFirst() throws {
        let year = try window(.year, "2026-01-15")
        XCTAssertEqual(year.from, "2026-01-01")
        XCTAssertEqual(year.previousFrom, "2025-01-01")
        XCTAssertEqual(year.previousTo, "2025-12-31")
    }

    // ── Boundaries ───────────────────────────────────────────────────────────

    /// On the first of the month the period is one day long, and the previous one
    /// is the month that just ended.
    func testOnTheFirstOfAMonthThePeriodIsASingleDay() throws {
        let month = try window(.month, "2026-03-01")
        XCTAssertEqual(month.from, "2026-03-01")
        XCTAssertEqual(month.to, "2026-03-01")
        XCTAssertEqual(month.previousFrom, "2026-02-01")
        XCTAssertEqual(month.previousTo, "2026-02-28")
    }

    /// February 2024 had 29 days, and the previous month must end on the 29th.
    func testTheLeapDayIsIncludedInThePreviousMonth() throws {
        let month = try window(.month, "2024-03-15")
        XCTAssertEqual(month.previousFrom, "2024-02-01")
        XCTAssertEqual(month.previousTo, "2024-02-29")
    }

    func testOnJanuaryFirstTheYearIsOneDayAndThePreviousIsWhole() throws {
        let year = try window(.year, "2026-01-01")
        XCTAssertEqual(year.from, "2026-01-01")
        XCTAssertEqual(year.to, "2026-01-01")
        XCTAssertEqual(year.previousFrom, "2025-01-01")
        XCTAssertEqual(year.previousTo, "2025-12-31")
    }

    /// Whatever the period, the baseline ends the day before it begins. No gap,
    /// no overlap.
    func testThePreviousWindowAlwaysEndsTheDayBeforeTheCurrentBegins() throws {
        for period in StatsPeriod.allCases {
            for today in ["2026-01-01", "2026-01-15", "2026-03-01", "2024-02-29", "2026-12-31"] {
                let window = try self.window(period, today)
                let from = try XCTUnwrap(DayResolver.parseDate(window.from))
                let previousTo = try XCTUnwrap(DayResolver.parseDate(window.previousTo))
                XCTAssertEqual(
                    from.timeIntervalSince(previousTo), 86_400,
                    "\(period.rawValue) on \(today)"
                )
            }
        }
    }

    func testAMalformedDateYieldsNoWindow() {
        XCTAssertNil(StatsWindows.window(period: .month, today: "not-a-date"))
    }

    // ── The floor ────────────────────────────────────────────────────────────

    func testNoFloorChangesNothing() throws {
        let month = try window(.month, "2026-01-15")
        XCTAssertEqual(StatsWindows.applyingFloor(month, floor: ""), month)
    }

    func testAFloorBeforeBothWindowsChangesNothing() throws {
        let month = try window(.month, "2026-01-15")
        XCTAssertEqual(StatsWindows.applyingFloor(month, floor: "2025-11-01"), month)
    }

    /// A floor inside the baseline shortens it. The comparison stays fair only
    /// because the trend is measured per day.
    func testAFloorInsideThePreviousPeriodShortensTheBaseline() throws {
        let month = try window(.month, "2026-01-15")
        let floored = StatsWindows.applyingFloor(month, floor: "2025-12-15")

        XCTAssertEqual(floored.from, "2026-01-01", "the current period is untouched")
        XCTAssertEqual(floored.previousFrom, "2025-12-15")
        XCTAssertEqual(floored.previousTo, "2025-12-31")
        XCTAssertTrue(floored.hasBaseline)
    }

    /// A floor inside the CURRENT period leaves the baseline inverted — which
    /// means "there is no comparable history", not "the baseline was zero".
    func testAFloorInsideTheCurrentPeriodLeavesNoBaseline() throws {
        let month = try window(.month, "2026-01-15")
        let floored = StatsWindows.applyingFloor(month, floor: "2026-01-10")

        XCTAssertEqual(floored.from, "2026-01-10")
        XCTAssertEqual(floored.to, "2026-01-15")
        XCTAssertFalse(floored.hasBaseline, "previousFrom now exceeds previousTo")
    }

    /// The floor is compared as a STRING. That works only because `yyyy-MM-dd`
    /// sorts chronologically — the reason the schema stores dates that way.
    func testTheFloorIsAppliedByStringComparison() throws {
        let week = try window(.week, "2026-01-15")
        let floored = StatsWindows.applyingFloor(week, floor: "2026-01-12")
        XCTAssertEqual(floored.from, "2026-01-12")
        XCTAssertGreaterThan(floored.previousFrom, floored.previousTo)
    }
}
