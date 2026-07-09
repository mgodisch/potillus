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
import XCTest
@testable import PotillusKit

// =============================================================================
// TestVectors.swift – loader for the shared cross-platform golden vectors
// =============================================================================
//
// The vectors live at the repository root in `test-vectors/`, deliberately
// *outside* this Swift package, because the Android (JVM) test suite loads the
// very same files. Neither platform can change a formula without either
// updating the shared vectors — a visible, reviewable change — or turning its
// own suite red.
//
// WHY NOT SwiftPM RESOURCES?
//   SwiftPM can only bundle resources that live inside the target's own
//   directory, so `Bundle.module` cannot reach the repository root. Instead the
//   loader derives the root from `#filePath`, the compile-time path of *this*
//   source file. That is a standard technique for test fixtures: it is exact,
//   needs no build configuration, and is confined to test code (never shipped).
// =============================================================================

enum TestVectors {

    /// Absolute path of the repository root, derived from this file's location:
    /// `<root>/ios/PotillusKit/Tests/PotillusKitTests/TestVectors.swift`
    /// — so the root is four directory levels above the containing directory.
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)      // .../PotillusKitTests/TestVectors.swift
            .deletingLastPathComponent()     // .../PotillusKitTests
            .deletingLastPathComponent()     // .../Tests
            .deletingLastPathComponent()     // .../PotillusKit
            .deletingLastPathComponent()     // .../ios
            .deletingLastPathComponent()     // repository root
    }

    /// Loads and decodes a vector file from `test-vectors/`.
    ///
    /// - Parameter name: File name without the `.json` extension.
    /// - Throws: If the file is missing or malformed — a hard failure, because a
    ///   silently skipped parity suite would defeat its entire purpose.
    static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = repositoryRoot
            .appendingPathComponent("test-vectors")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// =============================================================================
// Decodable mirrors of the JSON vector schema
// =============================================================================

/// Root of `test-vectors/alcohol-calculator.json`.
struct AlcoholCalculatorVectors: Decodable {
    let constants: Constants
    let calculateGrams: [GramsCase]
    let calculateBAC: [BacCase]
    let limitPercent: [LimitPercentCase]
    let isOverLimit: [IsOverLimitCase]
    let trafficLight: [TrafficLightCase]
    let countLimitViolations: [ViolationsCase]

    struct Constants: Decodable {
        let ethanolDensity: Double
        let bingeThreshold: Double
        let widmarkR: Double
        let beta: Double
        let windowDays: Int
        let limitEpsilon: Double
    }

    struct IsOverLimitCase: Decodable {
        let description: String
        let totalGrams: Double
        let limitGrams: Double
        let expected: Bool
    }

    struct GramsCase: Decodable {
        let description: String
        let volumeMl: Int
        let alcoholPercent: Double
        let expected: Double
    }

    struct BacCase: Decodable {
        let description: String
        let totalGrams: Double
        let weightKg: Double
        let hoursElapsed: Double
        let expected: Double
    }

    struct LimitPercentCase: Decodable {
        let description: String
        let totalGrams: Double
        let limitGrams: Double
        let expected: Double
    }

    struct TrafficLightCase: Decodable {
        let description: String
        let gramsPerDrink: Double
        let todayGrams: Double
        let dailyLimitGrams: Double
        let weeklyTotalGrams: Double
        let weeklyLimitGrams: Double
        let drinkDaysThisWeek: Int
        let maxDrinkDaysPerWeek: Int
        /// `TrafficLight` is `String`-backed and `Codable`, so the JSON values
        /// "GREEN"/"YELLOW"/"RED" decode straight onto the Kotlin enum names.
        let expected: TrafficLight
    }

    struct ViolationsCase: Decodable {
        let description: String
        /// Each day is a `[isoDate, grams]` pair, kept positional to stay compact
        /// and language-neutral in the JSON.
        let days: [[DayField]]
        let dailyLimitGrams: Double
        let weeklyLimitGrams: Double
        let maxDrinkDaysPerWeek: Int
        let expected: Expected

        struct Expected: Decodable {
            let daysOverDailyLimit: Int
            let daysOverWeeklyLimit: Int
            let daysOverDrinkDayLimit: Int
        }

        /// The day pairs mix a string and a number, so decoding needs a small
        /// either-or wrapper rather than a homogeneous array element type.
        enum DayField: Decodable {
            case date(String)
            case grams(Double)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .date(string)
                } else {
                    self = .grams(try container.decode(Double.self))
                }
            }
        }

        /// Converts the positional pairs into domain `DaySummary` values.
        func daySummaries() throws -> [DaySummary] {
            try days.map { pair in
                guard pair.count == 2,
                      case let .date(date) = pair[0],
                      case let .grams(grams) = pair[1]
                else {
                    throw VectorError.malformedDayPair(description)
                }
                return DaySummary(date: date, totalGrams: grams)
            }
        }
    }

    enum VectorError: Error, CustomStringConvertible {
        case malformedDayPair(String)

        var description: String {
            switch self {
            case .malformedDayPair(let caseName):
                return "Malformed [date, grams] pair in vector case: \(caseName)"
            }
        }
    }
}
