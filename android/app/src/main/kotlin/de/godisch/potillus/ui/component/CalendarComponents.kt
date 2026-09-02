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
package de.godisch.potillus.ui.component

// =============================================================================
// CalendarComponents.kt – Year-view heat-map calendar
// =============================================================================
//
// LAYOUT STRATEGY:
//   The year is split into 4 rows of 3 months (chunked(3)).
//   Each month is laid out as a grid of week rows (0..5) × day columns (0..6).
//   Days are aligned to the locale's first weekday (`weekStart`, ISO 1..7);
//   `startPad` = number of empty cells before day 1, from domain/MonthGrid.
//
// DAY-CELL RENDERING:
//   Each day is a 10 × 10 dp box with 2 dp gaps (padding = cellGap / 2 on each side).
//   The colours are resolved from:
//     - empty (no summary):      MaterialTheme.colorScheme.surfaceVariant
//     - under limit:             MaterialTheme.colorScheme.primary   (app accent)
//     - over limit:              dangerRedColor()  (red)
//   Today gets a ring around the cell to distinguish it from data cells; it is
//   drawn before the padding, in onSurfaceVariant, so the card is behind it.
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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.MonthGrid
import de.godisch.potillus.domain.YearGrid
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.heatmapEmptyColor
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
 *   - **dangerRedColor** (red)      → entry exists, daily total > [limitGrams].
 *   - **onSurfaceVariant ring**     → drawn around the cell when the day equals
 *                                     [today], whatever its fill (or lack of one).
 *   - **nothing at all**            → the day lies outside the evaluated window:
 *                                     after [today], or before [statsFrom].
 *
 * Individual DAYS are not tappable: at 9.dp they are far below the 48.dp touch
 * target a reliable tap needs. A whole MONTH is, and it is comfortably large:
 * tapping one opens the month view on it, which is where a day gets picked.
 *
 * HOW THE GRID INDEX WORKS:
 *   For month M with `startPad` blanks before day 1 (0 = day 1 is on the
 *   locale's first weekday):
 *     For week row w (0..5) and day-of-week column d (0..6):
 *       `dayNum = w × 7 + d − startPad + 1`
 *   If `dayNum < 1` or `dayNum > lengthOfMonth`: render an empty placeholder box.
 *   Otherwise: look up the [DaySummary] for "YYYY-MM-DD" and colour accordingly.
 *
 * @param year        Calendar year to display.
 * @param summaries   Map from "YYYY-MM-DD" → [DaySummary] for all days with entries.
 *                    Days without entries are simply absent from the map.
 * @param limitGrams  Daily limit in grams; determines over/under colouring.
 * @param onMonthClick Called with the month number (1..12) when the user taps a
 *                    month block. The caller switches to the month view; no day
 *                    is selected, because a tap this size names a month, not a day.
 * @param today       Logical today (from [de.godisch.potillus.domain.DayResolver]).
 *                    Must be derived from DayResolver (not [LocalDate.now]) so the
 *                    day-change time is respected. Also the upper end of the
 *                    drawn window: later days render as nothing.
 * @param modifier    Optional layout modifier for the outer [Column].
 * @param statsFrom   Statistics start floor, or `null` for none. Earlier days
 *                    render as nothing, entry or not, because they are excluded
 *                    from every statistic the app shows.
 */
@Composable
fun YearCalendarView(
    year: Int,
    summaries: Map<String, DaySummary>,
    limitGrams: Double,
    today: LocalDate,
    onMonthClick: (Int) -> Unit,
    modifier: Modifier = Modifier,
    weekStart: Int = 1,
    statsFrom: LocalDate? = null,
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
    // The full standalone month name for the block's accessibility label. "LLLL"
    // for the same reason "LLL" is used above: a bare month name, not the genitive
    // that follows a day number. The year is included because the grid can be
    // paged away from the current one.
    val monthLabelFmt = DateTimeFormatter.ofPattern("LLLL yyyy", locale)
    // Localized MEDIUM date for the per-cell accessibility label (e.g. "28 Jun
    // 2026" / "2026/06/28"). Built once and reused for every labelled day cell.
    val dayDescDateFmt = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)
    val months = (1..12).map { YearMonth.of(year, it) }

    // Capture theme colours before entering Box/Column lambdas (see file header note)
    val green = MaterialTheme.colorScheme.primary
    val red = dangerRedColor()
    val empty = heatmapEmptyColor()
    val todayBorder = MaterialTheme.colorScheme.onSurfaceVariant

    // MEASURED AND LEFT AS IT IS (WCAG 1.4.11, 0.85.0 QA round).
    //
    //   empty cell against the card   1.12 : 1 dark, 1.29 : 1 light
    //
    // That is far below the 3 : 1 the criterion asks of a non-text indicator,
    // and it is deliberate. The DATA cells clear it -- an over-limit cell has
    // 3.25 : 1 -- so what is quiet here is the empty grid, not the information.
    // Raising the empty cells would turn a year of mostly-blank squares into a
    // lattice of 365 tiles competing with the data drawn on top of it, and the
    // maintainer judged the current balance right on device.
    //
    // Do not "fix" this from the numbers alone; the decision and the reasoning
    // behind it are the paragraph above.
    //
    // THE TODAY RING LEFT THAT GROUP. It was drawn in `outline` on top of the
    // cell fill, at 1.06 : 1 dark and 1.20 : 1 light, and on device it was a
    // marker nobody could find in either theme -- a different matter from a grid
    // that is quiet on purpose. It now sits outside the cell padding in
    // `onSurfaceVariant`, against the card alone: 5.13 : 1 and 5.21 : 1.
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
                    // THE MONTH IS THE TOUCH TARGET, not the day. A block spans about a
                    // third of the width and six cell rows, so it clears the 48.dp
                    // minimum many times over, and what it means is unambiguous: show
                    // me this month. The click sits on the Column rather than on the
                    // cells, which keeps the day cells free of targets too small to hit.
                    //
                    // clickable does NOT merge the children, so each labelled day stays
                    // its own node for accessibility services; the block adds a level
                    // above them. It carries the full month name (not the abbreviation
                    // the cells show) so the action is announced with a name rather than
                    // as an unlabelled target.
                    val monthLabel = ym.format(monthLabelFmt)
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 4.dp)
                            .clickable(role = Role.Button) { onMonthClick(ym.monthValue) }
                            .semantics { contentDescription = monthLabel },
                    ) {
                        // Month abbreviation header (e.g. "Jan", "Feb")
                        Text(
                            ym.format(monthFmt),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 2.dp),
                        )

                        // Week alignment: day 1 of the month may not fall on the
                        // configured first weekday. startPad = empty cells to prepend,
                        // computed by the domain (MonthGrid, pinned to the iOS grid by
                        // test-vectors/month-grid.json). The heat-map draws a fixed six
                        // rows for every month, so only the alignment is read here.
                        val startPad = MonthGrid.of(ym, weekStart).leadingBlanks

                        for (week in 0..5) {
                            Row {
                                for (dow in 0..6) {
                                    val dayNum = week * 7 + dow - startPad + 1
                                    val cellDate = if (dayNum in 1..ym.lengthOfMonth()) {
                                        ym.atDay(dayNum)
                                    } else {
                                        null
                                    }
                                    // OUTSIDE THE EVALUATED WINDOW: nothing is drawn.
                                    //
                                    // Three kinds of cell get the same empty box. The first
                                    // is the grid padding around the month. The other two
                                    // are days the app has no claim about:
                                    //
                                    //   - after the logical today: the future, which cannot
                                    //     have been abstinent yet.
                                    //   - before [statsFrom]: the span the user excluded from
                                    //     every statistic (R.string.stats_from_desc). Entries
                                    //     there are excluded too, so a coloured cell would
                                    //     show the heat-map counting what the Statistics
                                    //     screen does not.
                                    //
                                    // Both used to render as a neutral cell, which is the
                                    // same square an abstinent day gets. The legend calls
                                    // that colour "no entry" and that stayed true, but a
                                    // whole grid of it reads as recorded abstinence -- and
                                    // with statsFromDate defaulting to the install date
                                    // (AppPreferences.toAppSettings), every fresh install
                                    // showed a year of it. Drawing nothing says nothing.
                                    //
                                    // The empty box keeps its size and padding, so the week
                                    // columns stay aligned, and it carries no click target
                                    // and no semantics: a hidden day is inert and silent to
                                    // a screen reader, like the padding cells always were.
                                    // The two date bounds are [YearGrid.isDrawn]'s, which is
                                    // where they are pinned against iOS; only the
                                    // padding case stays here, because a padding cell
                                    // has no date to judge.
                                    val outsideWindow = cellDate == null ||
                                        !YearGrid.isDrawn(cellDate, today, statsFrom)
                                    if (outsideWindow) {
                                        // Empty placeholder to preserve grid alignment
                                        Box(Modifier.size(cellSize).padding(cellGap / 2))
                                    } else {
                                        // Derived from dayNum again rather than reusing the
                                        // nullable `cellDate`: this branch needs a plain
                                        // LocalDate, and the guard above already established
                                        // that dayNum names a day of this month.
                                        val localDate = ym.atDay(dayNum)
                                        val date = localDate.toString() // "YYYY-MM-DD"
                                        val summary = summaries[date]
                                        val color = when {
                                            // A day with only alcohol-free entries reads as
                                            // empty here, like a day with none at all: the
                                            // heat map is about drinking, and
                                            // AlcoholCalculator.isDrinkDay decides that
                                            // everywhere in the app.
                                            summary == null || !AlcoholCalculator.isDrinkDay(summary.totalGrams) -> empty
                                            AlcoholCalculator.isOverLimit(summary.totalGrams, limitGrams) -> red
                                            else -> green
                                        }
                                        val isToday = localDate == today
                                        // Per-cell accessibility label: the under/over-limit
                                        // state is conveyed on screen by cell COLOUR alone, so a
                                        // screen reader would otherwise get no access to it (WCAG
                                        // 1.4.1). We attach a "date, grams, status" description —
                                        // status reuses the same localized legend captions shown
                                        // below the grid. Only days that carry a summary are
                                        // labelled; empty days stay silent so the reader is not
                                        // flooded with 300+ "no entry" nodes.
                                        // (The blue/red under/over palette is already colour-blind
                                        // distinguishable — it is not a red/green pair — so no
                                        // extra non-colour VISUAL cue is added here.)
                                        //
                                        // A day of alcohol-free entries is silent too, and for the
                                        // same reason its cell is drawn empty above: the label
                                        // states what the colour states, and "0.0 g, under limit"
                                        // for a cell that shows nothing logged would put the two
                                        // at odds. The day's entries are reachable in the month
                                        // view, where the day can be tapped.
                                        val drinkSummary =
                                            summary?.takeIf { AlcoholCalculator.isDrinkDay(it.totalGrams) }
                                        val cellDesc: String? = drinkSummary?.let { s ->
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
                                        // NOT TAPPABLE, deliberately. A cell is 9.dp
                                        // wide where a touch target must be 48.dp
                                        // (WCAG 2.5.8, Material's own guidance): a
                                        // target four times too small is one the user
                                        // misses, and the neighbour they hit instead
                                        // selects the wrong day silently. The target
                                        // is the month block around these cells,
                                        // which opens the month view where a day can
                                        // be picked at a size a finger can hit.
                                        //
                                        // No focus ring on the cell either: it marked
                                        // where a tap would land, and the tap has
                                        // moved out to the block.
                                        Box(
                                            modifier = Modifier
                                                .size(cellSize)
                                                // TODAY RING BEFORE THE PADDING, so only the card
                                                // surface lies behind it and ONE colour clears 3:1
                                                // for every cell: 5.13:1 dark, 5.21:1 light. Drawn
                                                // after the padding it sat on the cell FILL, which
                                                // varies between empty, under-limit blue and
                                                // over-limit red, and no single colour clears the
                                                // bar against all three -- `onSurfaceVariant`
                                                // manages 3.78:1 on an empty cell but 1.13:1 on a
                                                // blue one. Same move the focus ring made, for the
                                                // same reason.
                                                .then(
                                                    if (isToday) {
                                                        Modifier.border(
                                                            // 1.5.dp, not 1.dp: the gap between two
                                                            // cells is cellGap, so a hairline ring
                                                            // merely fills it and reads as a wider
                                                            // gap. The half dp that reaches over
                                                            // the fill is what makes it a ring.
                                                            1.5.dp,
                                                            todayBorder,
                                                            RoundedCornerShape(2.dp),
                                                        )
                                                    } else {
                                                        Modifier
                                                    },
                                                )
                                                .padding(cellGap / 2)
                                                .background(color, RoundedCornerShape(1.dp))
                                                .then(
                                                    // A labelled cell exposes its description to
                                                    // accessibility services; an empty cell adds
                                                    // no semantics and stays silent. Reading does
                                                    // not depend on tapping, so the description
                                                    // outlived the click that used to sit here.
                                                    cellDesc?.let { d ->
                                                        Modifier.semantics { contentDescription = d }
                                                    } ?: Modifier,
                                                ),
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
