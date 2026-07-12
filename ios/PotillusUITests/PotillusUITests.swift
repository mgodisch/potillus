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

// =============================================================================
// PotillusUITests.swift – App Store screenshot capture
// =============================================================================
//
// Driven by `fastlane snapshot` (see fastlane/Snapfile), which runs this one test
// once per store locale and saves each `snapshot(...)` frame into
// fastlane/screenshots/ios/<locale>/. The Makefile's `screenshots-ios` target
// wraps the whole thing; nobody drives the app by hand.
//
// The app is launched in the deterministic screenshot mode added in patch -100:
// `-screenshotMode` swaps in an ephemeral, clock-pinned store seeded from the
// demo fixture, so every locale shows the same dated data. The fixture travels as
// JSON in `SCREENSHOT_FIXTURE_JSON`; the store locale travels in
// `SCREENSHOT_LOCALE` so the app can name the report PDF it writes for pages
// 07/08.
//
// Navigation is by `accessibilityIdentifier` only (`tab.*`, `nav.*`), never by
// visible label — the labels are localised, the identifiers are not, and the same
// path must hold across all 21 store locales. Sheets are dismissed with a downward
// swipe for the same reason (the Cancel button's title is localised).
// =============================================================================

final class PotillusUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)

        app.launchArguments += ["-screenshotMode"]
        if let url = Bundle(for: type(of: self)).url(forResource: "demo-backup", withExtension: "json"),
           let json = try? String(contentsOf: url, encoding: .utf8) {
            app.launchEnvironment["SCREENSHOT_FIXTURE_JSON"] = json
        }
        // BCP-47 (e.g. "de-DE", "zh-Hans", "pt-BR") — the same shape as the store
        // locale directory names, so the report file the app writes matches.
        app.launchEnvironment["SCREENSHOT_LOCALE"] = Locale.preferredLanguages.first ?? "en-US"
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 60), "the tab bar never appeared")

        // 01 — Today. Wait for the seed to land (the first row) before shooting, so
        // the capture is never of an empty, still-loading screen.
        _ = app.cells.firstMatch.waitForExistence(timeout: 30)
        snapshot("01_today")

        // Tabs are addressed by position, not identifier: SwiftUI does not forward a
        // view's accessibilityIdentifier onto its tab-bar button (so `tab.*` never
        // matched), and the visible titles are localized. The order matches
        // RootView's TabView: 0 Today, 1 Calendar, 2 Statistics, 3 Drinks.
        tabBar.buttons.element(boundBy: 1).tap()
        snapshot("02_calendar")

        tabBar.buttons.element(boundBy: 2).tap()
        snapshot("03_statistics")

        tabBar.buttons.element(boundBy: 3).tap()
        snapshot("04_drinks")

        // 06 — Settings, opened from Today's toolbar, then dismissed with a swipe.
        tabBar.buttons.element(boundBy: 0).tap()
        app.buttons["nav.settings"].tap()
        snapshot("06_settings")
        app.swipeDown(velocity: .fast)

        // 05 — Add a drink. Shot last, so no dismissal is needed afterwards.
        app.buttons["nav.addDrink"].tap()
        snapshot("05_add_drink")
    }
}
