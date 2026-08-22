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

// =============================================================================
// Metric rows
// =============================================================================
//
// WHAT WENT WRONG, TWICE
//   `LabeledContent(_:)` builds its label from a `Text`, and a `Text` bargaining
//   for width truncates before it wraps. On a 4.7-inch screen that left most of
//   this screen unreadable: "Total in Peri...", "Days Over Dai...". One row
//   escaped it, "Average per Drinking Day", not because it was built differently
//   but because it is long enough that SwiftUI abandons the side-by-side
//   arrangement and stacks value under label. The good behaviour was an accident
//   of length.
//
//   Telling the label to wrap instead of truncate then made every row worse: it
//   wrapped INSIDE the label's half of the row, two cramped lines against a
//   value that stayed put, and the row outgrew its height. The one row that had
//   been right lost what made it right.
//
// WHAT THE ROW HAS TO DO
//   Side by side while both fit. When they do not: label on the first line with
//   the WHOLE width to itself, value alone on the second, pinned to the trailing
//   edge where the eye scans for numbers. That is what the accidental row did,
//   and it is what every row should do.
//
// HOW
//   `ViewThatFits` is handed both arrangements and picks the first that fits.
//   The single-line one asks for its natural width — `lineLimit(1)` and
//   `fixedSize` on both parts, so neither can shrink itself into fitting and
//   hide the overflow. When that width is not there, the stacked arrangement is
//   used, and it gives each part the full row.
//
// WHY NOT `LabeledContent`
//   Its stacking is the framework's own and cannot be asked for on the
//   application's terms: it arrives with Dynamic Type, not with a label that has
//   run out of room. Owning both arrangements is what makes the outcome the same
//   on a 4.7-inch screen as on a 6.9-inch one.
// =============================================================================

extension StatsScreen {
    /// One figure row: label and value side by side, or stacked when they do not
    /// fit. See the note above.
    func metricRow(
        _ label: String,
        spokenLabel: String? = nil,
        spokenValue: String? = nil,
        @ViewBuilder value: () -> some View
    ) -> some View {
        MetricRow(label: label, value: value(), spokenLabel: spokenLabel, spokenValue: spokenValue)
    }
}

private struct MetricRow<Value: View>: View {
    // A row draws a label and a figure side by side, which VoiceOver meets as two
    // separate stops: "Total in Period", swipe, "123.4 g" — a figure with nothing
    // holding it, and a unit read as a letter. Every row therefore speaks as one
    // element: `.combine` where the drawn words already read aloud, a spoken
    // label where they do not (an abbreviation, or a unit that needs its word).
    let label: String
    let value: Value
    /// What VoiceOver says instead of the label, when the visible one abbreviates
    /// or the value needs its unit written out. `nil` combines the two as drawn.
    var spokenLabel: String?
    /// The figure as a sentence, spoken after `spokenLabel`. Only read when that
    /// one is set.
    var spokenValue: String?

    var body: some View {
        // The two branches are not interchangeable: an EMPTY `accessibilityLabel`
        // is still a label, and applying one alongside `.combine` would replace
        // the combined text with nothing. So the modifiers are chosen, not
        // defaulted.
        if let spokenLabel {
            arrangement
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
                .accessibilityValue(spokenValue ?? "")
        } else {
            arrangement
                .accessibilityElement(children: .combine)
        }
    }

    private var arrangement: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                value
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                value
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
