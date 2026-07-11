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

import Foundation
import UIKit
import PotillusKit

// =============================================================================
// ScreenshotMode.swift – deterministic App Store screenshot capture
// =============================================================================
//
// Enabled by the `-screenshotMode` launch argument (set by the PotillusUITests
// target added in patch -101). It replaces the live composition root with an
// EPHEMERAL one whose clock is frozen at the pinned date and whose database is
// seeded from the shared demo fixture, so every locale renders the same, dated
// data. This is the iOS counterpart of Android's ScreenshotClock +
// demo-backup.json flow, and it leaves no trace on disk.
//
// CONTRACT with the UI-test target (patch -101):
//   -screenshotMode                launch argument — enable this mode
//   SCREENSHOT_FIXTURE_JSON  env   the demo backup, as JSON text
//   SCREENSHOT_LOCALE        env   the store locale, for the report file name
//
// The two report pages 07/08 are produced here as well: the report is rendered
// to a PDF programmatically (no system "Save as PDF" dialog, unlike the manual
// Android step) and written into the app's Documents directory, from where the
// fastlane recipe pulls it with `xcrun simctl get_app_container` and rasterizes
// it with pdftoppm.
//
// Everything here runs ONLY when the launch argument is present, so a normal
// build never constructs an ephemeral store or reads the fixture.
// =============================================================================

enum ScreenshotMode {

    /// The frozen "today". Must equal the Makefile's SCREENSHOT_DATE and sit on or
    /// after the demo fixture's last logged day (the fixture spans 2026-01-01 ..
    /// 2026-06-30). Noon UTC keeps the resolved logical day clear of any
    /// day-change boundary in every real time zone.
    static let pinnedDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 30
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)
            ?? Date(timeIntervalSince1970: 1_782_820_800)
    }()

    /// The frozen day, as the `yyyy-MM-dd` string the domain speaks.
    static let pinnedDay = "2026-06-30"

    /// The first day of the demo period; the report spans this to `pinnedDay`.
    static let periodStart = "2026-01-01"

    /// Whether the app was launched for a screenshot run.
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    /// Builds the ephemeral, clock-pinned environment and kicks off the seed and
    /// the report render in the background. Returns nil only if even the empty
    /// in-memory environment cannot be built.
    ///
    /// The seed lands asynchronously; the screens refresh through their own
    /// database observation once the rows arrive, and the UI test waits for that
    /// content before it snapshots. Nothing blocks the launch.
    static func makeEnvironment() -> AppEnvironment? {
        guard let environment = try? AppEnvironment.makeEphemeral(
            clock: FixedClock(pinnedDate)
        ) else {
            return nil
        }
        Task.detached {
            await seedThenRenderReport(into: environment)
        }
        return environment
    }

    /// Seeds the database from `SCREENSHOT_FIXTURE_JSON`, then renders the report.
    /// Order matters: the report reads the seeded rows, so the import must finish
    /// before the render begins.
    private static func seedThenRenderReport(into environment: AppEnvironment) async {
        if let json = ProcessInfo.processInfo.environment["SCREENSHOT_FIXTURE_JSON"],
           let data = json.data(using: .utf8),
           let backup = try? BackupReader.parse(data) {
            _ = try? await environment.importer.restore(backup, mode: .replace)
        }
        await renderReport(from: environment)
    }

    /// Renders the two-page report for the demo period to a PDF and writes it into
    /// the app's Documents directory as `screenshot_report_<locale>.pdf`. Same
    /// three-step chain the export screen uses (data computes, renderer writes the
    /// HTML, printer paginates); only the destination differs — a file, not the
    /// document browser.
    @MainActor
    private static func renderReport(from environment: AppEnvironment) async {
        do {
            let entries = try environment.entries.inRange(from: periodStart, to: pinnedDay)
            // A report of nothing is not a report; the seed should always land, but
            // never write an empty file the recipe would then rasterize.
            guard !entries.isEmpty else { return }

            let settings = await environment.preferences.load()
            guard let data = ReportData.make(
                entries: entries,
                drinks: try environment.drinks.allOnce(),
                settings: settings,
                periodEnd: pinnedDay,
                today: pinnedDay
            ) else {
                return
            }

            let html = ReportRenderer.render(
                data: data,
                context: ReportRenderer.Context(
                    template: try ReportTemplate.load(),
                    appVersion: AppInfo.version,
                    systemVersion: UIDevice.current.systemVersion,
                    exportDate: pinnedDate,
                    locale: Loc.locale(for: settings.language),
                    labels: ReportLabels(language: settings.language)
                )
            )

            let pdf = try await ReportPdfPrinter().pdfData(html: html)
            let locale = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"]
                ?? Locale.current.identifier
            let directory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            )[0]
            try pdf.write(to: directory.appendingPathComponent("screenshot_report_\(locale).pdf"))
        } catch {
            // Screenshot builds only: a missing PDF is the recipe's own signal that
            // the report step failed, so there is nothing to surface from here.
        }
    }
}
