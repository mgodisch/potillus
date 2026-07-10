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
// ReportChart – the report's presentation arithmetic
// =============================================================================
//
// Bar heights, axis-label thinning, donut geometry, category colours. Everything
// the PDF needs in order to LOOK the same on both platforms, and nothing that
// needs a language: no strings, no locale, no formatting of numbers for a reader.
//
// Pinned by test-vectors/report-chart.json, which both suites read.
// =============================================================================

public enum ReportChart {

    /// The smallest bar a non-zero value may draw, in percent of the plot height.
    ///
    /// Without it, one beer in a month of heavy drinking would round to a bar of
    /// zero pixels and look like abstinence.
    public static let minimumVisibleBar = 2.0

    /// Headroom above the tallest bar of the trend chart, so neither it nor the
    /// dashed limit line touches the top edge.
    public static let trendHeadroom = 1.1

    /// Headroom above the tallest bar of the hour and weekday charts, which print
    /// their value above the bar and need room for the text.
    public static let barChartHeadroom = 1.15

    /// `value` as a percentage of `max`; zero when `max` is not positive.
    public static func percent(value: Double, max: Double) -> Double {
        max > 0 ? value / max * 100.0 : 0.0
    }

    /// The height of one bar, in percent of the plot.
    ///
    /// `nil` and zero both draw nothing: a weekday that never occurred and a
    /// weekday that was dry are different facts, but they draw the same bar. The
    /// distinction is carried by the value printed above it, not by the bar.
    public static func barHeight(value: Double?, ceiling: Double) -> Double {
        guard let value, value > 0.0 else { return 0.0 }
        return Swift.max(percent(value: value, max: ceiling), minimumVisibleBar)
    }

    /// Which buckets carry an x-axis label.
    ///
    /// Up to twelve buckets, all of them. Beyond that, roughly eight evenly spaced
    /// ones, always including the first and the last.
    ///
    /// THE STEP IS A 32-BIT FLOAT, deliberately. Kotlin writes
    /// `((n - 1).toFloat() / (target - 1))`, and the truncation that follows lands
    /// on different indices than the same arithmetic in `Double` would — for 16 of
    /// the first 400 series lengths, `n = 32` among them, which is a month of daily
    /// buckets. Using `Double` here would print a different axis on iOS than on
    /// Android for the same drinking. The shared vectors would catch it.
    public static func labelIndices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        guard count > 12 else { return Array(0..<count) }

        let target = 8
        let step = Swift.max(Float(count - 1) / Float(target - 1), 1.0)

        var indices = Set<Int>()
        for slot in 0..<target {
            indices.insert(Swift.min(Int(Float(slot) * step), count - 1))
        }
        indices.insert(count - 1)
        return indices.sorted()
    }

    // ── The donut ────────────────────────────────────────────────────────────

    /// One ring segment, as the three SVG attributes the template expects.
    public struct DonutSlice: Sendable, Equatable {
        /// The dash length, which equals the slice's percentage.
        public let dash: String
        /// The gap that follows it.
        public let gap: String
        /// The rotation that puts this slice after the ones before it.
        public let offset: String
    }

    /// Turns cumulative percentages into `stroke-dasharray` segments.
    ///
    /// The classic trick: a circle of radius 15.9155 has a circumference of very
    /// nearly 100, so a slice's dash length IS its percentage. The offset
    /// `25 - cumulative` rotates the ring to start at twelve o'clock and fill
    /// clockwise.
    ///
    /// Fractions come from grams, not from the rounded integer percents, so the
    /// segments butt up exactly instead of leaving a hairline gap at the end.
    public static func donutSlices(fractions: [Double]) -> [DonutSlice] {
        var cumulative = 0.0
        var slices: [DonutSlice] = []

        for fraction in fractions {
            slices.append(DonutSlice(
                dash: svgNumber(fraction),
                gap: svgNumber(100.0 - fraction),
                offset: svgNumber(25.0 - cumulative)
            ))
            cumulative += fraction
        }
        return slices
    }

    /// Two decimals with a DOT, whatever the device's locale.
    ///
    /// SVG treats both `,` and ` ` as list separators. A locale-aware formatter on
    /// a German device would emit `stroke-dasharray="40,00 60,00"`, which the
    /// renderer reads as the four values `40 0 60 0` — a zero gap, and the ring
    /// paints solid. Kotlin hits this through `String.format()` and passes
    /// `Locale.ROOT` to escape it.
    ///
    /// Swift's `String(format:)` already formats POSIX when given no locale, so the
    /// argument below is redundant. It is passed anyway: the requirement is that
    /// this number never follows the reader's locale, and a requirement stated in
    /// the code outlives one stated in a comment.
    public static func svgNumber(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

// =============================================================================
// ReportPalette
// =============================================================================

public enum ReportPalette {

    /// The donut colour of a stored category name.
    ///
    /// Matches the on-screen palette, so the PDF and the app colour the same
    /// drinking the same way. Hex only, with no character that HTML escaping would
    /// touch, so it can flow through `Template` into an SVG `stroke` attribute.
    public static func color(forCategory name: String) -> String {
        switch name {
        case "BEER": return "#F59E0B"       // amber-500
        case "WINE": return "#9333EA"       // purple-600
        case "SPIRITS": return "#EF4444"    // red-500
        case "LONGDRINK": return "#3B82F6"  // blue-500
        case "LIQUEUR": return "#10B981"    // emerald-500
        default: return "#6B7280"           // gray-500, and OTHER
        }
    }
}
