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
// BackupExporterTests.swift
// =============================================================================
//
// The JSON backup is the only route between Android and iOS, so the test that
// matters is the round trip: whatever this exporter writes, the importer must be
// able to read back into an identical database.
// =============================================================================

final class BackupExporterTests: XCTestCase {

    private var environment: AppEnvironment!
    private var exporter: BackupExporter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
        exporter = BackupExporter(
            drinks: environment.drinks,
            entries: environment.entries,
            preferences: environment.preferences
        )
    }

    @discardableResult
    private func seed() throws -> DrinkDefinition {
        let id = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer)
        )
        let drink = try XCTUnwrap(try environment.drinks.allOnce().first { $0.id == id })
        _ = try environment.entries.add(
            ConsumptionEntry(
                drinkId: drink.id, drinkName: drink.name, volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: 19.3, timestampMillis: 1_767_384_840_000,
                logicalDate: "2026-01-02", note: "on the terrace"
            )
        )
        return drink
    }

    // ── The round trip ───────────────────────────────────────────────────────

    /// The test that matters. Everything else here is a detail of this one.
    func testWhatWeExportTheImporterCanRead() async throws {
        try seed()
        try await environment.preferences.update { $0.weightKg = 82.5 }

        let data = try await exporter.makeBackup()
        let parsed = try Backup.parse(data)

        // A fresh device, restoring the file.
        let fresh = try AppEnvironment.makeEphemeral()
        let stats = try await fresh.importer.restore(parsed, mode: .replace)

        XCTAssertEqual(stats.imported, 1)
        XCTAssertEqual(try fresh.entries.all().count, 1)

        let restored = try XCTUnwrap(try fresh.entries.all().first)
        XCTAssertEqual(restored.drinkName, "Pils")
        XCTAssertEqual(restored.note, "on the terrace")
        XCTAssertEqual(restored.logicalDate, "2026-01-02")
        XCTAssertEqual(restored.gramsAlcohol, 19.3, accuracy: 1e-9)
        let restoredWeight = await fresh.preferences.load().weightKg
        XCTAssertEqual(restoredWeight, 82.5, accuracy: 1e-9)
    }

    // ── What goes in ─────────────────────────────────────────────────────────

    /// Presets are exported too. The importer recreates them, so omitting them
    /// looks harmless — until a user has renamed one, and the rename is lost.
    func testPresetsAreExportedSoThatEditsToThemSurvive() async throws {
        _ = try environment.drinks.add(
            DrinkDefinition(name: "My renamed preset", volumeMl: 330, alcoholPercent: 5.0,
                            isPreset: true, category: .beer)
        )

        let file = try Backup.parse(try await exporter.makeBackup())
        XCTAssertEqual(file.drinks.map(\.name), ["My renamed preset"])
        XCTAssertTrue(try XCTUnwrap(file.drinks.first).isPreset)
    }

    /// An absent `settings` key means "leave my settings alone". Emitting defaults
    /// instead would overwrite the recipient's with someone else's.
    func testOmittingSettingsOmitsTheKeyRatherThanWritingDefaults() async throws {
        try seed()
        try await environment.preferences.update { $0.weightKg = 82.5 }

        let data = try await exporter.makeBackup(includeSettings: false)
        XCTAssertNil(try Backup.parse(data).settings)

        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(object["settings"], "the key is absent, not null")

        // And the recipient keeps their own.
        let fresh = try AppEnvironment.makeEphemeral()
        try await fresh.preferences.update { $0.weightKg = 70.0 }
        _ = try await fresh.importer.restore(try Backup.parse(data), mode: .replace)
        let untouched = await fresh.preferences.load().weightKg
        XCTAssertEqual(untouched, 70.0, accuracy: 1e-9)
    }

    /// A body weight is the one field nobody should share by accident.
    func testSettingsCarryTheBodyWeightWhenIncluded() async throws {
        try await environment.preferences.update { $0.weightKg = 82.5 }
        let file = try Backup.parse(try await exporter.makeBackup(includeSettings: true))
        XCTAssertEqual(try XCTUnwrap(file.settings).weightKg, 82.5, accuracy: 1e-9)
    }

    func testAnEmptyDatabaseExportsAValidEmptyBackup() async throws {
        let file = try Backup.parse(try await exporter.makeBackup())
        XCTAssertTrue(file.drinks.isEmpty)
        XCTAssertTrue(file.entries.isEmpty)
        XCTAssertEqual(file.version, BackupFile.currentVersion)
    }

    // ── Shape ────────────────────────────────────────────────────────────────

    /// `themeMode` is an enum in the app and a string in the file. Every other
    /// field is copied straight across; a test rather than trust.
    func testSettingsMapFieldForField() {
        let settings = AppSettings(
            themeMode: .night, dayChangeHour: 3, dayChangeMinute: 15,
            dailyLimitGrams: 24, weeklyLimitGrams: 120, maxDrinkDaysPerWeek: 4,
            statsFromDate: "2026-01-01", biometricEnabled: true, allowScreenshots: true,
            alternativeStatusSymbols: true, language: "de", weightKg: 82.5
        )
        let mapped = BackupExporter.backupSettings(from: settings)

        XCTAssertEqual(mapped.themeMode, "NIGHT")
        XCTAssertEqual(mapped.dayChangeHour, 3)
        XCTAssertEqual(mapped.dayChangeMinute, 15)
        XCTAssertEqual(mapped.dailyLimitGrams, 24, accuracy: 1e-9)
        XCTAssertEqual(mapped.weeklyLimitGrams, 120, accuracy: 1e-9)
        XCTAssertEqual(mapped.maxDrinkDaysPerWeek, 4)
        XCTAssertEqual(mapped.statsFromDate, "2026-01-01")
        XCTAssertTrue(mapped.biometricEnabled)
        XCTAssertTrue(mapped.allowScreenshots)
        XCTAssertTrue(mapped.alternativeStatusSymbols)
        XCTAssertEqual(mapped.language, "de")
        XCTAssertEqual(mapped.weightKg, 82.5, accuracy: 1e-9)
    }

    /// Android writes `potillus_backup_20260102_2014.json`. Same convention, so a
    /// user with both phones finds their backups sorted together.
    func testTheFileNameFollowsAndroidsConvention() {
        let name = BackupExporter.suggestedFileName(
            now: Date(timeIntervalSince1970: 1_767_384_840)  // 2026-01-02 20:14 UTC
        )
        XCTAssertTrue(name.hasPrefix("potillus_backup_"), name)
        XCTAssertTrue(name.hasSuffix(".json"), name)
        XCTAssertFalse(name.contains("-"), "underscores, as on Android")
    }

    /// `exportedAt` is RFC 3339 in UTC, as Kotlin's `Instant.toString()` writes it.
    func testTheExportTimestampIsUtcAndEndsInZ() {
        let stamp = BackupExporter.timestamp(now: Date(timeIntervalSince1970: 1_767_384_840))
        XCTAssertEqual(stamp, "2026-01-02T20:14:00Z")
    }
}
