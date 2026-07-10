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
// DrinkValidatorTests.swift – cross-platform parity suite
// =============================================================================
//
// Driven by `test-vectors/drink-validation.json`, whose BOUNDS are generated from
// the Kotlin validator. Two of its cases exist only to pin string semantics the
// two languages do not share: UTF-16 length, and the non-breaking space.
// =============================================================================

struct DrinkValidationVectors: Decodable {
    let bounds: Bounds
    let validate: [Case]

    struct Bounds: Decodable {
        let maxNameLength: Int
        let volumeMlMin: Int
        let volumeMlMax: Int
        let alcoholPercentMin: Double
        let alcoholPercentMax: Double
    }

    struct Case: Decodable {
        let description: String
        let name: String
        let volumeMl: Int
        /// Absent when the case carries `alcoholPercentSpecial` instead.
        let alcoholPercent: Double?
        /// "NAN", "POSITIVE_INFINITY" or "NEGATIVE_INFINITY"; JSON has no literals.
        let alcoholPercentSpecial: String?
        let expected: Expected?

        struct Expected: Decodable {
            let field: String
            let reason: String
        }

        /// The percentage this case means, reconstituting the non-finite values.
        var percent: Double {
            if let alcoholPercent { return alcoholPercent }
            switch alcoholPercentSpecial {
            case "NAN": return .nan
            case "POSITIVE_INFINITY": return .infinity
            case "NEGATIVE_INFINITY": return -.infinity
            default: return .nan
            }
        }
    }
}

final class DrinkValidatorTests: XCTestCase {

    private static var loadedVectors: DrinkValidationVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("drink-validation", as: DrinkValidationVectors.self)
        } catch {
            XCTFail("Could not load the shared drink-validation vectors: \(error)")
        }
    }

    private var vectors: DrinkValidationVectors { Self.loadedVectors }

    // ── The vectors ──────────────────────────────────────────────────────────

    func testValidateAgainstSharedVectors() {
        for testCase in vectors.validate {
            let actual = DrinkValidator.validate(
                name: testCase.name, volumeMl: testCase.volumeMl, alcoholPercent: testCase.percent
            )

            if let expected = testCase.expected {
                let violation = actual
                XCTAssertNotNil(violation, "expected a violation: \(testCase.description)")
                XCTAssertEqual(violation?.field.rawValue, expected.field, testCase.description)
                XCTAssertEqual(violation?.reason.rawValue, expected.reason, testCase.description)
            } else {
                XCTAssertNil(actual, "expected acceptance: \(testCase.description)")
            }
        }
    }

    /// The bounds themselves are generated from the Kotlin source. If Android
    /// narrows a range and iOS does not, this fails before any behaviour test can
    /// quietly pass on stale numbers.
    func testBoundsMatchAndroid() {
        XCTAssertEqual(DrinkValidator.maxNameLength, vectors.bounds.maxNameLength)
        XCTAssertEqual(DrinkValidator.volumeMlRange.lowerBound, vectors.bounds.volumeMlMin)
        XCTAssertEqual(DrinkValidator.volumeMlRange.upperBound, vectors.bounds.volumeMlMax)
        XCTAssertEqual(
            DrinkValidator.alcoholPercentRange.lowerBound, vectors.bounds.alcoholPercentMin,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            DrinkValidator.alcoholPercentRange.upperBound, vectors.bounds.alcoholPercentMax,
            accuracy: 1e-9
        )
    }

    // ── The two string traps, stated in Swift terms ──────────────────────────

    /// `String.count` would accept this; Kotlin's `length` does not.
    func testNameLengthCountsUtf16CodeUnitsNotCharacters() {
        let fiftyOneEmoji = String(repeating: "🍺", count: 51)
        XCTAssertEqual(fiftyOneEmoji.count, 51, "grapheme clusters")
        XCTAssertEqual(fiftyOneEmoji.utf16.count, 102, "code units — over the limit")

        let violation = DrinkValidator.validate(
            name: fiftyOneEmoji, volumeMl: 500, alcoholPercent: 4.9
        )
        XCTAssertEqual(violation, .init(field: .name, reason: .tooLong))

        // Exactly 100 code units fits.
        XCTAssertNil(DrinkValidator.validate(
            name: String(repeating: "🍺", count: 50), volumeMl: 500, alcoholPercent: 4.9
        ))
    }

    /// Kotlin's `Char.isWhitespace()` is `Character.isWhitespace(c) || isSpaceChar(c)`,
    /// and `isSpaceChar` covers all of Zs — so Kotlin trims the non-breaking
    /// spaces, and Swift's `.whitespacesAndNewlines` agrees. Java's `isWhitespace`
    /// alone would not, which is what makes this worth a test rather than a
    /// comment: an earlier version of the port matched Java and was wrong.
    func testNonBreakingSpacesAreTrimmedLikeAnyOtherSpace() {
        XCTAssertEqual(
            DrinkValidator.validate(name: "\u{00A0}", volumeMl: 500, alcoholPercent: 4.9),
            .init(field: .name, reason: .blank)
        )
        XCTAssertEqual(
            DrinkValidator.validate(name: "\u{202F}", volumeMl: 500, alcoholPercent: 4.9),
            .init(field: .name, reason: .blank)
        )
        XCTAssertEqual(DrinkValidator.canonicalName("\u{00A0}Pils\u{00A0}"), "Pils")

        // Ordinary whitespace, unchanged.
        XCTAssertEqual(
            DrinkValidator.validate(name: " \t\n ", volumeMl: 500, alcoholPercent: 4.9),
            .init(field: .name, reason: .blank)
        )
    }

    // ── Ordering and the NaN guard ───────────────────────────────────────────

    func testTheFirstViolationInFieldOrderWins() {
        XCTAssertEqual(
            DrinkValidator.validate(name: "", volumeMl: 0, alcoholPercent: .nan),
            .init(field: .name, reason: .blank)
        )
        XCTAssertEqual(
            DrinkValidator.validate(name: "Pils", volumeMl: 0, alcoholPercent: .nan),
            .init(field: .volumeMl, reason: .outOfRange)
        )
    }

    /// A NaN reaching `SUM(gramsAlcohol)` poisons every total that follows.
    func testNaNIsRejectedAsNotFiniteRatherThanOutOfRange() {
        XCTAssertEqual(
            DrinkValidator.validate(name: "Pils", volumeMl: 500, alcoholPercent: .nan),
            .init(field: .alcoholPercent, reason: .notFinite)
        )
        XCTAssertFalse(DrinkValidator.isValid(name: "Pils", volumeMl: 500, alcoholPercent: .nan))
    }

    func testCanonicalNameIsWhatGetsStored() {
        XCTAssertEqual(DrinkValidator.canonicalName("  Pils  "), "Pils")
    }
}
