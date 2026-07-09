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
// DayResolverTests.swift – cross-platform parity suite for the logical day
// =============================================================================
//
// Driven by `test-vectors/day-resolver.json`, the same file the Android JVM
// suite asserts against. Because the logical-day boundary decides which day
// every entry belongs to, a divergence here would silently corrupt daily totals,
// the rolling seven-day window, violation counts, and streaks alike.
//
// The vectors deliberately include the two traps: DST transitions (the
// spring-forward gap and the fall-back repetition) and cross-timezone instants.
// =============================================================================

/// Root of `test-vectors/day-resolver.json`.
struct DayResolverVectors: Decodable {
    let resolve: [ResolveCase]
    let effectivePeriodDays: [EffectiveDaysCase]
    let computeCurrentAbstinence: [CurrentAbstinenceCase]
    let computeLongestAbstinence: [LongestAbstinenceCase]

    struct ResolveCase: Decodable {
        let description: String
        /// Absolute instant. `Int64` because millisecond epochs overflow `Int32`.
        let epochMillis: Int64
        /// IANA zone identifier, e.g. `Europe/Berlin`.
        let zoneId: String
        let changeHour: Int
        let changeMinute: Int
        let expected: String
    }

    struct EffectiveDaysCase: Decodable {
        let description: String
        let from: String
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

    func testResolveAgainstSharedVectors() throws {
        for testCase in vectors.resolve {
            let timeZone = try XCTUnwrap(
                TimeZone(identifier: testCase.zoneId),
                "Unknown time zone: \(testCase.zoneId)"
            )
            let actual = DayResolver.resolve(
                timestampMillis: testCase.epochMillis,
                changeHour: testCase.changeHour,
                changeMinute: testCase.changeMinute,
                timeZone: timeZone
            )
            XCTAssertEqual(actual, testCase.expected, "resolve: \(testCase.description)")
        }
    }

    /// The same instant is a different logical day in different zones. This is
    /// not a quirk to be smoothed over — it is the reason the zone must be an
    /// explicit parameter rather than an ambient global.
    func testResolveIsTimeZoneDependentForTheSameInstant() throws {
        // 2025-05-24 23:00 in New York is already 05:00 on the 25th in Berlin.
        let instant: Int64 = 1_748_142_000_000
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let berlin = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))

        let inNewYork = DayResolver.resolve(
            timestampMillis: instant, changeHour: 4, changeMinute: 0, timeZone: newYork
        )
        let inBerlin = DayResolver.resolve(
            timestampMillis: instant, changeHour: 4, changeMinute: 0, timeZone: berlin
        )
        XCTAssertNotEqual(inNewYork, inBerlin, "The same instant must resolve per zone")
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
}
