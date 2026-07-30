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
// StatsWindowOffsetTests.swift – how far back the screen may go
// =============================================================================
//
// The offset CEILING, which no shared vector covers: the vectors pin what a
// window looks like at a given offset, these pin how far back the user may go.
// The Kotlin counterpart is `StatsWindowOffsetTest`, case for case.
//
// The distinction the tests keep returning to is period arithmetic against day
// counting. 31 January and 1 February are one month apart although two days lie
// between them. The week is the deliberate exception: a rolling seven-day window,
// so whole sevens separate two of them.
// =============================================================================

final class StatsWindowOffsetTests: XCTestCase {

    private func offset(_ period: StatsPeriod, _ today: String, _ day: String) -> Int {
        StatsWindows.offsetOf(period: period, today: today, day: day)
    }

    // ── Months ───────────────────────────────────────────────────────────────

    func testAFloorInsideTheCurrentMonthAllowsNoStepBack() {
        XCTAssertEqual(offset(.month, "2026-07-30", "2026-07-01"), 0)
    }

    func testAFloorOneDayBeforeTheMonthAllowsOneStep() {
        // Two days apart, one period apart: the boundary is what counts.
        XCTAssertEqual(offset(.month, "2026-02-01", "2026-01-31"), 1)
    }

    func testMonthOffsetsCountBoundariesAcrossAYearEnd() {
        XCTAssertEqual(offset(.month, "2026-07-30", "2025-08-15"), 11)
    }

    // ── Years ────────────────────────────────────────────────────────────────

    func testAFloorInsideTheCurrentYearAllowsNoStepBack() {
        XCTAssertEqual(offset(.year, "2026-07-30", "2026-01-01"), 0)
    }

    func testYearOffsetsCountCalendarYearsNotElapsedDays() {
        XCTAssertEqual(offset(.year, "2026-07-30", "2024-12-31"), 2)
    }

    // ── The rolling week ─────────────────────────────────────────────────────

    func testAFloorInsideTheCurrentSevenDaysAllowsNoStepBack() {
        XCTAssertEqual(offset(.week, "2026-07-30", "2026-07-24"), 0)
    }

    func testWholeSevensSeparateRollingWeeks() {
        XCTAssertEqual(offset(.week, "2026-07-30", "2026-07-23"), 1)
        XCTAssertEqual(offset(.week, "2026-07-30", "2026-07-16"), 2)
    }

    func testAPartialWeekDoesNotAddAStep() {
        // Thirteen days back is still one whole seven, not two.
        XCTAssertEqual(offset(.week, "2026-07-30", "2026-07-17"), 1)
    }

    // ── Bounds that must not open the offset up ───────────────────────────────

    func testADayAfterTodayNamesNoPastPeriod() {
        XCTAssertEqual(offset(.month, "2026-07-30", "2026-08-01"), 0)
    }

    func testTodayItselfNamesTheCurrentPeriod() {
        XCTAssertEqual(offset(.month, "2026-07-30", "2026-07-30"), 0)
    }

    /// An unreadable bound yields 0 rather than an open range.
    ///
    /// The floor comes from storage and a backup file may carry anything. Reading a
    /// broken value as "no limit" would let the screen wander into empty windows;
    /// reading it as "no step back" keeps it where the data is.
    func testAnUnparseableBoundClosesTheOffset() {
        XCTAssertEqual(offset(.month, "2026-07-30", "2026-02-30"), 0)
        XCTAssertEqual(offset(.month, "not a date", "2026-01-01"), 0)
    }
}
