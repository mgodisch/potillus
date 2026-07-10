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

final class ReportChartTests: XCTestCase {

    private static var loadedVectors: ReportChartVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("report-chart", as: ReportChartVectors.self)
        } catch {
            XCTFail("Could not load the shared chart vectors: \(error)")
        }
    }

    private var vectors: ReportChartVectors { Self.loadedVectors }
    private static let epsilon = 1e-9

    // ── The shared contract ──────────────────────────────────────────────────

    func testPercentAgainstSharedVectors() {
        for testCase in vectors.pct {
            XCTAssertEqual(
                ReportChart.percent(value: testCase.value, max: testCase.max),
                testCase.expected, accuracy: Self.epsilon, testCase.description
            )
        }
    }

    func testBarHeightAgainstSharedVectors() {
        for testCase in vectors.barHeight {
            XCTAssertEqual(
                ReportChart.barHeight(value: testCase.value, ceiling: testCase.ceiling),
                testCase.expected, accuracy: Self.epsilon, testCase.description
            )
        }
    }

    func testLabelIndicesAgainstSharedVectors() {
        for testCase in vectors.labelIndices {
            XCTAssertEqual(
                ReportChart.labelIndices(count: testCase.count),
                testCase.expected, testCase.description
            )
        }
    }

    func testCategoryColoursAgainstSharedVectors() {
        for testCase in vectors.categoryColor {
            XCTAssertEqual(
                ReportPalette.color(forCategory: testCase.categoryName),
                testCase.expected, testCase.categoryName
            )
        }
    }

    func testDonutSlicesAgainstSharedVectors() {
        for testCase in vectors.donut {
            let slices = ReportChart.donutSlices(fractions: testCase.fractions)
            XCTAssertEqual(slices.count, testCase.expected.count, testCase.description)
            for (actual, want) in zip(slices, testCase.expected) {
                XCTAssertEqual(actual.dash, want.dash, testCase.description)
                XCTAssertEqual(actual.gap, want.gap, testCase.description)
                XCTAssertEqual(actual.offset, want.offset, testCase.description)
            }
        }
    }

    // ── Properties the vectors imply but do not state ────────────────────────

    /// Sixteen of the first four hundred series lengths land on different indices
    /// in `Float` than in `Double`. This is the shape of that difference.
    func testTheStepIsAFloatAndItMatters() {
        // n = 32 is a month of daily buckets. In Double the seventh slot truncates
        // to 31 and collapses into the final index; in Float it lands on 30.
        XCTAssertEqual(ReportChart.labelIndices(count: 32), [0, 4, 8, 13, 17, 22, 26, 30, 31])

        // The same computation in Double, spelled out, to show it disagrees.
        let target = 8
        let doubleStep = Swift.max(Double(32 - 1) / Double(target - 1), 1.0)
        var inDouble = Set<Int>()
        for slot in 0..<target { inDouble.insert(Swift.min(Int(Double(slot) * doubleStep), 31)) }
        inDouble.insert(31)
        XCTAssertNotEqual(
            inDouble.sorted(), ReportChart.labelIndices(count: 32),
            "if these ever agree, the Float in labelIndices has been lost"
        )
    }

    /// The first and last bucket always carry a label, whatever the thinning does.
    func testTheFirstAndLastBucketAreAlwaysLabelled() {
        for count in 1...400 {
            let indices = ReportChart.labelIndices(count: count)
            XCTAssertEqual(indices.first, 0, "count \(count)")
            XCTAssertEqual(indices.last, count - 1, "count \(count)")
        }
    }

    /// Labels are strictly ascending and never point past the end.
    func testLabelIndicesAreSortedAndInRange() {
        for count in 0...400 {
            let indices = ReportChart.labelIndices(count: count)
            XCTAssertEqual(indices, indices.sorted(), "count \(count)")
            XCTAssertEqual(Set(indices).count, indices.count, "duplicates at count \(count)")
            XCTAssertTrue(indices.allSatisfy { $0 >= 0 && $0 < count }, "count \(count)")
        }
    }

    /// Beyond twelve buckets the axis is thinned, never dense.
    func testALongSeriesIsThinnedToAboutEightLabels() {
        XCTAssertEqual(ReportChart.labelIndices(count: 12).count, 12, "twelve are all labelled")
        for count in 13...400 {
            let labels = ReportChart.labelIndices(count: count).count
            XCTAssertLessThanOrEqual(labels, 9, "count \(count) drew \(labels) labels")
            XCTAssertGreaterThanOrEqual(labels, 7, "count \(count) drew \(labels) labels")
        }
    }

    /// The ring closes: the last slice ends exactly where the first began.
    func testTheDonutRingCloses() {
        let slices = ReportChart.donutSlices(fractions: [40, 35, 25])
        XCTAssertEqual(slices.first?.offset, "25.00", "the first slice starts at twelve o'clock")
        XCTAssertEqual(slices.last?.offset, "-50.00", "and the last picks up where the second left")
        XCTAssertEqual(slices.last?.dash, "25.00")
        XCTAssertEqual(slices.last?.gap, "75.00")
    }

    /// The number that must never follow the reader's locale.
    func testSvgNumbersAlwaysUseADot() {
        XCTAssertEqual(ReportChart.svgNumber(40.0), "40.00")
        XCTAssertEqual(ReportChart.svgNumber(33.333), "33.33")
        XCTAssertEqual(ReportChart.svgNumber(-50.0), "-50.00")
        XCTAssertFalse(ReportChart.svgNumber(1.5).contains(","), "a comma would split the value")
    }

    /// Every category the model can produce has a colour, and none of them carry a
    /// character that HTML escaping would rewrite on the way into the SVG.
    func testEveryCategoryHasAnEscapeSafeColour() {
        for category in DrinkCategory.allCases {
            let colour = ReportPalette.color(forCategory: category.rawValue)
            XCTAssertTrue(colour.hasPrefix("#"), "\(category)")
            XCTAssertEqual(colour.count, 7, "\(category)")
            XCTAssertEqual(
                Template.render(template: "{{C}}", scalars: ["C": colour]), colour,
                "the colour must survive HTML escaping unchanged"
            )
        }
    }

    /// An unknown name is not a crash and not a blank: it is the colour of OTHER.
    func testAnUnknownCategoryTakesTheColourOfOther() {
        XCTAssertEqual(
            ReportPalette.color(forCategory: "NONSENSE"),
            ReportPalette.color(forCategory: "OTHER")
        )
    }

    // ── Bar heights ──────────────────────────────────────────────────────────

    /// A dry weekday and a weekday that never happened draw the same bar. The
    /// difference is carried by the value printed above it.
    func testNothingAndZeroDrawTheSameBar() {
        XCTAssertEqual(ReportChart.barHeight(value: nil, ceiling: 100), 0.0)
        XCTAssertEqual(ReportChart.barHeight(value: 0, ceiling: 100), 0.0)
    }

    /// One beer in a heavy month must not round to nothing.
    func testATinyValueKeepsASliver() {
        XCTAssertEqual(
            ReportChart.barHeight(value: 0.01, ceiling: 500),
            ReportChart.minimumVisibleBar, accuracy: Self.epsilon
        )
    }
}
