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
// BackupTests.swift – the JSON backup is the interoperability contract
// =============================================================================
//
// The centrepiece is `testReadsTheRealAndroidDemoBackup`: it parses
// `fastlane/demo-backup.json`, a genuine backup written by the Android app and
// already committed to this repository as the screenshot fixture. If iOS can
// read that file, byte for byte as it exists, the compatibility claim is
// demonstrated rather than asserted.
//
// The remaining tests pin the format's compatibility rules — strict on required
// fields, lenient on optional ones, and a hard refusal to read a file written by
// a newer app.
// =============================================================================

final class BackupTests: XCTestCase {

    // ── The real fixture ─────────────────────────────────────────────────────

    private func demoBackupData() throws -> Data {
        try TestVectors.repositoryFile("fastlane/demo-backup.json")
    }

    func testReadsTheRealAndroidDemoBackup() throws {
        let backup = try BackupReader.parse(try demoBackupData())

        XCTAssertEqual(backup.version, 2, "the fixture is a format 2 file")
        XCTAssertEqual(backup.exportedAt, "2026-06-30T20:00:00Z")
        XCTAssertEqual(backup.drinks.count, 15)
        XCTAssertEqual(backup.entries.count, 85)
        XCTAssertNil(backup.settings, "a pre-v3 file carries no settings block")
    }

    /// Every category string in the fixture must map onto a known case; a silent
    /// decay to `.other` here would mean the two enums had diverged.
    func testEveryCategoryInTheFixtureIsKnown() throws {
        let backup = try BackupReader.parse(try demoBackupData())
        let categories = Set(backup.drinks.map(\.category))
        XCTAssertFalse(categories.contains(.other), "no drink should decay to OTHER")
        XCTAssertTrue(categories.isSuperset(of: [.beer, .wine, .spirits]))
    }

    func testFixtureEntriesCarryTheirFieldsIntact() throws {
        let backup = try BackupReader.parse(try demoBackupData())
        let first = try XCTUnwrap(backup.entries.first)

        XCTAssertEqual(first.id, 1)
        XCTAssertEqual(first.drinkId, 7)
        XCTAssertEqual(first.drinkName, "Red Wine (Regular)")
        XCTAssertEqual(first.gramsAlcohol, 15.98, accuracy: 1e-9)
        XCTAssertEqual(first.timestampMillis, 1_767_381_240_000)
        XCTAssertEqual(first.logicalDate, "2026-01-02")
        XCTAssertEqual(first.note, "", "absent note reads as the empty string, never nil")
    }

    /// Read the real file, write it back, read it again: no field may be lost or
    /// altered along the way.
    func testRoundTripOfTheRealFixturePreservesEverything() throws {
        let original = try BackupReader.parse(try demoBackupData())
        let rewritten = try BackupReader.parse(try BackupWriter.makeJSON(original))

        XCTAssertEqual(rewritten.drinks, original.drinks)
        XCTAssertEqual(rewritten.entries, original.entries)
        XCTAssertEqual(rewritten.version, original.version)
        XCTAssertEqual(rewritten.exportedAt, original.exportedAt)
    }

    /// Sorted keys make an export deterministic: the same data always produces
    /// the same bytes, so a diff of two backups shows only real changes.
    func testWritingIsDeterministic() throws {
        let backup = try BackupReader.parse(try demoBackupData())
        let first = try BackupWriter.makeJSON(backup)
        let second = try BackupWriter.makeJSON(backup)
        XCTAssertEqual(first, second)
    }

    // ── Version gating ───────────────────────────────────────────────────────

    /// Reading a newer file would look like success while silently dropping the
    /// fields this code does not know. Refuse instead.
    func testAFileFromANewerAppIsRejected() throws {
        let data = try json(["version": BackupFile.currentVersion + 1, "drinks": [], "entries": []])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(
                error as? BackupError,
                .versionTooHigh(found: BackupFile.currentVersion + 1, max: BackupFile.currentVersion)
            )
        }
    }

    /// A file with no version key predates versioning: it is format 1.
    func testAMissingVersionKeyMeansFormatOne() throws {
        let data = try json(["drinks": [], "entries": []])
        XCTAssertEqual(try BackupReader.parse(data).version, 1)
    }

    // ── Optional fields tolerate old files ───────────────────────────────────

    /// Format 1 drinks have no `category`; they must restore as OTHER, not fail.
    func testADrinkWithoutACategoryBecomesOther() throws {
        let data = try json([
            "version": 1,
            "drinks": [["id": 1, "name": "Pils", "volumeMl": 500, "alcoholPercent": 4.9]],
            "entries": [],
        ])
        let backup = try BackupReader.parse(data)
        XCTAssertEqual(backup.drinks.first?.category, .other)
        XCTAssertEqual(backup.drinks.first?.isPreset, false)
        XCTAssertEqual(backup.drinks.first?.isFavorite, false)
    }

    /// A category added by a future version decays rather than throwing.
    func testAnUnknownCategoryDecaysToOther() throws {
        let data = try json([
            "version": 2,
            "drinks": [["id": 1, "name": "Cider", "volumeMl": 500, "alcoholPercent": 4.5,
                        "category": "CIDER"]],
            "entries": [],
        ])
        XCTAssertEqual(try BackupReader.parse(data).drinks.first?.category, .other)
    }

    /// Unknown keys inside a known object are ignored, so a field added later
    /// never breaks an older reader.
    func testUnknownKeysAreIgnored() throws {
        let data = try json([
            "version": 2,
            "somethingNew": 42,
            "drinks": [["id": 1, "name": "Pils", "volumeMl": 500, "alcoholPercent": 4.9,
                        "futureField": true]],
            "entries": [],
        ])
        XCTAssertEqual(try BackupReader.parse(data).drinks.count, 1)
    }

    /// `JSONSerialization` types numbers strictly, so an ABV written as `5`
    /// rather than `5.0` must still read as a Double — Android's `org.json`
    /// coerces both ways and a backup must cross the boundary either direction.
    func testIntegersCoerceToDoublesAndBack() throws {
        let data = try json([
            "version": 2,
            "drinks": [["id": 1, "name": "Pils", "volumeMl": 500, "alcoholPercent": 5]],
            "entries": [],
        ])
        XCTAssertEqual(try BackupReader.parse(data).drinks.first?.alcoholPercent ?? 0, 5.0, accuracy: 1e-9)
    }

    // ── Required fields are strict ───────────────────────────────────────────

    func testAMissingRequiredDrinkFieldIsAnError() throws {
        let data = try json([
            "version": 2,
            "drinks": [["id": 1, "volumeMl": 500, "alcoholPercent": 4.9]],  // no name
            "entries": [],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError, .missingField(object: "drink", key: "name"))
        }
    }

    func testAMissingRequiredEntryFieldIsAnError() throws {
        let data = try json([
            "version": 2,
            "drinks": [],
            "entries": [["id": 1, "drinkId": 1, "drinkName": "Pils", "volumeMl": 500,
                         "alcoholPercent": 4.9, "logicalDate": "2026-01-01"]],  // no grams, no timestamp
        ])
        XCTAssertThrowsError(try BackupReader.parse(data))
    }

    /// A malformed logical date would silently mis-bucket every statistic built
    /// on it, so it is rejected at the door.
    func testAMalformedLogicalDateIsRejected() throws {
        let data = try json([
            "version": 2,
            "drinks": [],
            "entries": [["id": 1, "drinkId": 1, "drinkName": "Pils", "volumeMl": 500,
                         "alcoholPercent": 4.9, "gramsAlcohol": 19.3,
                         "timestampMillis": 1_767_381_240_000, "logicalDate": "01/02/2026"]],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError, .malformedDate("01/02/2026"))
        }
    }

    // ── Value ranges (Android BackupManager Guard 2/3/4 parity) ──────────────
    //
    // Physically impossible values must be refused at parse time, before they
    // reach the database and corrupt the BAC / statistics maths. The GRDB schema
    // only constrains nullability, so the reader is the last line of defence.

    func testAnOutOfRangeDrinkVolumeIsRejected() throws {
        let data = try json([
            "version": 2,
            "drinks": [["id": 1, "name": "Pils", "volumeMl": 0, "alcoholPercent": 4.9]],
            "entries": [],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError,
                           .valueOutOfRange(object: "drink", key: "volumeMl", value: "0"))
        }
    }

    func testAnOutOfRangeDrinkAlcoholPercentIsRejected() throws {
        let data = try json([
            "version": 2,
            "drinks": [["id": 1, "name": "Pils", "volumeMl": 500, "alcoholPercent": 150.0]],
            "entries": [],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError,
                           .valueOutOfRange(object: "drink", key: "alcoholPercent", value: "150.0"))
        }
    }

    func testANegativeEntryGramsAlcoholIsRejected() throws {
        let data = try json([
            "version": 2,
            "drinks": [],
            "entries": [["id": 1, "drinkId": 1, "drinkName": "Pils", "volumeMl": 500,
                         "alcoholPercent": 4.9, "gramsAlcohol": -1.0,
                         "timestampMillis": 1_767_381_240_000, "logicalDate": "2026-01-01"]],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError,
                           .valueOutOfRange(object: "entry", key: "gramsAlcohol", value: "-1.0"))
        }
    }

    func testANonPositiveEntryTimestampIsRejected() throws {
        let data = try json([
            "version": 2,
            "drinks": [],
            "entries": [["id": 1, "drinkId": 1, "drinkName": "Pils", "volumeMl": 500,
                         "alcoholPercent": 4.9, "gramsAlcohol": 19.3,
                         "timestampMillis": 0, "logicalDate": "2026-01-01"]],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError,
                           .valueOutOfRange(object: "entry", key: "timestampMillis", value: "0"))
        }
    }

    /// A non-finite number (JSON `1e400` decodes to `Double.infinity`) would
    /// propagate through every SUM(); it must not slip through as a finite value.
    func testANonFiniteEntryAlcoholPercentIsRejected() throws {
        let raw = """
        {"version":2,"drinks":[],"entries":[{"id":1,"drinkId":1,"drinkName":"Pils",\
        "volumeMl":500,"alcoholPercent":1e400,"gramsAlcohol":19.3,\
        "timestampMillis":1767381240000,"logicalDate":"2026-01-01"}]}
        """
        XCTAssertThrowsError(try BackupReader.parse(Data(raw.utf8)))
    }

    /// A lenient formatter can CLAMP an impossible day to a valid one; the
    /// parse -> format round-trip rejects the clamped result. February 30th does
    /// not exist, so it must be refused rather than quietly stored as the 28th.
    func testAClampedCalendarDateIsRejected() throws {
        let data = try json([
            "version": 2,
            "drinks": [],
            "entries": [["id": 1, "drinkId": 1, "drinkName": "Pils", "volumeMl": 500,
                         "alcoholPercent": 4.9, "gramsAlcohol": 19.3,
                         "timestampMillis": 1_767_381_240_000, "logicalDate": "2026-02-30"]],
        ])
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError, .malformedDate("2026-02-30"))
        }
    }

    // ── Size limit (Android MAX_BACKUP_BYTES parity) ─────────────────────────

    /// The in-`parse` backstop refuses an over-limit buffer before the JSON
    /// parser walks it, regardless of how the bytes were obtained.
    func testOversizedDataIsRejected() {
        let data = Data(count: BackupReader.maxBackupBytes + 1)
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(
                error as? BackupError,
                .fileTooLarge(foundBytes: BackupReader.maxBackupBytes + 1,
                              maxBytes: BackupReader.maxBackupBytes))
        }
    }

    func testReadDataReadsAWellSizedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        let payload = Data(#"{"version":2,"drinks":[],"entries":[]}"#.utf8)
        try payload.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let read = try BackupReader.readData(from: url)
        XCTAssertEqual(read, payload)
        // And the bytes parse into an empty, valid backup.
        let backup = try BackupReader.parse(read)
        XCTAssertTrue(backup.drinks.isEmpty)
        XCTAssertTrue(backup.entries.isEmpty)
    }

    func testReadDataRejectsAnOversizedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        try Data(count: BackupReader.maxBackupBytes + 1).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try BackupReader.readData(from: url)) { error in
            guard case .fileTooLarge = (error as? BackupError) else {
                return XCTFail("expected .fileTooLarge, got \(error)")
            }
        }
    }

    // ── Malformed input ──────────────────────────────────────────────────────

    func testEmptyDataIsAnError() {
        XCTAssertThrowsError(try BackupReader.parse(Data())) { error in
            XCTAssertEqual(error as? BackupError, .fileEmpty)
        }
    }

    func testNonJSONDataIsAnError() throws {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError, .invalidJSON)
        }
    }

    func testAJSONArrayRootIsAnError() throws {
        let data = Data("[1,2,3]".utf8)
        XCTAssertThrowsError(try BackupReader.parse(data)) { error in
            XCTAssertEqual(error as? BackupError, .invalidJSON)
        }
    }

    // ── Settings block ───────────────────────────────────────────────────────

    /// A format 3 settings block survives a read/write round trip unchanged. The
    /// raw block is preserved verbatim by the reader; `SettingsSanitizer` clamps
    /// it only later, at import time.
    func testSettingsSurviveARoundTrip() throws {
        let settings = BackupSettings(
            themeMode: "DARK", dayChangeHour: 5, dayChangeMinute: 30,
            dailyLimitGrams: 24.0, weeklyLimitGrams: 120.0, maxDrinkDaysPerWeek: 4,
            statsFromDate: "2026-01-01", biometricEnabled: true, allowScreenshots: false,
            alternativeStatusSymbols: true, language: "de", weightKg: 82.5
        )
        let backup = BackupFile(
            version: 3, exportedAt: "2026-07-09T12:00:00Z",
            drinks: [], entries: [], settings: settings
        )

        let reparsed = try BackupReader.parse(try BackupWriter.makeJSON(backup))
        XCTAssertEqual(reparsed.settings, settings)
    }

    /// An iOS export currently omits the settings key, exactly as a format 1 or 2
    /// file does, so an Android import leaves the local preferences untouched.
    func testAnExportWithoutSettingsOmitsTheKey() throws {
        let backup = BackupFile(exportedAt: "2026-07-09T12:00:00Z", drinks: [], entries: [])
        let data = try BackupWriter.makeJSON(backup)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(root["settings"])
        XCTAssertNotNil(root["_comment"], "the GPL notice travels with the file")
    }

    // ── Helper ───────────────────────────────────────────────────────────────

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}
