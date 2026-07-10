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
// LimitGaugeTests.swift – the bar must not lie
// =============================================================================
//
// Two failures matter here. A bar that overflows its track is ugly; a bar that
// looks calm while the limit is blown is dishonest. The clamping and the colour
// are therefore tested separately, because they are separate questions.
// =============================================================================

final class LimitGaugeTests: XCTestCase {

    // ── Fill: clamped, so the bar cannot overflow ────────────────────────────

    func testFillIsProportionalBelowTheLimit() {
        XCTAssertEqual(LimitGauge.fillFraction(totalGrams: 10, limitGrams: 20), 0.5, accuracy: 1e-9)
        XCTAssertEqual(LimitGauge.fillFraction(totalGrams: 0, limitGrams: 20), 0.0, accuracy: 1e-9)
    }

    func testFillIsClampedAtOne() {
        XCTAssertEqual(LimitGauge.fillFraction(totalGrams: 26, limitGrams: 20), 1.0, accuracy: 1e-9)
        XCTAssertEqual(LimitGauge.fillFraction(totalGrams: 1e9, limitGrams: 20), 1.0, accuracy: 1e-9)
    }

    /// An unconfigured limit must not divide by zero or draw a full bar.
    func testAnUnconfiguredLimitDrawsAnEmptyBar() {
        XCTAssertEqual(LimitGauge.fillFraction(totalGrams: 50, limitGrams: 0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 50, limitGrams: 0), .calm)
    }

    // ── Colour: from the UNCLAMPED value, so an overflow still shows ─────────

    func testEmphasisBandsForGramBars() {
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 14.9, limitGrams: 20), .calm)
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 15.0, limitGrams: 20), .warning, "75 % exactly")
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 19.9, limitGrams: 20), .warning)
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 20.0, limitGrams: 20), .danger, "reached")
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 26.0, limitGrams: 20), .danger)
    }

    /// The bar is full at 130 %, but it is red, not calm. Clamping the fill must
    /// never clamp the meaning.
    func testAnOverflowingBarIsStillRed() {
        let total = 26.0, limit = 20.0
        XCTAssertEqual(LimitGauge.fillFraction(totalGrams: total, limitGrams: limit), 1.0, accuracy: 1e-9)
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: total, limitGrams: limit), .danger)
    }

    // ── Drink days: a full bar means "may I drink NOW?" ──────────────────────

    /// At the cap, but today already spent a drink day: another drink today costs
    /// no further day, so the user may keep drinking. Amber.
    func testAtTheCapWithTodayAlreadyADrinkDayIsAmber() {
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 5, maxDrinkDays: 5, todayIsDrinkDay: true),
            .warning
        )
    }

    /// The same 5/5 bar, but today is still dry: the first drink would spend a
    /// sixth drink day. Red — the bar looks identical, the answer does not.
    func testAtTheCapWithTodayStillDryIsRed() {
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 5, maxDrinkDays: 5, todayIsDrinkDay: false),
            .danger
        )
    }

    func testExceedingTheCapIsRedEitherWay() {
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 6, maxDrinkDays: 5, todayIsDrinkDay: true), .danger
        )
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 6, maxDrinkDays: 5, todayIsDrinkDay: false), .danger
        )
    }

    func testDrinkDayBandsBelowTheCap() {
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 0, maxDrinkDays: 5, todayIsDrinkDay: false), .calm
        )
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 3, maxDrinkDays: 5, todayIsDrinkDay: false),
            .calm, "60 %"
        )
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 4, maxDrinkDays: 5, todayIsDrinkDay: false),
            .warning, "80 %"
        )
    }

    /// The bar must never contradict the traffic-light dot, since both answer
    /// "may I drink now?". Pinned across the whole grid.
    func testTheBarAgreesWithTheTrafficLightGate() {
        for maxDays in 1...7 {
            for days in 0...(maxDays + 2) {
                for todayIsDrinkDay in [true, false] where !(days == 0 && todayIsDrinkDay) {
                    let gaugeSaysDanger = LimitGauge.drinkDaysEmphasis(
                        drinkDays: days, maxDrinkDays: maxDays, todayIsDrinkDay: todayIsDrinkDay
                    ) == .danger

                    // The dot's own gate, computed independently.
                    let pastDrinkDays = days - (todayIsDrinkDay ? 1 : 0)
                    let dotSaysDanger = pastDrinkDays >= maxDays

                    XCTAssertEqual(
                        gaugeSaysDanger, dotSaysDanger,
                        "days=\(days) max=\(maxDays) todayIsDrinkDay=\(todayIsDrinkDay)"
                    )
                }
            }
        }
    }

    /// The gram bar and the drink-day bar treat a full bar differently, and that
    /// is the point. Pin it, so a future "consistency" refactor argues with a test.
    func testAFullGramBarIsRedButAFullDrinkDayBarNeedNotBe() {
        XCTAssertEqual(LimitGauge.emphasis(totalGrams: 20, limitGrams: 20), .danger)
        XCTAssertEqual(
            LimitGauge.drinkDaysEmphasis(drinkDays: 5, maxDrinkDays: 5, todayIsDrinkDay: true),
            .warning
        )
    }

    func testDrinkDayFillIsClampedAndSafeAgainstAZeroCap() {
        XCTAssertEqual(LimitGauge.drinkDaysFillFraction(drinkDays: 9, maxDrinkDays: 5), 1.0, accuracy: 1e-9)
        XCTAssertEqual(LimitGauge.drinkDaysFillFraction(drinkDays: 2, maxDrinkDays: 0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(LimitGauge.drinkDaysFillFraction(drinkDays: 0, maxDrinkDays: 5), 0.0, accuracy: 1e-9)
    }
}
