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

import PotillusKit
import SwiftUI

// =============================================================================
// StatsScreen – choosing which period to show
// =============================================================================
//
// Split from StatsScreen.swift for the reason StatsScreenExport was: the view
// outgrew SwiftLint's body limit, and the seam it offered was the right one. That
// file shows the figures; this one decides WHICH period they describe.
//
// The arithmetic is NOT here. How long a period is, which one an offset names, and
// how far back the user may go are all answered by `StatsWindows` and clamped in
// `StatsModel`, so they can be asserted in tests rather than looked at on a
// device. What this file owns is the label and the two buttons.
// =============================================================================

extension StatsScreen {

    /// WHICH period is on screen, with an arrow either side.
    ///
    /// Without it the offset would be invisible: three steps back, figures for
    /// some month, and no way to tell which. The dates are the window's own, so the
    /// label states what the figures actually cover — the floor is already applied,
    /// and the current period ends today rather than on the period's last day.
    ///
    /// Each arrow points the way it travels: back towards the past on the left,
    /// forward towards today on the right. They are the only way to move the
    /// period — the screen-wide swipe that used to do the same is gone, here and
    /// on Android. Both read `canGoEarlier` / `canGoLater` from the model, so the
    /// buttons cannot disagree with it about the edges.
    ///
    /// WHY THE ARROWS ARE BUILT THE WAY THEY ARE
    ///   A `List` row hands its content the default button style, which makes the
    ///   WHOLE ROW one target; with two buttons in a row the tap belongs to
    ///   neither and nothing happens. `.borderless` was the documented answer and
    ///   shipped in 0.85.0; on device it did not take, and both arrows stayed
    ///   dead however precisely they were hit. So the row no longer relies on a
    ///   button style resolving correctly inside a list: `.plain` keeps the row
    ///   mechanism out of it, and an explicit `contentShape` over a sized frame
    ///   states the target instead of inheriting whatever a bare glyph implies.
    ///   A bare `Image` is about twelve by fifteen points of hit area, well under
    ///   the 44 the HIG asks for and under WCAG 2.5.8's 24 as well.
    ///
    /// WHY THE EDGE IS VISIBLE
    ///   At the oldest period the left arrow is disabled, at the current one the
    ///   right. Two grey chevrons side by side read as a broken control rather
    ///   than as an edge, so the backing shape stays put and only its fill and
    ///   its glyph drop back. What is there and what is reachable then say two
    ///   different things, which is what the user needs to know.
    var periodRange: some View {
        HStack(spacing: 12) {
            periodArrow(
                systemImage: "chevron.left",
                enabled: model.state.canGoEarlier,
                label: Loc.string("Earlier period", locale: locale)
            ) {
                Task { await model.shiftPeriod(by: 1) }
            }
            Spacer()
            Text(periodRangeLabel)
                .font(.subheadline)
                .monospacedDigit()
            Spacer()
            periodArrow(
                systemImage: "chevron.right",
                enabled: model.state.canGoLater,
                label: Loc.string("Later period", locale: locale)
            ) {
                Task { await model.shiftPeriod(by: -1) }
            }
        }
        // The row carries no background and no separator of its own, so the label
        // sits directly on the list's own surface the way the period picker above
        // it does. Left alone it drew a full row background with a rule on top,
        // which read as a card cut in half.
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// One paging arrow: a tinted square that is its own tap target.
    ///
    /// The shape is what the segmented picker above uses for its own track, so the
    /// two controls read as one band. 44 points square is the HIG's minimum and
    /// comfortably above WCAG 2.5.8.
    @ViewBuilder
    private func periodArrow(
        systemImage: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemFill).opacity(enabled ? 1.0 : 0.4))
                )
                // Stated, not inherited: without it the target is the glyph.
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// "1 Jul 2026 – 30 Jul 2026" in the in-app locale, or the single day when the
    /// window covers one.
    ///
    /// The en dash is spelled out rather than localised: between two dates it reads
    /// the same in every language this app ships, and the locale's order and
    /// separators come from `DateFormatter`'s medium style.
    private var periodRangeLabel: String {
        let from = model.state.from
        let to = model.state.to
        guard !from.isEmpty, !to.isEmpty,
              let start = DayResolver.parseDate(from), let end = DayResolver.parseDate(to)
        else { return "" }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = .medium
        let startText = formatter.string(from: start)
        if from == to { return startText }
        return "\(startText) \u{2013} \(formatter.string(from: end))"
    }
}
