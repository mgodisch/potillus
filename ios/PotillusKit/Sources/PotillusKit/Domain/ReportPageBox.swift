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
// WHY `100vh` DID NOT WORK EITHER
//
//   It was the obvious answer: one page box, by definition, in paged media. It
//   printed a sheet 1691 pt tall — 2.23 pages — and the report came out on six.
//   WebKit's print layout gives the page box no height that CSS can ask for, in
//   millimetres or in viewport units.
//
// WHAT THIS DOES INSTEAD: IT STOPS ASKING
//
//   The sheet is only tall because `margin-top: auto` needs a tall box to push the
//   disclaimer to its bottom edge. The CONTENT fits with room to spare — sheet one
//   ends 66 pt above the page bottom, sheet two 138 pt.
//
//   So the height is dropped, and the disclaimer follows the content instead of the
//   paper. `page-break-before: always` between sheets then yields exactly two pages,
//   and nothing in that sentence depends on how WebKit resolves a length.
//
//   THE COST IS COSMETIC AND REAL: on iOS the disclaimer sits under the last table
//   rather than at the foot of the page, some 40 pt higher on sheet one and 110 pt
//   higher on sheet two. Android, whose print framework resolves millimetres
//   correctly, keeps the pinned footer. A report that is right in the wrong place
//   beats a report on twice the pages.
//
// WHY iOS ONLY
//
//   Android prints this template correctly today. A change to the shared template
//   would have to be re-verified there, and `min-height: 267mm` states an intent —
//   the printable area of A4 — worth keeping. So the override is appended at print
//   time, on the platform that needs it, and the template goes on saying what it
//   means.
// =============================================================================

public enum ReportPageBox {

    /// Frees the sheet from a height it cannot compute, and unpins the footer.
    ///
    /// `min-height: 0` — the sheet becomes as tall as its content, which fits.
    /// `margin-top` — a fixed gap replaces `auto`, which would otherwise still push
    /// the disclaimer against a bottom edge that is now the content's, not the
    /// page's, and would collapse the gap to nothing.
    ///
    /// Nothing here clips: a sheet whose content one day outgrows a page will simply
    /// break across two, which is what the template would do anyway.
    public static let stylesheet = """
        <style>
        /* Injected by the iOS printer; see ReportPageBox.swift. */
        .sheet { min-height: 0; }
        .sheet > .disclaimer { margin-top: 18pt; }
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
