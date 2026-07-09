/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.ui.component

// =============================================================================
// CalendarComponents.kt – Year-view heat-map calendar
// =============================================================================
//
// LAYOUT STRATEGY:
//   The year is split into 4 rows of 3 months (chunked(3)).
//   Each month is laid out as a grid of week rows (0..5) × day columns (0..6).
//   Days are aligned to Monday (ISO week start: dayOfWeek.value = 1..7,
//   where 1 = Monday). `startPad` = number of empty cells before day 1.
//
// DAY-CELL RENDERING:
//   Each day is a 10 × 10 dp box with 2 dp gaps (padding = cellGap / 2 on each side).
//   The colours are resolved from:
//     - empty (no summary):      MaterialTheme.colorScheme.surfaceVariant
//     - under limit:             MaterialTheme.colorScheme.primary   (app accent)
//     - over limit:              errorColor()  (red)
//   Today gets an additional border ring to distinguish it from data cells.
//
// COLOUR CAPTURE (same pattern as ChartComponents.kt):
//   Theme colours must be captured in the @Composable scope before any
//   conditional or lambda that cannot call @Composable functions.
// =============================================================================

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.ui.theme.dangerRedColor
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Compact full-year calendar heat-map.
 *
 * Renders 12 months in a 4×3 grid. Each day is a small coloured square:
 *   - **surfaceVariant** (neutral)  → no consumption entry recorded.
 *   - **primary** (accent blue)     → entry exists, daily total ≤ [limitGrams].
 *   - **errorColor** (red)          → entry exists, daily total > [limitGrams].
 *   - **outline border**            → the cell additionally shows a border when
 *                                     the day equals [today] (regardless of consumption).
 *
 * Cells with a consumption entry are tappable; empty cells are inert.
 *
 * HOW THE GRID INDEX WORKS:
 *   For month M starting on weekday `startPad` (0 = Mon):
 *     For week row w (0..5) and day-of-week column d (0..6):
 *       `dayNum = w × 7 + d − startPad + 1`
 *   If `dayNum < 1` or `dayNum > lengthOfMonth`: render an empty placeholder box.
 *   Otherwise: look up the [DaySummary] for "YYYY-MM-DD" and colour accordingly.
 *
 * @param year        Calendar year to display.
 * @param summaries   Map from "YYYY-MM-DD" → [DaySummary] for all days with entries.
 *                    Days without entries are simply absent from the map.
 * @param limitGrams  Daily limit in grams; determines over/under colouring.
 * @param today       Logical today (from [de.godisch.potillus.domain.DayResolver]).
 *                    Must be derived from DayResolver (not [LocalDate.now]) so the
 *                    day-change time is respected.
 * @param onDayClick  Called with the ISO-8601 date when the user taps a non-empty day.
 * @param modifier    Optional layout modifier for the outer [Column].
 */
@Composable
fun YearCalendarView(
    year: Int,
    summaries: Map<String, DaySummary>,
    limitGrams: Double,
    today: LocalDate,
    onDayClick: (String) -> Unit,
    modifier: Modifier = Modifier,
    weekStart: Int = 1,
) {
    // Per-app locale (LocaleSupport.kt rule: never Locale.getDefault() for
    // user-visible text). Without the explicit locale this formatter followed
    // the JVM default — i.e. the SYSTEM language — so the year calendar's
    // month abbreviations ignored the in-app language on every API level
    // (found in the v0.79.0 QA delta review).
    val locale = LocalContext.current.formattingLocale()
    // "LLL" (STANDALONE abbreviated month), not "MMM" (format context): these
    // cells are bare month labels without a day, and in inflected languages the
    // format context is the genitive meant to follow a day number. Most shipped
    // locales render both identically, but the standalone letter is the
    // grammatically correct one — same rule as the Today card's month caption
    // (TextStyle.FULL_STANDALONE) and the month+year labels (monthYearFormatter,
    // see l10n/LocaleSupport.kt).
    val monthFmt = DateTimeFormatter.ofPattern("LLL", locale)
    // Localized MEDIUM date for the per-cell accessibility label (e.g. "28 Jun
    // 2026" / "2026/06/28"). Built once and reused for every labelled day cell.
    val dayDescDateFmt = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)
    val months = (1..12).map { YearMonth.of(year, it) }

    // Capture theme colours before entering Box/Column lambdas (see file header note)
    val green = MaterialTheme.colorScheme.primary
    val red = dangerRedColor()
    val empty = MaterialTheme.colorScheme.surfaceVariant
    val todayBorder = MaterialTheme.colorScheme.outline
    val cellSize = 10.dp
    val cellGap = 2.dp

    Column(modifier = modifier.padding(horizontal = 8.dp)) {
        // Rows of 3 months
        months.chunked(3).forEach { rowMonths ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                rowMonths.forEach { ym ->
                    Column(modifier = Modifier.weight(1f).padding(horizontal = 4.dp)) {
                        // Month abbreviation header (e.g. "Jan", "Feb")
                        Text(
                            ym.format(monthFmt),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 2.dp),
                        )

                        // Week alignment: day 1 of the month may not fall on the
                        // configured first weekday. startPad = empty cells to prepend.
                        // weekStart is ISO 1..7; (value - weekStart + 7) % 7 maps the
                        // first day to its column (0 = the configured week-start day).
                        val firstDay = ym.atDay(1)
                        val startPad = (firstDay.dayOfWeek.value - weekStart + 7) % 7

                        for (week in 0..5) {
                            Row {
                                for (dow in 0..6) {
                                    val dayNum = week * 7 + dow - startPad + 1
                                    if (dayNum < 1 || dayNum > ym.lengthOfMonth()) {
                                        // Empty placeholder to preserve grid alignment
                                        Box(Modifier.size(cellSize).padding(cellGap / 2))
                                    } else {
                                        val date = ym.atDay(dayNum).toString() // "YYYY-MM-DD"
                                        val summary = summaries[date]
                                        val color = when {
                                            summary == null || summary.totalGrams == 0.0 -> empty
                                            AlcoholCalculator.isOverLimit(summary.totalGrams, limitGrams) -> red
                                            else -> green
                                        }
                                        val localDate = ym.atDay(dayNum)
                                        val isToday = localDate == today
                                        // Per-cell accessibility label: the under/over-limit
                                        // state is conveyed on screen by cell COLOUR alone, so a
                                        // screen reader would otherwise get no access to it (WCAG
                                        // 1.4.1). We attach a "date, grams, status" description —
                                        // status reuses the same localized legend captions shown
                                        // below the grid. Only days that carry a summary are
                                        // tappable and labelled; empty days stay inert and silent
                                        // so the reader is not flooded with 300+ "no entry" nodes.
                                        // (The blue/red under/over palette is already colour-blind
                                        // distinguishable — it is not a red/green pair — so no
                                        // extra non-colour VISUAL cue is added here.)
                                        val cellDesc: String? = summary?.let { s ->
                                            val statusRes = if (AlcoholCalculator.isOverLimit(s.totalGrams, limitGrams)) {
                                                R.string.year_calendar_over_limit
                                            } else {
                                                R.string.year_calendar_under_limit
                                            }
                                            stringResource(
                                                R.string.year_calendar_day_desc,
                                                dayDescDateFmt.format(localDate),
                                                s.totalGrams.fmt1(locale),
                                                stringResource(statusRes),
                                            )
                                        }
                                        Box(
                                            modifier = Modifier
                                                .size(cellSize)
                                                .padding(cellGap / 2)
                                                .background(color, RoundedCornerShape(1.dp))
                                                .then(
                                                    if (isToday) {
                                                        Modifier.border(1.dp, todayBorder, RoundedCornerShape(1.dp))
                                                    } else {
                                                        Modifier
                                                    },
                                                )
                                                .then(
                                                    // A labelled cell exposes its description to
                                                    // accessibility services; an empty cell adds
                                                    // no semantics and stays silent.
                                                    cellDesc?.let { d ->
                                                        Modifier.semantics { contentDescription = d }
                                                    } ?: Modifier,
                                                )
                                                .clickable(enabled = summary != null, role = Role.Button) { onDayClick(date) },
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                // Pad the last row if it has fewer than 3 months (never occurs for a 12-month year,
                // but handles edge cases if the months list is ever made dynamic)
                repeat(3 - rowMonths.size) { Spacer(Modifier.weight(1f)) }
            }
            Spacer(Modifier.height(10.dp))
        }

        // Colour legend at the bottom
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.year_calendar_no_entry),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Box(Modifier.padding(horizontal = 4.dp).size(10.dp).background(empty, RoundedCornerShape(1.dp)))
            Text(
                stringResource(R.string.year_calendar_under_limit),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Box(Modifier.padding(horizontal = 4.dp).size(10.dp).background(green, RoundedCornerShape(1.dp)))
            Text(
                stringResource(R.string.year_calendar_over_limit),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Box(Modifier.padding(start = 4.dp).size(10.dp).background(red, RoundedCornerShape(1.dp)))
        }
    }
}
