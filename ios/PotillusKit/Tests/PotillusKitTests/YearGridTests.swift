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
// YearGridTests.swift – the drawn window and the twelve months
// =============================================================================
//
// The layout itself is `MonthGrid`'s, tested there. What is new here is the
// window: which days the year view draws at all. Its boundaries are the easy
// thing to get wrong, so each one is asserted by name rather than by a sweep
// that would pass with an off-by-one at either end.
// =============================================================================

final class YearGridTests: XCTestCase {

    private func grid(today: String, statsFrom: String = "") -> YearGrid {
        YearGrid(year: 2026, firstDayOfWeekIso: 1, today: today, statsFrom: statsFrom)
    }

    // ── Shape ────────────────────────────────────────────────────────────────

    func testTheYearHasTwelveMonthsInCalendarOrder() {
        let year = grid(today: "2026-07-29")

        XCTAssertEqual(year.months.count, 12)
        XCTAssertEqual(year.months.map(\.month), Array(1...12))
    }

    func testEveryMonthCarriesItsOwnDays() {
        let year = grid(today: "2026-07-29")

        XCTAssertEqual(year.months[0].grid.days.count, 31, "January")
        XCTAssertEqual(year.months[1].grid.days.count, 28, "February 2026 is not a leap year")
        XCTAssertEqual(year.months[3].grid.days.count, 30, "April")
    }

    func testTheQueryRangeSpansTheWholeYear() {
        let range = grid(today: "2026-07-29").range

        XCTAssertEqual(range.from, "2026-01-01")
        XCTAssertEqual(range.to, "2026-12-31")
    }

    /// The range is the year, not the window: a floor inside the year must not
    /// narrow what is fetched, or changing it would need a refetch to redraw.
    func testTheQueryRangeIgnoresTheFloor() {
        let range = grid(today: "2026-07-29", statsFrom: "2026-03-01").range

        XCTAssertEqual(range.from, "2026-01-01")
    }

    // ── The drawn window ─────────────────────────────────────────────────────

    func testTodayIsDrawnAndTomorrowIsNot() {
        let year = grid(today: "2026-07-29")

        XCTAssertTrue(year.isDrawn("2026-07-29"), "the day in progress is drawn")
        XCTAssertFalse(year.isDrawn("2026-07-30"))
        XCTAssertFalse(year.isDrawn("2026-12-31"))
    }

    func testTheStartDateItselfIsDrawn() {
        let year = grid(today: "2026-07-29", statsFrom: "2026-03-01")

        XCTAssertTrue(year.isDrawn("2026-03-01"), "the day the user counts from is drawn")
        XCTAssertFalse(year.isDrawn("2026-02-28"))
        XCTAssertTrue(year.isDrawn("2026-03-02"))
    }

    /// The empty string is the app-wide "no floor" sentinel, so only the future
    /// is left out.
    func testWithoutAFloorOnlyTheFutureIsHidden() {
        let year = grid(today: "2026-07-29")

        XCTAssertNil(year.statsFrom)
        XCTAssertTrue(year.isDrawn("2026-01-01"))
        XCTAssertFalse(year.isDrawn("2026-08-01"))
    }

    /// A floor after today draws nothing: an empty grid is the honest answer,
    /// rather than a window that silently reopens at one end.
    func testAFloorAfterTodayLeavesNothingDrawn() {
        let year = grid(today: "2026-07-29", statsFrom: "2026-09-01")

        XCTAssertFalse(year.isDrawn("2026-07-29"))
        XCTAssertFalse(year.isDrawn("2026-09-01"))
    }
}
