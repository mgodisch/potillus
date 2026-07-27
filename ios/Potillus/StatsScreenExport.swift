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
    /// The offered range starts at the configured "statistics from" floor — a
    /// user who scoped the statistics to a date wants exports scoped the same
    /// way. Without a floor it starts at the first day the visible period
    /// covers (`model.state.from`), so the dialog proposes the period on
    /// screen. Android's export dialog pre-fills by the same rule
    /// (StatsScreen's `exportFrom`).
    func beginExport(_ kind: ExportRangeSheet.Kind) async {
        let settings = await environment.preferences.load()
        let floor = settings.statsFromDate.isEmpty ? model.state.from : settings.statsFromDate

        guard
            let start = DayResolver.parseDate(floor),
            let end = DayResolver.parseDate(model.state.today)
        else {
            exportFailure = Loc.string("The statistics period could not be read.", locale: locale)
            return
        }

        exportDefaults = (from: start, to: end)
        pendingExport = kind
    }

    /// Sends the confirmed range to whichever exporter asked for it.
    func runExport(_ kind: ExportRangeSheet.Kind, from: String, to: String) async {
        switch kind {
        case .csv: await prepareCsv(from: from, to: to)
        case .pdf: await preparePdf(from: from, to: to)
        }
    }

    /// Builds the CSV for the VISIBLE period, then presents the document browser.
    ///
    /// The range is `state.from ... state.to`, so what the user exports is what
    /// the screen shows. Filtering happens in SQLite, over the index on
    /// `logicalDate`, rather than by loading the whole log into memory — the same
    /// choice Android's `exportCsv` makes, and for the same reason.
    func prepareCsv(from: String, to: String) async {
        do {
            let entries = try environment.entries.inRange(from: from, to: to)
            // Android refuses an empty export rather than writing a lone header.
            // A file with no rows looks like a broken export, not an empty period.
            guard !entries.isEmpty else {
                exportFailure = Loc.string("No entries in this period.", locale: locale)
                return
            }

            // The export follows the UI language, as Android's does: an empty tag
            // ("System") falls back to the English captions. The header cells come
            // from `CsvHeaderLabels`, the drink names from the user's own data.
            let language = await environment.preferences.load().language
            let csv = CsvExporter.buildCsv(
                headerCells: CsvHeaderLabels.cells(language: language),
                entries: entries,
                drinks: try environment.drinks.allOnce()
            )
            exportedCsv = CsvDocument(data: CsvExporter.fileData(csv: csv))
            isExporting = true
        } catch {
            exportFailure = describeExportFailure(error)
        }
    }

    /// `MAJOR.MINOR.PATCH`, defined once in `AppInfo`; the report footer and the
    /// About screen read the same value rather than two copies of the lookup.
    static var appVersion: String { AppInfo.version }

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
                exportFailure = Loc.string("No entries in this period.", locale: locale)
                return
            }

            // The model already resolved the logical today when it loaded the
            // window; asking a clock again could straddle the day-change hour and
            // give the report a different today than the screen behind it.
            let settings = await environment.preferences.load()
            // `locale` and `timeZone` are left at their defaults deliberately:
            // both describe the DEVICE, not the in-app language. See the
            // parameter documentation on `ReportData.make` — the weekday
            // column order follows the phone's region, while the labels below
            // follow `settings.language`.
            guard let data = ReportData.make(
                entries: entries,
                drinks: try environment.drinks.allOnce(),
                settings: settings,
                periodEnd: to,
                today: model.state.today
            ) else {
                exportFailure = Loc.string("No entries in this period.", locale: locale)
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
            exportFailure = describeExportFailure(error)
        }
    }

    /// The user-facing text for an export that could not be completed.
    ///
    /// The alert's TITLE is localized ("Export failed"); before the 0.84.0 QA round
    /// its BODY was the bare `String(describing: error)`, so every one of the twenty
    /// non-English languages showed an English Swift error dump under a translated
    /// heading. `SettingsScreen.describeBackupFailure` already solved the same
    /// problem for the backup pickers, and Android answers the same event with the
    /// localized `export_failed`; this is that shape, for the export side.
    ///
    /// The technical detail is KEPT, not dropped: it rides inside the localized
    /// frame exactly as `describeBackupFailure`'s `default` case does with
    /// "Read error: %@". That honours the content policy on `TodayModel.failure` —
    /// an unforeseeable diagnostic stays quotable into a bug report — while the
    /// sentence around it follows the in-app language.
    ///
    /// The FORESEEABLE export failures do not come through here at all: an empty
    /// period and an unreadable statistics window are mapped to their own sentences
    /// at the call sites above.
    ///
    /// - Parameter error: The failure thrown by the exporter or returned by the
    ///   system file picker.
    /// - Returns: A localized sentence carrying the technical description.
    func describeExportFailure(_ error: Error) -> String {
        Loc.string("Export error: %@", String(describing: error), locale: locale)
    }
}
