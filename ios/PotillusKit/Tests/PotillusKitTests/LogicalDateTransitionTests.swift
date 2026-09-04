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
// LogicalDateTransitionTests.swift – the derived day equals the stored one
// =============================================================================
//
// TEMPORARY BY DESIGN. This suite has one job: to show that switching from the
// stored `logicalDate` to a day derived from the reading moves no entry that
// v0.86.0 wrote. It states the claim the changeover rests on as an assertion,
// and it goes when the column does — there is nothing left to compare then.
// The Kotlin twin is `LogicalDateTransitionTest`.
//
// HOW v0.86.0 WROTE AN ENTRY, and why that is what this reproduces: the sheet
// offered a time, the screen supplied the logical day, and
// `DayResolver.instant(logicalDate:)` placed the one on the other;
// `utcOffsetSeconds` recorded the frame that instant fell in.
//
// THAT PLACEMENT IS GONE FROM THE APP — the sheet composes a whole reading now,
// so nothing in production maps a logical day back onto an instant — and
// `placeOnLogicalDay` below is a deliberate copy of it. A test of a historical
// write path has to carry that path itself; calling the successor would be
// asking the new rule whether it agrees with itself. `utcOffsetSeconds` and
// `resolve` are still the production ones, because those are what the claim is
// about.
//
// The suite deliberately does NOT cover entries older than v0.86.0: those are
// exactly the ones that DO move, and 2.6 of the specification says so.
// =============================================================================

final class LogicalDateTransitionTests: XCTestCase {

    /// The instant v0.86.0 stored for a wall-clock time on a logical day.
    ///
    /// A copy of the `DayResolver.instant(logicalDate:…)` that existed while the
    /// sheet offered hours and minutes alone: a time before the day-change
    /// boundary belongs to the FOLLOWING calendar day. See the file header for
    /// why it is copied rather than called.
    private static func placeOnLogicalDay(
        logicalDate: String,
        hour: Int,
        minute: Int,
        changeHour: Int,
        changeMinute: Int,
        timeZone: TimeZone
    ) -> Int64? {
        guard let day = DayResolver.parseDate(logicalDate) else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = utc.dateComponents([.year, .month, .day], from: day)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)
        var wanted = DateComponents(
            year: parts.year, month: parts.month, day: parts.day, hour: hour, minute: minute
        )
        if isBeforeChangeTime, let next = parts.day { wanted.day = next + 1 }
        guard let placed = calendar.date(from: wanted) else { return nil }
        return Int64((placed.timeIntervalSince1970 * 1000).rounded())
    }

    /// One zone with a summer switch, one with another, one with none.
    private let zoneNames = ["Europe/Berlin", "America/New_York", "Asia/Tokyo"]

    /// The default boundary, midnight, and one with minutes past an hour.
    private let changeTimes = [(4, 0), (0, 0), (6, 30)]

    /// Ordinary days plus both sides of the 2026 switches in both zones, so the
    /// placement runs into a shortened and a lengthened day.
    private let logicalDays = [
        "2026-01-15",
        "2026-03-07", "2026-03-08",  // New York springs forward on the 8th
        "2026-03-28", "2026-03-29",  // Berlin springs forward on the 29th
        "2026-06-15",
        "2026-10-24", "2026-10-25",  // Berlin falls back on the 25th
        "2026-10-31", "2026-11-01",  // New York falls back on the 1st
    ]

    /// Every entry v0.86.0 could write resolves back to the day it was filed
    /// under.
    ///
    /// THE SPRING-FORWARD GAP IS THE ONE EXCEPTION, and it is skipped rather
    /// than asserted: a wall-clock time that does not exist in the zone is not a
    /// reading anyone made, and Foundation answers it with the instant the zone
    /// offers instead. What is stored is then an hour the user did not type — a
    /// defect of the old write path, not of the new derivation, and the count is
    /// asserted to stay in single figures so a skip can never quietly swallow
    /// the suite.
    func testTheDerivedDayEqualsTheStoredLogicalDateForEveryV0860Entry() throws {
        var checked = 0
        var skippedGapReadings = 0

        for zoneName in zoneNames {
            let zone = try XCTUnwrap(TimeZone(identifier: zoneName))
            var reader = Calendar(identifier: .gregorian)

            for (changeHour, changeMinute) in changeTimes {
                for logicalDay in logicalDays {
                    for hour in 0..<24 {
                        for minute in [0, 30] {
                            guard let stored = Self.placeOnLogicalDay(
                                logicalDate: logicalDay,
                                hour: hour,
                                minute: minute,
                                changeHour: changeHour,
                                changeMinute: changeMinute,
                                timeZone: zone
                            ) else {
                                skippedGapReadings += 1
                                continue
                            }
                            let offsetSeconds = DayResolver.utcOffsetSeconds(
                                timestampMillis: stored, timeZone: zone
                            )

                            // The wall clock the row would show, read through the
                            // frame it recorded — the production display path.
                            reader.timeZone = DayResolver.displayTimeZone(
                                utcOffsetSeconds: offsetSeconds
                            )
                            let readBack = reader.dateComponents(
                                [.hour, .minute],
                                from: Date(timeIntervalSince1970: Double(stored) / 1000.0)
                            )
                            if readBack.hour != hour || readBack.minute != minute {
                                skippedGapReadings += 1
                                continue
                            }

                            checked += 1
                            XCTAssertEqual(
                                DayResolver.resolve(
                                    timestampMillis: stored,
                                    utcOffsetSeconds: offsetSeconds,
                                    changeHour: changeHour,
                                    changeMinute: changeMinute
                                ),
                                logicalDay,
                                """
                                \(zoneName) \(logicalDay) \
                                \(String(format: "%02d:%02d", hour, minute)) \
                                with boundary \(changeHour):\(changeMinute)
                                """
                            )
                        }
                    }
                }
            }
        }

        XCTAssertGreaterThan(checked, 1000, "The suite must actually have run")
        XCTAssertLessThan(
            skippedGapReadings, 24,
            "Only the spring-forward gap may be skipped, not \(skippedGapReadings) readings"
        )
    }
}
