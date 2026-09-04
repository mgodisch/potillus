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
// DayResolverTests.swift – cross-platform parity suite for the logical day
// =============================================================================
//
// Driven by `test-vectors/day-resolver.json`, the same file the Android JVM
// suite asserts against. Because the logical-day boundary decides which day
// every entry belongs to, a divergence here would silently corrupt daily totals,
// the rolling seven-day window, violation counts, and streaks alike.
//
// The vectors cover what a recorded frame leaves of the two traps: each instant
// around a daylight-saving switch is read once in the offset before it and once
// in the offset after, and the same instant is read in two frames. A fixed
// offset knows no switch, so the pairs are the statement `resolve` can still
// make — and the one that lands on two days is the one that matters.
// =============================================================================

/// Root of `test-vectors/day-resolver.json`.
struct DayResolverVectors: Decodable {
    let resolve: [ResolveCase]
    let logicalDayDiffers: [LogicalDayDiffersCase]
    let effectivePeriodDays: [EffectiveDaysCase]
    let windowDays: [WindowDaysCase]
    let computeCurrentAbstinence: [CurrentAbstinenceCase]
    let computeLongestAbstinence: [LongestAbstinenceCase]
    let firstDayOfWeekIso: [FirstWeekdayCase]

    struct ResolveCase: Decodable {
        let description: String
        /// Absolute instant. `Int64` because millisecond epochs overflow `Int32`.
        let epochMillis: Int64
        /// The frame the reading was taken in. No zone is consulted.
        let utcOffsetSeconds: Int
        let changeHour: Int
        let changeMinute: Int
        let expected: String
    }

    struct LogicalDayDiffersCase: Decodable {
        let description: String
        /// The composed instant of the date and time in the sheet.
        let epochMillis: Int64
        let utcOffsetSeconds: Int
        let changeHour: Int
        let changeMinute: Int
        /// The logical day the sheet was opened on.
        let logicalDay: String
        /// True when the entry counts toward another day, so the note shows.
        let expected: Bool
    }

    struct EffectiveDaysCase: Decodable {
        let description: String
        let from: String
        let today: String
        let todayIsDrinkDay: Bool
        let expected: Int
    }

    struct WindowDaysCase: Decodable {
        let description: String
        let from: String
        let to: String
        let today: String
        let todayIsDrinkDay: Bool
        let expected: Int
    }

    struct CurrentAbstinenceCase: Decodable {
        let description: String
        let dates: [String]
        let today: String
        let statsFrom: String
        let expected: Int
    }

    struct LongestAbstinenceCase: Decodable {
        let description: String
        let dates: [String]
        let today: String
        let statsFrom: String
        let expected: Int
    }

    struct FirstWeekdayCase: Decodable {
        let description: String
        /// A BCP-47 tag, which `Locale(identifier:)` takes with either separator.
        let languageTag: String
        /// ISO-8601: 1 = Monday … 7 = Sunday.
        let expected: Int
    }
}

final class DayResolverTests: XCTestCase {

    private static var loadedVectors: DayResolverVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("day-resolver", as: DayResolverVectors.self)
        } catch {
            XCTFail("Could not load shared test vectors: \(error)")
        }
    }

    private var vectors: DayResolverVectors { Self.loadedVectors }

    // ── resolve ──────────────────────────────────────────────────────────────

    func testResolveAgainstSharedVectors() {
        for testCase in vectors.resolve {
            let actual = DayResolver.resolve(
                timestampMillis: testCase.epochMillis,
                utcOffsetSeconds: testCase.utcOffsetSeconds,
                changeHour: testCase.changeHour,
                changeMinute: testCase.changeMinute
            )
            XCTAssertEqual(actual, testCase.expected, "resolve: \(testCase.description)")
        }
    }

    // ── logicalDayDiffers ────────────────────────────────────────────────────

    func testLogicalDayDiffersAgainstSharedVectors() {
        for testCase in vectors.logicalDayDiffers {
            let actual = DayResolver.logicalDayDiffers(
                timestampMillis: testCase.epochMillis,
                utcOffsetSeconds: testCase.utcOffsetSeconds,
                changeHour: testCase.changeHour,
                changeMinute: testCase.changeMinute,
                logicalDay: testCase.logicalDay
            )
            XCTAssertEqual(actual, testCase.expected, "logicalDayDiffers: \(testCase.description)")
        }
    }

    /// The same instant is a different logical day in a different frame. This is
    /// not a quirk to be smoothed over — it is the reason the offset must be an
    /// explicit parameter rather than an ambient global. The entry keeps the
    /// frame it was written in, so the day it counts toward does not move when
    /// the device zone does.
    func testResolveFollowsTheOffsetItIsGivenForTheSameInstant() {
        // 2025-05-24 23:00 read at -04:00 is already 05:00 on the 25th at +02:00.
        let instant: Int64 = 1_748_142_000_000

        let atMinusFour = DayResolver.resolve(
            timestampMillis: instant, utcOffsetSeconds: -4 * 3600, changeHour: 4, changeMinute: 0
        )
        let atPlusTwo = DayResolver.resolve(
            timestampMillis: instant, utcOffsetSeconds: 2 * 3600, changeHour: 4, changeMinute: 0
        )
        XCTAssertNotEqual(atMinusFour, atPlusTwo, "The same instant must resolve per frame")
    }

    // ── effectivePeriodDays ──────────────────────────────────────────────────

    func testEffectivePeriodDaysAgainstSharedVectors() {
        for testCase in vectors.effectivePeriodDays {
            let actual = DayResolver.effectivePeriodDays(
                from: testCase.from,
                today: testCase.today,
                todayIsDrinkDay: testCase.todayIsDrinkDay
            )
            XCTAssertEqual(actual, testCase.expected, "effectivePeriodDays: \(testCase.description)")
        }
    }

    // ── windowDays ───────────────────────────────────────────────────────────

    func testWindowDaysAgainstSharedVectors() {
        for testCase in vectors.windowDays {
            let actual = DayResolver.windowDays(
                from: testCase.from,
                to: testCase.to,
                today: testCase.today,
                todayIsDrinkDay: testCase.todayIsDrinkDay
            )
            XCTAssertEqual(actual, testCase.expected, "windowDays: \(testCase.description)")
        }
    }

    // ── computeCurrentAbstinence ─────────────────────────────────────────────

    func testComputeCurrentAbstinenceAgainstSharedVectors() {
        for testCase in vectors.computeCurrentAbstinence {
            let actual = DayResolver.computeCurrentAbstinence(
                sortedDates: testCase.dates,
                today: testCase.today,
                statsFrom: testCase.statsFrom
            )
            XCTAssertEqual(actual, testCase.expected, "computeCurrentAbstinence: \(testCase.description)")
        }
    }

    // ── computeLongestAbstinence ─────────────────────────────────────────────

    func testComputeLongestAbstinenceAgainstSharedVectors() {
        for testCase in vectors.computeLongestAbstinence {
            let actual = DayResolver.computeLongestAbstinence(
                sortedDates: testCase.dates,
                today: testCase.today,
                statsFrom: testCase.statsFrom
            )
            XCTAssertEqual(actual, testCase.expected, "computeLongestAbstinence: \(testCase.description)")
        }
    }

    // ── Structural tests (not vector-driven) ─────────────────────────────────

    func testParseDateAndFormatDateRoundTrip() throws {
        for dateString in ["2025-01-01", "2024-02-29", "2025-12-31", "2025-05-24"] {
            let parsed = try XCTUnwrap(DayResolver.parseDate(dateString))
            XCTAssertEqual(DayResolver.formatDate(parsed), dateString)
        }
    }

    func testParseDateRejectsMalformedInput() {
        XCTAssertNil(DayResolver.parseDate("2025-13-01"))
        XCTAssertNil(DayResolver.parseDate("not-a-date"))
        XCTAssertNil(DayResolver.parseDate(""))
    }

    /// The formatter must never adopt a device locale's alternate calendar or
    /// numerals — on a Thai device a naive formatter prints Buddhist-era years,
    /// which would corrupt every stored `logicalDate`.
    func testFormattingIsIndependentOfTheDeviceLocale() throws {
        let parsed = try XCTUnwrap(DayResolver.parseDate("2025-05-24"))
        XCTAssertEqual(DayResolver.formatDate(parsed), "2025-05-24")
        XCTAssertTrue(DayResolver.formatDate(parsed).hasPrefix("2025"))
    }

    /// Abstinence counts must never be negative, whatever the caller passes.
    func testAbstinenceIsNeverNegative() {
        XCTAssertGreaterThanOrEqual(
            DayResolver.computeCurrentAbstinence(sortedDates: ["2030-01-01"], today: "2025-01-01"), 0
        )
        XCTAssertGreaterThanOrEqual(
            DayResolver.computeLongestAbstinence(sortedDates: [], today: "", statsFrom: ""), 0
        )
    }

    // ── parseDate is strict ──────────────────────────────────────────────────
    //
    // Kotlin's LocalDate.parse throws on a day the calendar does not have and on a
    // spelling that is not canonical. This side reproduces both by formatting its
    // result back and demanding the original string, rather than resting on
    // DateFormatter's leniency — which is a framework detail, not a contract.

    func testADayTheCalendarDoesNotHaveIsRejected() {
        XCTAssertNil(DayResolver.parseDate("2026-02-30"))
        XCTAssertNil(DayResolver.parseDate("2025-02-29"), "2025 is not a leap year")
        XCTAssertNil(DayResolver.parseDate("2026-13-01"))
        XCTAssertNil(DayResolver.parseDate("2026-04-31"))
    }

    func testALeapDayThatExistsIsAccepted() {
        XCTAssertNotNil(DayResolver.parseDate("2024-02-29"), "2024 is a leap year")
    }

    func testANonCanonicalSpellingIsRejected() {
        XCTAssertNil(DayResolver.parseDate("2026-1-1"))
        XCTAssertNil(DayResolver.parseDate("26-01-01"))
    }

    func testACanonicalDateRoundTrips() {
        for text in ["2026-01-01", "2026-06-29", "2024-02-29", "2026-12-31"] {
            let parsed = DayResolver.parseDate(text)
            XCTAssertEqual(parsed.map(DayResolver.formatDate), text)
        }
    }
}

// =============================================================================
// The recorded local frame
// =============================================================================
//
// In an extension so `type_body_length` stays inside SwiftLint's limit; these
// belong to the same suite and run with it.

extension DayResolverTests {

    func testUtcOffsetSecondsReadsTheOffsetInForceAtThatInstant() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        // 2026-01-15T12:00Z is winter in Berlin: +01:00.
        let winter: Int64 = 1_768_478_400_000
        // 2026-07-15T12:00Z is summer: +02:00.
        let summer: Int64 = 1_784_116_800_000
        XCTAssertEqual(
            DayResolver.utcOffsetSeconds(timestampMillis: winter, timeZone: berlin), 3600
        )
        XCTAssertEqual(
            DayResolver.utcOffsetSeconds(timestampMillis: summer, timeZone: berlin), 7200
        )
    }

    func testDisplayTimeZoneUsesTheRecordedOffset() {
        XCTAssertEqual(DayResolver.displayTimeZone(utcOffsetSeconds: 3600).secondsFromGMT(), 3600)
        XCTAssertEqual(DayResolver.displayTimeZone(utcOffsetSeconds: 0).secondsFromGMT(), 0)
        XCTAssertEqual(
            DayResolver.displayTimeZone(utcOffsetSeconds: -5 * 3600).secondsFromGMT(), -5 * 3600
        )
    }

    /// 22:30 in Berlin in January, read from a device that has since moved to New
    /// York. The recorded frame still says 22:30 — and there is no zone to pass
    /// in any more, which is what makes that unconditional.
    func testARecordedFrameSurvivesAChangeOfZone() {
        let instant = Date(timeIntervalSince1970: 1_768_512_600)  // 2026-01-15T21:30Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DayResolver.displayTimeZone(utcOffsetSeconds: 3600)
        XCTAssertEqual(calendar.component(.hour, from: instant), 22)
        XCTAssertEqual(calendar.component(.minute, from: instant), 30)
        XCTAssertEqual(calendar.component(.day, from: instant), 15)
    }

    // ── firstDayOfWeekIso ────────────────────────────────────────────────────
    //
    // The number that heads column 0 of the calendar grid and orders the report's
    // weekday histogram. This side reads `Calendar.firstWeekday`, which counts
    // Sunday as 1, and converts to the ISO numbering Kotlin's `WeekFields`
    // returns directly. Two schemes, one off-by-one away from rotating the whole
    // week — and until the 0.85.0 QA round neither platform asserted the
    // conversion. The shared vectors now do.

    func testFirstDayOfWeekIsoAgainstSharedVectors() {
        for testCase in vectors.firstDayOfWeekIso {
            let actual = DayResolver.firstDayOfWeekIso(
                locale: Locale(identifier: testCase.languageTag)
            )
            XCTAssertEqual(actual, testCase.expected, "firstDayOfWeekIso: \(testCase.description)")
        }
    }

    /// Whatever the locale, the answer is an ISO weekday. A `Calendar.firstWeekday`
    /// carried through unconverted would leave the range intact and still be wrong,
    /// so this guards the shape while the vectors above guard the value.
    func testFirstDayOfWeekIsoStaysInTheIsoRange() {
        for identifier in Locale.availableIdentifiers.prefix(200) {
            let iso = DayResolver.firstDayOfWeekIso(locale: Locale(identifier: identifier))
            XCTAssertTrue(
                (1...7).contains(iso),
                "firstDayOfWeekIso returned \(iso) for \(identifier)"
            )
        }
    }
}
