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
// Trend.swift – direction of a per-day-average trend
// =============================================================================
//
// A faithful Swift port of the Android `domain/Trend.kt`.
//
// The comparison is always made on grams of alcohol PER CALENDAR DAY, never on
// totals: the current (possibly in-progress) period is divided by its effective
// days and the previous (complete) period by its full day count, so a partial
// month compares fairly against a full previous month. Both averages are rounded
// to 0.1 g — the precision shown to the user — before comparing, so a difference
// below that reads as "no change".
// =============================================================================

/// Direction of a per-day-average trend versus a previous period.
///
/// Shared by the Statistics screen and the Today card so both render the same
/// arrow for the same situation. The raw values match the Kotlin enum constant
/// names, so the shared JSON vectors can name them directly.
public enum Trend: String, Sendable, Equatable, Codable {

    /// Current average is higher (more alcohol, the "worse" direction): red ↑.
    case up = "UP"

    /// Current average is lower (less alcohol, the "better" direction): green ↓.
    case down = "DOWN"

    /// Equal at 0.1 g precision, or no comparable previous value exists
    /// (previous average ≤ 0): no arrow is shown.
    case flat = "FLAT"

    /// Rounds grams to 0.1 g, commercially.
    ///
    /// The inputs are non-negative, so Kotlin's `Math.round` (ties toward
    /// positive infinity) and Swift's `.toNearestOrAwayFromZero` agree. The rule
    /// is spelled out rather than left to the default, to keep the choice visible.
    private static func round1(_ grams: Double) -> Double {
        (grams * 10.0).rounded(.toNearestOrAwayFromZero) / 10.0
    }

    /// Classifies `currentAvg` grams/day against `prevAvg` grams/day.
    ///
    /// Returns `.flat` when there is no usable previous value (`prevAvg <= 0`) or
    /// the two are equal once rounded to 0.1 g.
    public static func of(currentAvg: Double, prevAvg: Double) -> Trend {
        guard prevAvg > 0.0 else { return .flat }
        let current = round1(currentAvg)
        let previous = round1(prevAvg)
        if current > previous { return .up }
        if current < previous { return .down }
        return .flat
    }
}
