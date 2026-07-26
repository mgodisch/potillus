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

    /// The teens, called out on their own. 11 to 14 end in 1 to 4 and take
    /// neither of the forms those digits otherwise select, in Polish, Russian and
    /// Ukrainian alike. This is the case a rule written as `n % 10 == 1` gets
    /// wrong, and it would read as a real word.
    func testTheTeensDoNotFollowTheirLastDigit() {
        for language in ["pl", "ru", "uk"] {
            XCTAssertNotEqual(
                DayPlural.category(11, language: language),
                DayPlural.category(21, language: language),
                "\(language): 11 must not take the form 21 takes"
            )
            XCTAssertNotEqual(
                DayPlural.category(12, language: language),
                DayPlural.category(22, language: language),
                "\(language): 12 must not take the form 22 takes"
            )
        }
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
