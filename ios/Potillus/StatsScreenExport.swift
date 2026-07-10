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

import PotillusKit
import SwiftUI
import UIKit

// =============================================================================
// StatsScreen – exporting
// =============================================================================
//
// Split from StatsScreen.swift because the view outgrew SwiftLint's body limit,
// and the seam it offered was the right one: that file shows the statistics, this
// one carries them out of the app.
//
// Both exporters refuse an empty period rather than writing an empty file. Android
// does the same, and for the same reason: a file with no rows looks like a broken
// export, not like an empty month.
// =============================================================================

extension StatsScreen {

    /// The range sheet, built from the pre-fill `beginExport` resolved.
    ///
    /// It lives here rather than inline in `body` because the view had outgrown
    /// SwiftLint's limit, and because a sheet about exporting belongs beside the
    /// exporters. A missing pre-fill renders nothing: `beginExport` sets it before
    /// it sets `pendingExport`, so the sheet cannot appear without one.
    @ViewBuilder
    func exportRangeSheet(for kind: ExportRangeSheet.Kind) -> some View {
        if let defaults = exportDefaults {
            ExportRangeSheet(
                kind: kind,
                initialFrom: defaults.from,
                initialTo: defaults.to,
                latest: defaults.to,
                onConfirm: { from, to in
                    pendingExport = nil
                    Task { await runExport(kind, from: from, to: to) }
                },
                onCancel: { pendingExport = nil }
            )
        }
    }

    /// Resolves the sheet's pre-fill, then shows it.
    ///
    /// Android pre-fills with the "statistics from" date and today — NOT with the
    /// window on screen. Someone looking at July who imported a backup of last
    /// spring wants the spring, and the app should offer it rather than hide it
    /// behind a greyed-out button.
    ///
    /// An empty `statsFromDate` means "from the first entry", which the window's own
    /// start already expresses.
    func beginExport(_ kind: ExportRangeSheet.Kind) async {
        let settings = await environment.preferences.load()
        let floor = settings.statsFromDate.isEmpty ? model.state.from : settings.statsFromDate

        guard
            let start = DayResolver.parseDate(floor),
            let end = DayResolver.parseDate(model.state.today)
        else {
            exportFailure = "The statistics period could not be read."
            return
        }

        exportDefaults = (from: start, to: end)
        pendingExport = kind
    }

    /// Sends the confirmed range to whichever exporter asked for it.
    func runExport(_ kind: ExportRangeSheet.Kind, from: String, to: String) async {
        switch kind {
        case .csv: prepareCsv(from: from, to: to)
        case .pdf: await preparePdf(from: from, to: to)
        }
    }

    /// Builds the CSV for the VISIBLE period, then presents the document browser.
    ///
    /// The range is `state.from ... state.to`, so what the user exports is what
    /// the screen shows. Filtering happens in SQLite, over the index on
    /// `logicalDate`, rather than by loading the whole log into memory — the same
    /// choice Android's `exportCsv` makes, and for the same reason.
    func prepareCsv(from: String, to: String) {
        do {
            let entries = try environment.entries.inRange(from: from, to: to)
            // Android refuses an empty export rather than writing a lone header.
            // A file with no rows looks like a broken export, not an empty period.
            guard !entries.isEmpty else {
                exportFailure = "No entries in this period."
                return
            }

            let csv = CsvExporter.buildCsv(
                headerCells: CsvExporter.englishHeaderCells,
                entries: entries,
                drinks: try environment.drinks.allOnce()
            )
            exportedCsv = CsvDocument(data: CsvExporter.fileData(csv: csv))
            isExporting = true
        } catch {
            exportFailure = String(describing: error)
        }
    }

    /// `MAJOR.MINOR.PATCH`, with any build suffix removed.
    ///
    /// Android prints `BuildConfig.VERSION_NAME.substringBefore("-")` so that a
    /// debug build's `-debug` never reaches the footer. `MARKETING_VERSION` comes
    /// from `Version.xcconfig`, which `tools/gen-ios-version.py` derives from
    /// CHANGELOG.md, so the same rule applies for the same reason.
    static var appVersion: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        let version = (raw as? String) ?? "0.0.0"
        return String(version.prefix(while: { $0 != "-" }))
    }

    /// Builds the PDF report for the period on screen.
    ///
    /// Three steps, in three places, on purpose: `ReportData` computes, the
    /// renderer writes HTML, and the printer paginates. The first two are covered by
    /// tests; only the third needs a screen.
    ///
    /// The layout happens on the main actor because a `WKWebView` insists on it.
    /// The user sees a spinner in place of the export button, and the button is
    /// disabled meanwhile: a second tap would start a second web view.
    func preparePdf(from: String, to: String) async {
        isBuildingPdf = true
        defer { isBuildingPdf = false }

        do {
            let entries = try environment.entries.inRange(from: from, to: to)
            // Android refuses an empty report rather than printing empty tables. A
            // report of nothing is not a report; it is a page of dashes.
            guard !entries.isEmpty else {
                exportFailure = "No entries in this period."
                return
            }

            // The model already resolved the logical today when it loaded the
            // window; asking a clock again could straddle the day-change hour and
            // give the report a different today than the screen behind it.
            let settings = await environment.preferences.load()
            guard let data = ReportData.make(
                entries: entries,
                drinks: try environment.drinks.allOnce(),
                settings: settings,
                periodEnd: to,
                today: model.state.today
            ) else {
                exportFailure = "No entries in this period."
                return
            }

            // The report follows the UI language, as Android's does: the labels come
            // from that language and the locale drives numbers, dates, and the CJK
            // glyph orthography (REPORT_LANG). An empty tag ("System") yields English
            // labels and the current locale.
            let reportLocale = Loc.locale(for: settings.language)
            let html = ReportRenderer.render(
                data: data,
                context: ReportRenderer.Context(
                    template: try ReportTemplate.load(),
                    appVersion: Self.appVersion,
                    systemVersion: UIDevice.current.systemVersion,
                    exportDate: Date(),
                    locale: reportLocale,
                    labels: ReportLabels(language: settings.language)
                )
            )

            exportedPdf = PdfDocument(data: try await ReportPdfPrinter().pdfData(html: html))
            isExportingPdf = true
        } catch {
            exportFailure = String(describing: error)
        }
    }
}
