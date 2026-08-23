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

import Charts
import SwiftUI

// =============================================================================
// StatsScreen – the hour and weekday charts
// =============================================================================
//
// Two more chart sections, in an extension for the same length-budget reason as
// the formatting helpers below (SwiftLint `type_body_length`).
// =============================================================================

extension StatsScreen {

    // `timeOfDay` and `weekdays` carry no access modifier: the body that
    // composes them lives in StatsScreen.swift, and `fileprivate` would end
    // at this file. The helpers below them stay fileprivate — they have no
    // caller outside it.
    var timeOfDay: some View {
        Section(Loc.string("Time of Day", locale: locale)) {
            Chart(hourPoints) { point in
                BarMark(
                    x: .value("Hour", point.label),
                    y: .value("Grams per day", point.average)
                )
                // Swift Charts speaks a mark from its `.value` labels, which gave
                // "0 0: 0" — the axis form "00" read as two digits, and a bare
                // number after it. The sentence replaces both, and it is stated on
                // the MARK so the focus lands on the bar the figure belongs to.
                //
                // The empty value is deliberate: the label already carries the
                // figure, and without this the chart's own generated value would
                // follow it with the same number a second time.
                .accessibilityLabel(hourSpoken(point))
                .accessibilityValue("")
            }
            .chartYAxisLabel(Loc.string("g / day", locale: locale))
            .frame(height: 140)
        }
    }

    /// "0 to 3 hours: 0.5 grams of alcohol" — the bucket's whole span in words.
    ///
    /// The axis carries only the start hour, because that is what fits under eight
    /// columns on a 4.7-inch screen. A reader has no such limit, and a span with
    /// one end named is not a span.
    fileprivate func hourSpoken(_ point: HourPoint) -> String {
        Loc.string(
            "%1$@ to %2$@ hours: %3$@ grams of alcohol",
            String(point.id * 3),
            String((point.id + 1) * 3),
            Loc.number(point.average, fractionDigits: 1, locale: locale),
            locale: locale
        )
    }

    /// Named rather than a tuple: `Chart` wants `Identifiable`, and a key path
    /// into a tuple element is not something to rely on.
    fileprivate var hourPoints: [HourPoint] {
        model.state.hourBucketAverages.enumerated().map { index, average in
            HourPoint(id: index, label: bucketLabel(index), average: average)
        }
    }

    /// "00", "03" … "21". The bucket covers three hours starting there.
    fileprivate func bucketLabel(_ index: Int) -> String {
        String(format: "%02d", index * 3)
    }

    var weekdays: some View {
        Section(Loc.string("Weekday", locale: locale)) {
            Chart(weekdayPoints) { point in
                BarMark(
                    x: .value("Weekday", point.label),
                    y: .value("Grams", point.average)
                )
                // The axis abbreviates to two or three letters, which a reader
                // gets as a fragment rather than a day. The full name has room in
                // the sentence, and the grams arrive with their unit spelled out.
                // Empty value for the same reason as the hour chart above.
                .accessibilityLabel(weekdaySpoken(point))
                .accessibilityValue("")
            }
            .chartYAxisLabel(Loc.string("g", locale: locale))
            .frame(height: 140)
        }
    }

    /// "Monday: 19.7 grams of alcohol", in the in-app language.
    fileprivate func weekdaySpoken(_ point: WeekdayPoint) -> String {
        Loc.string(
            "%1$@: %2$@ grams of alcohol",
            weekdayName(point.id),
            Loc.number(point.average, fractionDigits: 1, locale: locale),
            locale: locale
        )
    }

    /// Columns whose average is nil are DROPPED, not drawn as zero: that weekday
    /// never occurred in the period, which is not the same as a dry weekday.
    fileprivate var weekdayPoints: [WeekdayPoint] {
        zip(model.state.weekdayOrder, model.state.weekdayAverages)
            .compactMap { iso, average in
                average.map { WeekdayPoint(id: iso, label: weekdaySymbol(iso), average: $0) }
            }
    }
}

// =============================================================================
// Presentation helpers
// =============================================================================
//
// These live in a same-file extension rather than the main type so that
// `StatsScreen`'s body stays within SwiftLint's `type_body_length`. A same-file
// extension shares the type's `private` scope, so the view code above still
// reaches them.
// =============================================================================

extension StatsScreen {
    /// The axis form: "Mon", "Tue" …
    ///
    /// `formatter.locale`, as every other DateFormatter in this project sets it.
    /// Without it the symbols follow the DEVICE language while the rest of the
    /// screen follows the in-app one, so a German app on an English phone drew an
    /// English axis under German headings.
    private func weekdaySymbol(_ iso: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return "" }
        return symbols[iso == 7 ? 0 : iso]
    }

    /// The spoken form: "Monday", "Tuesday" … Same source, same rotation, full
    /// words — the axis has room for three letters, a sentence has room for the day.
    private func weekdayName(_ iso: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.standaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return "" }
        return symbols[iso == 7 ? 0 : iso]
    }
}

private struct HourPoint: Identifiable {
    let id: Int
    let label: String
    let average: Double
}

private struct WeekdayPoint: Identifiable {
    /// The ISO weekday number, which is already unique within a week.
    let id: Int
    let label: String
    let average: Double
}
