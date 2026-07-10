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
// ReportRendererTests
// =============================================================================
//
// There is deliberately NO golden HTML file here.
//
// The template exists so that a person can rearrange the report by hand — column
// widths, page breaks, section order — without touching code. A golden file would
// turn every such edit into a failing test and a diff to re-bless, and the tool
// would be fighting the thing it was built for.
//
// So these tests assert PROPERTIES that must hold whatever the layout becomes: no
// placeholder is left unfilled, every block has the right number of rows, the
// numbers follow the report's locale, and the SVG numbers do not.
// =============================================================================

final class ReportRendererTests: XCTestCase {

    // ── Fixtures ─────────────────────────────────────────────────────────────

    private func loadTemplate() throws -> String {
        let data = try TestVectors.repositoryFile("report/report_template.html")
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func settings() -> AppSettings {
        var value = AppSettings()
        value.dailyLimitGrams = 24
        value.weeklyLimitGrams = 168
        value.maxDrinkDaysPerWeek = 5
        value.weightKg = 80
        return value
    }

    private func entries() -> [ConsumptionEntry] {
        // Three months, so the monthly table has rows and the chart has buckets.
        // 2026-03-02 is a Monday.
        let days = ["2026-03-02", "2026-03-05", "2026-03-20", "2026-04-01",
                    "2026-04-02", "2026-05-11", "2026-05-30"]
        // March stays inside the 24 g limit; April and May do not. The report must
        // be able to show both a clean month and a warned one.
        let grams = [10.0, 20.0, 15.0, 40.0, 50.0, 60.0, 70.0]

        return zip(days, grams).enumerated().map { index, pair in
            ConsumptionEntry(
                id: Int64(index + 1), drinkId: Int64(index % 2 + 1), drinkName: "d",
                volumeMl: 500, alcoholPercent: 5, gramsAlcohol: pair.1,
                timestampMillis: 1_772_411_400_000, logicalDate: pair.0
            )
        }
    }

    private func drinks() -> [DrinkDefinition] {
        [
            DrinkDefinition(id: 1, name: "Beer", volumeMl: 500, alcoholPercent: 5,
                            isPreset: true, isFavorite: false, category: .beer),
            DrinkDefinition(id: 2, name: "Wine", volumeMl: 200, alcoholPercent: 12,
                            isPreset: true, isFavorite: false, category: .wine),
        ]
    }

    private func makeData(locale: Locale = Locale(identifier: "en_US")) throws -> ReportData {
        try XCTUnwrap(
            ReportData.make(
                entries: entries(), drinks: drinks(), settings: settings(),
                periodEnd: "2026-05-30", today: "2026-06-10",
                timeZone: TimeZone(identifier: "UTC")!, locale: locale
            )
        )
    }

    private func context(
        template: String, locale: Locale = Locale(identifier: "en_US")
    ) -> ReportRenderer.Context {
        ReportRenderer.Context(
            template: template, appVersion: "0.81.0", systemVersion: "17.4",
            exportDate: Date(timeIntervalSince1970: 1_781_000_000), locale: locale
        )
    }

    /// The template documents itself in an HTML comment, and that comment contains
    /// the literal token `{{PLACEHOLDER}}` as an example. It is not a placeholder
    /// the renderer must fill, so comments come out before we look for leftovers.
    private func strippingComments(_ html: String) -> String {
        // `(?s)` lets `.` cross a line break. Without it the template's multi-line
        // documentation comment survives, carrying its example `{{PLACEHOLDER}}`
        // into the assertion below and failing it for the wrong reason.
        html.replacingOccurrences(
            of: "(?s)<!--.*?-->", with: "", options: [.regularExpression]
        )
    }

    // ── Nothing left behind ──────────────────────────────────────────────────

    func testEveryPlaceholderIsFilled() throws {
        let html = ReportRenderer.render(
            data: try makeData(), context: context(template: try loadTemplate())
        )
        let body = strippingComments(html)

        XCTAssertFalse(
            body.contains("{{"),
            "an unfilled placeholder would print verbatim in the PDF"
        )
    }

    func testNoRepeatMarkerSurvives() throws {
        let html = ReportRenderer.render(
            data: try makeData(), context: context(template: try loadTemplate())
        )
        XCTAssertFalse(html.contains("<!-- repeat:"))
        XCTAssertFalse(html.contains("<!-- end:"))
    }

    /// The renderer must know every block the template declares. If someone adds
    /// one, this fails before the PDF shows an HTML comment where a table should be.
    func testTheRendererFillsExactlyTheBlocksTheTemplateDeclares() throws {
        let template = try loadTemplate()
        let regex = try NSRegularExpression(pattern: "<!--\\s*repeat:(\\w+)\\s*-->")
        let range = NSRange(template.startIndex..., in: template)
        let declared = Set(regex.matches(in: template, range: range).compactMap { match -> String? in
            guard let captured = Range(match.range(at: 1), in: template) else { return nil }
            return String(template[captured])
        })

        let filled = Set(
            ReportRenderer.repeats(
                data: try makeData(), context: context(template: template)
            ).keys
        )
        XCTAssertEqual(declared, filled)
    }

    // ── Row counts ───────────────────────────────────────────────────────────

    func testTheChartsHaveExactlyAsManyBarsAsTheyHaveLabels() throws {
        let data = try makeData()
        let context = self.context(template: try loadTemplate())
        let blocks = ReportRenderer.repeats(data: data, context: context)

        XCTAssertEqual(blocks["HBARS"]?.count, 24, "one bar per clock hour")
        XCTAssertEqual(blocks["HLABELS"]?.count, 24)
        XCTAssertEqual(blocks["WDBARS"]?.count, 7, "one bar per weekday")
        XCTAssertEqual(blocks["WDLABELS"]?.count, 7)
        XCTAssertEqual(blocks["BARS"]?.count, data.chartBuckets.count)
        XCTAssertEqual(blocks["BARSLABELS"]?.count, data.chartBuckets.count)
        XCTAssertEqual(blocks["MONTHS"]?.count, data.months.count)
        XCTAssertEqual(blocks["CATEGORIES"]?.count, data.categories.count)
        XCTAssertEqual(blocks["PIE_SLICES"]?.count, data.categories.count)
        XCTAssertEqual(blocks["KPIS"]?.count, 16, "the grid is four across and four down")
    }

    /// Only a few buckets carry a tick label; the rest of the cells are empty, so
    /// each label sits under its own bar.
    func testOnlySomeTrendBucketsAreLabelled() throws {
        let data = try makeData()
        let rows = ReportRenderer.trendLabelRows(
            data: data, context: context(template: try loadTemplate())
        )
        let labelled = rows.filter { !($0["BAR_LABEL"] ?? "").isEmpty }.count
        XCTAssertEqual(labelled, ReportChart.labelIndices(count: data.chartBuckets.count).count)
        XCTAssertFalse(rows.first?["BAR_LABEL"]?.isEmpty ?? true, "the first bucket is labelled")
        XCTAssertFalse(rows.last?["BAR_LABEL"]?.isEmpty ?? true, "and so is the last")
    }

    // ── Locale ───────────────────────────────────────────────────────────────

    /// Reader-facing numbers follow the report's locale; SVG numbers never do.
    func testGermanNumbersUseACommaButSvgAttributesDoNot() throws {
        let german = Locale(identifier: "de_DE")
        let html = ReportRenderer.render(
            data: try makeData(locale: german),
            context: context(template: try loadTemplate(), locale: german)
        )

        XCTAssertTrue(html.contains("24,0 g/day"), "the daily limit reads with a comma")

        // A comma inside stroke-dasharray would split one value into two and paint
        // the whole ring. Every dasharray must hold exactly two dot-decimals.
        let regex = try NSRegularExpression(pattern: "stroke-dasharray=\"([^\"]*)\"")
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        XCTAssertFalse(matches.isEmpty, "the donut is drawn")

        for match in matches {
            let value = try XCTUnwrap(Range(match.range(at: 1), in: html))
            XCTAssertFalse(String(html[value]).contains(","), "a comma would split the value")
        }
    }

    func testTheDocumentLanguageIsTaggedForTheGlyphChoice() throws {
        let japanese = Locale(identifier: "ja_JP")
        let values = ReportRenderer.scalars(
            data: try makeData(locale: japanese),
            context: context(template: try loadTemplate(), locale: japanese)
        )
        XCTAssertEqual(values["REPORT_LANG"], "ja-JP", "an underscore is not a BCP-47 tag")
    }

    // ── Individual values ────────────────────────────────────────────────────

    func testTheLicenceFooterIsEnglishAndNamesTheSystem() {
        let footer = ReportLabels.footer2(appVersion: "0.81.0", systemVersion: "17.4")
        XCTAssertTrue(footer.contains("v0.81.0"))
        XCTAssertTrue(footer.contains("iOS 17.4"))
        XCTAssertTrue(footer.contains("WITHOUT ANY WARRANTY"))
    }

    /// A month with no day over the limit prints an en dash, not a zero, so the
    /// column reads as a column.
    func testAMonthWithinTheLimitShowsADashRatherThanAZero() throws {
        let rows = ReportRenderer.monthRows(
            data: try makeData(), context: context(template: try loadTemplate())
        )
        let clean = rows.filter { $0["M_ROW_CLASS"] == "" }
        XCTAssertFalse(clean.isEmpty, "the fixture has a month within the limit")
        XCTAssertTrue(clean.allSatisfy { $0["M_OVER"] == "–" })
    }

    /// A weekday the period never contained draws no bar and prints no value.
    func testAnAbsentWeekdayIsBlankRatherThanZero() throws {
        let data = try makeData()
        let rows = ReportRenderer.weekdayBarRows(
            data: data, context: context(template: try loadTemplate())
        )
        for (row, average) in zip(rows, data.weekdayAverages) where average == nil {
            XCTAssertEqual(row["WD_VALUE"], "")
            XCTAssertEqual(row["WD_HEIGHT_PCT"], "0")
        }
    }

    /// Every category in the table has a swatch, and the donut has the same colour.
    func testTheTableSwatchAndTheDonutSliceAgree() throws {
        let data = try makeData()
        let context = self.context(template: try loadTemplate())
        let table = ReportRenderer.categoryRows(data: data, context: context)
        let donut = ReportRenderer.pieRows(data: data)

        XCTAssertEqual(table.map { $0["C_COLOR"] }, donut.map { $0["PIE_FILL"] })
    }

    /// A drink named `<script>` must not become one.
    func testAHostileCategoryLabelCannotBreakTheMarkup() throws {
        var labels = ReportLabels()
        labels.category = { _ in "<script>alert(1)</script>" }

        var context = self.context(template: try loadTemplate())
        context.labels = labels

        let html = ReportRenderer.render(data: try makeData(), context: context)
        XCTAssertFalse(html.contains("<script>alert(1)</script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    /// Weekday columns start where the locale starts its week.
    func testWeekdayLabelsFollowTheLocalesWeekStart() throws {
        let german = Locale(identifier: "de_DE")
        let american = Locale(identifier: "en_US")

        let germanRows = ReportRenderer.weekdayLabelRows(
            data: try makeData(locale: german),
            context: context(template: try loadTemplate(), locale: german)
        )
        let americanRows = ReportRenderer.weekdayLabelRows(
            data: try makeData(locale: american),
            context: context(template: try loadTemplate(), locale: american)
        )

        XCTAssertEqual(germanRows.count, 7)
        XCTAssertEqual(americanRows.count, 7)
        XCTAssertNotEqual(
            germanRows.first?["WD_NAME"], americanRows.first?["WD_NAME"],
            "Germany starts on Monday, the United States on Sunday"
        )
        XCTAssertTrue(
            germanRows.allSatisfy { ($0["WD_NAME"] ?? "").count <= 2 },
            "the column is two characters wide"
        )
    }
}
