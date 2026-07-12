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
// BackupValidationTests.swift – the reader is the last line of defence
// =============================================================================
//
// These tests were split out of BackupTests in the v0.82.0 QA round: they cover
// the import GUARDS — value-range rejection (Android BackupManager Guard 2/3/4
// parity) and the byte-size cap (MAX_BACKUP_BYTES parity) — while BackupTests
// keeps the format-compatibility and round-trip suite. The split is not cosmetic:
// together in one class the two suites exceeded SwiftLint's `type_body_length`
// limit, which `--strict` turns into a build error. Grouping the rejection tests
// here keeps each class within the limit AND reads more clearly, because a reader
// looking for "what does the importer refuse?" now finds it in one place.
//
// The `json(_:)` helper is duplicated from BackupTests rather than shared: a
// three-line JSONSerialization wrapper is not worth a common base class, and a
// self-contained test file is easier to read than one that reaches into another.
// =============================================================================

final class BackupValidationTests: XCTestCase {

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
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
}
