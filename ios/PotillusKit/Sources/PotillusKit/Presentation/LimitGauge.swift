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

// =============================================================================
// LimitGauge.swift – what a progress bar should show, without knowing about UI
// =============================================================================
//
// The rules Android's `LimitBar` and `DrinkDaysBar` draw by, extracted so they
// can be tested. Since the v0.86.0 review Android keeps them in
// `domain/LimitGauge.kt` too, and `test-vectors/limit-gauge.json` holds the two
// to one answer sheet. The SwiftUI views map `Emphasis` onto colours and
// nothing else.
//
// TWO FRACTIONS, NOT ONE
//   The bar's FILL is clamped to 0...1, or a 130 % day would draw past the track.
//   The COLOUR is decided from the UNCLAMPED value, so the overflow still shows.
//   Conflating them would either break the layout or hide the violation.
//
// A DELIBERATE ASYMMETRY BETWEEN THE TWO BARS
//   The two bars follow two different rules, because the two limits mean two
//   different things.
//
//   GRAMS. Red only when the limit is EXCEEDED, decided by the domain layer's
//   ONE definition of "over the limit" (`AlcoholCalculator.isOverLimit`) — the
//   same epsilon-guarded check the calendar dots, the statistics chart and the
//   PDF report use, and the same rule Android's `LimitBar` applies. Reaching
//   the limit exactly is allowed (the limit is what the user may consume), so
//   a full bar stays amber; the epsilon keeps a total that DISPLAYS as exactly
//   the limit from flipping red through binary floating-point drift.
//
//   DRINK DAYS. A full bar does NOT mean stop, because a drink day, once spent,
//   stays spent for the whole day. What matters is whether the allowance was
//   already exhausted BEFORE today:
//
//     - Today is already a drink day, and today is what completed the count:
//       drinking more today adds no further drink day. Amber — at the cap, but
//       today is free.
//     - Today is NOT yet a drink day and the count is already full: the first
//       drink today would spend a day the user does not have. Red.
//
//   This is precisely `AlcoholCalculator.drinkDayLimitReached`, the ONE named
//   drink-day gate — the same predicate `trafficLight` consults, mirroring
//   Kotlin's `drinkDayLimitReached`, and pinned by the `drinkDayLimitReached`
//   section of `alcohol-calculator.json` on both platforms.
//
//   The bar and the traffic-light dot therefore cannot disagree, which they could
//   under the simpler `days > max` rule: at 5/5 with today already a drink day,
//   `days > max` is false (amber) — correct — but at 5/5 with today NOT a drink
//   day it is also false (amber), while the dot is already red. The gate fixes it.
// =============================================================================

/// How urgently a gauge should read. The view chooses the colours.
public enum Emphasis: String, Sendable, Equatable, CaseIterable {
    /// Below three quarters of the allowance.
    case calm = "CALM"
    /// Three quarters or more, but still within the allowance.
    case warning = "WARNING"
    /// The allowance is exceeded (grams) or exhausted before today (drink days).
    case danger = "DANGER"
}

/// Turns a total and a limit into what a progress bar needs.
public enum LimitGauge {

    /// Where the amber band begins.
    public static let warningThreshold = 0.75

    /// The fill fraction, clamped to `0...1` so the bar cannot overflow its track.
    ///
    /// The clamping is a DRAWING concern. Ask `emphasis` for the truth about
    /// whether the limit was passed.
    public static func fillFraction(totalGrams: Double, limitGrams: Double) -> Double {
        min(AlcoholCalculator.limitPercent(totalGrams: totalGrams, limitGrams: limitGrams), 1.0)
    }

    /// The colour band for a gram bar.
    ///
    /// Red is decided by `AlcoholCalculator.isOverLimit` — the single,
    /// epsilon-guarded definition of "over the limit" every other surface uses
    /// (see the file header) — so a total exactly at the limit reads `.warning`,
    /// never `.danger`. The amber band still comes from the unclamped fraction.
    ///
    /// An unconfigured limit (`<= 0`) reads as `.calm`: an empty bar, not a
    /// permanent alarm. `limitPercent` already guards the division; the guard
    /// here additionally keeps `isOverLimit` — for which any positive total
    /// "exceeds" a zero limit — from turning that empty bar red.
    public static func emphasis(totalGrams: Double, limitGrams: Double) -> Emphasis {
        guard limitGrams > 0.0 else { return .calm }
        if AlcoholCalculator.isOverLimit(totalGrams: totalGrams, limitGrams: limitGrams) {
            return .danger
        }
        let fraction = AlcoholCalculator.limitPercent(
            totalGrams: totalGrams, limitGrams: limitGrams
        )
        return fraction >= warningThreshold ? .warning : .calm
    }

    /// The fill fraction for the drink-day bar.
    public static func drinkDaysFillFraction(drinkDays: Int, maxDrinkDays: Int) -> Double {
        let denominator = Double(max(maxDrinkDays, 1))
        return min(max(Double(drinkDays) / denominator, 0.0), 1.0)
    }

    /// The colour band for the drink-day bar.
    ///
    /// Red when the allowance was already exhausted BEFORE today, because the
    /// next drink would then spend a drink day the user does not have. A day that
    /// is already a drink day costs nothing further, so a full bar can still be
    /// amber. See the file header.
    ///
    /// - Parameters:
    ///   - drinkDays: Days with alcohol in the trailing window, today included.
    ///   - maxDrinkDays: The allowance.
    ///   - todayIsDrinkDay: Whether today has already had alcohol. Pass
    ///     `state.totalGrams > 0`.
    public static func drinkDaysEmphasis(
        drinkDays: Int, maxDrinkDays: Int, todayIsDrinkDay: Bool
    ) -> Emphasis {
        // The same predicate AlcoholCalculator.trafficLight consults, so bar
        // and dot agree by construction (see the file header).
        if AlcoholCalculator.drinkDayLimitReached(
            drinkDaysThisWeek: drinkDays,
            maxDrinkDaysPerWeek: maxDrinkDays,
            todayIsDrinkDay: todayIsDrinkDay
        ) {
            return .danger
        }

        let denominator = Double(max(maxDrinkDays, 1))
        let fraction = max(Double(drinkDays) / denominator, 0.0)
        return fraction < warningThreshold ? .calm : .warning
    }
}
