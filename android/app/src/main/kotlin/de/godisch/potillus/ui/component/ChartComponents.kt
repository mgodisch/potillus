/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
 * =============================================================================
 */
package de.godisch.potillus.ui.component

// =============================================================================
// ChartComponents.kt – Custom Compose Canvas charts
// =============================================================================
//
// WHY CUSTOM CANVAS INSTEAD OF A CHART LIBRARY?
//   Third-party chart libraries (MPAndroidChart, Vico, etc.) add significant
//   APK size and pull in transitive dependencies. For the two simple charts
//   this app needs (bar chart, donut chart) a few dozen lines of Canvas drawing
//   code is leaner, fully customisable, and avoids version-compatibility issues.
//
// COMPOSE CANVAS DRAWING COORDINATE SYSTEM:
//   (0, 0) is the top-left corner. x increases to the right; y increases downward.
//   Bars are drawn from the bottom of the canvas upward, so:
//     barTop    = chartH − barH
//     barBottom = chartH         (implicit; barH is the height)
//
// CAPTURING COMPOSABLE COLORS BEFORE CANVAS SCOPE:
//   MaterialTheme.colorScheme.* and custom theme helpers (warningColor(),
//   dangerRedColor()) are @Composable and cannot be called inside a Canvas{}
//   lambda (which is a DrawScope, not a composable context). They must be
//   captured in local variables in the enclosing @Composable function before
//   entering Canvas.
// =============================================================================

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import de.godisch.potillus.R
import de.godisch.potillus.domain.ChartBucket
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.successColor

// ════════════════════════════════════════════════════════════════════════════
// BAR CHART
// ════════════════════════════════════════════════════════════════════════════

/**
 * Draws a vertical bar chart of consumption over a real time axis, with a dashed
 * daily-limit line and explicit markers for abstinent buckets.
 *
 * Each bar is one [ChartBucket]: a day (WEEK / MONTH periods) or a whole week
 * (YEAR period, ≈ 52 bars). Because the series is gap-free (every day in the
 * period is represented, even those with no entries), the x-axis is a proper
 * time axis rather than a list of drink days.
 *
 * Layout:
 * - A bar's height is proportional to [ChartBucket.avgPerDay] relative to [maxVal].
 * - Abstinent buckets ([ChartBucket.isAbstinent], i.e. 0 g) carry NO bar; instead
 *   a small green tick is drawn at the baseline so "recorded, nothing consumed"
 *   is visually distinct from a near-zero bar or from missing data.
 * - A horizontal dashed line marks the daily [limitGrams] threshold. Since bars
 *   are a per-day average, the line stays comparable for weekly buckets too.
 * - Axis labels are THINNED for dense charts (see below); [labelFn] formats one
 *   bucket into a short, locale-specific label.
 *
 * Colour coding:
 * - avg ≤ limit → [MaterialTheme.colorScheme.primary] (app's accent colour)
 * - avg > limit → [dangerRedColor] (the saturated red shared with delete icons
 *   and traffic-light bullets, so all "danger" reds match)
 * - Limit line  → [dangerRedColor] (red dashed)
 * - Abstinent tick → [successColor] (green)
 *
 * LABEL THINNING:
 *   With up to ~53 buckets one label per bar is unreadable. For ≤ 12 buckets
 *   every bar is labelled and aligned to its column; for more, a small evenly
 *   spaced subset is shown (axis context rather than per-bar precision).
 *
 * SCALE:
 *   `maxVal = max(highestBucketAvg, limitGrams) × 1.15` — 15 % headroom so
 *   neither the tallest bar nor the limit line touches the top edge.
 *
 * @param buckets     Continuous, chronological bucket series (see [ChartBucketing]).
 * @param limitGrams  Daily limit threshold for the dashed line and bar colouring.
 * @param labelFn     Formats one [ChartBucket] into a short axis label, e.g. "Mo",
 *                    "1." or "Jan". Provided by the screen so the chart stays
 *                    locale-agnostic.
 * @param modifier    Optional layout modifier.
 */
@Composable
fun AlcoholBarChart(
    buckets: List<ChartBucket>,
    limitGrams: Double,
    labelFn: (ChartBucket) -> String,
    modifier: Modifier = Modifier
) {
    if (buckets.isEmpty()) {
        Box(modifier.height(180.dp), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.no_data),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }

    // Capture theme colors before entering Canvas (see file header note)
    val maxVal     = maxOf(buckets.maxOf { it.avgPerDay }, limitGrams) * 1.15
    val barColor   = MaterialTheme.colorScheme.primary
    // Daily-limit line in the saturated danger red (was amber) so it reads as a
    // "do not cross" threshold and matches the over-limit bar colour.
    val limitColor = dangerRedColor()
    // Over-limit bars use the saturated danger red (same hue as delete icons /
    // traffic-light bullets) rather than the softer Material `error` colour, so
    // every "over limit" cue in the app shares one consistent red.
    val overColor  = dangerRedColor()
    val tickColor  = successColor()

    Canvas(modifier = modifier.fillMaxWidth().height(200.dp).padding(top = 8.dp, bottom = 24.dp)) {
        val chartH  = size.height
        val chartW  = size.width
        // Each bar occupies an equal horizontal slice (spacing = chartW / numBars).
        // The actual bar width is 60 % of the slice to leave gaps between bars.
        // coerceAtLeast(2f) keeps a hairline bar visible even with ~53 weekly bars.
        val spacing = chartW / buckets.size
        val barW    = (spacing * 0.6f).coerceAtLeast(2f)

        // Limit line Y coordinate: distance from the bottom = (limitGrams / maxVal) * chartH
        val limitY  = chartH - (limitGrams / maxVal * chartH).toFloat()

        // Draw dashed horizontal limit line
        drawLine(
            color       = limitColor,
            start       = Offset(0f, limitY),
            end         = Offset(chartW, limitY),
            strokeWidth = 2.dp.toPx(),
            pathEffect  = PathEffect.dashPathEffect(floatArrayOf(10f, 6f))
        )

        buckets.forEachIndexed { i, bucket ->
            val centerX = i * spacing + spacing / 2f
            if (bucket.isAbstinent) {
                // Green tick at the baseline: two short strokes forming a check.
                // Sized to the slice so it stays visible but never overlaps neighbours.
                val s     = (spacing * 0.30f).coerceIn(2.dp.toPx(), 5.dp.toPx())
                val baseY = chartH - 1.dp.toPx()
                val w     = 1.5.dp.toPx()
                drawLine(tickColor,
                    Offset(centerX - s, baseY - s * 0.5f),
                    Offset(centerX - s * 0.25f, baseY), strokeWidth = w)
                drawLine(tickColor,
                    Offset(centerX - s * 0.25f, baseY),
                    Offset(centerX + s, baseY - s), strokeWidth = w)
            } else {
                // barH: height in pixels; coerceAtLeast(2f) makes even 0.x-gram bars visible
                val barH = (bucket.avgPerDay / maxVal * chartH).toFloat().coerceAtLeast(2f)
                val left = centerX - barW / 2f
                val color = if (bucket.avgPerDay > limitGrams) overColor else barColor
                drawRoundRect(
                    color        = color,
                    topLeft      = Offset(left, chartH - barH),
                    size         = Size(barW, barH),
                    cornerRadius = CornerRadius(3.dp.toPx())
                )
            }
        }
    }

    // X-axis labels. For a short series, one aligned label per bar; for a dense
    // series, a handful of evenly spaced labels for axis context.
    if (buckets.size <= 12) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceAround) {
            buckets.forEach { bucket ->
                Text(
                    text      = labelFn(bucket),
                    style     = MaterialTheme.typography.labelSmall,
                    color     = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    maxLines  = 1,
                    overflow  = TextOverflow.Ellipsis,
                    modifier  = Modifier.weight(1f)
                )
            }
        }
    } else {
        // ~6 evenly spaced samples (first … last). Not column-aligned, but readable.
        val targetLabels = 6
        val step = ((buckets.size - 1).toFloat() / (targetLabels - 1)).coerceAtLeast(1f)
        val sampled = (0 until targetLabels)
            .map { (it * step).toInt().coerceAtMost(buckets.size - 1) }
            .distinct()
            .map { buckets[it] }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            sampled.forEach { bucket ->
                Text(
                    text     = labelFn(bucket),
                    style    = MaterialTheme.typography.labelSmall,
                    color    = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// SIMPLE VALUE BAR CHART  (weekday profile · hour-of-day profile)
// ════════════════════════════════════════════════════════════════════════════

/**
 * A lightweight vertical bar chart for a fixed list of [values] with optional
 * per-bar labels. Used on the Statistics screen for the hour-of-day profile
 * (24 bars) and the weekday profile (7 bars), mirroring the same two charts in
 * the PDF report.
 *
 * Unlike [AlcoholBarChart] this chart has NO time axis, NO daily-limit line and
 * NO abstinence ticks. It simply maps each value to a bar whose height is
 * proportional to the largest value in the list. A value ≤ 0 draws NO bar, which
 * is how an empty slot is shown — an hour with no consumption, or a weekday that
 * never occurred as a drink day.
 *
 * Theme colours are captured before the [Canvas] block, because the Canvas lambda
 * is a DrawScope (not a composable scope) and cannot call @Composable helpers
 * (see this file's header note).
 *
 * @param values   One value per bar, in display order. ≤ 0 ⇒ empty slot (no bar).
 * @param labelFor Axis label for a bar index, or "" to leave it blank — used to
 *                 thin the dense 24-hour axis down to every few hours.
 * @param showValues When true, each non-empty bar gets its value printed just
 *                 above it (one decimal). Bar heights then reserve headroom so the
 *                 topmost label is not clipped.
 * @param modifier Optional layout modifier.
 */
@Composable
fun ValueBarChart(
    values: List<Double>,
    labelFor: (Int) -> String,
    modifier: Modifier = Modifier,
    showValues: Boolean = false
) {
    if (values.isEmpty() || values.all { it <= 0.0 }) {
        Box(modifier.height(140.dp), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.no_data),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }

    // coerceAtLeast(0.001): avoids division by zero in the height calculation.
    val maxVal   = (values.maxOrNull() ?: 0.0).coerceAtLeast(0.001)
    val barColor = MaterialTheme.colorScheme.primary
    // Resolved here (not inside the Canvas DrawScope, which cannot read theme).
    val valueArgb = MaterialTheme.colorScheme.onSurfaceVariant.toArgb()
    // With value labels, scale bars against a 25%-taller reference so the label
    // above the tallest bar stays inside the canvas.
    val heightRef = if (showValues) maxVal * 1.25 else maxVal

    Canvas(modifier = modifier.fillMaxWidth().height(150.dp).padding(top = 8.dp, bottom = 4.dp)) {
        val chartH  = size.height
        val chartW  = size.width
        val spacing = chartW / values.size
        // 70% of a slice as bar width works for both the 7-bar weekday chart and
        // the 24-bar hour chart; coerceAtLeast(2f) keeps thin hour bars visible.
        val barW    = (spacing * 0.7f).coerceAtLeast(2f)

        val valuePaint = if (showValues) android.graphics.Paint().apply {
            isAntiAlias = true
            color       = valueArgb
            textAlign   = android.graphics.Paint.Align.CENTER
            textSize    = 10.sp.toPx()
        } else null

        values.forEachIndexed { i, v ->
            if (v <= 0.0) return@forEachIndexed
            // barH proportional to the tallest bar; coerceAtLeast(2f) keeps a tiny
            // but non-zero value visible.
            val barH    = (v / heightRef * chartH).toFloat().coerceAtLeast(2f)
            val centerX = i * spacing + spacing / 2f
            val barTop  = chartH - barH
            drawRoundRect(
                color        = barColor,
                topLeft      = Offset(centerX - barW / 2f, barTop),
                size         = Size(barW, barH),
                cornerRadius = CornerRadius(3.dp.toPx())
            )
            // Value just above the bar (one decimal), if requested.
            valuePaint?.let { p ->
                drawContext.canvas.nativeCanvas.drawText(
                    "%.1f".format(v), centerX, barTop - 2.dp.toPx(), p
                )
            }
        }
    }

    // Axis labels, one weighted cell per column; labelFor returns "" for the
    // thinned-out slots so dense (hourly) axes stay readable.
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceAround) {
        values.indices.forEach { i ->
            Text(
                text      = labelFor(i),
                style     = MaterialTheme.typography.labelSmall,
                color     = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                maxLines  = 1,
                overflow  = TextOverflow.Ellipsis,
                modifier  = Modifier.weight(1f)
            )
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// CATEGORY DONUT CHART
// ════════════════════════════════════════════════════════════════════════════

/**
 * Fixed colour assigned to each [DrinkCategory] in the donut chart and its legend.
 *
 * Using fixed colours (not theme colours) keeps the chart consistent across
 * light and dark themes and makes the categories immediately recognisable.
 * The colours are taken from the Tailwind CSS palette (500-level) for
 * good contrast against both light and dark backgrounds.
 */
private val CATEGORY_COLORS = mapOf(
    DrinkCategory.BEER      to Color(0xFFF59E0B),   // amber-500
    DrinkCategory.WINE      to Color(0xFF9333EA),   // purple-600
    DrinkCategory.SPIRITS   to Color(0xFFEF4444),   // red-500
    DrinkCategory.LONGDRINK to Color(0xFF3B82F6),   // blue-500
    DrinkCategory.LIQUEUR   to Color(0xFF10B981),   // emerald-500
    DrinkCategory.OTHER     to Color(0xFF6B7280)    // gray-500
)

/**
 * Renders a donut chart of alcohol consumption broken down by [DrinkCategory],
 * followed by a two-column legend.
 *
 * A donut chart is an annular ring divided into arc segments. Each segment's
 * sweep angle is proportional to its share of [data]'s total:
 *   sweepAngle = (grams / totalGrams) × 360°
 *
 * A 1° gap is subtracted from each segment's sweep so adjacent segments are
 * visually separated even when their proportions are very close.
 *
 * The chart starts at −90° (top of the circle) and progresses clockwise,
 * matching the conventional "12 o'clock start" of pie/donut charts.
 *
 * When [data] is empty, a centred "no data" placeholder is shown.
 *
 * @param data      Map from [DrinkCategory] to total grams in the selected period.
 *                  Zero-value entries are filtered out by the caller (StatsViewModel).
 * @param modifier  Optional layout modifier for the outer composable.
 */
@Composable
fun CategoryDonutChart(
    data: Map<DrinkCategory, Double>,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) {
        Box(modifier.height(120.dp), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.no_data),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }

    // coerceAtLeast(0.001): prevents division by zero in the percentage calculation
    // when only zero-gram entries are present (edge case).
    val total   = data.values.sum().coerceAtLeast(0.001)
    // Sort largest segment first so the most prominent category starts at the top
    val entries = data.entries.sortedByDescending { it.value }

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(160.dp)
    ) {
        // Donut geometry: radius fills 88 % of the smaller canvas dimension;
        // stroke width is 38 % of the radius, giving the "ring" appearance.
        val radius      = minOf(size.width, size.height) / 2f * 0.88f
        val strokeWidth = radius * 0.38f
        val cx          = size.width / 2f
        val cy          = size.height / 2f
        val arcBounds   = androidx.compose.ui.geometry.Rect(
            left   = cx - radius,
            top    = cy - radius,
            right  = cx + radius,
            bottom = cy + radius
        )

        var startAngle = -90f   // start at 12 o'clock
        entries.forEach { (category, grams) ->
            val sweepAngle = (grams / total * 360f).toFloat()
            drawArc(
                color       = CATEGORY_COLORS[category] ?: Color.Gray,
                startAngle  = startAngle,
                sweepAngle  = sweepAngle - 1f,   // 1° visual gap between segments
                useCenter   = false,             // false = arc only (no pie wedge lines)
                topLeft     = arcBounds.topLeft,
                size        = androidx.compose.ui.geometry.Size(radius * 2, radius * 2),
                style       = Stroke(width = strokeWidth)
            )
            startAngle += sweepAngle
        }
    }

    // Legend: entries arranged in two columns via chunked(2)
    Column(Modifier.fillMaxWidth().padding(top = 8.dp)) {
        entries.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                row.forEach { (category, grams) ->
                    Row(
                        modifier          = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Colour swatch drawn via drawBehind to avoid an extra composable
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .then(
                                    Modifier.drawBehind {
                                        drawCircle(color = CATEGORY_COLORS[category] ?: Color.Gray)
                                    }
                                )
                        )
                        Spacer(Modifier.width(6.dp))
                        Column {
                            Text(
                                category.displayLabel(),
                                style    = MaterialTheme.typography.labelSmall,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                "${"%.1f".format(grams)} g · ${"%.0f".format(grams / total * 100)} %",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                // Pad the row to two columns if it only has one entry
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}
