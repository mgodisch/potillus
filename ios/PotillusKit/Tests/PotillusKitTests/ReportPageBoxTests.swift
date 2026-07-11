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

final class ReportPageBoxTests: XCTestCase {

    func testTheOverrideLandsInsideTheHead() throws {
        let html = "<html><head><title>x</title></head><body></body></html>"
        let out = ReportPageBox.inject(into: html)

        let head = try XCTUnwrap(out.range(of: "</head>"))
        let style = try XCTUnwrap(out.range(of: ".sheet { min-height: 0; }"))
        XCTAssertLessThan(style.lowerBound, head.lowerBound, "the style must precede </head>")
    }

    /// The template's own `.sheet` rule has the same specificity, so the later rule
    /// wins. Landing last in the head is the whole mechanism.
    func testTheOverrideComesAfterTheTemplatesOwnRule() throws {
        let html = "<html><head><style>.sheet { min-height: 267mm; }</style></head><body></body></html>"
        let out = ReportPageBox.inject(into: html)

        let original = try XCTUnwrap(out.range(of: "267mm"))
        let override = try XCTUnwrap(out.range(of: "min-height: 0;"))
        XCTAssertLessThan(original.lowerBound, override.lowerBound)
    }

    func testTheDocumentIsOtherwiseUntouched() {
        let html = "<html><head></head><body><p>Beer</p></body></html>"
        let out = ReportPageBox.inject(into: html)

        XCTAssertTrue(out.contains("<p>Beer</p>"))
        XCTAssertTrue(out.hasPrefix("<html><head>"))
        XCTAssertTrue(out.hasSuffix("</body></html>"))
    }

    /// A wrong-sized report is visible. A `<style>` spliced somewhere unknown is not.
    func testADocumentWithoutAHeadIsReturnedUnchanged() {
        let html = "<p>no head here</p>"
        XCTAssertEqual(ReportPageBox.inject(into: html), html)
    }

    func testInjectionHappensOnceEvenWithSeveralSheets() {
        let html = """
            <html><head></head><body>
            <div class="sheet">one</div>
            <div class="sheet">two</div>
            </body></html>
            """
        let out = ReportPageBox.inject(into: html)
        XCTAssertEqual(out.components(separatedBy: "min-height: 0;").count - 1, 1)
    }

    /// Nothing here may clip: a sheet whose content one day outgrows a page must
    /// break across two, not lose rows from an alcohol report in silence.
    func testTheOverrideNeverClips() {
        XCTAssertFalse(ReportPageBox.stylesheet.contains("overflow"))
        XCTAssertFalse(ReportPageBox.stylesheet.contains("max-height"))
    }

    /// `auto` is what pins the disclaimer to the sheet's bottom. With the height
    /// gone, that bottom is the content's, and the gap would collapse to nothing.
    func testTheFooterIsUnpinnedAndSpaced() {
        XCTAssertTrue(ReportPageBox.stylesheet.contains(".sheet > .disclaimer"))
        XCTAssertTrue(ReportPageBox.stylesheet.contains("margin-top: 18pt"))
        XCTAssertFalse(ReportPageBox.stylesheet.contains("margin-top: auto"))
    }
}
