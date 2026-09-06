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
// BackupImporterTests.swift – restoring must not re-attribute history
// =============================================================================
//
// Against a real in-memory database and a real encrypted preferences store.
// The failures worth catching here are the quiet ones: an entry that ends up
// pointing at the wrong drink, a second import that doubles the log, a partial
// import left behind by a mid-way failure.
// =============================================================================

final class BackupImporterTests: XCTestCase {

    private var database: AppDatabase!
    private var drinks: DrinkRepository!
    private var entries: EntryRepository!
    private var directory: URL!
    private var preferences: PreferencesStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try AppDatabase(inMemory: true)
        drinks = DrinkRepository(database: database)
        entries = EntryRepository(database: database)

        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        preferences = PreferencesStore(
            fileURL: directory.appendingPathComponent("prefs.bin"),
            keyProvider: InMemoryKeyProvider()
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        database = nil
        try super.tearDownWithError()
    }

    private func makeImporter() -> BackupImporter {
        BackupImporter(database: database, preferences: preferences, entries: entries)
    }

    private func backup(
        drinks backupDrinks: [DrinkDefinition],
        entries backupEntries: [ConsumptionEntry],
        settings: BackupSettings? = nil
    ) -> BackupFile {
        BackupFile(
            version: 3, exportedAt: "2026-07-09T12:00:00Z",
            drinks: backupDrinks, entries: backupEntries, settings: settings
        )
    }

    /// Noon on 2026-01-01, read at +00:00 — the instant every seeded entry sits on.
    private static let noonJan1: Int64 = 1_767_268_800_000

    /// One entry on the logical 1 January.
    ///
    /// `at` is a nudge WITHIN the day, not an instant: the timestamp is noon plus
    /// that many milliseconds. The instant and `logicalDate` HAVE TO AGREE here,
    /// and not only because the repository derives the day — the import repairs a
    /// reading that sits two or more days from the day it is filed under, and a
    /// bare `500` is fifty-six years away. It would be repaired, its timestamp
    /// would move, and the MERGE duplicate check, which matches on the timestamp,
    /// would stop recognising it.
    private func entry(drinkId: Int64, at millis: Int64, name: String = "x") -> ConsumptionEntry {
        ConsumptionEntry(
            drinkId: drinkId, drinkName: name, volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.3, timestampMillis: Self.noonJan1 + millis,
            logicalDate: "2026-01-01", utcOffsetSeconds: 0
        )
    }

    // ── Id remapping: the quiet corruption ───────────────────────────────────

    /// The backup's drink ids belong to another device. Joining on the NAME is
    /// what stops an entry logged as "Pils" from reappearing as "Whisky".
    func testEntriesAreRemappedOntoTheLocalDrinkOfTheSameName() async throws {
        // Local: Whisky is id 1, Pils is id 2.
        _ = try drinks.add(DrinkDefinition(name: "Whisky", volumeMl: 40, alcoholPercent: 40))
        let localPils = try drinks.add(DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9))

        // Backup: Pils happens to be id 1 there.
        let file = backup(
            drinks: [DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9)],
            entries: [entry(drinkId: 1, at: 1_000)]
        )
        try await makeImporter().restore(file, mode: .merge)

        let stored = try XCTUnwrap(try entries.all().first)
        XCTAssertEqual(stored.drinkId, localPils, "the entry must point at the LOCAL Pils")
    }

    /// A drink the device does not know is inserted, and the new id is used.
    func testAnUnknownBackupDrinkIsInserted() async throws {
        let file = backup(
            drinks: [DrinkDefinition(id: 7, name: "Cider", volumeMl: 500, alcoholPercent: 4.5)],
            entries: [entry(drinkId: 7, at: 1_000)]
        )
        try await makeImporter().restore(file, mode: .merge)

        let catalogue = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(catalogue.map(\.name), ["Cider"])

        let stored = try XCTUnwrap(try entries.all().first)
        XCTAssertEqual(stored.drinkId, catalogue[0].id)
    }

    /// A backup that lists the same name twice must not create two local rows.
    func testDuplicateNamesInTheBackupMapToOneLocalDrink() async throws {
        let file = backup(
            drinks: [
                DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9),
                DrinkDefinition(id: 2, name: "Pils", volumeMl: 500, alcoholPercent: 4.9),
            ],
            entries: [entry(drinkId: 1, at: 1_000), entry(drinkId: 2, at: 2_000)]
        )
        try await makeImporter().restore(file, mode: .merge)

        let catalogue = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(catalogue.count, 1)
        XCTAssertEqual(Set(try entries.all().map(\.drinkId)).count, 1)
    }

    /// An entry referencing a drink the backup never defines makes the file
    /// inconsistent. Importing it would orphan the entry, so the whole import
    /// aborts — and the transaction leaves nothing behind.
    func testAnUnmappedDrinkAbortsTheImportWithoutPartialData() async throws {
        let file = backup(
            drinks: [DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9)],
            entries: [entry(drinkId: 1, at: 1_000), entry(drinkId: 99, at: 2_000)]
        )

        do {
            try await makeImporter().restore(file, mode: .merge)
            XCTFail("an unmapped drink must abort the import")
        } catch {
            XCTAssertEqual(error as? ImportError, .unmappedDrink(backupDrinkId: 99))
        }

        XCTAssertTrue(try entries.all().isEmpty, "the transaction must have rolled back")
        let catalogue = try await firstValue(drinks.observeDrinks())
        XCTAssertTrue(catalogue.isEmpty, "the inserted drink must have rolled back too")
    }

    // ── REPLACE ──────────────────────────────────────────────────────────────

    /// REPLACE makes the catalogue identical to the backup: the old log and every
    /// local drink are wiped, including presets. A preset the backup omits ("Preset"
    /// here) is dropped; a preset the backup carries ("House Lager") is recreated
    /// with its `isPreset` flag intact. This is the v0.83.0 fix — previously the
    /// seeded presets lingered alongside the imported drinks.
    func testReplaceMakesTheCatalogueMatchTheBackupExactly() async throws {
        _ = try drinks.add(DrinkDefinition(name: "Preset", volumeMl: 500, alcoholPercent: 5, isPreset: true))
        _ = try drinks.add(DrinkDefinition(name: "House Lager", volumeMl: 500, alcoholPercent: 4.8, isPreset: true))
        let mine = try drinks.add(DrinkDefinition(name: "Mine", volumeMl: 500, alcoholPercent: 5))
        _ = try entries.add(entry(drinkId: mine, at: 500), settings: AppSettings())

        let file = backup(
            drinks: [
                DrinkDefinition(id: 1, name: "House Lager", volumeMl: 500, alcoholPercent: 4.8, isPreset: true),
                DrinkDefinition(id: 2, name: "Cider", volumeMl: 330, alcoholPercent: 4.5),
            ],
            entries: [entry(drinkId: 1, at: 1_000)]
        )
        let stats = try await makeImporter().restore(file, mode: .replace)

        XCTAssertEqual(stats, ImportStats(imported: 1, skipped: 0))
        XCTAssertEqual(try entries.all().count, 1, "the old entry is gone")

        let catalogue = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(
            Set(catalogue.map(\.name)), ["House Lager", "Cider"],
            "catalogue equals the backup; 'Preset' and 'Mine' are gone"
        )
        let lager = try XCTUnwrap(catalogue.first { $0.name == "House Lager" })
        XCTAssertTrue(lager.isPreset, "a preset in the backup keeps its isPreset flag")
    }

    // ── MERGE ────────────────────────────────────────────────────────────────

    /// Importing the same file twice must not double the history.
    func testMergeSkipsEntriesItAlreadyHas() async throws {
        let file = backup(
            drinks: [DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9)],
            entries: [entry(drinkId: 1, at: 1_000), entry(drinkId: 1, at: 2_000)]
        )

        let first = try await makeImporter().restore(file, mode: .merge)
        XCTAssertEqual(first, ImportStats(imported: 2, skipped: 0))

        let second = try await makeImporter().restore(file, mode: .merge)
        XCTAssertEqual(second, ImportStats(imported: 0, skipped: 2))
        XCTAssertEqual(try entries.all().count, 2, "a second import must add nothing")
    }

    /// The de-duplication key is timestamp AND drink: the same instant with a
    /// different drink is a real, separate entry.
    func testMergeKeepsTheSameInstantForADifferentDrink() async throws {
        let file = backup(
            drinks: [
                DrinkDefinition(id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9),
                DrinkDefinition(id: 2, name: "Wine", volumeMl: 200, alcoholPercent: 13),
            ],
            entries: [entry(drinkId: 1, at: 1_000), entry(drinkId: 2, at: 1_000)]
        )
        let stats = try await makeImporter().restore(file, mode: .merge)
        XCTAssertEqual(stats, ImportStats(imported: 2, skipped: 0))
    }

    // ── Settings ─────────────────────────────────────────────────────────────

    /// The gap left open in the backup port: settings are now applied.
    func testSettingsAreAppliedAndSanitised() async throws {
        let raw = BackupSettings(
            themeMode: "NIGHT", dayChangeHour: 99, dayChangeMinute: 30,
            dailyLimitGrams: 1e9, weeklyLimitGrams: 120.0, maxDrinkDaysPerWeek: 4,
            statsFromDate: "2026-1-1", biometricEnabled: true, allowScreenshots: false,
            alternativeStatusSymbols: true, language: "DE", weightKg: 82.5
        )
        try await makeImporter().restore(backup(drinks: [], entries: [], settings: raw), mode: .replace)

        let stored = await preferences.load()
        XCTAssertEqual(stored.themeMode, .night)
        XCTAssertEqual(stored.dayChangeHour, 23, "an absurd hour is clamped, not stored")
        XCTAssertEqual(stored.dailyLimitGrams, 500.0, accuracy: 1e-9, "an absurd limit is clamped")
        XCTAssertEqual(stored.statsFromDate, "", "a non-canonical date is dropped")
        XCTAssertEqual(stored.language, "de", "the language tag is canonicalised")
        XCTAssertEqual(stored.weightKg, 82.5, accuracy: 1e-9)
    }

    /// A pre-v3 backup carries no settings; the local ones must be left alone.
    func testABackupWithoutSettingsLeavesPreferencesUntouched() async throws {
        try await preferences.update { $0.weightKg = 70.0; $0.language = "fr" }

        try await makeImporter().restore(backup(drinks: [], entries: []), mode: .replace)

        let stored = await preferences.load()
        XCTAssertEqual(stored.weightKg, 70.0, accuracy: 1e-9)
        XCTAssertEqual(stored.language, "fr")
    }

    /// A MERGE must not touch the local settings. Nothing asserted this until the
    /// 0.84.0 review, which is how the two platforms diverged unseen: Android has
    /// always ignored a merged backup's settings, this side applied them.
    func testMergeLeavesTheLocalSettingsAlone() async throws {
        try await preferences.update { $0.weightKg = 70.0; $0.dailyLimitGrams = 20.0 }

        let raw = BackupSettings(
            themeMode: "NIGHT", dayChangeHour: 6, dayChangeMinute: 30,
            dailyLimitGrams: 99.0, weeklyLimitGrams: 400.0, maxDrinkDaysPerWeek: 7,
            statsFromDate: "2026-01-01", biometricEnabled: true, allowScreenshots: true,
            alternativeStatusSymbols: true, language: "fr", weightKg: 55.0
        )
        try await makeImporter().restore(
            backup(drinks: [], entries: [], settings: raw), mode: .merge
        )

        let stored = await preferences.load()
        XCTAssertEqual(stored.weightKg, 70.0, accuracy: 1e-9, "a merge must not restyle the user")
        XCTAssertEqual(
            stored.dailyLimitGrams, 20.0, accuracy: 1e-9,
            "the daily limit decides what the app says about the user's drinking"
        )
    }

    /// An importer without a preferences store imports data only, and does not
    /// fail on a backup that carries settings.
    func testAnImporterWithoutPreferencesIgnoresTheSettingsBlock() async throws {
        let raw = BackupSettings(
            themeMode: "NIGHT", dayChangeHour: 5, dayChangeMinute: 0,
            dailyLimitGrams: 23.0, weeklyLimitGrams: 137.0, maxDrinkDaysPerWeek: 6,
            statsFromDate: "", biometricEnabled: false, allowScreenshots: false,
            alternativeStatusSymbols: false, language: "", weightKg: 0.0
        )
        let importer = BackupImporter(database: database, preferences: nil)
        let stats = try await importer.restore(
            backup(drinks: [], entries: [], settings: raw), mode: .replace
        )
        XCTAssertEqual(stats, ImportStats(imported: 0, skipped: 0))
    }

    // ── The real fixture, end to end ─────────────────────────────────────────

    /// The strongest statement this suite can make: a genuine Android backup,
    /// parsed and imported, yields exactly its 15 drinks and 85 entries.
    func testTheRealAndroidDemoBackupImportsCompletely() async throws {
        let data = try TestVectors.repositoryFile("fastlane/demo-backup.json")
        let file = try BackupReader.parse(data)

        let stats = try await makeImporter().restore(file, mode: .replace)
        XCTAssertEqual(stats, ImportStats(imported: 85, skipped: 0))

        let catalogue = try await firstValue(drinks.observeDrinks())
        XCTAssertEqual(catalogue.count, 15)
        XCTAssertEqual(try entries.all().count, 85)

        // Every entry resolves to a drink that exists.
        let ids = Set(catalogue.compactMap(\.id))
        for stored in try entries.all() {
            XCTAssertTrue(ids.contains(stored.drinkId), "orphaned entry after import")
        }
    }

    // ── Helper ───────────────────────────────────────────────────────────────

    private func firstValue<T>(_ stream: AsyncThrowingStream<T, Error>) async throws -> T {
        for try await value in stream { return value }
        throw XCTSkip("observation finished without emitting a value")
    }
}

// The settings cases sit in an extension rather than in the class body: SwiftLint
// counts only the body against `type_body_length`, and the suite had reached it.
extension BackupImporterTests {

    /// Settings replace the local ones — except the three "absent" sentinels,
    /// which leave the local value standing, as on Android. (Until v0.86.0 this
    /// side replaced wholesale: a backup with an empty `statsFromDate` erased
    /// the seeded floor.)
    func testSettingsReplaceExceptForAbsentSentinels() async throws {
        try await preferences.update {
            $0.weightKg = 70.0; $0.language = "fr"; $0.statsFromDate = "2025-06-01"
            $0.biometricEnabled = true; $0.dailyLimitGrams = 20.0
        }

        let raw = BackupSettings(
            themeMode: "SYSTEM", dayChangeHour: 4, dayChangeMinute: 0,
            dailyLimitGrams: 23.0, weeklyLimitGrams: 137.0, maxDrinkDaysPerWeek: 6,
            statsFromDate: "", biometricEnabled: false, allowScreenshots: false,
            alternativeStatusSymbols: false, language: "", weightKg: 0.0
        )
        let stats = try await makeImporter().restore(
            backup(drinks: [], entries: [], settings: raw), mode: .replace
        )

        let stored = await preferences.load()
        XCTAssertEqual(stored.dailyLimitGrams, 23.0, accuracy: 1e-9, "a real value replaces")
        XCTAssertFalse(stored.biometricEnabled, "false is a value, not an absence")
        XCTAssertEqual(stored.weightKg, 70.0, accuracy: 1e-9, "0 means unset: the local weight stays")
        XCTAssertEqual(stored.language, "fr", "\"\" means follow the system: the local choice stays")
        XCTAssertEqual(stored.statsFromDate, "2025-06-01", "\"\" means no floor: the local floor stays")
        XCTAssertFalse(stats.lockNotRestored)
    }

    /// The lock fails closed, so a backup's `biometricEnabled` is armed only on
    /// a device that can authenticate; otherwise it is left off and reported.
    func testTheLockIsNotRestoredOnADeviceThatCannotAuthenticate() async throws {
        let raw = BackupSettings(
            themeMode: "SYSTEM", dayChangeHour: 4, dayChangeMinute: 0,
            dailyLimitGrams: 20.0, weeklyLimitGrams: 80.0, maxDrinkDaysPerWeek: 4,
            statsFromDate: "2026-01-01", biometricEnabled: true, allowScreenshots: false,
            alternativeStatusSymbols: false, language: "de", weightKg: 80.0
        )

        let refused = try await makeImporter().restore(
            backup(drinks: [], entries: [], settings: raw), mode: .replace, deviceCanAuthenticate: false
        )
        XCTAssertTrue(refused.lockNotRestored)
        let afterRefusal = await preferences.load()
        XCTAssertFalse(afterRefusal.biometricEnabled)
        XCTAssertEqual(afterRefusal.language, "de", "everything else is applied")

        let armed = try await makeImporter().restore(
            backup(drinks: [], entries: [], settings: raw), mode: .replace, deviceCanAuthenticate: true
        )
        XCTAssertFalse(armed.lockNotRestored)
        let afterArming = await preferences.load()
        XCTAssertTrue(afterArming.biometricEnabled)
    }

    /// The shared `apply` vectors in backup-settings.json; Android's
    /// `SettingsViewModelTest` drives `applyImportedSettings` through the same
    /// cases.
    func testApplyMatchesTheSharedVectors() async throws {
        let vectors = try TestVectors.load("backup-settings", as: SettingsVectors.self)
        for testCase in vectors.apply {
            try await preferences.replace(with: AppSettings(
                statsFromDate: testCase.local.statsFromDate,
                biometricEnabled: testCase.local.biometricEnabled,
                language: testCase.local.language,
                weightKg: testCase.local.weightKg
            ))
            let raw = BackupSettings(
                themeMode: "SYSTEM", dayChangeHour: 4, dayChangeMinute: 0,
                dailyLimitGrams: 20.0, weeklyLimitGrams: 80.0, maxDrinkDaysPerWeek: 4,
                statsFromDate: testCase.backup.statsFromDate,
                biometricEnabled: testCase.backup.biometricEnabled,
                allowScreenshots: false, alternativeStatusSymbols: false,
                language: testCase.backup.language, weightKg: testCase.backup.weightKg
            )

            let stats = try await makeImporter().restore(
                backup(drinks: [], entries: [], settings: raw), mode: .replace,
                deviceCanAuthenticate: testCase.deviceCanAuthenticate
            )

            let stored = await preferences.load()
            let what = testCase.description
            XCTAssertEqual(stored.language, testCase.expected.language, "\(what): language")
            XCTAssertEqual(
                stored.weightKg, testCase.expected.weightKg, accuracy: 1e-9, "\(what): weightKg"
            )
            XCTAssertEqual(stored.statsFromDate, testCase.expected.statsFromDate, "\(what): statsFromDate")
            XCTAssertEqual(
                stored.biometricEnabled, testCase.expected.biometricEnabled, "\(what): biometricEnabled"
            )
            XCTAssertEqual(
                stats.lockNotRestored, testCase.expected.lockNotRestored, "\(what): lockNotRestored"
            )
        }
    }
}

// =============================================================================
// The logical day after an import
// =============================================================================
//
// An extension, not more members: `type_body_length` counts the class body and
// this suite was already at the limit.

extension BackupImporterTests {

    /// 02:00 UTC on 2 January, read at +00:00, filed under the 2nd — the day a
    /// backup written under a MIDNIGHT boundary carries. Under this device's
    /// default 04:00 boundary it belongs to the 1st; whether it gets there is
    /// what the tests below ask.
    private func twoAmJan2(drinkId: Int64) -> ConsumptionEntry {
        ConsumptionEntry(
            drinkId: drinkId, drinkName: "x", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.3, timestampMillis: Self.noonJan1 + 14 * 3_600_000,
            logicalDate: "2026-01-02", utcOffsetSeconds: 0
        )
    }

    /// A MERGE writes no setting, so nothing but the import itself can put the
    /// derived day back in force. Until the v0.86.0 QA round nothing did, and a
    /// merged backup kept the file's days until the next launch.
    func testMergeDerivesTheImportedDaysUnderTheLocalBoundary() async throws {
        let file = backup(
            drinks: [DrinkDefinition(id: 1, name: "x", volumeMl: 500, alcoholPercent: 4.9)],
            entries: [twoAmJan2(drinkId: 1)],
            settings: BackupSettings(
                themeMode: "SYSTEM", dayChangeHour: 0, dayChangeMinute: 0,
                dailyLimitGrams: 24.0, weeklyLimitGrams: 140.0, maxDrinkDaysPerWeek: 5,
                statsFromDate: "", biometricEnabled: false, allowScreenshots: false,
                alternativeStatusSymbols: false, language: "", weightKg: 0.0
            )
        )
        try await makeImporter().restore(file, mode: .merge)

        let stored = try XCTUnwrap(try entries.all().first)
        XCTAssertEqual(stored.logicalDate, "2026-01-01", "the file's midnight day gives way to the local 04:00")
    }

    /// A REPLACE with a settings block moves the boundary first and derives the
    /// days under the boundary it RESTORED, not the one in force when the import
    /// began.
    func testReplaceDerivesTheImportedDaysUnderTheRestoredBoundary() async throws {
        let file = backup(
            drinks: [DrinkDefinition(id: 1, name: "x", volumeMl: 500, alcoholPercent: 4.9)],
            entries: [twoAmJan2(drinkId: 1)],
            settings: BackupSettings(
                themeMode: "SYSTEM", dayChangeHour: 3, dayChangeMinute: 0,
                dailyLimitGrams: 24.0, weeklyLimitGrams: 140.0, maxDrinkDaysPerWeek: 5,
                statsFromDate: "", biometricEnabled: false, allowScreenshots: false,
                alternativeStatusSymbols: false, language: "", weightKg: 0.0
            )
        )
        try await makeImporter().restore(file, mode: .replace)

        let settings = await preferences.load()
        XCTAssertEqual(settings.dayChangeHour, 3)
        let stored = try XCTUnwrap(try entries.all().first)
        XCTAssertEqual(stored.logicalDate, "2026-01-01", "02:00 is before the restored 03:00 boundary")
    }

    /// Without an entry repository the importer leaves the derivation to
    /// `DayRealignment`, and a settings-less REPLACE still lands.
    func testAnImporterWithoutEntriesLeavesTheFileDaysStanding() async throws {
        let importer = BackupImporter(database: database, preferences: preferences)
        let file = backup(
            drinks: [DrinkDefinition(id: 1, name: "x", volumeMl: 500, alcoholPercent: 4.9)],
            entries: [twoAmJan2(drinkId: 1)]
        )
        try await importer.restore(file, mode: .replace)

        let stored = try XCTUnwrap(try entries.all().first)
        XCTAssertEqual(stored.logicalDate, "2026-01-02", "nothing derived: the collector will")
    }

}
