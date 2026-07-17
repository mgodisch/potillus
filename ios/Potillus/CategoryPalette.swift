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

import SwiftUI
import PotillusKit

// =============================================================================
// CategoryPalette – the on-screen colour of a drink category
// =============================================================================
//
// ONE PALETTE, THREE PLACES
//   The six category colours are stated exactly once, in PotillusKit's
//   `ReportPalette.color(forCategory:)`, and pinned by the shared test vector
//   test-vectors/report-chart.json — the same vector Android checks. This file
//   only translates that hex string into a SwiftUI Color, so the Statistics
//   donut, the PDF report and the Android app cannot drift apart.
//
//   Its docstring has claimed all along that it "matches the on-screen palette";
//   until the donut existed, iOS had no on-screen palette to match. Now it does,
//   and the claim is true.
//
// WHY THIS LIVES IN THE APP TARGET
//   PotillusKit imports no SwiftUI anywhere — it is deliberately UI-free, which
//   is what lets it be tested without a host app. A `Color` cannot live there, so
//   the hex-to-Color step happens here, at the edge that already knows about
//   views.
// =============================================================================

enum CategoryPalette {

    /// The donut colour of a drink category.
    static func color(for category: DrinkCategory) -> Color {
        // rawValue is the stored name ("BEER", "WINE", ...) — the same string the
        // PDF renderer passes, so both ask the palette the identical question.
        Color(hex: ReportPalette.color(forCategory: category.rawValue))
    }
}

private extension Color {

    /// Parses `#RRGGBB`.
    ///
    /// Deliberately narrow: `ReportPalette` promises "hex only, with no character
    /// that HTML escaping would touch", so there is no alpha, no short form and no
    /// named colour to handle. An unparseable string falls back to the palette's
    /// own default grey rather than trapping — a wrong colour is a blemish, a
    /// crash on the Statistics screen is not.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0x6B_7280
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}
