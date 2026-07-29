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
// CalendarScreen – the year heat-map
// =============================================================================
//
// Split from CalendarScreen.swift for the reason StatsScreenExport was: the view
// outgrew SwiftLint's body limit, and the seam it offered was the right one. That
// file shows one month in full; this one shows a whole year at a glance, over the
// same summaries.
//
// The arithmetic is NOT here. Which days exist, where a month's first day falls,
// and which days lie inside the drawn window are all `YearGrid`'s answers, so
// they can be asserted in `YearGridTests` rather than looked at on a device. What
// this file decides is what a day LOOKS like.
// =============================================================================

extension CalendarScreen {

    // `body` in CalendarScreen.swift inserts these three, so they are internal;
    // `private` would not reach across the file boundary. The helpers below are
    // used only here and stay private, as StatsScreenExport arranges it.

    // ── Year heat-map ────────────────────────────────────────────────────────
    //
    // Twelve months at a glance, the second layout over the same summaries. The
    // arithmetic is `YearGrid`'s; what lives here is how a day looks.

    var yearHeader: some View {
        HStack {
            Button { Task { await model.previousYear() } } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Loc.string("Previous year", locale: locale))
            Spacer()
            Text(String(model.state.year))
                .font(.headline)
                .monospacedDigit()
            Spacer()
            Button { Task { await model.nextYear() } } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Loc.string("Next year", locale: locale))
        }
        .padding(.horizontal)
    }

    /// Three months per row, each a block of week columns.
    var yearGrid: some View {
        VStack(spacing: 12) {
            ForEach(Array(stride(from: 0, to: 12, by: 3)), id: \.self) { start in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(model.state.yearGrid.months[start..<min(start + 3, 12)], id: \.month) { month in
                        yearMonth(month)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    /// One month of the heat-map: its abbreviated name over a grid of day cells.
    private func yearMonth(_ month: YearGrid.Month) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(monthAbbreviation(month.month))
                .font(.caption2)
                .foregroundStyle(.secondary)
            // A fixed seven-column grid, with the leading blanks rendered as empty
            // cells so the first day lands under its weekday. `MonthGrid` counted
            // them; drawing them is all that is left.
            LazyVGrid(columns: yearColumns, spacing: 2) {
                ForEach(0..<month.grid.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(width: 9, height: 9)
                }
                ForEach(month.grid.days, id: \.self) { date in
                    yearDayCell(date)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var yearColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(9), spacing: 2), count: 7)
    }

    /// One day. Outside the drawn window nothing is rendered but the space the
    /// cell occupies, so the week columns stay aligned while the day itself makes
    /// no claim — see `YearGrid` for which days those are and why.
    ///
    /// NOT TAPPABLE, deliberately. A 9-point square is far under the 44-point
    /// target the HIG asks for, and a target that small is one the user misses —
    /// hitting the neighbouring day instead, silently. Picking and editing a day
    /// is the month view's job; this grid is for reading. Switching layouts drops
    /// the selection anyway, so no route to a day is lost.
    @ViewBuilder
    private func yearDayCell(_ date: String) -> some View {
        if !model.state.yearGrid.isDrawn(date) {
            Color.clear
                .frame(width: 9, height: 9)
        } else {
            let summary = model.state.summaries[date]
            RoundedRectangle(cornerRadius: 2)
                .fill(yearCellColour(date, summary: summary))
                .frame(width: 9, height: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            date == model.state.today ? Color.primary : .clear,
                            lineWidth: 1
                        )
                )
                // Only days with something logged are spoken, matching the month
                // grid's dot and Android's heat-map: a reader met with 365 "no
                // entry" nodes learns nothing from them. Reading never depended on
                // tapping, so the label outlived the button.
                .accessibilityHidden(summary == nil)
                .accessibilityLabel(yearCellLabel(date, summary: summary))
        }
    }

    /// Neutral when nothing was logged, accent under the limit, red over it —
    /// the same three states the legend names, and the same reading the month
    /// grid's dot gives.
    ///
    /// The empty fill is a LITERAL, not `Color.secondary` at some opacity as it
    /// was first written. It has to separate "nothing logged" from a day outside
    /// the window, which is not painted at all, and a translucent system colour
    /// left the two looking alike in both themes on hardware. A literal can be
    /// measured; the values below were.
    ///
    /// MEASURED (CIE L*, sRGB), against the standard backgrounds
    /// (`systemBackground`: #FFFFFF light, #000000 dark):
    ///
    ///   light #DDE3F0  L* 90.1  -> delta L* 9.9
    ///   dark  #1B1B1D  L*  9.8  -> delta L* 9.8
    ///
    /// Both match the 9.9 of Android's light theme, the one judged good on a
    /// device; the light value IS Android's, so the two ports now agree. A WCAG
    /// ratio is the wrong instrument here and 1.4.11's 3:1 the wrong target —
    /// see `heatmapEmptyColor` in Android's Color.kt for the reasoning, which
    /// applies unchanged. Re-measure delta L* rather than the ratio, and check on
    /// a device: "Increase Contrast" and a non-standard background both shift the
    /// result.
    private func yearCellColour(_ date: String, summary: DaySummary?) -> Color {
        guard let summary, summary.totalGrams > 0 else { return emptyCellFill }
        return model.isOverLimit(date) ? .red : .accentColor
    }

    /// The fill for a day with nothing logged; see `yearCellColour` for the
    /// measurements behind the two values.
    private var emptyCellFill: Color {
        colorScheme == .dark
            ? Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1D / 255)
            : Color(red: 0xDD / 255, green: 0xE3 / 255, blue: 0xF0 / 255)
    }

    private func yearCellLabel(_ date: String, summary: DaySummary?) -> String {
        guard let summary else { return "" }
        let grams = Loc.number(summary.totalGrams, fractionDigits: 1, locale: locale)
        let status = Loc.string(
            model.isOverLimit(date) ? "over limit" : "under limit",
            locale: locale
        )
        return Loc.string("%@, %@ g, %@", date, grams, status, locale: locale)
    }

    /// The three states, named. Without it the colours are a code the screen
    /// never explains.
    var yearLegend: some View {
        HStack(spacing: 4) {
            Spacer()
            Text(Loc.string("no entry", locale: locale))
                .font(.caption2)
                .foregroundStyle(.secondary)
            legendSwatch(emptyCellFill)
            Text(Loc.string("under limit", locale: locale))
                .font(.caption2)
                .foregroundStyle(.secondary)
            legendSwatch(.accentColor)
            Text(Loc.string("over limit", locale: locale))
                .font(.caption2)
                .foregroundStyle(.secondary)
            legendSwatch(.red)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        // One label for the row: read swatch by swatch it would be three colours
        // with no names attached.
        .accessibilityElement(children: .combine)
    }

    private func legendSwatch(_ colour: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(colour)
            .frame(width: 9, height: 9)
    }

    /// "Jan", "Feb" … in the in-app locale. The STANDALONE symbols, not the
    /// formatting ones: these are bare month names without a day beside them, and
    /// inflected languages spell the two differently — the same distinction
    /// Android draws with "LLL" against "MMM".
    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.shortStandaloneMonthSymbols ?? []
        guard symbols.count == 12, (1...12).contains(month) else { return "" }
        return symbols[month - 1]
    }}
