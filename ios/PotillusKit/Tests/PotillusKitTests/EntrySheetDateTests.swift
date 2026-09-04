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
// The entry sheet's date field, as arithmetic
// =============================================================================
//
// These are the cases a UI test reaches worst — the small hours, a day-change
// time after the sheet's default hour, a tapped day that happens to be today —
// which is why the rule lives in `EntrySheetDate` rather than in the sheet.
// `EntrySheetDateTest.kt` is the twin; the two are held together by these cases
// rather than by a shared vector, because nothing outside the sheet depends on
// the answer.
//
// Everything runs in UTC, so a reading stated here is the reading the rule sees.
// =============================================================================

final class EntrySheetDateTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    /// `yyyy-MM-dd HH:mm` in UTC.
    private func at(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    /// The calendar day of `date`, in UTC — what an assertion about the date
    /// field is really about; the time of day it carries is meaningless.
    private func day(of date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // ── The Today screen and the drinks list ─────────────────────────────────

    func testTheTodaySheetOpensOnThePresentMoment() {
        let reading = EntrySheetDate.initial(
            origin: .now, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            now: at("2026-03-11 06:00"), timeZone: utc
        )
        XCTAssertEqual(day(of: reading.date), "2026-03-11")
        XCTAssertEqual(reading.hour, 6)
        XCTAssertEqual(reading.minute, 0)
    }

    /// It is 06:00 and the user types 02:00: four hours ago, not twenty hours
    /// ahead. The gap this closes is the whole reason the rule exists.
    func testATimeLaterThanNowBelongsToYesterday() throws {
        let ahead = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .now, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 2, minute: 0, now: at("2026-03-11 06:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: ahead), "2026-03-11")

        let behind = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .now, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 23, minute: 0, now: at("2026-03-11 06:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: behind), "2026-03-10")
    }

    func testThePresentMinuteCountsAsTodayAndTheNextAsYesterday() throws {
        let onTheMinute = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .now, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 6, minute: 0, now: at("2026-03-11 06:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: onTheMinute), "2026-03-11")

        let oneMinuteOn = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .now, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 6, minute: 1, now: at("2026-03-11 06:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: oneMinuteOn), "2026-03-10")
    }

    /// 01:00, the user adds the beer they had at 23:00. Two hours back, not
    /// twenty-one forward — which is what taking the running calendar day would
    /// have made of it.
    func testAnEveningTimeTypedAfterMidnight() throws {
        let followed = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .now, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 23, minute: 0, now: at("2026-03-11 01:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: followed), "2026-03-10")
    }

    // ── The calendar ─────────────────────────────────────────────────────────

    func testATappedDayOpensInTheEvening() {
        let reading = EntrySheetDate.initial(
            origin: .calendar, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            now: at("2026-03-15 12:00"), timeZone: utc
        )
        XCTAssertEqual(day(of: reading.date), "2026-03-10")
        XCTAssertEqual(reading.hour, 20)
    }

    /// With a 21:00 boundary, 20:00 belongs to the day before — so the sheet
    /// offers the calendar 11th to keep the entry on the logical 10th. The
    /// default hour is taste; this is what makes it safe for every setting.
    func testADayChangeAfterTheDefaultHourPutsItOnTheNextDay() {
        let reading = EntrySheetDate.initial(
            origin: .calendar, logicalDay: "2026-03-10", changeHour: 21, changeMinute: 0,
            now: at("2026-03-15 12:00"), timeZone: utc
        )
        XCTAssertEqual(day(of: reading.date), "2026-03-11")
        XCTAssertEqual(reading.hour, 20)
    }

    /// Otherwise tapping today in the calendar would jump the clock to the
    /// evening, which is not what someone logging a drink now means.
    func testTappingTodayOpensOnThePresentMoment() {
        let reading = EntrySheetDate.initial(
            origin: .calendar, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            now: at("2026-03-10 12:00"), timeZone: utc
        )
        XCTAssertEqual(day(of: reading.date), "2026-03-10")
        XCTAssertEqual(reading.hour, 12)
    }

    func testTheCalendarKeepsTheEntryOnTheTappedDay() throws {
        let evening = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .calendar, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 23, minute: 0, now: at("2026-03-15 12:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: evening), "2026-03-10")

        // Before the boundary, so the FOLLOWING calendar day keeps it on the 10th.
        let smallHours = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .calendar, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 1, minute: 0, now: at("2026-03-15 12:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: smallHours), "2026-03-11")

        // Exactly on the boundary is not before it.
        let onTheBoundary = try XCTUnwrap(EntrySheetDate.followUp(
            origin: .calendar, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 4, minute: 0, now: at("2026-03-15 12:00"), timeZone: utc
        ))
        XCTAssertEqual(day(of: onTheBoundary), "2026-03-10")
    }

    // ── Editing ──────────────────────────────────────────────────────────────

    func testEditingFollowsNothing() {
        XCTAssertNil(EntrySheetDate.followUp(
            origin: .edit, logicalDay: "2026-03-10", changeHour: 4, changeMinute: 0,
            hour: 2, minute: 0, now: at("2026-03-11 06:00"), timeZone: utc
        ))
    }

    // ── Guards ───────────────────────────────────────────────────────────────

    func testADayThatIsNotACanonicalDateFallsBackToThePresentMoment() {
        let reading = EntrySheetDate.initial(
            origin: .calendar, logicalDay: "2026-3-10", changeHour: 4, changeMinute: 0,
            now: at("2026-03-15 12:00"), timeZone: utc
        )
        XCTAssertEqual(day(of: reading.date), "2026-03-15")
        XCTAssertNil(EntrySheetDate.followUp(
            origin: .calendar, logicalDay: "2026-3-10", changeHour: 4, changeMinute: 0,
            hour: 1, minute: 0, now: at("2026-03-15 12:00"), timeZone: utc
        ))
    }
}
