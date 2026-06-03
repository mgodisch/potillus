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
//   errorColor()) are @Composable and cannot be called inside a Canvas{} lambda
//   (which is a DrawScope, not a composable context). They must be captured in
//   local variables in the enclosing @Composable function before entering Canvas.
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import de.godisch.potillus.R
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.ui.theme.errorColor
import de.godisch.potillus.ui.theme.warningColor

// ════════════════════════════════════════════════════════════════════════════
// BAR CHART
// ════════════════════════════════════════════════════════════════════════════

/**
 * Draws a vertical bar chart of daily alcohol consumption with a dashed limit line.
 *
 * Layout:
 * - Bars fill the available width equally; each bar's height is proportional
 *   to its [DaySummary.totalGrams] relative to [maxGrams].
 * - A horizontal dashed line marks the [limitGrams] threshold.
 * - A label row below the chart shows one label per day, produced by [labelFn].
 * - When [dataPoints] is empty, a centred "no data" placeholder is shown instead.
 *
 * Colour coding:
 * - Bar below limit → [MaterialTheme.colorScheme.primary] (app's accent colour)
 * - Bar above limit → [errorColor] (red)
 * - Limit line       → [warningColor] (amber dashed)
 *
 * SCALE:
 *   `maxGrams = max(highestDay, limitGrams) × 1.15`
 *   The 1.15 factor adds 15 % headroom above the tallest bar or the limit line
 *   so neither touches the top edge of the canvas.
 *
 * @param dataPoints  Daily summaries to plot. Only days WITH entries are included
 *                    (no zero-bar days); the x-axis spacing is uniform regardless
 *                    of gaps in the data.
 * @param limitGrams  Daily limit threshold for the dashed line and bar colouring.
 * @param labelFn     Converts a "YYYY-MM-DD" date string to a short axis label
 *                    (e.g. "Mo", "1.", "Jan"). Provided by the calling screen so
 *                    the chart stays locale-agnostic.
 * @param modifier    Optional layout modifier.
 */
@Composable
fun AlcoholBarChart(
    dataPoints: List<DaySummary>,
    limitGrams: Double,
    labelFn: (String) -> String,
    modifier: Modifier = Modifier
) {
    if (dataPoints.isEmpty()) {
        Box(modifier.height(180.dp), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.no_data),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }

    // Capture theme colors before entering Canvas (see file header note)
    val maxGrams   = maxOf(dataPoints.maxOf { it.totalGrams }, limitGrams) * 1.15
    val barColor   = MaterialTheme.colorScheme.primary
    val limitColor = warningColor()
    val overColor  = errorColor()

    Canvas(modifier = modifier.fillMaxWidth().height(200.dp).padding(top = 8.dp, bottom = 24.dp)) {
        val chartH  = size.height
        val chartW  = size.width
        // Each bar occupies an equal horizontal slice (spacing = chartW / numBars).
        // The actual bar width is 60 % of the slice to leave gaps between bars.
        // coerceAtLeast(4f) ensures a minimum 4px bar even with many data points.
        val spacing = chartW / dataPoints.size
        val barW    = (spacing * 0.6f).coerceAtLeast(4f)

        // Limit line Y coordinate: distance from the bottom = (limitGrams / maxGrams) * chartH
        val limitY  = chartH - (limitGrams / maxGrams * chartH).toFloat()

        // Draw dashed horizontal limit line
        drawLine(
            color       = limitColor,
            start       = Offset(0f, limitY),
            end         = Offset(chartW, limitY),
            strokeWidth = 2.dp.toPx(),
            pathEffect  = PathEffect.dashPathEffect(floatArrayOf(10f, 6f))
        )

        // Draw each bar
        dataPoints.forEachIndexed { i, day ->
            // barH: height in pixels; coerceAtLeast(2f) makes even 0.x-gram entries visible
            val barH  = (day.totalGrams / maxGrams * chartH).toFloat().coerceAtLeast(2f)
            // Center the bar within its horizontal slice
            val left  = i * spacing + (spacing - barW) / 2
            val color = if (day.totalGrams > limitGrams) overColor else barColor
            drawRoundRect(
                color        = color,
                topLeft      = Offset(left, chartH - barH),
                size         = Size(barW, barH),
                cornerRadius = CornerRadius(3.dp.toPx())
            )
        }
    }

    // X-axis label row: one Text per data point, equally spaced
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceAround) {
        dataPoints.forEach { day ->
            Text(
                text      = labelFn(day.date),
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
