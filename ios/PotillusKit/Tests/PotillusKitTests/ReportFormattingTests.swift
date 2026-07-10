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

final class ReportFormattingTests: XCTestCase {

    private static var loadedVectors: ReportFormatVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("report-format", as: ReportFormatVectors.self)
        } catch {
            XCTFail("Could not load the shared formatting vectors: \(error)")
        }
    }

    private var vectors: ReportFormatVectors { Self.loadedVectors }

    // ── The shared contract ──────────────────────────────────────────────────

    func testAgainstTheJvmsOwnOutput() {
        for testCase in vectors.cases {
            let locale = Locale(identifier: testCase.locale)
            let label = "\(testCase.locale) \(testCase.value)"

            XCTAssertEqual(
                ReportFormatting.oneDecimal(testCase.value, locale: locale),
                testCase.fmt1, "one decimal, \(label)"
            )
            XCTAssertEqual(
                ReportFormatting.noDecimals(testCase.value, locale: locale),
                testCase.fmt0, "no decimals, \(label)"
            )
        }
    }

    // ── The ties that made this file necessary ───────────────────────────────

    /// Kotlin rounds half UP; `String(format:)` rounds half to EVEN. These four
    /// values are where the two part company, and they are ordinary values: a
    /// daily limit of 20.5 g is a limit a person might set.
    func testTiesRoundAwayFromZeroLikeKotlinNotToEvenLikePrintf() {
        let english = Locale(identifier: "en")

        XCTAssertEqual(ReportFormatting.noDecimals(2.5, locale: english), "3")
        XCTAssertEqual(ReportFormatting.noDecimals(20.5, locale: english), "21")
        XCTAssertEqual(ReportFormatting.oneDecimal(0.25, locale: english), "0.3")
        XCTAssertEqual(ReportFormatting.oneDecimal(12.35, locale: english), "12.4")

        // What the naive port would have printed. Kept as a warning, not a wish.
        XCTAssertEqual(String(format: "%.0f", 2.5), "2")
        XCTAssertEqual(String(format: "%.1f", 0.25), "0.2")
    }

    /// The rounding sees `12.35`, not `12.3499999999999996`. Feeding the raw
    /// `Double` to `Decimal(_:)` would carry the binary error into the tie and
    /// round down.
    func testRoundingUsesTheShortestDecimalRepresentation() {
        XCTAssertEqual(ReportFormatting.oneDecimal(12.35, locale: Locale(identifier: "en")), "12.4")
        XCTAssertEqual(ReportFormatting.oneDecimal(0.15, locale: Locale(identifier: "en")), "0.2")
    }

    /// `%.1f` never groups. A four-figure gram total is not "1,234.5".
    func testThousandsAreNotGrouped() {
        XCTAssertEqual(ReportFormatting.oneDecimal(1234.5, locale: Locale(identifier: "en")), "1234.5")
        XCTAssertEqual(ReportFormatting.noDecimals(1234.5, locale: Locale(identifier: "de")), "1235")
    }

    /// The decimal mark follows the report's locale, not the device's.
    func testTheDecimalMarkFollowsTheGivenLocale() {
        XCTAssertEqual(ReportFormatting.oneDecimal(0.5, locale: Locale(identifier: "en")), "0.5")
        XCTAssertEqual(ReportFormatting.oneDecimal(0.5, locale: Locale(identifier: "de")), "0,5")
        XCTAssertEqual(ReportFormatting.oneDecimal(0.5, locale: Locale(identifier: "fr")), "0,5")
    }

    /// A number bound for an SVG attribute must never take a comma, whatever the
    /// reader's locale. That path deliberately does not come through here.
    func testSvgNumbersRemainPosixWhateverTheLocale() {
        XCTAssertEqual(ReportChart.svgNumber(0.5), "0.50")
        XCTAssertFalse(ReportChart.svgNumber(0.5).contains(","))
    }

    /// Zero prints its decimal place, so a table column stays aligned.
    func testZeroKeepsItsDecimalPlace() {
        XCTAssertEqual(ReportFormatting.oneDecimal(0.0, locale: Locale(identifier: "en")), "0.0")
        XCTAssertEqual(ReportFormatting.noDecimals(0.0, locale: Locale(identifier: "en")), "0")
    }
}
