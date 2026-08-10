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
// The paging arrow
// =============================================================================
//
// WHAT IT IS FOR
//   Three headers page through time with an arrow on either side: the calendar's
//   month, the calendar's year, and the statistics period. All three sit in a
//   `List` row, and all six arrows were unusable in 0.85.0 — a tap did nothing,
//   however precisely it landed.
//
// WHY NOT A `Button`
//   A `List` row hands its content the row's own button treatment, and a row
//   holding TWO buttons has no way to say which one a tap meant. The documented
//   escape is a button style: `.borderless` was tried first and shipped, then
//   `.plain` with an explicit `contentShape`. Neither took on device. What DOES
//   work in this codebase is a plain tap gesture on a shaped view — the year
//   heat-map's month blocks have used exactly that since they were written, and
//   they respond. So this drops the button semantics altogether rather than
//   trying a third style.
//
//   The cost is that the accessibility side must be stated by hand, which is why
//   the traits and the label are set explicitly below. A tap gesture carries no
//   meaning to VoiceOver on its own.
//
// WHY IT LOOKS LIKE THIS
//   The tinted square is the tap target made visible. A bare chevron is roughly
//   twelve by fifteen points, well under the HIG's 44 and under WCAG 2.5.8's 24,
//   so even a working button would have been a poor one. The fill is the one the
//   segmented period picker uses for its own track, so a header and the picker
//   above it read as one band.
//
// WHY A DISABLED ARROW KEEPS ITS SHAPE
//   At the oldest period there is nowhere further back to go. Two grey chevrons
//   floating side by side read as a broken control; a visible but dimmed key
//   reads as an edge. The shape stays, the fill and the glyph drop back, and
//   VoiceOver stops offering it as a button.
// =============================================================================

/// One arrow in a header that pages backwards and forwards through time.
struct PagerArrow: View {

    /// Which way this arrow travels. The glyph follows from it, so no call site
    /// has to name a chevron.
    enum Direction {
        case backward
        case forward

        var systemImage: String {
            switch self {
            case .backward: return "chevron.left"
            case .forward: return "chevron.right"
            }
        }
    }

    let direction: Direction
    /// What VoiceOver announces: "Previous month", "Earlier period".
    let label: String
    /// False at the edge of what can be shown.
    var enabled: Bool = true
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    var body: some View {
        Image(systemName: direction.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
            .frame(width: 44, height: 44)
            .background(shape.fill(Color(.tertiarySystemFill).opacity(enabled ? 1.0 : 0.4)))
            // Stated, not inherited: without it the target is the glyph's own
            // outline and the tinted square around it would be decoration.
            .contentShape(shape)
            .onTapGesture {
                guard enabled else { return }
                action()
            }
            // A tap gesture is invisible to assistive technology, so the element
            // is described here instead: one element, named, and a button only
            // while it can actually be pressed.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(enabled ? [.isButton] : [])
    }
}
