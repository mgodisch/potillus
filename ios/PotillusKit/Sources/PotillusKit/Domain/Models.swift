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
// Models.swift – Domain value types
// =============================================================================
//
// These mirror the Android `domain/model/Models.kt` types one-to-one. They are
// plain values (Swift `struct` / `enum`) with no dependency on UIKit, SwiftUI,
// or any database, so the whole domain layer can be unit tested natively on
// macOS with `swift test`, without booting a simulator.
//
// WHY MIRROR RATHER THAN SHARE?
//   The project deliberately ports the domain logic to Swift instead of sharing
//   a Kotlin Multiplatform binary (see docs/IOS_MIGRATION.md). The guard against
//   the two implementations drifting apart is the shared golden-vector suite in
//   `test-vectors/`, which both platforms load and assert against.
// =============================================================================

/// Capacity status for one drink serving: how many more of it fit within *all*
/// active limits.
///
/// Mirrors the Android `TrafficLight` enum. The raw values match the Kotlin
/// enum constant names so the shared JSON vectors can name them directly.
public enum TrafficLight: String, Sendable, Equatable, Codable {
    /// Two or more servings still fit.
    case green = "GREEN"
    /// Exactly one serving still fits.
    case yellow = "YELLOW"
    /// No serving fits, or a limit gate has already been tripped.
    case red = "RED"
}

/// Total alcohol consumed on one logical day.
///
/// - Parameters:
///   - date: The logical day in ISO-8601 form (`yyyy-MM-dd`). "Logical" because
///     the user can move the day boundary past midnight, so a 02:00 drink may
///     still belong to the previous day.
///   - totalGrams: Grams of pure ethanol logged on that day.
///   - entryCount: Number of individual entries that make up the total.
public struct DaySummary: Sendable, Equatable {
    public let date: String
    public let totalGrams: Double
    public let entryCount: Int

    public init(date: String, totalGrams: Double, entryCount: Int = 1) {
        self.date = date
        self.totalGrams = totalGrams
        self.entryCount = entryCount
    }
}

/// The three thresholds that are simultaneously in force.
public struct LimitInfo: Sendable, Equatable {
    /// Daily gram limit.
    public let limitGrams: Double
    /// Gram limit across the trailing seven-day window.
    public let weeklyLimitGrams: Double
    /// Maximum number of distinct drinking days inside any seven-day window.
    public let maxDrinkDaysPerWeek: Int

    public init(limitGrams: Double, weeklyLimitGrams: Double, maxDrinkDaysPerWeek: Int = 5) {
        self.limitGrams = limitGrams
        self.weeklyLimitGrams = weeklyLimitGrams
        self.maxDrinkDaysPerWeek = maxDrinkDaysPerWeek
    }
}

/// How often each of the three limits was exceeded over a period.
public struct LimitViolations: Sendable, Equatable {
    /// Days whose own total exceeds the daily gram limit.
    public let daysOverDailyLimit: Int
    /// Days whose trailing seven-day gram total exceeds the weekly limit.
    public let daysOverWeeklyLimit: Int
    /// Days that are themselves beyond the drink-day budget of their window.
    public let daysOverDrinkDayLimit: Int

    public init(daysOverDailyLimit: Int, daysOverWeeklyLimit: Int, daysOverDrinkDayLimit: Int) {
        self.daysOverDailyLimit = daysOverDailyLimit
        self.daysOverWeeklyLimit = daysOverWeeklyLimit
        self.daysOverDrinkDayLimit = daysOverDrinkDayLimit
    }
}

/// The subset of user preferences the calculator needs.
///
/// The full Android `AppSettings` carries UI preferences too; only the limit
/// fields are relevant to the domain maths, so only those are modelled here.
public struct AppSettings: Sendable, Equatable {
    public let dailyLimitGrams: Double
    public let weeklyLimitGrams: Double
    public let maxDrinkDaysPerWeek: Int

    public init(
        dailyLimitGrams: Double = 20.0,
        weeklyLimitGrams: Double = 100.0,
        maxDrinkDaysPerWeek: Int = 5
    ) {
        self.dailyLimitGrams = dailyLimitGrams
        self.weeklyLimitGrams = weeklyLimitGrams
        self.maxDrinkDaysPerWeek = maxDrinkDaysPerWeek
    }
}
