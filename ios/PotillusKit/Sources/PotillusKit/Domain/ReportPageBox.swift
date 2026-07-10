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

import Foundation

// =============================================================================
// ReportPageBox – the sheet is exactly one page tall, whatever a millimetre is
// =============================================================================
//
// THE MEASUREMENT THIS EXISTS FOR
//
//   The template sizes each logical page with `min-height: 267mm`, which is what
//   the `@page` margins leave of an A4 sheet. Android's print framework resolves
//   that to 267 printed millimetres. WebKit, printing through
//   `UIViewPrintFormatter`, does not:
//
//       min-height asked   sheet printed   ratio
//       267 mm             320.9 mm        1.2018
//       240 mm             288.4 mm        1.2017
//
//   Measured off two exported PDFs, at the same zoom, with the printable box
//   verified to be exactly 267 mm. The relationship is linear through the origin,
//   so absolute lengths in the block layout are inflated by a constant a little
//   over 1.2. The report's two sheets each overflow, and it prints on four pages.
//
//   The donut, sized `44mm` square in the SVG, comes out 40.1 mm — neither 44 nor
//   1.2018 × 44. Two different length resolutions in one document. Whatever WebKit
//   is doing here, this is not the file in which to reverse-engineer it.
//
// WHAT THIS DOES INSTEAD
//
//   `267 / 1.2018 = 222.2mm` would work today and would be a number with no
//   meaning, derived from two data points, waiting for the next iOS to move it.
//
//   `100vh` is one page box, by definition, in paged media. Whatever factor WebKit
//   applies, it applies to the page as well, and it cancels. The sheet is one page
//   tall because it is told to be one page tall, not because a conversion happened
//   to come out right.
//
// WHY iOS ONLY
//
//   Android prints this template correctly today. A change to the shared template
//   would have to be re-verified there, and `min-height: 267mm` states an intent —
//   the printable area of A4 — that `100vh` states only obliquely. So the override
//   is appended at print time, on this platform, where it is needed, and the
//   template goes on saying what it means.
// =============================================================================

public enum ReportPageBox {

    /// Overrides the sheet height, and nothing else.
    ///
    /// `min-height` alone: the sheet must be free to grow if its content ever
    /// exceeds a page, exactly as the template intends. `height: 100vh` would clip
    /// it instead, and clipping an alcohol report loses rows without saying so.
    public static let stylesheet = """
        <style>
        /* Injected by the iOS printer; see ReportPageBox.swift. */
        .sheet { min-height: 100vh; }
        </style>
        """

    /// Returns `html` with the override placed last in its `<head>`.
    ///
    /// Last, so it wins on specificity ties with the template's own rule, which is
    /// written with the same single-class selector.
    ///
    /// A document without a `</head>` is returned unchanged rather than repaired.
    /// The template has one; if a future edit removes it, the report will print at
    /// the wrong size, and that is a visible failure. Silently splicing a `<style>`
    /// into an unknown position would be an invisible one.
    public static func inject(into html: String) -> String {
        guard let head = html.range(of: "</head>", options: .caseInsensitive) else {
            return html
        }
        return html.replacingCharacters(in: head, with: "\(stylesheet)\n</head>")
    }
}
