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

import de.godisch.potillus.domain.model.DaySummary
import java.time.LocalDate

// =============================================================================
// WeekdayProfile.kt – the seven-column weekday chart, computed once
// =============================================================================
//
// WHY THIS FILE EXISTS
//   The Statistics screen and the PDF report draw the same seven bars, and each
//   used to build them itself — the same loop over daily summaries, written out
//   twice. That is how the two came to divide by different things without anyone
//   noticing, and why a correction had to be made in two places. iOS keeps the
//   calculation in `StatsAggregator.weekdayAverages`; this is its Kotlin twin,
//   and `test-vectors/weekday-profile.json` holds the two to one answer sheet
//   (`WeekdayProfileVectorTest` on each side).
//
// WHAT A BAR MEANS
//   EVERY MONDAY IN THE PERIOD IS A MONDAY, including the dry ones. The divisor
//   is how often the weekday OCCURS between `from` and `to`, not how many of
//   those days happen to carry an entry, so a bar answers "how much do I drink
//   on a Monday" rather than "when I drink on a Monday, how much". Four Mondays
//   with one 40 g evening read 10 g, not 40.
//
//   The report states the two forms separately elsewhere — average per day
//   beside average per drink day — and the neighbouring hour chart divides by
//   the period's length for the same reason: only then do the bars sum to
//   something, seven weekday averages to a week's consumption. Dividing one
//   chart by a different denominator than the other, with nothing in the caption
//   to say so, was the earlier behaviour.
//
// THE RUNNING DAY
//   A day is only a dry day once it is over. The running day therefore counts
//   towards its weekday's divisor only if it has already seen alcohol — the same
//   superposition rule `DayResolver.windowDays` and `ChartBucketing.bucketize`
//   apply. Before v0.86.0 the running day always counted, so Monday morning showed
//   a 0 g Monday bar that the rest of the screen still called undecided, and
//   the sum relation to the hour chart was off by a day.
// =============================================================================

/** The weekday chart's seven columns. */
object WeekdayProfile {

    /** How many columns the chart has. Seven, and the reason is the calendar. */
    private const val COLUMNS = 7

    /**
     * Average grams for each weekday column, in [order] order.
     *
     * Computed from the DAILY SUMMARIES — one total per day — not from individual
     * entries, so a day with six beers counts once, as a day. A day with only
     * alcohol-free drinks has a summary of 0.0 g and counts as what it is: a dry
     * day, like any other day without alcohol.
     *
     * A column is `null` only when the weekday does not occur in [from]..[to] at
     * all, which needs a range shorter than a week. An average of nothing is not
     * zero, and the chart must be able to draw the difference between "no Tuesday
     * in this period" and "Tuesdays were dry".
     *
     * @param summaries        Daily totals; a day absent from the list counts as 0 g.
     * @param from             Inclusive first day of the period ("YYYY-MM-DD").
     * @param to               Inclusive last day of the period.
     * @param firstDayOfWeekIso The locale's first weekday, ISO 1 = Monday.
     * @param inProgressDay    The logical day still running, when it lies in
     *                         [from]..[to] (the Statistics screen passes today for
     *                         a window ending today; a past window and the report
     *                         pass nothing). A running day without alcohol is
     *                         not counted; with alcohol it is.
     * @return Seven averages, or `null` where the weekday does not occur.
     */
    fun averages(
        summaries: List<DaySummary>,
        from: String,
        to: String,
        firstDayOfWeekIso: Int,
        inProgressDay: String? = null,
    ): List<Double?> {
        val start = runCatching { DayResolver.parseDate(from) }.getOrNull()
        val end = runCatching { DayResolver.parseDate(to) }.getOrNull()
        if (start == null || end == null || start.isAfter(end)) {
            return List(COLUMNS) { null }
        }

        // Summed rather than overwritten: the caller's list is one row per day,
        // but summing costs nothing and cannot silently drop a duplicate.
        val totalsByDate = mutableMapOf<String, Double>()
        summaries.forEach { totalsByDate.merge(it.date, it.totalGrams, Double::plus) }

        val sums = DoubleArray(COLUMNS)
        val counts = IntArray(COLUMNS)
        var day: LocalDate = start
        while (!day.isAfter(end)) {
            val column = (day.dayOfWeek.value - firstDayOfWeekIso + COLUMNS) % COLUMNS
            val date = DayResolver.formatDate(day)
            val grams = totalsByDate[date] ?: 0.0
            sums[column] += grams
            // The running day is undecided until it is over or has seen alcohol.
            if (date != inProgressDay || AlcoholCalculator.isDrinkDay(grams)) counts[column]++
            day = day.plusDays(1)
        }

        return (0 until COLUMNS).map { if (counts[it] == 0) null else sums[it] / counts[it] }
    }

    /**
     * The seven ISO weekday numbers, starting at the locale's first day.
     *
     * The chart's column order, and the order [averages] returns its values in.
     *
     * @param firstDayOfWeekIso The locale's first weekday, ISO 1 = Monday.
     */
    fun order(firstDayOfWeekIso: Int): List<Int> =
        (0 until COLUMNS).map { (firstDayOfWeekIso - 1 + it) % COLUMNS + 1 }
}
