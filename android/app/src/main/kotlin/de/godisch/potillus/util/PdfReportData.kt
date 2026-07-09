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
 * =============================================================================
 */
package de.godisch.potillus.util

import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.ChartBucket
import de.godisch.potillus.domain.ChartBucketing
import de.godisch.potillus.domain.ChartGranularity
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.domain.model.LimitInfo
import de.godisch.potillus.domain.model.LimitViolations
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

// =============================================================================
// PdfReportData – the report's numbers, computed with NO Android dependencies
// =============================================================================
//
// SEPARATION OF CONCERNS (the whole point of the v0.61.0 PDF redesign):
//   • PdfReportData (this file) computes WHAT the report says — every KPI,
//     monthly aggregate, category share, time-of-day figure and streak. It is a
//     plain Kotlin object with no Context, no Canvas, no WebView, and no string
//     resources, so it can be unit-tested on the JVM (see PdfReportDataTest).
//   • PdfReportBuilder turns this data into HOW the report looks by resolving
//     localised labels, formatting numbers, and filling the HTML/CSS template.
//   • WebViewPdfPrinter turns that HTML into a PDF via the system print dialog.
//
//   The arithmetic here is intentionally identical to the figures the on-screen
//   Statistics view shows (it reuses AlcoholCalculator and DayResolver), so the
//   PDF and the app never disagree.
// =============================================================================

/**
 * Per-month aggregate for the monthly table and the trend chart.
 *
 * @param monthKey  "YYYY-MM" sort key (e.g. "2026-01").
 * @param drinkDays Number of distinct drink days in the month (within the period).
 * @param totalGrams Sum of pure-alcohol grams for the month.
 * @param avgPerCalendarDay Total grams divided by the month's full length in days
 *                  (NOT by drink days), matching the on-screen monthly average.
 * @param daysOverDailyLimit Count of drink days whose own total exceeds the daily limit.
 */
data class MonthStat(
    val monthKey: String,
    val drinkDays: Int,
    val totalGrams: Double,
    val avgPerCalendarDay: Double,
    val daysOverDailyLimit: Int,
)

/**
 * One category's contribution to total consumption.
 *
 * @param categoryName The [de.godisch.potillus.domain.model.DrinkCategory] enum
 *                     name ("BEER", "WINE", …); the display label is resolved later.
 * @param grams        Pure-alcohol grams attributed to this category.
 * @param percent      Share of the period total, rounded to a whole percent.
 */
data class CategoryStat(
    val categoryName: String,
    val grams: Double,
    val percent: Int,
)

/**
 * The complete, presentation-free dataset for one PDF report.
 *
 * Every field is a primitive, a domain value object, or a list thereof — never a
 * formatted string and never a localised label. Formatting and localisation are
 * the [PdfReportBuilder]'s job.
 */
data class PdfReportData(
    // ── Period & configuration ───────────────────────────────────────────────
    val firstDate: String,
    val lastDate: String,
    val totalDays: Int,
    val limitInfo: LimitInfo,
    val weightKg: Double,

    // ── Headline KPIs ─────────────────────────────────────────────────────────
    val totalGrams: Double,
    val avgPerDay: Double,
    val avgPerDrinkDay: Double,
    val drinkDays: Int,
    val abstinentDays: Int,
    val violations: LimitViolations,
    val bingeDays: Int,

    // ── Medians (robust companions to the headline mean KPIs) ───────────────────
    /** Median of the per-calendar-day grams over the whole period (abstinent days count as 0 g). */
    val medianPerDay: Double,
    /** Median of the per-drink-day grams over the drink days only. */
    val medianPerDrinkDay: Double,
    /** Mean number of drink days per calendar month across [months]. */
    val avgDrinkDaysPerMonth: Double,
    /** Median number of drink days per calendar month across [months]. */
    val medianDrinkDaysPerMonth: Double,
    /** Highest single-day pure-alcohol total (g) over the period. */
    val maxPerDay: Double,
    /** Highest pure-alcohol total (g) in any 7 consecutive calendar days (rolling window). */
    val maxPer7Days: Double,

    // ── Monthly breakdown & trend ──────────────────────────────────────────────
    /** Ascending by [MonthStat.monthKey]. The trend chart is shown only when ≥ 2. */
    val months: List<MonthStat>,

    /**
     * Continuous, gap-free consumption series over [firstDate]..[lastDate] for the
     * report's time-axis chart. Abstinent days appear as zero buckets. Granularity
     * is chosen by [ChartBucketing.granularityForSpan] from the span length.
     */
    val chartBuckets: List<ChartBucket>,

    /** Bucket width of [chartBuckets]; drives the chart's axis-label format. */
    val chartGranularity: ChartGranularity,

    // ── Category breakdown ──────────────────────────────────────────────────────
    /** Descending by grams. */
    val categories: List<CategoryStat>,

    // ── Time-of-day pattern ─────────────────────────────────────────────────────
    /**
     * Pure-alcohol grams consumed in each hour-of-day bucket, indexed 0..23
     * (the list always has exactly 24 entries). This drives the report's 24-bar
     * time-of-day chart, which replaced the former "share before / after 17:00"
     * two-number split. Hours with no consumption are 0.0.
     */
    val hourlyGrams: List<Double>,

    // ── Weekday profile ────────────────────────────────────────────────────────
    /**
     * ISO weekday numbers (1 = Mon … 7 = Sun) in display order, rotated so the
     * first entry is the locale's first weekday (see [de.godisch.potillus.domain.DayResolver.firstDayOfWeekIso]).
     * Pairs index-for-index with
     * [weekdayAverages].
     */
    val weekdayOrder: List<Int>,
    /**
     * Average grams on each weekday in [weekdayOrder] order. `null` means the
     * weekday never occurred as a drink day in the period (rendered as "–").
     */
    val weekdayAverages: List<Double?>,

    // ── Abstinence streaks ──────────────────────────────────────────────────────
    val longestAbstinence: Int,
    val currentAbstinence: Int,
) {
    companion object {

        /** Daily-life convenience: the binge threshold lives on AlcoholCalculator. */
        val bingeThreshold: Double get() = AlcoholCalculator.BINGE_THRESHOLD

        /**
         * Computes the full report dataset for [entries] in the chosen period.
         *
         * @param entries   Consumption entries for the (inclusive) date range. Must be
         *                  non-empty; the caller checks this before calling.
         * @param drinks    Drink catalogue, used to map each entry to its category.
         * @param settings  Current limits, weight and day-change configuration.
         * @param periodEnd The user-chosen INCLUSIVE end of the export range
         *                  ("YYYY-MM-DD"), or `null` when the caller has no explicit
         *                  range (legacy behaviour: the streaks anchor at the real
         *                  logical today). Used only to anchor the abstinence
         *                  streaks — see the streak block below for why a HISTORICAL
         *                  range must not anchor at today (v0.81.0 QA fix).
         * @return A fully computed [PdfReportData].
         */
        fun from(
            entries: List<ConsumptionEntry>,
            drinks: List<DrinkDefinition>,
            settings: AppSettings,
            periodEnd: String? = null,
        ): PdfReportData {
            val drinkMap = drinks.associateBy { it.id }

            // Group once; reused for every per-day / per-month aggregate below.
            val byDate = entries.groupBy { it.logicalDate }

            val firstDate = entries.minOf { it.logicalDate }
            val lastDate = entries.maxOf { it.logicalDate }
            val limitInfo = AlcoholCalculator.getLimitInfo(settings)

            // Calendar span of the period (inclusive), used for averages and abstinent days.
            val totalDays = LocalDate.parse(firstDate)
                .datesUntil(LocalDate.parse(lastDate).plusDays(1))
                .count().toInt()

            val drinkDays = byDate.size
            val abstinentDays = (totalDays - drinkDays).coerceAtLeast(0)
            val totalGrams = entries.sumOf { it.gramsAlcohol }
            val avgPerDay = if (totalDays > 0) totalGrams / totalDays else 0.0
            val avgPerDrink = if (drinkDays > 0) totalGrams / drinkDays else 0.0

            // Shared limit-violation counter → identical figures to the Statistics screen.
            val daySummaries = byDate.map { (date, es) ->
                DaySummary(date, es.sumOf { it.gramsAlcohol }, es.size)
            }
            val violations = AlcoholCalculator.countLimitViolations(
                summaries = daySummaries,
                dailyLimitGrams = limitInfo.limitGrams,
                weeklyLimitGrams = limitInfo.weeklyLimitGrams,
                maxDrinkDaysPerWeek = limitInfo.maxDrinkDaysPerWeek,
            )
            val binge = AlcoholCalculator.BINGE_THRESHOLD
            val bingeDays = byDate.count { (_, es) -> AlcoholCalculator.isOverLimit(es.sumOf { it.gramsAlcohol }, binge) }

            // ── Monthly aggregates (ascending). Unlike the old canvas exporter we do
            //    NOT truncate to a row budget here: the HTML report paginates
            //    automatically, so all months are emitted and flow across pages.
            //
            //    Period bounds as LocalDate, reused to clip partial first/last months.
            val periodStartDate = LocalDate.parse(firstDate)
            val periodEndExclusive = LocalDate.parse(lastDate).plusDays(1)
            val months = byDate.entries
                .groupBy { it.key.substring(0, 7) } // "YYYY-MM"
                .toSortedMap()
                .map { (monthKey, days) ->
                    val monthStart = LocalDate.parse("$monthKey-01")
                    val monthEndExclusive = monthStart.plusMonths(1)
                    // Number of THIS month's calendar days that actually fall inside the
                    // reporting period [firstDate, lastDate]. For a partial first or last
                    // month (a "started" month) this is fewer than lengthOfMonth(); for a
                    // fully contained month it equals lengthOfMonth(). Dividing by this —
                    // rather than by the full calendar-month length — stops the not-yet-
                    // recorded tail of a started month from being silently treated as
                    // abstinent, which previously deflated the g/day figure.
                    val effStart = maxOf(monthStart, periodStartDate)
                    val effEndExclusive = minOf(monthEndExclusive, periodEndExclusive)
                    val effDays = ChronoUnit.DAYS.between(effStart, effEndExclusive)
                        .toInt().coerceAtLeast(1)
                    val mGrams = days.sumOf { it.value.sumOf { e -> e.gramsAlcohol } }
                    val mOver = days.count { AlcoholCalculator.isOverLimit(it.value.sumOf { e -> e.gramsAlcohol }, limitInfo.limitGrams) }
                    MonthStat(
                        monthKey = monthKey,
                        drinkDays = days.size,
                        totalGrams = mGrams,
                        avgPerCalendarDay = mGrams / effDays,
                        daysOverDailyLimit = mOver,
                    )
                }

            // ── Category breakdown (descending by grams). Grouped by enum name; an
            //    unknown / missing drink falls back to OTHER, as before.
            val totalForPct = totalGrams.coerceAtLeast(0.01)
            val catGrams = linkedMapOf<String, Double>()
            entries.forEach { e ->
                val cat = drinkMap[e.drinkId]?.category?.name ?: "OTHER"
                catGrams[cat] = (catGrams[cat] ?: 0.0) + e.gramsAlcohol
            }
            val categories = catGrams.entries
                .sortedByDescending { it.value }
                .map { (name, g) ->
                    CategoryStat(name, g, Math.round(g / totalForPct * 100).toInt())
                }

            // ── Time-of-day pattern: grams of pure alcohol per hour-of-day bucket.
            //    24 fixed buckets (0..23). Each entry's full gram amount is attributed
            //    to the local clock hour at which it was logged. This drives the report's
            //    24-bar chart, which replaced the older "share before / after 17:00" split.
            val hourlyGrams = DoubleArray(24)
            entries.forEach { e ->
                val hour = LocalDateTime
                    .ofInstant(Instant.ofEpochMilli(e.timestampMillis), ZoneId.systemDefault())
                    .hour
                hourlyGrams[hour] += e.gramsAlcohol
            }

            // ── Medians (robust companions to the mean KPIs).
            //    medianPerDay spans EVERY calendar day in the period (abstinent days
            //    contribute 0 g), mirroring avgPerDay's denominator; medianPerDrinkDay
            //    spans only the days that had entries, mirroring avgPerDrinkDay.
            val perDayTotals = buildList {
                var day = periodStartDate
                while (day.isBefore(periodEndExclusive)) {
                    add(byDate[day.toString()]?.sumOf { it.gramsAlcohol } ?: 0.0)
                    day = day.plusDays(1)
                }
            }
            val perDrinkDayTotals = byDate.values.map { es -> es.sumOf { it.gramsAlcohol } }
            val medianPerDay = median(perDayTotals)
            val medianPerDrinkDay = median(perDrinkDayTotals)
            // Drink-days-per-month distribution across the calendar months in the period.
            val drinkDaysPerMonth = months.map { it.drinkDays.toDouble() }
            val avgDrinkDaysPerMonth = if (drinkDaysPerMonth.isNotEmpty()) drinkDaysPerMonth.average() else 0.0
            val medianDrinkDaysPerMonth = median(drinkDaysPerMonth)

            // Peaks. maxPerDay is the single worst day; maxPer7Days is the worst
            // *rolling* 7-consecutive-calendar-day window (mirrors the app's 7-day
            // limit horizon). For a period shorter than 7 days there is no full
            // window, so the whole-period total is used.
            val maxPerDay = perDayTotals.maxOrNull() ?: 0.0
            val maxPer7Days =
                if (perDayTotals.size <= 7) {
                    perDayTotals.sum()
                } else {
                    (0..perDayTotals.size - 7).maxOf { start ->
                        var sum = 0.0
                        for (i in start until start + 7) sum += perDayTotals[i]
                        sum
                    }
                }

            // ── Weekday profile, rotated to start at the locale's first weekday.
            //    The app no longer has a configurable week start, so the column order
            //    follows the device locale (Mon-first in most of Europe, Sun-first in
            //    the US, etc.) via DayResolver.firstDayOfWeekIso().
            val ws = DayResolver.firstDayOfWeekIso()
            val weekdayOrder = (0..6).map { i -> (ws - 1 + i) % 7 + 1 } // ISO 1..7
            val dayTotals = Array(7) { mutableListOf<Double>() }
            byDate.forEach { (dateStr, es) ->
                val col = (LocalDate.parse(dateStr).dayOfWeek.value - ws + 7) % 7 // 0 = week-start
                dayTotals[col].add(es.sumOf { it.gramsAlcohol })
            }
            val weekdayAverages = dayTotals.map { list -> if (list.isEmpty()) null else list.average() }

            // ── Abstinence streaks (shared DayResolver logic).
            //    The anchor is passed to BOTH computations so the tail gap — the
            //    completed dry days since the last recorded drink — is included in
            //    the longest streak exactly as it is in the current streak. The
            //    parameterless legacy call (today = "", tail gap ignored) produced a
            //    report in which "current abstinence" could EXCEED "longest
            //    abstinence" (impossible by definition) whenever the ongoing run was
            //    the longest one — precisely the improving-user case this report is
            //    for — and disagreed with the Statistics screen, against this file's
            //    "identical figures" contract (fixed in the v0.79.0 QA review; see
            //    PdfReportDataTest for the pinning tests). No statsFrom is passed:
            //    the report is scoped to [firstDate, lastDate] and firstDate is by
            //    construction a drink day, so no initial gap can exist here.
            //
            //    STREAK ANCHOR for historical ranges (v0.81.0 QA fix): the export
            //    dialog lets the user pick a range that ended in the past. Anchoring
            //    such a report's streaks at the REAL today counted every day from
            //    the last in-range drink up to now as abstinent — including days
            //    outside the report on which the user did drink — so "current
            //    abstinence" was arbitrarily inflated and "longest abstinence"
            //    could overrun the report period. The anchor is therefore clamped
            //    to the report range: for a range ending before today it is
            //    periodEnd + 1 day, which makes computeCurrentAbstinence count the
            //    completed dry days up to AND INCLUDING the (finished) last report
            //    day — i.e. "abstinence as of the period end". For a range ending
            //    today (the default export) the anchor stays the real logical
            //    today, preserving the in-progress-day semantics and the screen
            //    parity. A null periodEnd keeps the legacy today anchor.
            val allDates = byDate.keys.sorted()
            val today = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
            val streakAnchor = if (periodEnd != null && periodEnd < today) {
                DayResolver.formatDate(DayResolver.parseDate(periodEnd).plusDays(1))
            } else {
                today
            }
            val longest = DayResolver.computeLongestAbstinence(allDates, streakAnchor)
            val current = DayResolver.computeCurrentAbstinence(allDates, streakAnchor)

            // Time-axis consumption series for the report chart. The span is the
            // recorded range [firstDate, lastDate]; granularity scales with its
            // length (daily → weekly → monthly) so the bar count stays readable.
            val chartGranularity = ChartBucketing.granularityForSpan(totalDays)
            val chartBuckets = ChartBucketing.bucketize(daySummaries, firstDate, lastDate, chartGranularity)

            return PdfReportData(
                firstDate = firstDate,
                lastDate = lastDate,
                totalDays = totalDays,
                limitInfo = limitInfo,
                weightKg = settings.weightKg,
                totalGrams = totalGrams,
                avgPerDay = avgPerDay,
                avgPerDrinkDay = avgPerDrink,
                drinkDays = drinkDays,
                abstinentDays = abstinentDays,
                violations = violations,
                bingeDays = bingeDays,
                medianPerDay = medianPerDay,
                medianPerDrinkDay = medianPerDrinkDay,
                avgDrinkDaysPerMonth = avgDrinkDaysPerMonth,
                medianDrinkDaysPerMonth = medianDrinkDaysPerMonth,
                maxPerDay = maxPerDay,
                maxPer7Days = maxPer7Days,
                months = months,
                chartBuckets = chartBuckets,
                chartGranularity = chartGranularity,
                categories = categories,
                hourlyGrams = hourlyGrams.toList(),
                weekdayOrder = weekdayOrder,
                weekdayAverages = weekdayAverages,
                longestAbstinence = longest,
                currentAbstinence = current,
            )
        }

        /**
         * Median (50th percentile) of [values]; 0.0 for an empty list. For an even
         * count it is the mean of the two central values. The input list is copied
         * and sorted, so the caller's list is left untouched.
         */
        private fun median(values: List<Double>): Double {
            if (values.isEmpty()) return 0.0
            val sorted = values.sorted()
            val mid = sorted.size / 2
            return if (sorted.size % 2 == 1) {
                sorted[mid]
            } else {
                (sorted[mid - 1] + sorted[mid]) / 2.0
            }
        }
    }
}
