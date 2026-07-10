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
// SettingsModelTests.swift
// =============================================================================
//
// The model is thin; what it must guarantee is that NOTHING reaches the store
// unclamped, whatever a view hands it.
// =============================================================================

@MainActor
final class SettingsModelTests: XCTestCase {

    private var environment: AppEnvironment!
    private var model: SettingsModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
        model = SettingsModel(preferences: environment.preferences)
    }

    override func tearDown() async throws {
        model.stop()
        try await super.tearDown()
    }

    /// What actually landed in the store, bypassing the model's own copy.
    private func stored() async -> AppSettings {
        await environment.preferences.load()
    }

    // ── Every write is clamped ───────────────────────────────────────────────

    /// The slider cannot produce 9000 g. Something else might.
    func testAnOutOfRangeLimitIsClampedBeforeItReachesTheStore() async {
        await model.update { $0.dailyLimitGrams = 9_000 }

        let settings = await stored()
        XCTAssertEqual(settings.dailyLimitGrams, SettingsSanitizer.dailyLimitRange.upperBound)
        XCTAssertNil(model.failure)
    }

    func testAnImpossibleClockIsClamped() async {
        await model.update {
            $0.dayChangeHour = 47
            $0.dayChangeMinute = -3
        }

        let settings = await stored()
        XCTAssertEqual(settings.dayChangeHour, 23)
        XCTAssertEqual(settings.dayChangeMinute, 0)
    }

    func testDrinkDaysAreClampedIntoAWeek() async {
        await model.update { $0.maxDrinkDaysPerWeek = 99 }
        let clampedHigh = await stored().maxDrinkDaysPerWeek
        XCTAssertEqual(clampedHigh, 7)

        await model.update { $0.maxDrinkDaysPerWeek = 0 }
        let clampedLow = await stored().maxDrinkDaysPerWeek
        XCTAssertEqual(clampedLow, 1)
    }

    /// A NaN must not be clamped into the range; it must be rejected outright, or
    /// every gram total downstream becomes NaN.
    func testANaNLimitFallsBackToTheDefaultRatherThanPropagating() async {
        await model.update { $0.weeklyLimitGrams = .nan }

        let settings = await stored()
        XCTAssertEqual(settings.weeklyLimitGrams, AppSettings().weeklyLimitGrams)
        XCTAssertTrue(settings.weeklyLimitGrams.isFinite)
    }

    func testAnUnknownLanguageTagIsCanonicalised() async {
        await model.update { $0.language = "DE-de" }
        let language = await stored().language
        XCTAssertEqual(language, SupportedLocales.canonicalTag("DE-de"))
    }

    // ── Weight: zero is absence, not a measurement ───────────────────────────

    func testAPositiveWeightIsClampedButZeroIsPreserved() async {
        await model.update { $0.weightKg = 9_999 }
        let clamped = await stored().weightKg
        XCTAssertEqual(clamped, SettingsSanitizer.weightRange.upperBound)
        XCTAssertTrue(model.hasWeight)

        await model.clearWeight()
        let settings = await stored()
        XCTAssertEqual(settings.weightKg, 0.0, "zero means 'not set', not 1 kg")
        XCTAssertFalse(model.hasWeight)
    }

    /// A negative weight is nonsense, and nonsense means "unset" — not 1 kg.
    func testANegativeWeightBecomesUnset() async {
        await model.update { $0.weightKg = -80 }
        let weight = await stored().weightKg
        XCTAssertEqual(weight, 0.0)
    }

    // ── The statistics floor ─────────────────────────────────────────────────

    func testOnlyACanonicalStatsDateSurvives() async {
        await model.update { $0.statsFromDate = "2026-1-5" }
        let dropped = await stored().statsFromDate
        XCTAssertEqual(dropped, "", "a non-canonical date is dropped")

        await model.update { $0.statsFromDate = "2026-01-05" }
        let kept = await stored().statsFromDate
        XCTAssertEqual(kept, "2026-01-05")
        XCTAssertTrue(model.hasStatsFloor)

        await model.clearStatsFromDate()
        XCTAssertFalse(model.hasStatsFloor)
    }

    // ── Observation ──────────────────────────────────────────────────────────

    /// A backup import writes settings behind this screen's back. The screen must
    /// notice.
    func testTheScreenSeesAChangeMadeElsewhere() async throws {
        model.start()
        try await environment.preferences.update { $0.dailyLimitGrams = 24.0 }

        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline, model.settings.dailyLimitGrams != 24.0 {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(model.settings.dailyLimitGrams, 24.0, accuracy: 1e-9)
    }
}
