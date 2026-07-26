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

/// Drives `ReportLabels.days` from the shared `plural-days.json` vectors.
///
/// The words come from Android's `<plurals name="days">`; the rule that picks
/// among them is `DayPlural`. Asserting the two together is the point: a rule
/// written down wrong here produces a real word from the right language, which is
/// exactly the kind of mistake no reviewer of this repository could catch by
/// reading. Android's `getQuantityString` is the authority, and it reads the same
/// file.
final class DayPluralVectorTest: XCTestCase {

    private func vectors() throws -> DayPluralVectors {
        try TestVectors.load("plural-days", as: DayPluralVectors.self)
    }

    /// Every language, every count, through the labels a report would use.
    func testEveryLanguageMatchesTheVectors() throws {
        let vectors = try self.vectors()
        for (language, cases) in vectors.cases {
            let labels = ReportLabels(language: language)
            for testCase in cases {
                XCTAssertEqual(
                    labels.days(testCase.count), testCase.expected,
                    "\(language) at \(testCase.count)"
                )
            }
        }
    }

    /// The category itself, so a failure says which rule went wrong rather than
    /// only which word came out.
    func testEveryCategoryMatchesTheVectors() throws {
        let vectors = try self.vectors()
        for (language, cases) in vectors.cases {
            for testCase in cases {
                XCTAssertEqual(
                    DayPlural.category(testCase.count, language: language).rawValue,
                    testCase.category,
                    "\(language) at \(testCase.count)"
                )
            }
        }
    }

    /// The teens, called out on their own. 12 ends in 2 and does not take the form
    /// 22 takes, in Polish, Russian and Ukrainian alike — this is the case a rule
    /// written as `count % 10` alone gets wrong, and it would read as a real word.
    func testTheTeensDoNotFollowTheirLastDigit() {
        for language in ["pl", "ru", "uk"] {
            XCTAssertNotEqual(
                DayPlural.category(12, language: language),
                DayPlural.category(22, language: language),
                "\(language): 12 must not take the form 22 takes"
            )
        }
    }

    /// Where Polish parts company with Russian and Ukrainian.
    ///
    /// Russian and Ukrainian give 21, 31 and 41 the singular — "21 день", one day
    /// — while Polish reserves its singular for the number one and nothing else.
    /// An earlier version of this file asserted that 11 and 21 differ in all three,
    /// which is true of two of them; Polish gives both the same form, and the shared
    /// vectors said so all along.
    func testPolishReservesTheSingularForOne() {
        for language in ["ru", "uk"] {
            XCTAssertEqual(DayPlural.category(21, language: language), .one, language)
            XCTAssertNotEqual(
                DayPlural.category(11, language: language),
                DayPlural.category(21, language: language),
                "\(language): 11 must not take the form 21 takes"
            )
        }
        XCTAssertEqual(DayPlural.category(1, language: "pl"), .one)
        XCTAssertEqual(DayPlural.category(21, language: "pl"), .many, "only one is one in Polish")
        XCTAssertEqual(DayPlural.category(11, language: "pl"), .many)
    }

    /// French counts zero as singular, and is the only shipped language that does.
    func testFrenchCountsZeroAsSingular() {
        XCTAssertEqual(DayPlural.category(0, language: "fr"), .one)
        XCTAssertEqual(DayPlural.category(0, language: "de"), .other)
    }

    /// A language the catalogue does not know falls back to the English rule
    /// rather than crashing or picking a form at random.
    func testAnUnknownLanguageTakesTheEnglishRule() {
        XCTAssertEqual(DayPlural.category(1, language: "xx"), .one)
        XCTAssertEqual(DayPlural.category(2, language: "xx"), .other)
    }
}
