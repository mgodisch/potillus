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

import Foundation

// =============================================================================
// LimitGauge.swift – what a progress bar should show, without knowing about UI
// =============================================================================
//
// The rules Android's `LimitBar` and `DrinkDaysBar` encode, extracted so they can
// be tested. The SwiftUI views map `Emphasis` onto colours and nothing else.
//
// TWO FRACTIONS, NOT ONE
//   The bar's FILL is clamped to 0...1, or a 130 % day would draw past the track.
//   The COLOUR is decided from the UNCLAMPED value, so the overflow still shows.
//   Conflating them would either break the layout or hide the violation.
//
// A DELIBERATE ASYMMETRY BETWEEN THE TWO BARS
//   Both bars answer the same question — "may I drink now?" — and the two limits
//   answer it differently.
//
//   GRAMS. Red when the limit is REACHED (fraction >= 1.0). Having drunk exactly
//   the daily allowance leaves no room for the next drink, so the bar says stop.
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
//   This is precisely the drink-day gate in `AlcoholCalculator.trafficLight`:
//
//       pastDrinkDays = drinkDaysThisWeek - (todayIsDrinkDay ? 1 : 0)
//       if pastDrinkDays >= maxDrinkDaysPerWeek { return .red }
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
    /// The allowance is reached (grams) or exceeded (drink days).
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

    /// The colour band for a gram bar, from the unclamped fraction.
    ///
    /// An unconfigured limit (`<= 0`) reads as `.calm`: an empty bar, not a
    /// permanent alarm. `limitPercent` already guards the division.
    public static func emphasis(totalGrams: Double, limitGrams: Double) -> Emphasis {
        let fraction = AlcoholCalculator.limitPercent(
            totalGrams: totalGrams, limitGrams: limitGrams
        )
        if fraction >= 1.0 { return .danger }
        if fraction >= warningThreshold { return .warning }
        return .calm
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
        // The same gate as AlcoholCalculator.trafficLight, so bar and dot agree.
        let pastDrinkDays = drinkDays - (todayIsDrinkDay ? 1 : 0)
        if pastDrinkDays >= maxDrinkDays { return .danger }

        let denominator = Double(max(maxDrinkDays, 1))
        let fraction = max(Double(drinkDays) / denominator, 0.0)
        return fraction < warningThreshold ? .calm : .warning
    }
}
