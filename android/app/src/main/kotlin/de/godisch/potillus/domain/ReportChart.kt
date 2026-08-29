/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.domain

/**
 * The report chart's presentation arithmetic: bar heights, axis labels and the
 * donut's ring geometry.
 *
 * None of this touches Android. It sits here rather than in the PDF builder
 * because it decides what the chart CLAIMS -- a bar of zero height reads as
 * abstinence, a slice that starts a hair late leaves a gap in the ring -- and
 * because both platforms must decide it the same way. The Swift twin is
 * `Domain/ReportChart.swift` in PotillusKit; `test-vectors/report-chart.json`
 * holds them together.
 */
object ReportChart {

    /** Percentage of [value] relative to [max] (0 when [max] is non-positive). */
    fun percent(value: Double, max: Double): Double = if (max > 0) value / max * 100.0 else 0.0

    /**
     * The smallest bar a non-zero value may draw, in percent of the plot height.
     *
     * Without a floor, one beer in a month of heavy drinking scales to a bar of
     * zero pixels and reads as abstinence. Two percent is the smallest strip the
     * print resolution still separates from the baseline.
     */
    const val MINIMUM_VISIBLE_BAR = 2.0

    /**
     * Height of one chart bar, in percent of the plot area.
     *
     * The rule the three bar charts of the report share: a bucket with no value
     * and a bucket with a zero value both draw nothing, and any amount above zero
     * draws at least [MINIMUM_VISIBLE_BAR].
     *
     * NULL AND ZERO DRAW THE SAME BAR, AND THAT IS DELIBERATE. A weekday that
     * never occurred in the period and a weekday that occurred and stayed dry are
     * different facts, but a bar of height zero is the honest picture of both.
     * What tells them apart is the value printed above the bar, which the callers
     * leave blank in the first case.
     *
     * A function rather than three inline expressions: the rule used to be
     * written out once per chart (trend, hour, weekday), which is three chances
     * for it to drift and no way for `ReportChartVectorTest` to reach it. `test-vectors/report-chart.json` holds
     * the `barHeight` cases that the Swift `ReportChart.barHeight` is pinned
     * against, and this is the function that lets the Kotlin suite assert the
     * same ones (0.85.0 QA round).
     *
     * @param value   The bucket's value, or null when the bucket holds no value.
     * @param ceiling The value the full plot height stands for; see the headroom
     *                factors at the call sites.
     */
    fun barHeight(value: Double?, ceiling: Double): Double {
        if (value == null || value <= 0.0) return 0.0
        return percent(value, ceiling).coerceAtLeast(MINIMUM_VISIBLE_BAR)
    }

    /**
     * Two decimals with a DOT, whatever the device's locale.
     *
     * SVG treats both `,` and ` ` as list separators, so a locale-aware format on
     * a German device emits `stroke-dasharray="40,00 60,00"`, which the renderer
     * reads as the four values `40 0 60 0` — a zero gap, and the ring paints
     * solid. [java.util.Locale.ROOT] is what keeps the separator a dot. The Swift
     * twin is `ReportChart.svgNumber`.
     */
    fun svgNumber(value: Double): String = String.format(java.util.Locale.ROOT, "%.2f", value)

    /**
     * One ring segment of the category donut, as the three SVG attributes the
     * template expects.
     */
    data class DonutSlice(val dash: String, val gap: String, val offset: String)

    /**
     * Turns a list of slice percentages into `stroke-dasharray` segments.
     *
     * The classic trick: a circle of radius 15.9155 has a circumference of very
     * nearly 100, so a slice's dash length IS its percentage, and the gap is what
     * remains of the ring. The offset `25 − cumulative` rotates each slice past
     * the ones before it and puts the first one at twelve o'clock, so the ring
     * fills clockwise.
     *
     * The caller passes fractions derived from GRAMS rather than from the rounded
     * integer percents the table prints, so the segments butt up exactly instead
     * of leaving a hairline gap at the end of the ring.
     *
     * The `donut` section of `test-vectors/report-chart.json` pins this geometry
     * on both platforms, and the Kotlin suite needs a named function to assert
     * it against.
     *
     * @param fractions Slice percentages in drawing order, each in 0..100.
     */
    fun donutSlices(fractions: List<Double>): List<DonutSlice> {
        var cumulative = 0.0
        return fractions.map { fraction ->
            val slice = DonutSlice(
                dash = svgNumber(fraction),
                gap = svgNumber(100.0 - fraction),
                offset = svgNumber(25.0 - cumulative),
            )
            cumulative += fraction
            slice
        }
    }

    /**
     * Indices of the buckets that should carry an x-axis label. For a short
     * series (≤ 12 bars) every bucket is labelled; for longer series a small,
     * evenly spaced subset (~8 labels) keeps the axis readable. The first and
     * last buckets are always included.
     */
    fun labelIndices(n: Int): Set<Int> {
        if (n <= 0) return emptySet()
        if (n <= 12) return (0 until n).toSet()
        val target = 8
        val step = ((n - 1).toFloat() / (target - 1)).coerceAtLeast(1f)
        return (0 until target)
            .map { (it * step).toInt().coerceAtMost(n - 1) }
            .toSortedSet()
            .apply { add(n - 1) }
    }
}

/**
 * The donut's category colours.
 *
 * Separate from [ReportChart] because it is a palette rather than arithmetic,
 * the same split the Swift side makes with `ReportPalette`.
 */
object ReportPalette {

    /**
     * Hex colour for a [DrinkCategory] name, matching the on-screen donut palette
     * (`ui.component.categoryColors`) so the PDF donut and the app
     * use the same colours. Escape-safe (no `< > & " '`), so it can flow through
     * SimpleTemplate into an SVG `stroke`/CSS `background`.
     *
     * ReportChartVectorTest checks these colours against the shared vectors the
     * Swift renderer reads too. They must match, or the same drinking prints in
     * different colours on the two platforms.
     */
    fun color(name: String): String = when (name) {
        "BEER" -> "#F59E0B" // amber-500
        "WINE" -> "#9333EA" // purple-600
        "SPIRITS" -> "#EF4444" // red-500
        "LONGDRINK" -> "#3B82F6" // blue-500
        "LIQUEUR" -> "#10B981" // emerald-500
        else -> "#6B7280" // gray-500 (OTHER)
    }
}
