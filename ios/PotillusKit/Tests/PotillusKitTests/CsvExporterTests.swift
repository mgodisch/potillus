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
// CsvExporterTests.swift – cross-platform parity suite
// =============================================================================
//
// Driven by `test-vectors/csv-export.json`, the same file the Android JVM suite
// asserts against. The vectors carry the exact expected document, CRLF endings
// and all, so a divergence in quoting, ordering, number formatting or the
// formula guard turns one side red.
// =============================================================================

/// Root of `test-vectors/csv-export.json`.
struct CsvVectors: Decodable {
    let escapeField: [EscapeCase]
    let buildCsv: [BuildCase]

    struct EscapeCase: Decodable {
        let description: String
        let input: String
        let expected: String
    }

    struct BuildCase: Decodable {
        let description: String
        let headers: [String]
        let entries: [VectorEntry]
        let drinks: [VectorDrink]
        let zoneId: String
        let expected: String
    }

    struct VectorEntry: Decodable {
        let drinkId: Int64
        let drinkName: String
        let volumeMl: Int
        let alcoholPercent: Double
        let gramsAlcohol: Double
        let timestampMillis: Int64
        let logicalDate: String
        let note: String

        var domain: ConsumptionEntry {
            ConsumptionEntry(
                drinkId: drinkId, drinkName: drinkName, volumeMl: volumeMl,
                alcoholPercent: alcoholPercent, gramsAlcohol: gramsAlcohol,
                timestampMillis: timestampMillis, logicalDate: logicalDate, note: note
            )
        }
    }

    struct VectorDrink: Decodable {
        let id: Int64
        let category: String

        var domain: DrinkDefinition {
            DrinkDefinition(
                id: id, name: "", volumeMl: 0, alcoholPercent: 0,
                category: DrinkCategory.from(stored: category)
            )
        }
    }
}

final class CsvExporterTests: XCTestCase {

    private static var loadedVectors: CsvVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("csv-export", as: CsvVectors.self)
        } catch {
            XCTFail("Could not load the shared CSV vectors: \(error)")
        }
    }

    private var vectors: CsvVectors { Self.loadedVectors }

    // ── escapeField ──────────────────────────────────────────────────────────

    func testEscapeFieldAgainstSharedVectors() {
        for testCase in vectors.escapeField {
            XCTAssertEqual(
                CsvExporter.escapeField(testCase.input), testCase.expected,
                "escapeField: \(testCase.description)"
            )
        }
    }

    // ── buildCsv ─────────────────────────────────────────────────────────────

    func testBuildCsvAgainstSharedVectors() throws {
        for testCase in vectors.buildCsv {
            let zone = try XCTUnwrap(
                TimeZone(identifier: testCase.zoneId), "unknown zone \(testCase.zoneId)"
            )
            let actual = CsvExporter.buildCsv(
                headerCells: testCase.headers,
                entries: testCase.entries.map(\.domain),
                drinks: testCase.drinks.map(\.domain),
                timeZone: zone
            )
            XCTAssertEqual(actual, testCase.expected, "buildCsv: \(testCase.description)")
        }
    }

    // ── Structural tests (not vector-driven) ─────────────────────────────────

    /// RFC 4180 §2: every record, including the last, ends with CRLF. A bare LF
    /// would leave older Excel versions reading one long line.
    func testEveryRecordEndsWithCRLFIncludingTheLast() {
        let csv = CsvExporter.buildCsv(headerCells: ["A", "B"], entries: [], drinks: [])
        XCTAssertTrue(csv.hasSuffix("\r\n"))
        XCTAssertFalse(csv.contains("\n\n"))
        XCTAssertEqual(csv, "A,B\r\n")
    }

    /// The grams column must never use a comma as the decimal separator, whatever
    /// the process locale: that comma would split the value across two columns.
    func testGramsUseADotDecimalSeparator() {
        let entry = ConsumptionEntry(
            drinkId: 1, drinkName: "x", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.6, timestampMillis: 0, logicalDate: "2026-01-01"
        )
        let csv = CsvExporter.buildCsv(
            headerCells: ["d", "t", "n", "c", "v", "a", "g", "note"],
            entries: [entry], drinks: [], timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertTrue(csv.contains(",19.60,"), "expected a dot separator, got: \(csv)")
        XCTAssertFalse(csv.contains("19,60"))
    }

    /// The BOM belongs to the file, not to the document.
    func testBuildCsvDoesNotEmitTheBomButFileDataDoes() {
        let csv = CsvExporter.buildCsv(headerCells: ["A"], entries: [], drinks: [])
        XCTAssertFalse(csv.hasPrefix("\u{FEFF}"))

        let bytes = CsvExporter.fileData(csv: csv)
        XCTAssertEqual(bytes.prefix(3), CsvExporter.utf8BOM)
    }

    /// A drink deleted since the entry was logged must not break the export.
    func testAnEntryWhoseDrinkIsGoneFallsBackToOther() {
        let entry = ConsumptionEntry(
            drinkId: 404, drinkName: "Ghost", volumeMl: 100, alcoholPercent: 40.0,
            gramsAlcohol: 31.56, timestampMillis: 0, logicalDate: "2026-01-01"
        )
        let csv = CsvExporter.buildCsv(
            headerCells: ["d", "t", "n", "c", "v", "a", "g", "note"],
            entries: [entry], drinks: [], timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertTrue(csv.contains(",OTHER,"))
    }

    /// The time column shows wall-clock time in the given zone; `logicalDate` is
    /// the stored logical day. Around the day-change hour the two disagree, and
    /// that is correct.
    func testTimeColumnFollowsTheGivenZone() {
        let entry = ConsumptionEntry(
            drinkId: 1, drinkName: "x", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.3, timestampMillis: 1_767_381_240_000,
            logicalDate: "2026-01-02"
        )
        let headers = ["d", "t", "n", "c", "v", "a", "g", "note"]

        let berlin = CsvExporter.buildCsv(
            headerCells: headers, entries: [entry], drinks: [],
            timeZone: TimeZone(identifier: "Europe/Berlin")!
        )
        let newYork = CsvExporter.buildCsv(
            headerCells: headers, entries: [entry], drinks: [],
            timeZone: TimeZone(identifier: "America/New_York")!
        )

        XCTAssertTrue(berlin.contains(",20:14,"))
        XCTAssertTrue(newYork.contains(",14:14,"))
    }

    /// The formula guard must not fire on a character that merely appears later
    /// in the field, or ordinary text would gain stray quotes.
    func testFormulaGuardOnlyFiresOnTheFirstCharacter() {
        XCTAssertEqual(CsvExporter.escapeField("a=1+1"), "a=1+1")
        XCTAssertEqual(CsvExporter.escapeField("=1+1"), "'=1+1")
    }

    // ── File name and headers ────────────────────────────────────────────────

    /// Android writes `libellus_potionis_export_20260102_201400.csv`. Same convention, so a
    /// spreadsheet built against one platform's export opens against the other's.
    func testTheFileNameFollowsAndroidsConvention() {
        let name = CsvExporter.suggestedFileName(
            now: Date(timeIntervalSince1970: 1_767_384_840)  // 2026-01-02 20:14 UTC
        )
        XCTAssertTrue(name.hasPrefix("libellus_potionis_export_"), name)
        XCTAssertTrue(name.hasSuffix(".csv"), name)
    }

    /// The header must have exactly as many cells as a row has columns, or every
    /// spreadsheet reading the file misaligns.
    func testTheHeaderHasOneCellPerColumn() {
        let drink = DrinkDefinition(
            id: 1, name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer
        )
        let entry = ConsumptionEntry(
            drinkId: 1, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
            gramsAlcohol: 19.3, timestampMillis: 1_767_384_840_000, logicalDate: "2026-01-02"
        )
        let csv = CsvExporter.buildCsv(
            headerCells: CsvExporter.englishHeaderCells,
            entries: [entry], drinks: [drink],
            timeZone: TimeZone(identifier: "UTC")!
        )

        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2, "a header and one record")
        XCTAssertEqual(
            lines[0].components(separatedBy: ",").count,
            lines[1].components(separatedBy: ",").count,
            "header and row must have the same number of columns"
        )
        XCTAssertEqual(CsvExporter.englishHeaderCells.count, 8)
    }

    // ── Localized headers (Android csv_col_* parity) ─────────────────────────

    func testHeaderCellsAreLocalized() {
        // Verbatim from Android's values-de/strings.xml csv_col_*.
        XCTAssertEqual(
            CsvHeaderLabels.cells(language: "de"),
            ["Datum", "Uhrzeit", "Getränk", "Kategorie",
             "Menge_ml", "Alkohol_Prozent", "Gramm_Alkohol", "Notiz"])
    }

    func testHeaderCellsFallBackToEnglish() {
        // The "System" setting (empty tag) and any unknown language use English.
        XCTAssertEqual(CsvHeaderLabels.cells(language: ""), CsvHeaderLabels.englishCells)
        XCTAssertEqual(CsvHeaderLabels.cells(language: "xx"), CsvHeaderLabels.englishCells)
        XCTAssertEqual(CsvExporter.englishHeaderCells, CsvHeaderLabels.englishCells)
    }

    func testEveryLanguageHasEightHeaderCells() {
        let tags = ["", "de", "da", "nl", "nb", "sv", "es", "fr", "it", "pt", "pt-BR",
                    "ro", "cs", "pl", "ru", "uk", "el", "ja", "ko", "zh-Hans", "zh-Hant"]
        for tag in tags {
            XCTAssertEqual(CsvHeaderLabels.cells(language: tag).count, 8, "language \(tag)")
        }
    }
}
