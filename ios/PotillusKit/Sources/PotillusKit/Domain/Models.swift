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
//   a Kotlin Multiplatform binary. The guard against
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

/// A snapshot of the day's consumption against the active limits — everything the
/// traffic-light question needs, gathered once so every drink in a list is judged
/// against the same moment. Mirrors Android's `DrinkCapacity`.
///
/// The screen builds one of these from the current day's totals, then asks
/// `status(forServing:)` for each drink's default serving. Keeping the snapshot
/// separate from the per-drink call is what lets a whole list stay consistent:
/// the budget is read once, not re-read between rows.
public struct DrinkCapacity: Sendable, Equatable {
    /// Grams already logged today.
    public var todayGrams: Double
    /// Today's gram limit.
    public var dailyLimitGrams: Double
    /// Grams across the trailing seven-day window.
    public var weeklyTotalGrams: Double
    /// The seven-day gram limit.
    public var weeklyLimitGrams: Double
    /// Distinct drinking days in that window, today included.
    public var drinkDaysThisWeek: Int
    /// The drinking-days allowance.
    public var maxDrinkDaysPerWeek: Int

    public init(
        todayGrams: Double = 0,
        dailyLimitGrams: Double = 0,
        weeklyTotalGrams: Double = 0,
        weeklyLimitGrams: Double = 0,
        drinkDaysThisWeek: Int = 0,
        maxDrinkDaysPerWeek: Int = 0
    ) {
        self.todayGrams = todayGrams
        self.dailyLimitGrams = dailyLimitGrams
        self.weeklyTotalGrams = weeklyTotalGrams
        self.weeklyLimitGrams = weeklyLimitGrams
        self.drinkDaysThisWeek = drinkDaysThisWeek
        self.maxDrinkDaysPerWeek = maxDrinkDaysPerWeek
    }

    /// The traffic-light status for one serving of `gramsPerDrink` grams, against
    /// this snapshot. A thin pass-through to `AlcoholCalculator.trafficLight`, so
    /// the dot and the shared test vectors compute the identical answer.
    public func status(forServing gramsPerDrink: Double) -> TrafficLight {
        AlcoholCalculator.trafficLight(
            gramsPerDrink: gramsPerDrink,
            todayGrams: todayGrams,
            dailyLimitGrams: dailyLimitGrams,
            weeklyTotalGrams: weeklyTotalGrams,
            weeklyLimitGrams: weeklyLimitGrams,
            drinkDaysThisWeek: drinkDaysThisWeek,
            maxDrinkDaysPerWeek: maxDrinkDaysPerWeek
        )
    }
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

/// Category of a drink, used for grouping and colour-coding.
///
/// Persisted as the case's raw string (never an ordinal), exactly as on Android,
/// so inserting a new case can never re-label existing rows. An unknown value
/// read from the database decays to `.other` rather than throwing — the forward
/// compatibility rule from CONTRIBUTING.md section 4.
public enum DrinkCategory: String, Sendable, Equatable, Codable, CaseIterable {
    case beer = "BEER"
    case wine = "WINE"
    case spirits = "SPIRITS"
    case longdrink = "LONGDRINK"
    case liqueur = "LIQUEUR"
    case other = "OTHER"

    /// Decodes a stored category string, falling back to `.other`.
    ///
    /// The Swift counterpart of Kotlin's
    /// `runCatching { valueOf(name) }.getOrDefault(OTHER)`.
    public static func from(stored value: String) -> DrinkCategory {
        DrinkCategory(rawValue: value) ?? .other
    }
}

/// A drink the user can log. The domain view of the `drinks` table.
///
/// Mirrors Android's `DrinkDefinition`. `id == 0` means "not yet persisted",
/// matching the Kotlin default; the database assigns the real id on insert.
/// `Hashable` because SwiftUI's `Picker` tags its options by value; every stored
/// property is already hashable, so the conformance is synthesised.
public struct DrinkDefinition: Sendable, Equatable, Hashable, Identifiable {
    public var id: Int64
    public var name: String
    public var volumeMl: Int
    public var alcoholPercent: Double
    public var isPreset: Bool
    public var isFavorite: Bool
    public var category: DrinkCategory

    public init(
        id: Int64 = 0,
        name: String,
        volumeMl: Int,
        alcoholPercent: Double,
        isPreset: Bool = false,
        isFavorite: Bool = false,
        category: DrinkCategory = .other
    ) {
        self.id = id
        self.name = name
        self.volumeMl = volumeMl
        self.alcoholPercent = alcoholPercent
        self.isPreset = isPreset
        self.isFavorite = isFavorite
        self.category = category
    }
}

/// One logged consumption event. The domain view of the `entries` table.
///
/// Mirrors Android's `ConsumptionEntry`. The drink attributes are snapshots
/// taken at logging time, so editing a drink never rewrites history.
public struct ConsumptionEntry: Sendable, Equatable, Identifiable {
    public var id: Int64
    public var drinkId: Int64
    public var drinkName: String
    public var volumeMl: Int
    public var alcoholPercent: Double
    public var gramsAlcohol: Double
    public var timestampMillis: Int64
    public var logicalDate: String
    public var note: String

    public init(
        id: Int64 = 0,
        drinkId: Int64,
        drinkName: String,
        volumeMl: Int,
        alcoholPercent: Double,
        gramsAlcohol: Double,
        timestampMillis: Int64,
        logicalDate: String,
        note: String = ""
    ) {
        self.id = id
        self.drinkId = drinkId
        self.drinkName = drinkName
        self.volumeMl = volumeMl
        self.alcoholPercent = alcoholPercent
        self.gramsAlcohol = gramsAlcohol
        self.timestampMillis = timestampMillis
        self.logicalDate = logicalDate
        self.note = note
    }
}

/// The subset of user preferences the calculator needs.
///
/// The full Android `AppSettings` carries UI preferences too; only the limit
/// fields are relevant to the domain maths, so only those are modelled here.
/// Codable, because `PreferencesStore` persists it as encrypted JSON. The field
/// names are the wire format, so renaming one is a migration, not a refactor.
public struct AppSettings: Sendable, Equatable, Codable {

    /// Follow the system, or force light/dark. Persisted by name, never ordinal.
    public var themeMode: ThemeMode

    /// The hour and minute at which one logical day becomes the next. A drink at
    /// 02:00 belongs to the previous evening, which is why this is not midnight.
    public var dayChangeHour: Int
    public var dayChangeMinute: Int

    public var dailyLimitGrams: Double
    public var weeklyLimitGrams: Double
    public var maxDrinkDaysPerWeek: Int

    /// Statistics start here, `yyyy-MM-dd`. Empty means NO lower bound at all —
    /// not "from the first entry": every period still runs from its own start
    /// (the 1st for a month, January for a year), so days before any data exists
    /// are counted as ordinary days with no drinks. A brand-new installation is
    /// therefore seeded with the install date; see `PreferencesStore
    /// .seedOnFirstLaunch()`. `SettingsModel.clearStatsFromDate()` writes empty
    /// deliberately, to mean "cover my whole history".
    public var statsFromDate: String

    public var biometricEnabled: Bool
    public var allowScreenshots: Bool
    public var alternativeStatusSymbols: Bool

    /// A locale tag from `SupportedLocales.tags`, or empty for the system locale.
    public var language: String

    /// Body weight in kilograms, feeding the Widmark estimate.
    ///
    /// `0.0` is the SENTINEL for "not set", not a real weight. It must never be
    /// clamped up to the 1 kg floor, or an unset weight would silently become a
    /// one-kilogram body and the BAC estimate would be nonsense.
    public var weightKg: Double

    /// The canonical defaults, identical to Kotlin's `AppSettings()`.
    public init(
        themeMode: ThemeMode = .system,
        dayChangeHour: Int = 4,
        dayChangeMinute: Int = 0,
        dailyLimitGrams: Double = 20.0,
        weeklyLimitGrams: Double = 100.0,
        maxDrinkDaysPerWeek: Int = 5,
        statsFromDate: String = "",
        biometricEnabled: Bool = false,
        allowScreenshots: Bool = false,
        alternativeStatusSymbols: Bool = false,
        language: String = "",
        weightKg: Double = 0.0
    ) {
        self.themeMode = themeMode
        self.dayChangeHour = dayChangeHour
        self.dayChangeMinute = dayChangeMinute
        self.dailyLimitGrams = dailyLimitGrams
        self.weeklyLimitGrams = weeklyLimitGrams
        self.maxDrinkDaysPerWeek = maxDrinkDaysPerWeek
        self.statsFromDate = statsFromDate
        self.biometricEnabled = biometricEnabled
        self.allowScreenshots = allowScreenshots
        self.alternativeStatusSymbols = alternativeStatusSymbols
        self.language = language
        self.weightKg = weightKg
    }
}

/// How the app picks its colour scheme. Persisted by raw name, as on Android.
public enum ThemeMode: String, Sendable, Equatable, Codable, CaseIterable {
    case system = "SYSTEM"
    case day = "DAY"
    case night = "NIGHT"

    /// Decodes a stored value, falling back to `.system` for anything unknown.
    public static func from(stored value: String) -> ThemeMode {
        ThemeMode(rawValue: value) ?? .system
    }
}
