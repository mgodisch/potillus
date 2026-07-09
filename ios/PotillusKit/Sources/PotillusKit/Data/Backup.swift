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
// Backup.swift – the JSON backup format, version 3
// =============================================================================
//
// A faithful Swift port of Android's `util/BackupManager.kt` reader/writer.
// This file is the single most important interoperability surface in the
// project: the JSON backup is the ONLY supported way a user carries their
// history between an Android phone and an iPhone. (A database *file* is not —
// Room and GRDB keep incompatible bookkeeping tables.)
//
// FORMAT HISTORY
//   1 → initial: drinks + entries.
//   2 → adds `category` on drink objects.
//   3 → adds a top-level `settings` object (theme, limits, day-change time,
//       body weight, language, …).
//
// COMPATIBILITY RULES, mirrored exactly from the Kotlin importer:
//   - Required fields are read strictly; a missing one is a hard error.
//   - Optional/newer fields are read with defaults, so a version 1 or 2 file
//     restores unchanged. A missing `category` becomes OTHER.
//   - A file whose `version` exceeds the one this code knows is REJECTED rather
//     than read with unknown fields silently dropped. Truncating a newer backup
//     would look like success while losing data.
//   - Unknown keys inside a known object are ignored, so a field added later
//     never breaks an older reader.
//
// SCOPE NOTE — SETTINGS
//   On Android the settings live in an encrypted DataStore, separate from the
//   database. iOS has no preferences store yet, so this code PRESERVES the
//   settings block (reads it into a struct, writes it back out) but does not
//   apply it anywhere. Wiring it to a preferences store, including the value
//   clamping the Kotlin parser performs, belongs with that store. Until then a
//   backup written by iOS omits the key, exactly as a format 1/2 file does, and
//   an Android import leaves the local settings untouched — the same behaviour
//   a pre-v3 backup already produces.
// =============================================================================

/// The decoded contents of a backup file.
public struct BackupFile: Sendable, Equatable {

    /// Highest format version this code can read and write.
    public static let currentVersion = 3

    /// The format version the file declares. Absent means version 1.
    public let version: Int

    /// ISO-8601 instant the file was written. Informational only.
    public let exportedAt: String

    public let drinks: [DrinkDefinition]
    public let entries: [ConsumptionEntry]

    /// The raw settings object, preserved verbatim. `nil` for a pre-v3 file.
    /// See the scope note above.
    public let settings: BackupSettings?

    public init(
        version: Int = BackupFile.currentVersion,
        exportedAt: String,
        drinks: [DrinkDefinition],
        entries: [ConsumptionEntry],
        settings: BackupSettings? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.drinks = drinks
        self.entries = entries
        self.settings = settings
    }
}

/// The `settings` block of a format 3 backup, carried through unchanged.
///
/// Deliberately a separate type from the domain's `AppSettings`: that one is the
/// slice the calculator needs, this one is the wire format. Conflating them
/// would let a wire-format change ripple into the maths.
public struct BackupSettings: Sendable, Equatable, Codable {
    public var themeMode: String
    public var dayChangeHour: Int
    public var dayChangeMinute: Int
    public var dailyLimitGrams: Double
    public var weeklyLimitGrams: Double
    public var maxDrinkDaysPerWeek: Int
    public var statsFromDate: String
    public var biometricEnabled: Bool
    public var allowScreenshots: Bool
    public var alternativeStatusSymbols: Bool
    public var language: String
    public var weightKg: Double
}

/// Every way reading a backup can fail. Modelled as distinct cases, mirroring
/// the Kotlin `sealed class ImportError`, so a UI can localise each one without
/// string-matching an exception message.
public enum BackupError: Error, Equatable, CustomStringConvertible {

    /// The file held no bytes.
    case fileEmpty

    /// The bytes are not valid JSON, or the root is not an object.
    case invalidJSON

    /// Written by a newer app. Reading it would silently drop unknown fields.
    case versionTooHigh(found: Int, max: Int)

    /// A field the format requires is missing or has the wrong type.
    case missingField(object: String, key: String)

    /// A `logicalDate` that is not `yyyy-MM-dd`.
    case malformedDate(String)

    public var description: String {
        switch self {
        case .fileEmpty:
            return "The backup file is empty."
        case .invalidJSON:
            return "The backup file is not valid JSON."
        case .versionTooHigh(let found, let max):
            return "Backup format \(found) is newer than this app understands (\(max))."
        case .missingField(let object, let key):
            return "Missing required field '\(key)' in \(object)."
        case .malformedDate(let value):
            return "Not an ISO-8601 date: '\(value)'."
        }
    }
}

// =============================================================================
// Reading
// =============================================================================

public enum BackupReader {

    /// Parses `data` into a `BackupFile`.
    ///
    /// Uses `JSONSerialization` rather than `Codable` on purpose. The format's
    /// compatibility rules are *per field* — required here, defaulted there —
    /// and a synthesised `Decodable` would make every optional field an
    /// `Optional`, pushing the defaulting logic out to every call site. Reading
    /// the dictionary directly keeps the rules where they are documented, and
    /// mirrors what `org.json`'s `getXxx` / `optXxx` pair expresses on Android.
    public static func parse(_ data: Data) throws -> BackupFile {
        guard !data.isEmpty else { throw BackupError.fileEmpty }

        let parsed = try? JSONSerialization.jsonObject(with: data)
        guard let root = parsed as? [String: Any] else { throw BackupError.invalidJSON }

        // A file with no version key is a format 1 file.
        let version = root["version"] as? Int ?? 1
        guard version <= BackupFile.currentVersion else {
            throw BackupError.versionTooHigh(found: version, max: BackupFile.currentVersion)
        }

        let exportedAt = root["exportedAt"] as? String ?? ""

        let drinkObjects = root["drinks"] as? [[String: Any]] ?? []
        let drinks = try drinkObjects.map(parseDrink)

        let entryObjects = root["entries"] as? [[String: Any]] ?? []
        let entries = try entryObjects.map(parseEntry)

        var settings: BackupSettings?
        if let raw = root["settings"] as? [String: Any] {
            settings = parseSettings(raw)
        }

        return BackupFile(
            version: version,
            exportedAt: exportedAt,
            drinks: drinks,
            entries: entries,
            settings: settings
        )
    }

    private static func parseDrink(_ object: [String: Any]) throws -> DrinkDefinition {
        guard let name = object["name"] as? String else {
            throw BackupError.missingField(object: "drink", key: "name")
        }
        guard let volumeMl = intValue(object["volumeMl"]) else {
            throw BackupError.missingField(object: "drink", key: "volumeMl")
        }
        guard let alcoholPercent = doubleValue(object["alcoholPercent"]) else {
            throw BackupError.missingField(object: "drink", key: "alcoholPercent")
        }

        return DrinkDefinition(
            id: int64Value(object["id"]) ?? 0,
            name: name,
            volumeMl: volumeMl,
            alcoholPercent: alcoholPercent,
            isPreset: object["isPreset"] as? Bool ?? false,
            isFavorite: object["isFavorite"] as? Bool ?? false,
            // Absent in format 1; an unknown value from a newer app decays too.
            category: DrinkCategory.from(stored: object["category"] as? String ?? "OTHER")
        )
    }

    private static func parseEntry(_ object: [String: Any]) throws -> ConsumptionEntry {
        guard let drinkId = int64Value(object["drinkId"]) else {
            throw BackupError.missingField(object: "entry", key: "drinkId")
        }
        guard let drinkName = object["drinkName"] as? String else {
            throw BackupError.missingField(object: "entry", key: "drinkName")
        }
        guard let volumeMl = intValue(object["volumeMl"]) else {
            throw BackupError.missingField(object: "entry", key: "volumeMl")
        }
        guard let alcoholPercent = doubleValue(object["alcoholPercent"]) else {
            throw BackupError.missingField(object: "entry", key: "alcoholPercent")
        }
        guard let gramsAlcohol = doubleValue(object["gramsAlcohol"]) else {
            throw BackupError.missingField(object: "entry", key: "gramsAlcohol")
        }
        guard let timestampMillis = int64Value(object["timestampMillis"]) else {
            throw BackupError.missingField(object: "entry", key: "timestampMillis")
        }
        guard let logicalDate = object["logicalDate"] as? String else {
            throw BackupError.missingField(object: "entry", key: "logicalDate")
        }
        // A malformed logical date would silently mis-bucket every statistic.
        guard DayResolver.parseDate(logicalDate) != nil else {
            throw BackupError.malformedDate(logicalDate)
        }

        return ConsumptionEntry(
            id: int64Value(object["id"]) ?? 0,
            drinkId: drinkId,
            drinkName: drinkName,
            volumeMl: volumeMl,
            alcoholPercent: alcoholPercent,
            gramsAlcohol: gramsAlcohol,
            timestampMillis: timestampMillis,
            logicalDate: logicalDate,
            note: object["note"] as? String ?? ""
        )
    }

    /// Settings are carried through; every field falls back to the Kotlin
    /// parser's default when absent. Range clamping is intentionally NOT done
    /// here — see the scope note at the top of this file.
    private static func parseSettings(_ object: [String: Any]) -> BackupSettings {
        BackupSettings(
            themeMode: object["themeMode"] as? String ?? "SYSTEM",
            dayChangeHour: intValue(object["dayChangeHour"]) ?? 4,
            dayChangeMinute: intValue(object["dayChangeMinute"]) ?? 0,
            dailyLimitGrams: doubleValue(object["dailyLimitGrams"]) ?? 20.0,
            weeklyLimitGrams: doubleValue(object["weeklyLimitGrams"]) ?? 100.0,
            maxDrinkDaysPerWeek: intValue(object["maxDrinkDaysPerWeek"]) ?? 5,
            statsFromDate: object["statsFromDate"] as? String ?? "",
            biometricEnabled: object["biometricEnabled"] as? Bool ?? false,
            allowScreenshots: object["allowScreenshots"] as? Bool ?? false,
            alternativeStatusSymbols: object["alternativeStatusSymbols"] as? Bool ?? false,
            language: object["language"] as? String ?? "",
            weightKg: doubleValue(object["weightKg"]) ?? 0.0
        )
    }

    // ── Numeric coercion ─────────────────────────────────────────────────────
    //
    // `JSONSerialization` returns numbers as `NSNumber`, so `as? Int` succeeds
    // for a JSON integer but FAILS for `4.0` written as a double, and `as?
    // Double` fails for a bare integer. Android's `org.json` coerces both ways
    // (`getDouble` on an int works). These helpers restore that leniency, so a
    // backup written by either platform reads on the other.

    private static func intValue(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

// =============================================================================
// Writing
// =============================================================================

public enum BackupWriter {

    /// The GPL notice carried in the file's `_comment` array, matching the one
    /// Android writes. A backup is a document the user may publish; it says what
    /// it is and under what terms.
    public static let commentLines = [
        "Libellus Potionis - Privacy-Friendly Alcohol Tracker",
        "Copyright (c) 2026 Martin A. Godisch <android@godisch.de>",
        "License: GNU General Public License v3 or later",
        "https://www.gnu.org/licenses/",
    ]

    /// Serialises `backup` to pretty-printed JSON with sorted keys.
    ///
    /// Sorted keys make the output stable, so two exports of the same data are
    /// byte-identical and a diff of two backups shows only real changes.
    public static func makeJSON(_ backup: BackupFile) throws -> Data {
        var root: [String: Any] = [
            "_comment": commentLines,
            "version": backup.version,
            "exportedAt": backup.exportedAt,
            "drinks": backup.drinks.map(encode),
            "entries": backup.entries.map(encode),
        ]

        // A pre-v3 file simply has no settings key; so does an iOS export until
        // the preferences store exists.
        if let settings = backup.settings {
            root["settings"] = encode(settings)
        }

        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func encode(_ drink: DrinkDefinition) -> [String: Any] {
        [
            "id": drink.id,
            "name": drink.name,
            "volumeMl": drink.volumeMl,
            "alcoholPercent": drink.alcoholPercent,
            "isPreset": drink.isPreset,
            "isFavorite": drink.isFavorite,
            // Stored by name, never ordinal.
            "category": drink.category.rawValue,
        ]
    }

    private static func encode(_ entry: ConsumptionEntry) -> [String: Any] {
        [
            "id": entry.id,
            "drinkId": entry.drinkId,
            "drinkName": entry.drinkName,
            "volumeMl": entry.volumeMl,
            "alcoholPercent": entry.alcoholPercent,
            "gramsAlcohol": entry.gramsAlcohol,
            "timestampMillis": entry.timestampMillis,
            "logicalDate": entry.logicalDate,
            "note": entry.note,
        ]
    }

    private static func encode(_ settings: BackupSettings) -> [String: Any] {
        [
            "themeMode": settings.themeMode,
            "dayChangeHour": settings.dayChangeHour,
            "dayChangeMinute": settings.dayChangeMinute,
            "dailyLimitGrams": settings.dailyLimitGrams,
            "weeklyLimitGrams": settings.weeklyLimitGrams,
            "maxDrinkDaysPerWeek": settings.maxDrinkDaysPerWeek,
            "statsFromDate": settings.statsFromDate,
            "biometricEnabled": settings.biometricEnabled,
            "allowScreenshots": settings.allowScreenshots,
            "alternativeStatusSymbols": settings.alternativeStatusSymbols,
            "language": settings.language,
            "weightKg": settings.weightKg,
        ]
    }
}
