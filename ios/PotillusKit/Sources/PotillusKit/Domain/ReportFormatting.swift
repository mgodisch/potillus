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
// ReportFormatting – numbers, as the report prints them
// =============================================================================
//
// Two functions, and a great deal of care about a single digit.
//
// THE PROBLEM
//   Kotlin formats with `String.format(locale, "%.1f", x)`. Java rounds HALF UP,
//   applied to the SHORTEST decimal representation of the double. C's `printf` —
//   which is what Swift's `String(format:)` calls — rounds the exact binary value
//   to nearest, ties to even. Measured on OpenJDK 21 and on glibc:
//
//       value    Kotlin %.1f   printf %.1f     Kotlin %.0f   printf %.0f
//       0.25     0.3           0.2             0             0
//       2.5      2.5           2.5             3             2
//       20.5     20.5          20.5            21            20
//       12.35    12.4          12.3            12            12
//
//   A daily limit of 20.5 g would print as "21" in the Android report and as "20"
//   in the iOS one, from the same data, on the same day.
//
// THE FIX
//   Do not use `String(format:)` for reader-facing numbers. Round the shortest
//   decimal representation with `NSDecimalRound(.plain)` — half away from zero,
//   which is HALF UP for the non-negative values this app produces — and only
//   then hand the settled number to a locale-aware formatter for its decimal mark.
//
//   `ReportChart.svgNumber` is the exception that proves the rule: it feeds a
//   machine, not a reader, so it wants POSIX and does not care about the tie.
//
// Pinned by test-vectors/report-format.json, whose expected strings were produced
// BY THE JVM rather than typed by hand.
// =============================================================================

public enum ReportFormatting {

    /// One decimal place, in `locale`'s convention. `12.35` → `"12,4"` in German.
    public static func oneDecimal(_ value: Double, locale: Locale) -> String {
        format(value, fractionDigits: 1, locale: locale)
    }

    /// No decimal places. `20.5` → `"21"`, as Kotlin prints it.
    public static func noDecimals(_ value: Double, locale: Locale) -> String {
        format(value, fractionDigits: 0, locale: locale)
    }

    /// Rounds first, formats second. The order is the whole point.
    ///
    /// `Decimal(string: String(value))` goes through the SHORTEST round-trip
    /// representation — `String(12.35)` is `"12.35"`, not
    /// `"12.3499999999999996447"` — which is the same decimal Java rounds. Handing
    /// the raw `Double` to `Decimal(_:)` instead would carry the binary error into
    /// the rounding and land on `12.3`.
    private static func format(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        var exact = Decimal(string: String(value)) ?? Decimal(value)
        var rounded = Decimal()
        // `.plain` is half away from zero. Java's HALF_UP is the same for the
        // non-negative grams, limits and averages this report deals in.
        NSDecimalRound(&rounded, &exact, fractionDigits, .plain)

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        // `%.1f` never groups: 1234.5 must not become "1,234.5".
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        // The number is already settled; this only chooses the decimal mark.
        let number = NSDecimalNumber(decimal: rounded)
        return formatter.string(from: number) ?? String(format: "%.\(fractionDigits)f", value)
    }
}
