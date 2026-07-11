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
// DrinkValidator.swift – the rules a drink definition must satisfy
// =============================================================================
//
// A faithful port of `domain/DrinkValidator.kt`, asserted against
// `test-vectors/drink-validation.json` — whose bounds are GENERATED from that
// Kotlin source. This matters more than usual here: these rules had already
// drifted apart once on Android, where the ViewModel and the edit dialog held
// two different volume limits and only one of them checked the name's length.
// A generated vector is the only mechanism that makes a fourth copy impossible.
//
// THE BOUNDS, and why each is where it is
//   Volume 1...5000 ml. Five litres is past any single serving; the bound exists
//   to catch a typo (50000 for 500), not to express a belief about vessels.
//
//   Alcohol 0...100 %, finite. Zero is legitimate — alcohol-free beer is a drink
//   one wants to log. Finiteness is checked SEPARATELY and FIRST, because NaN
//   compares false against every bound: `(0.0...100.0).contains(.nan)` is false,
//   which happens to reject it, but a hand-written `!(percent > 100)` would let
//   it through, and a NaN reaching `SUM(gramsAlcohol)` poisons every total.
//
//   Name non-blank and at most 100 characters, both measured AFTER trimming, so
//   "   " is blank rather than a three-character name, and trailing spaces cannot
//   push an otherwise legal name over the limit.
//
// TWO STRING SEMANTICS THAT LOOK IDENTICAL AND ARE NOT
//   Kotlin is the authority here, because Android shipped these rules first and a
//   drink accepted on one platform must be accepted on the other.
//
//   1. LENGTH. Kotlin's `String.length` counts UTF-16 CODE UNITS; Swift's
//      `String.count` counts GRAPHEME CLUSTERS. A name of 100 beer emojis is 200
//      units to Kotlin (rejected) and 100 characters to Swift (accepted). The
//      count is therefore taken over `utf16`.
//
//   2. WHITESPACE. Kotlin's `Char.isWhitespace()` is NOT Java's
//      `Character.isWhitespace()`. It is defined as
//
//          Character.isWhitespace(ch) || Character.isSpaceChar(ch)
//
//      and `isSpaceChar` covers the whole Zs category, non-breaking spaces
//      included. Kotlin therefore trims U+00A0, and Swift's
//      `.whitespacesAndNewlines` agrees. The two are equivalent for every
//      character a drink name can carry, and no custom set is needed. (This was
//      not obvious: Java alone excludes the non-breaking spaces, and an earlier
//      version of this file "corrected" Swift to match Java, which the shared
//      vectors then proved wrong on the JVM.)
// =============================================================================

/// Validates the three user-supplied fields of a `DrinkDefinition`.
///
/// Consulted by the model before a write and by the view to enable its Save
/// button, so a button can never offer to save what the model would reject.
public enum DrinkValidator {

    /// Longest accepted drink name, measured after trimming.
    public static let maxNameLength = 100

    /// Accepted serving size in millilitres.
    public static let volumeMlRange = 1...5_000

    /// Accepted alcohol content, percent by volume.
    public static let alcoholPercentRange = 0.0...100.0

    /// Which field a `Violation` refers to.
    public enum Field: String, Sendable, Equatable {
        case name = "NAME"
        case volumeMl = "VOLUME_ML"
        case alcoholPercent = "ALCOHOL_PERCENT"
    }

    /// Why a field was rejected.
    public enum Reason: String, Sendable, Equatable {
        case blank = "BLANK"
        case tooLong = "TOO_LONG"
        case outOfRange = "OUT_OF_RANGE"
        case notFinite = "NOT_FINITE"
    }

    /// A single rejected field.
    public struct Violation: Sendable, Equatable, Error, CustomStringConvertible {
        public let field: Field
        public let reason: Reason

        public init(field: Field, reason: Reason) {
            self.field = field
            self.reason = reason
        }

        public var description: String { "\(field.rawValue) \(reason.rawValue)" }
    }

    /// The first rule the fields break, or nil when the definition is acceptable.
    ///
    /// Checks run in field order — name, volume, alcohol — so the error points at
    /// the first field the user would fix reading the form top to bottom.
    public static func validate(
        name: String, volumeMl: Int, alcoholPercent: Double
    ) -> Violation? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty { return Violation(field: .name, reason: .blank) }
        // utf16, not `count`: Kotlin measures UTF-16 code units. See the header.
        if trimmed.utf16.count > maxNameLength {
            return Violation(field: .name, reason: .tooLong)
        }
        if !volumeMlRange.contains(volumeMl) {
            return Violation(field: .volumeMl, reason: .outOfRange)
        }

        // Before the range test: see the file header on NaN.
        if !alcoholPercent.isFinite {
            return Violation(field: .alcoholPercent, reason: .notFinite)
        }
        if !alcoholPercentRange.contains(alcoholPercent) {
            return Violation(field: .alcoholPercent, reason: .outOfRange)
        }

        return nil
    }

    /// Whether the three fields form an acceptable drink definition.
    public static func isValid(name: String, volumeMl: Int, alcoholPercent: Double) -> Bool {
        validate(name: name, volumeMl: volumeMl, alcoholPercent: alcoholPercent) == nil
    }

    /// The name as it should be STORED: trimmed.
    ///
    /// Kept next to the rules that measured it, so a caller cannot validate the
    /// trimmed name and then persist the untrimmed one.
    public static func canonicalName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
