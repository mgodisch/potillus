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
@testable import PotillusKit

// =============================================================================
// SettingsSanitizerTests.swift – cross-platform parity suite
// =============================================================================
//
// Driven by `test-vectors/backup-settings.json`. Each case is a raw `settings`
// object as it might appear in a backup file; the expectation is the sanitised
// `AppSettings`. The Android suite feeds the same objects through
// `BackupManager.parseBackupJson`.
//
// The tests exercise the WHOLE chain — wrap the object in a minimal backup,
// parse it, sanitise it — because that is the path a real restore takes, and a
// defaulting rule that lives in the reader rather than the sanitiser would
// otherwise go untested.
// =============================================================================

struct SettingsVectors: Decodable {
    let localeTags: [String]
    let sanitize: [SanitizeCase]

    struct SanitizeCase: Decodable {
        let description: String
        /// The raw object; decoded loosely, since it may omit any key.
        let input: RawSettings
        let expected: ExpectedSettings
    }

    /// Every field optional: a case may specify only the one it exercises.
    struct RawSettings: Decodable {
        let themeMode: String?
        let dayChangeHour: Int?
        let dayChangeMinute: Int?
        let dailyLimitGrams: Double?
        let weeklyLimitGrams: Double?
        let maxDrinkDaysPerWeek: Int?
        let statsFromDate: String?
        let biometricEnabled: Bool?
        let allowScreenshots: Bool?
        let alternativeStatusSymbols: Bool?
        let language: String?
        let weightKg: Double?

        /// Re-encodes to the JSON object the vector described, omitting absent
        /// keys, so the reader's defaulting is exercised rather than bypassed.
        func jsonObject() -> [String: Any] {
            var object: [String: Any] = [:]
            if let themeMode { object["themeMode"] = themeMode }
            if let dayChangeHour { object["dayChangeHour"] = dayChangeHour }
            if let dayChangeMinute { object["dayChangeMinute"] = dayChangeMinute }
            if let dailyLimitGrams { object["dailyLimitGrams"] = dailyLimitGrams }
            if let weeklyLimitGrams { object["weeklyLimitGrams"] = weeklyLimitGrams }
            if let maxDrinkDaysPerWeek { object["maxDrinkDaysPerWeek"] = maxDrinkDaysPerWeek }
            if let statsFromDate { object["statsFromDate"] = statsFromDate }
            if let biometricEnabled { object["biometricEnabled"] = biometricEnabled }
            if let allowScreenshots { object["allowScreenshots"] = allowScreenshots }
            if let alternativeStatusSymbols {
                object["alternativeStatusSymbols"] = alternativeStatusSymbols
            }
            if let language { object["language"] = language }
            if let weightKg { object["weightKg"] = weightKg }
            return object
        }
    }

    struct ExpectedSettings: Decodable {
        let themeMode: String
        let dayChangeHour: Int
        let dayChangeMinute: Int
        let dailyLimitGrams: Double
        let weeklyLimitGrams: Double
        let maxDrinkDaysPerWeek: Int
        let statsFromDate: String
        let biometricEnabled: Bool
        let allowScreenshots: Bool
        let alternativeStatusSymbols: Bool
        let language: String
        let weightKg: Double
    }
}

final class SettingsSanitizerTests: XCTestCase {

    private static var loadedVectors: SettingsVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("backup-settings", as: SettingsVectors.self)
        } catch {
            XCTFail("Could not load the shared settings vectors: \(error)")
        }
    }

    private var vectors: SettingsVectors { Self.loadedVectors }

    /// Wraps a raw settings object in the smallest valid format 3 backup and runs
    /// it through the real reader, exactly as a restore would.
    private func sanitized(_ raw: [String: Any]) throws -> AppSettings {
        let root: [String: Any] = [
            "version": 3, "exportedAt": "2026-07-09T12:00:00Z",
            "drinks": [], "entries": [], "settings": raw,
        ]
        let data = try JSONSerialization.data(withJSONObject: root)
        let backup = try BackupReader.parse(data)
        let settings = try XCTUnwrap(backup.settings, "a format 3 file must carry settings")
        return SettingsSanitizer.sanitize(settings)
    }

    // ── The vectors ──────────────────────────────────────────────────────────

    func testSanitizeAgainstSharedVectors() throws {
        for testCase in vectors.sanitize {
            let actual = try sanitized(testCase.input.jsonObject())
            let expected = testCase.expected
            let label = testCase.description

            XCTAssertEqual(actual.themeMode.rawValue, expected.themeMode, "themeMode: \(label)")
            XCTAssertEqual(actual.dayChangeHour, expected.dayChangeHour, "dayChangeHour: \(label)")
            XCTAssertEqual(actual.dayChangeMinute, expected.dayChangeMinute, "dayChangeMinute: \(label)")
            XCTAssertEqual(
                actual.dailyLimitGrams, expected.dailyLimitGrams, accuracy: 1e-9,
                "dailyLimitGrams: \(label)"
            )
            XCTAssertEqual(
                actual.weeklyLimitGrams, expected.weeklyLimitGrams, accuracy: 1e-9,
                "weeklyLimitGrams: \(label)"
            )
            XCTAssertEqual(
                actual.maxDrinkDaysPerWeek, expected.maxDrinkDaysPerWeek,
                "maxDrinkDaysPerWeek: \(label)"
            )
            XCTAssertEqual(actual.statsFromDate, expected.statsFromDate, "statsFromDate: \(label)")
            XCTAssertEqual(actual.biometricEnabled, expected.biometricEnabled, "biometricEnabled: \(label)")
            XCTAssertEqual(actual.allowScreenshots, expected.allowScreenshots, "allowScreenshots: \(label)")
            XCTAssertEqual(
                actual.alternativeStatusSymbols, expected.alternativeStatusSymbols,
                "alternativeStatusSymbols: \(label)"
            )
            XCTAssertEqual(actual.language, expected.language, "language: \(label)")
            XCTAssertEqual(actual.weightKg, expected.weightKg, accuracy: 1e-9, "weightKg: \(label)")
        }
    }

    // ── The locale catalogue must not drift ──────────────────────────────────

    /// The vector's tag list is the Android catalogue (`SupportedLocales.kt`),
    /// which is the canonical cross-platform source. iOS ships the SAME languages
    /// but spells Chinese by script (`zh-Hans`/`zh-Hant`) where Android spells it
    /// by region (`zh-CN`/`zh-TW`), because iOS String Catalogs key Chinese that
    /// way. Rather than duplicate the list, this maps each Android tag through the
    /// very migration the app uses when RESTORING an Android backup on iOS
    /// (`canonicalTag`, which rewrites `zh-CN`→`zh-Hans` etc.). So this asserts two
    /// things at once: the language SETS agree (no drift — if Android gains a
    /// language and iOS does not, a mapped tag becomes `""` and the lists differ),
    /// and the real backup-interop path produces exactly the iOS catalogue.
    func testLocaleCatalogueMatchesAndroid() {
        let expected = vectors.localeTags.map { SupportedLocales.canonicalTag($0) }
        XCTAssertEqual(SupportedLocales.tags, expected)
    }

    func testCanonicalTagIsCaseInsensitiveAndCanonicalising() {
        XCTAssertEqual(SupportedLocales.canonicalTag("DE"), "de")
        XCTAssertEqual(SupportedLocales.canonicalTag("pt-br"), "pt-BR")
        XCTAssertEqual(SupportedLocales.canonicalTag("xx"), "")
        XCTAssertEqual(SupportedLocales.canonicalTag(""), "")

        // Migration: the Chinese codes this app stored before the String Catalog
        // existed must resolve to the script tags the catalogue now uses, so a
        // backup or setting written under the old code keeps its language on upgrade
        // instead of silently dropping to System.
        XCTAssertEqual(SupportedLocales.canonicalTag("zh-CN"), "zh-Hans")
        XCTAssertEqual(SupportedLocales.canonicalTag("zh-TW"), "zh-Hant")
        XCTAssertEqual(SupportedLocales.canonicalTag("ZH-cn"), "zh-Hans", "migration is case-insensitive")
        XCTAssertEqual(SupportedLocales.canonicalTag("zh-Hans"), "zh-Hans")
        XCTAssertEqual(SupportedLocales.canonicalTag("zh-Hant"), "zh-Hant")
    }

    // ── The two rules that look like bugs ────────────────────────────────────

    /// An unset weight (0.0) must survive as 0.0, never be clamped to the 1 kg
    /// floor. Otherwise a restore would invent a one-kilogram body.
    func testUnsetWeightIsNotClampedUpToTheFloor() throws {
        XCTAssertEqual(try sanitized(["weightKg": 0.0]).weightKg, 0.0)
        XCTAssertEqual(try sanitized(["weightKg": -12.0]).weightKg, 0.0)
        // But a real, too-small weight is clamped.
        XCTAssertEqual(try sanitized(["weightKg": 0.4]).weightKg, 1.0, accuracy: 1e-9)
    }

    /// A date that parses but is not canonical must be dropped, not kept.
    func testOnlyCanonicalStatsDatesSurvive() throws {
        XCTAssertEqual(try sanitized(["statsFromDate": "2026-01-01"]).statsFromDate, "2026-01-01")
        XCTAssertEqual(try sanitized(["statsFromDate": "2026-1-1"]).statsFromDate, "")
        XCTAssertEqual(try sanitized(["statsFromDate": "2026-02-30"]).statsFromDate, "")
        XCTAssertEqual(try sanitized(["statsFromDate": "01/02/2026"]).statsFromDate, "")
    }

    /// A hostile or corrupt file must not be able to disable the limits.
    func testAbsurdLimitsAreClampedIntoUsableRanges() throws {
        let settings = try sanitized([
            "dailyLimitGrams": 1e9, "weeklyLimitGrams": 1e9, "maxDrinkDaysPerWeek": 99,
        ])
        XCTAssertEqual(settings.dailyLimitGrams, 500.0, accuracy: 1e-9)
        XCTAssertEqual(settings.weeklyLimitGrams, 3500.0, accuracy: 1e-9)
        XCTAssertEqual(settings.maxDrinkDaysPerWeek, 7)
    }

    /// An hour of 25 would make DayResolver produce a time that does not exist.
    func testDayChangeTimeIsClampedIntoARealClock() throws {
        XCTAssertEqual(try sanitized(["dayChangeHour": 25]).dayChangeHour, 23)
        XCTAssertEqual(try sanitized(["dayChangeHour": -3]).dayChangeHour, 0)
        XCTAssertEqual(try sanitized(["dayChangeMinute": 90]).dayChangeMinute, 59)
    }

    // ── The two overloads must agree ─────────────────────────────────────────

    /// `sanitize(BackupSettings)` reads a file; `sanitize(AppSettings)` guards a
    /// screen. They repeat a field list, so a test — not a comment — keeps them
    /// from repeating a rule differently.
    func testBothOverloadsAgreeOnEveryField() {
        let raw = BackupSettings(
            themeMode: "NIGHT",
            dayChangeHour: 47,
            dayChangeMinute: -3,
            dailyLimitGrams: 9_000,
            weeklyLimitGrams: .nan,
            maxDrinkDaysPerWeek: 99,
            statsFromDate: "2026-1-5",
            biometricEnabled: true,
            allowScreenshots: true,
            alternativeStatusSymbols: true,
            language: "DE-de",
            weightKg: -80
        )

        let fromBackup = SettingsSanitizer.sanitize(raw)

        // The same values, already typed as the app holds them.
        let asApp = AppSettings(
            themeMode: .night,
            dayChangeHour: 47,
            dayChangeMinute: -3,
            dailyLimitGrams: 9_000,
            weeklyLimitGrams: .nan,
            maxDrinkDaysPerWeek: 99,
            statsFromDate: "2026-1-5",
            biometricEnabled: true,
            allowScreenshots: true,
            alternativeStatusSymbols: true,
            language: "DE-de",
            weightKg: -80
        )

        XCTAssertEqual(SettingsSanitizer.sanitize(asApp), fromBackup)
    }

    /// Sanitising twice must change nothing the first pass did not.
    func testSanitisingIsIdempotent() {
        let once = SettingsSanitizer.sanitize(
            AppSettings(dailyLimitGrams: 9_000, maxDrinkDaysPerWeek: 99, weightKg: -1)
        )
        XCTAssertEqual(SettingsSanitizer.sanitize(once), once)
    }
}
