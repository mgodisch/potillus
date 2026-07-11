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
// TemplateTests
// =============================================================================
//
// The shared vectors carry the cases both platforms must agree on. The tests
// below them cover what a JSON vector cannot express: that the two regex engines
// were made to agree about which characters may form a key.
// =============================================================================

final class TemplateTests: XCTestCase {

    private static var loadedVectors: TemplateVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("template-render", as: TemplateVectors.self)
        } catch {
            XCTFail("Could not load the shared template vectors: \(error)")
        }
    }

    private var vectors: TemplateVectors { Self.loadedVectors }

    // ── The shared contract ──────────────────────────────────────────────────

    func testRenderAgainstSharedVectors() {
        for testCase in vectors.render {
            let actual = Template.render(
                template: testCase.template,
                scalars: testCase.scalars,
                repeats: testCase.repeats
            )
            XCTAssertEqual(actual, testCase.expected, "render: \(testCase.description)")
        }
    }

    /// Cheap insurance against a vector file that silently lost its cases.
    func testTheVectorFileIsNotEmpty() {
        XCTAssertGreaterThanOrEqual(vectors.render.count, 20)
    }

    // ── What the vectors cannot say ──────────────────────────────────────────

    /// A key is ASCII, because Kotlin's `\w` is ASCII.
    ///
    /// This cannot live in a shared vector. Android's UNIT tests run on the JVM,
    /// whose `\w` is `[a-zA-Z0-9_]`, but the app on a device uses ICU, whose `\w`
    /// also matches `Ö`. The two Android regex engines disagree with each other,
    /// so there is no single "Android behaviour" for a vector to pin. `Template`
    /// spells the class out and matches the JVM — the behaviour Android's own
    /// tests assert — and this test says so out loud.
    func testAKeyIsAsciiEvenThoughTheValueNeedNotBe() {
        let rendered = Template.render(
            template: "{{TÖTAL}} {{TOTAL}}",
            scalars: ["TÖTAL": "substituted", "TOTAL": "Grüße & Küsse"]
        )
        XCTAssertEqual(
            rendered, "{{TÖTAL}} Grüße &amp; Küsse",
            "a non-ASCII key is not a placeholder; a non-ASCII value passes through"
        )
    }

    /// `stringByReplacingMatches(in:withTemplate:)` would read `$1` in the VALUE as
    /// a back-reference into the match. Kotlin's replacement lambda does not, so
    /// `Template` must not either.
    func testADollarSignInAValueIsNotABackReference() {
        XCTAssertEqual(
            Template.render(template: "{{V}}", scalars: ["V": "$1 and \\1"]),
            "$1 and \\1"
        )
    }

    /// Same hazard, one level deeper: the value arrives from a row rather than the
    /// document.
    func testADollarSignInARowValueIsNotABackReference() {
        XCTAssertEqual(
            Template.render(
                template: "<!-- repeat:R -->{{V}}<!-- end:R -->",
                scalars: [:],
                repeats: ["R": [["V": "$0"]]]
            ),
            "$0"
        )
    }

    /// The report passes every block name it knows, some with no rows. The block
    /// and its markers must both disappear, or the PDF shows an HTML comment.
    func testEveryBlockOfTheRealTemplateCanCollapse() throws {
        let template = try String(
            data: TestVectors.repositoryFile("report/report_template.html"),
            encoding: .utf8
        )
        let html = try XCTUnwrap(template)

        let names = ["BARS", "BARSLABELS", "CATEGORIES", "HBARS", "HLABELS",
                     "KPIS", "MONTHS", "PIE_SLICES", "WDBARS", "WDLABELS"]
        let emptied = Template.render(
            template: html,
            scalars: [:],
            repeats: Dictionary(uniqueKeysWithValues: names.map { ($0, [[String: String]]()) })
        )

        XCTAssertFalse(emptied.contains("<!-- repeat:"), "a repeat marker survived")
        XCTAssertFalse(emptied.contains("<!-- end:"), "an end marker survived")
    }

    /// Every block the template declares must be listed in the test above, or the
    /// test would pass while a new block quietly went unrendered.
    func testTheTemplateDeclaresExactlyTheBlocksWeExpect() throws {
        let template = try String(
            data: TestVectors.repositoryFile("report/report_template.html"),
            encoding: .utf8
        )
        let html = try XCTUnwrap(template)

        let regex = try NSRegularExpression(pattern: "<!--\\s*repeat:(\\w+)\\s*-->")
        let range = NSRange(html.startIndex..., in: html)
        let found = Set(regex.matches(in: html, range: range).compactMap { match -> String? in
            guard let captured = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[captured])
        })

        XCTAssertEqual(
            found,
            ["BARS", "BARSLABELS", "CATEGORIES", "HBARS", "HLABELS",
             "KPIS", "MONTHS", "PIE_SLICES", "WDBARS", "WDLABELS"],
            "the template's repeat blocks changed; update the renderer and this test"
        )
    }
}
