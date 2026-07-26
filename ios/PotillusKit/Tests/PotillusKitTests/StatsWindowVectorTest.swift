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

/// Drives `StatsWindows` from the shared `stats-window.json` vectors.
///
/// This complements `StatsWindowTests` rather than replacing it: that suite is the
/// expressive one, and its expectations are where these vectors came from. This
/// file exists so the same boundaries are enforced on the Kotlin side, which until
/// the 0.84.0 review had the derivation inline in `StatsViewModel` with no test
/// that could reach it.
final class StatsWindowVectorTest: XCTestCase {

    private func period(_ raw: String) throws -> StatsPeriod {
        try XCTUnwrap(StatsPeriod(rawValue: raw), "unknown period \(raw) in the vectors")
    }

    /// Asserts one window against the four dates and the baseline flag a case
    /// carries. The case description goes into every message, so a red test names
    /// the boundary rather than only the value.
    private func assertMatches(_ testCase: StatsWindowVectors.Case, _ actual: StatsWindow?) throws {
        let window = try XCTUnwrap(actual, testCase.description)
        XCTAssertEqual(window.from, testCase.from, "\(testCase.description): from")
        XCTAssertEqual(window.to, testCase.to, "\(testCase.description): to")
        XCTAssertEqual(
            window.previousFrom, testCase.previousFrom, "\(testCase.description): previousFrom"
        )
        XCTAssertEqual(
            window.previousTo, testCase.previousTo, "\(testCase.description): previousTo"
        )
        XCTAssertEqual(
            window.hasBaseline, testCase.hasBaseline, "\(testCase.description): hasBaseline"
        )
    }

    // ── The three periods and their boundaries ───────────────────────────────

    func testWindowMatchesTheVectors() throws {
        let vectors = try TestVectors.load("stats-window", as: StatsWindowVectors.self)
        for testCase in vectors.window {
            try assertMatches(
                testCase,
                StatsWindows.window(period: try period(testCase.period), today: testCase.today)
            )
        }
    }

    // ── The floor ────────────────────────────────────────────────────────────

    func testApplyingFloorMatchesTheVectors() throws {
        let vectors = try TestVectors.load("stats-window", as: StatsWindowVectors.self)
        for testCase in vectors.applyingFloor {
            let floor = try XCTUnwrap(
                testCase.floor, "\(testCase.description): an applyingFloor case needs a floor"
            )
            let base = try XCTUnwrap(
                StatsWindows.window(period: try period(testCase.period), today: testCase.today),
                "\(testCase.description): the unclipped window must exist"
            )
            try assertMatches(testCase, StatsWindows.applyingFloor(base, floor: floor))
        }
    }

    // ── The invariant, over every period and day the vector lists ────────────

    func testThePreviousWindowEndsTheDayBeforeTheCurrentBegins() throws {
        let vectors = try TestVectors.load("stats-window", as: StatsWindowVectors.self)
        for raw in vectors.adjacency.periods {
            for today in vectors.adjacency.todays {
                let window = try XCTUnwrap(
                    StatsWindows.window(period: try period(raw), today: today),
                    "\(raw) on \(today): expected a window"
                )
                let from = try XCTUnwrap(DayResolver.parseDate(window.from))
                let previousTo = try XCTUnwrap(DayResolver.parseDate(window.previousTo))
                XCTAssertEqual(
                    from.timeIntervalSince(previousTo), 86_400, "\(raw) on \(today)"
                )
            }
        }
    }

    // ── Unparseable input ────────────────────────────────────────────────────
    //
    // The one case most likely to diverge: `java.time` throws where Foundation
    // returns nil, so both platforms pin the outcome rather than leaving it to
    // each one's taste.

    func testAnUnparseableTodayYieldsNoWindow() throws {
        let vectors = try TestVectors.load("stats-window", as: StatsWindowVectors.self)
        for testCase in vectors.invalidToday {
            XCTAssertNil(
                StatsWindows.window(period: try period(testCase.period), today: testCase.today),
                testCase.description
            )
        }
    }
}
