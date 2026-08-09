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
    ///
    /// THE MONTH IS THE TOUCH TARGET. A block is about a third of the width and six
    /// rows tall, far past the HIG's 44 points, and its meaning is plain: show me
    /// this month. Tapping opens the month layout on it without selecting a day —
    /// the finger named a month, and reading a day out of where inside the block it
    /// landed would be invention.
    ///
    /// `onTapGesture` and an explicit `accessibilityAction`, NOT a `Button`: a
    /// Button would merge its children into one element and take the per-day labels
    /// with it. This way the days stay individually readable and VoiceOver still
    /// offers the jump, announced by the month's full name.
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
        .contentShape(Rectangle())
        .onTapGesture { Task { await model.showMonth(month.month) } }
        .accessibilityAction(named: monthFullName(month.month)) {
            Task { await model.showMonth(month.month) }
        }
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
    /// hitting the neighbouring day instead, silently. The tap target is the month
    /// block around it (see `yearMonth`), which opens the month layout where days
    /// are picked and edited at a size a finger can hit.
    @ViewBuilder
    private func yearDayCell(_ date: String) -> some View {
        if !model.state.yearGrid.isDrawn(date) {
            Color.clear
                .frame(width: 9, height: 9)
        } else {
            let summary = model.state.summaries[date]
            RoundedRectangle(cornerRadius: 2)
                .fill(yearCellColour(date))
                .frame(width: 9, height: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            date == model.state.today ? Color.primary : .clear,
                            lineWidth: 1
                        )
                )
                // Only days with alcohol are spoken, matching this grid's own
                // colours, the month grid's dot and Android's heat-map: a reader
                // met with 365 "no entry" nodes learns nothing from them, and
                // "0.0 g, under limit" over a cell drawn empty would put label
                // and display at odds. Reading never depended on tapping, so the
                // label outlived the button.
                .accessibilityHidden(!model.isDrinkDay(date))
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
    ///   dark  #242426  L* 14.3  -> delta L* 14.3
    ///
    /// The light value is Android's, matching its 9.9, and the two ports agree
    /// there. The DARK one is deliberately larger. Android's dark grid sits on
    /// #1E2538 (L* 14.9) while this one sits on #000000, and the same lightness
    /// step read as less from that darker foot — 9.8 was judged too faint on a
    /// device, 14.3 right. L* is near-linear in perception across the midrange,
    /// but a near-black background is where that stops holding, so the two dark
    /// themes carry different numbers to look alike.
    ///
    /// The value keeps the faint blue cast of Apple's dark greys and lands
    /// between systemGray6 (L* 10.3) and systemGray5 (L* 18.1). A WCAG
    /// ratio is the wrong instrument here and 1.4.11's 3:1 the wrong target —
    /// see `heatmapEmptyColor` in Android's Color.kt for the reasoning, which
    /// applies unchanged. Re-measure delta L* rather than the ratio, and check on
    /// a device: "Increase Contrast" and a non-standard background both shift the
    /// result.
    ///
    /// The day is read from the model rather than passed in: "is this a drink
    /// day" and "is it over the limit" are one question each, and both already
    /// live there.
    private func yearCellColour(_ date: String) -> Color {
        // A day of alcohol-free entries reads as empty here, like a day with
        // none at all: the heat map is about drinking, and
        // `AlcoholCalculator.isDrinkDay` decides that everywhere in the app.
        guard model.isDrinkDay(date) else { return emptyCellFill }
        return model.isOverLimit(date) ? .red : .accentColor
    }

    /// The fill for a day with nothing logged; see `yearCellColour` for the
    /// measurements behind the two values.
    private var emptyCellFill: Color {
        colorScheme == .dark
            ? Color(red: 0x24 / 255, green: 0x24 / 255, blue: 0x26 / 255)
            : Color(red: 0xDD / 255, green: 0xE3 / 255, blue: 0xF0 / 255)
    }

    private func yearCellLabel(_ date: String, summary: DaySummary?) -> String {
        guard let summary, model.isDrinkDay(date) else { return "" }
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
    /// The full standalone month name, for the block's accessibility action. Same
    /// standalone-vs-format reasoning as `monthAbbreviation`; the year is included
    /// because the grid can be paged away from the current one.
    private func monthFullName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.standaloneMonthSymbols ?? []
        guard symbols.count == 12, (1...12).contains(month) else { return "" }
        return "\(symbols[month - 1]) \(model.state.year)"
    }

    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.shortStandaloneMonthSymbols ?? []
        guard symbols.count == 12, (1...12).contains(month) else { return "" }
        return symbols[month - 1]
    }}
