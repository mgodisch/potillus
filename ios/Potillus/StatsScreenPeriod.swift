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
    /// `PagerArrow`, not a `Button`: see that type for why two buttons in a list
    /// row cannot be tapped, and what the calendar's headers do about it. The two
    /// headers there page through months and years the same way, from the same
    /// component, so all three read and behave alike.
    ///
    /// The row itself carries no background and no separator, so the label sits
    /// directly on the list's own surface as the period picker above it does. Left
    /// alone it drew a full row background with a rule on top, which read as a card
    /// cut in half.
    var periodRange: some View {
        HStack(spacing: 12) {
            PagerArrow(
                direction: .backward,
                label: Loc.string("Earlier period", locale: locale),
                enabled: model.state.canGoEarlier
            ) {
                Task { await model.shiftPeriod(by: 1) }
            }
            Spacer()
            Text(periodRangeLabel)
                .font(.subheadline)
                .monospacedDigit()
                // The visible label is the medium style, which German writes as
                // "01.08.2026" and VoiceOver reads as three numbers with dots
                // between them. The spoken one is the long style, where the month
                // is a word and the day an ordinal in the languages that have one.
                .accessibilityLabel(periodRangeSpoken)
            Spacer()
            PagerArrow(
                direction: .forward,
                label: Loc.string("Later period", locale: locale),
                enabled: model.state.canGoLater
            ) {
                Task { await model.shiftPeriod(by: -1) }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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

    /// The same window in the long date style, joined by the word for "to".
    ///
    /// The en dash the visible label uses is read out as a dash or as nothing at
    /// all, which turns a range into two loose dates; the word states the relation.
    private var periodRangeSpoken: String {
        let from = model.state.from
        let to = model.state.to
        guard !from.isEmpty, !to.isEmpty,
              let start = DayResolver.parseDate(from), let end = DayResolver.parseDate(to)
        else { return "" }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = .long
        let startText = formatter.string(from: start)
        if from == to { return startText }
        return Loc.string("%1$@ to %2$@", startText, formatter.string(from: end), locale: locale)
    }
}
