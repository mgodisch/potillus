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
package de.godisch.potillus.domain

import de.godisch.potillus.domain.model.DaySummary
import java.time.LocalDate

// =============================================================================
// ChartBucketing.kt – Continuous time-axis series for the consumption chart
// =============================================================================
//
// WHY THIS EXISTS:
//   The daily-summary queries return only days that HAVE entries. A bar chart
//   built directly from them has no notion of abstinent days: gaps simply
//   vanish and the x-axis is a list of drink days rather than a real time axis.
//
//   To draw a proper time axis (and to show abstinent days), the sparse
//   summaries must be expanded into a GAP-FREE series that covers every day in
//   the period. For long periods (a whole year) one bar per day is unreadable,
//   so adjacent days are aggregated into fixed-width buckets (weeks or months).
//
// SEMANTICS OF A BUCKET (see [ChartBucket]):
//   - A bucket's value is the MEAN grams of pure alcohol PER CALENDAR DAY inside
//     the bucket (sum of the bucket's days ÷ number of those days). For a DAILY
//     bucket that is simply the day's own total, so the daily chart is unchanged
//     in meaning. Using a per-day average keeps the dashed DAILY-LIMIT reference
//     line directly comparable across all granularities (a weekly bar above the
//     line means the week averaged more than the daily limit).
//   - A bucket is "abstinent" when the entire bucket contained 0 g. Abstinent
//     buckets carry no bar; the renderer marks them with a small green tick so
//     "recorded, zero consumption" is visually distinct from a tiny bar.
//
// This object is deliberately Android-free (pure java.time + plain data) so it
// is unit-testable on the JVM and shared by BOTH the on-screen chart
// (StatsViewModel) and the PDF export (PdfReportData).
// =============================================================================

/** Time granularity of one bar in the consumption-over-time chart. */
enum class ChartGranularity { DAILY, WEEKLY, MONTHLY }

/**
 * One column of the consumption-over-time chart.
 *
 * @param labelDate   The bucket's first calendar day as "YYYY-MM-DD". The
 *                    calling screen turns this into a short axis label
 *                    (weekday, day-of-month, month name, …), so this type stays
 *                    locale-agnostic.
 * @param avgPerDay   Mean grams of pure alcohol per calendar day in the bucket
 *                    (see file header). Equals the day's total for DAILY buckets.
 * @param isAbstinent True when the whole bucket had zero consumption; rendered
 *                    as a green tick instead of a bar.
 */
data class ChartBucket(
    val labelDate: String,
    val avgPerDay: Double,
    val isAbstinent: Boolean
)

object ChartBucketing {

    /**
     * Picks a sensible granularity for an ARBITRARY span (used by the PDF export,
     * whose date range is whatever the user chose, not WEEK/MONTH/YEAR):
     *   - ≤ 35 days  → one bar per day,
     *   - ≤ 366 days → one bar per week (at most ~53 bars),
     *   - otherwise  → one bar per month.
     *
     * @param days Number of calendar days in the (inclusive) span.
     */
    fun granularityForSpan(days: Int): ChartGranularity = when {
        days <= 35  -> ChartGranularity.DAILY
        days <= 366 -> ChartGranularity.WEEKLY
        else        -> ChartGranularity.MONTHLY
    }

    /**
     * Expands sparse [summaries] (days WITH entries only) into a continuous,
     * gap-free list of buckets covering the inclusive range [from]..[to].
     *
     * Missing days contribute 0 g, so abstinent days appear as zero-value
     * buckets. Buckets are clamped to the period end, so the last week/month may
     * be shorter than a full week/month and its average is computed over the
     * days that actually fall inside the period.
     *
     * @param summaries   Daily totals for days that have entries ("YYYY-MM-DD").
     * @param from        Inclusive period start ("YYYY-MM-DD").
     * @param to          Inclusive period end   ("YYYY-MM-DD").
     * @param granularity Bucket width (see [granularityForSpan]).
     * @return            Buckets in chronological order, or empty when from > to.
     */
    fun bucketize(
        summaries: List<DaySummary>,
        from: String,
        to: String,
        granularity: ChartGranularity
    ): List<ChartBucket> {
        val start = LocalDate.parse(from, DayResolver.DATE_FORMATTER)
        val end   = LocalDate.parse(to, DayResolver.DATE_FORMATTER)
        if (start.isAfter(end)) return emptyList()

        // O(1) lookup of a day's total; days not present here are abstinent (0 g).
        val gramsByDate: Map<String, Double> = summaries.associate { it.date to it.totalGrams }
        // One day past the period end; used as an exclusive upper bound when summing.
        val endExclusive = end.plusDays(1)

        val buckets = ArrayList<ChartBucket>()
        var bucketStart = start
        while (!bucketStart.isAfter(end)) {
            // Natural (un-clamped) end of this bucket, exclusive.
            val naturalEndExclusive: LocalDate = when (granularity) {
                ChartGranularity.DAILY   -> bucketStart.plusDays(1)
                ChartGranularity.WEEKLY  -> bucketStart.plusWeeks(1)
                // Month buckets snap to the 1st of the next month so successive
                // buckets align to calendar months even if the first one starts
                // mid-month.
                ChartGranularity.MONTHLY -> bucketStart.withDayOfMonth(1).plusMonths(1)
            }
            // Never let a bucket run past the period.
            val cappedEndExclusive = if (naturalEndExclusive.isAfter(endExclusive))
                endExclusive else naturalEndExclusive

            var sum = 0.0
            var dayCount = 0
            var day = bucketStart
            while (day.isBefore(cappedEndExclusive)) {
                sum += gramsByDate[DayResolver.formatDate(day)] ?: 0.0
                dayCount++
                day = day.plusDays(1)
            }

            buckets.add(
                ChartBucket(
                    labelDate   = DayResolver.formatDate(bucketStart),
                    avgPerDay   = if (dayCount > 0) sum / dayCount else 0.0,
                    isAbstinent = sum == 0.0
                )
            )

            bucketStart = cappedEndExclusive
        }
        return buckets
    }
}
