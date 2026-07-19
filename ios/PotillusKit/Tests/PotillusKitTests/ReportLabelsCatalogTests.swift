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
// ReportLabelsCatalog – exercise every language's label builder
// =============================================================================
//
// ReportLabels(language:) dispatches to one applyXX() builder per shipping
// language (see Domain/ReportLabelsCatalog.swift). Those builders' WORD-FOR-WORD
// correctness against Android is verified separately by tools/check-l10n-parity.py;
// what the unit suite adds here is STRUCTURAL: building the labels for every
// language must run each builder and its per-language closures, and must never
// leave a report string empty. That both guards against a builder that forgets a
// field (or a closure that returns "") and gives the catalog the coverage the rest
// of the kit already has.
//
// The assertions are intentionally language-agnostic (non-emptiness, interpolation,
// the English fallback), so they hold in all 21 languages without duplicating the
// parity check's word-level expectations.
// =============================================================================

final class ReportLabelsCatalogTests: XCTestCase {

    /// Every language the report can render, plus the two inputs `reportTag(for:)`
    /// treats specially: the empty "System" choice and an unmapped tag.
    private var languages: [String] {
        ReportLabels.supportedLanguages + ["", "xx-unmapped"]
    }

    /// Building the labels for every language must run each applyXX() builder and
    /// leave no plain (non-closure) report string empty.
    func testEveryLanguageProducesCompleteLabels() {
        for language in languages {
            let labels = ReportLabels(language: language)
            let strings: [String] = [
                labels.title, labels.footer1,
                labels.sectionKpis, labels.sectionMonths, labels.sectionTrend,
                labels.sectionCategories, labels.sectionDaytime,
                labels.sectionWeekday, labels.sectionRisk,
                labels.metaExportDate, labels.metaPeriod, labels.metaLimit,
                labels.metaWeight, labels.metaLongestAbstinence,
                labels.metaCurrentAbstinence,
                labels.unitGramsPerDay, labels.unitGramsPerWeek,
                labels.unitDrinkDaysPerWeek,
                labels.kpiTotal, labels.kpiAvgPerDay, labels.kpiAvgPerDrinkDay,
                labels.kpiMedianPerDay, labels.kpiMedianPerDrinkDay,
                labels.kpiDrinkDays, labels.kpiAbstinentDays,
                labels.kpiMaxPerDay, labels.kpiMaxPer7Days,
                labels.kpiAvgDrinkDaysPerMonth, labels.kpiMedianDrinkDaysPerMonth,
                labels.columnMonth, labels.columnDrinkDays, labels.columnTotalGrams,
                labels.columnAvgPerDay, labels.columnOverDaily,
                labels.categoryHeading,
            ]
            for (index, value) in strings.enumerated() {
                XCTAssertFalse(
                    value.isEmpty,
                    "empty plain label #\(index) for language '\(language)'"
                )
            }
        }
    }

    /// The per-language closures — the drink-category names, the plural "days"
    /// form, and the number-bearing KPI strings — must run and return non-empty
    /// text for every language. Calling `category` for each stored key also covers
    /// the nested switch inside every builder's category closure, including its
    /// `default`.
    func testEveryLanguageClosuresReturnNonEmpty() {
        let categoryKeys = ["BEER", "WINE", "SPIRITS", "LONGDRINK", "LIQUEUR",
                            "UNMAPPED"]
        for language in languages {
            let labels = ReportLabels(language: language)
            for key in categoryKeys {
                XCTAssertFalse(
                    labels.category(key).isEmpty,
                    "empty category '\(key)' for language '\(language)'"
                )
            }
            for count in [0, 1, 2, 5, 21] {
                XCTAssertFalse(
                    labels.days(count).isEmpty,
                    "empty days(\(count)) for language '\(language)'"
                )
            }
            XCTAssertFalse(labels.kpiBinge("60").isEmpty)
            XCTAssertFalse(labels.riskBingeDays("60").isEmpty)
            XCTAssertFalse(labels.kpiOverDaily("24").isEmpty)
            XCTAssertFalse(labels.kpiOverWeekly("168").isEmpty)
            XCTAssertFalse(labels.kpiOverDrinkDays(5).isEmpty)
        }
    }

    /// `footer2` is deliberately English on both platforms, but it must still
    /// interpolate the app and system versions it is given.
    func testFooter2InterpolatesVersions() {
        let footer = ReportLabels.footer2(appVersion: "0.84.0", systemVersion: "17.4")
        XCTAssertTrue(footer.contains("0.84.0"), "footer2 dropped the app version")
        XCTAssertTrue(footer.contains("17.4"), "footer2 dropped the system version")
    }

    /// An unmapped, non-empty tag keeps the English defaults (the switch's
    /// `default` branch), so its title equals the default initializer's; the empty
    /// "System" choice resolves through `reportTag(for:)` to a complete, non-empty
    /// title.
    func testReportTagFallbacks() {
        XCTAssertEqual(
            ReportLabels(language: "xx-unmapped").title,
            ReportLabels().title,
            "an unmapped tag should keep the English default title"
        )
        XCTAssertFalse(
            ReportLabels(language: "").title.isEmpty,
            "the System choice should still yield a title"
        )
    }
}
