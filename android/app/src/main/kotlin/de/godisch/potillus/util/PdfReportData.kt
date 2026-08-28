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
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale

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
    /**
     * This month's calendar days INSIDE the reporting period — the divisor behind
     * [avgPerCalendarDay]. Carried rather than recomputed because [MonthRollup]
     * needs it: a summary row's average is the summed grams over the summed days,
     * and averaging the averages of a 31-day and a 3-day month is not that.
     */
    val effectiveDays: Int,
    /**
     * For a summary row, the FIRST month it stands for; `null` for a single month.
     *
     * The report prints the row as a span, `"Jan 2025 – Jun 2025"`, from this and
     * [monthKey]. No new label: both ends go through the month formatter the
     * report already carries.
     */
    val rollupFromKey: String? = null,
)

/**
 * Caps the monthly table, so a report over a long period still fits its sheet.
 *
 * WHY A CAP AT ALL
 *   Sheet one holds the header, the key figures, the trend chart and this table,
 *   and the table was the only part with no upper bound: one row per calendar
 *   month, for however long the period ran. Sheet one has room for roughly eight
 *   more rows than the six a half-year report shows, so a two-year report ran off
 *   the page — and on iOS a report that outgrew its sheets lost the last one
 *   entirely (see ReportPdfPrinter's completeness check).
 *
 * WHAT IT DOES
 *   Keeps the most recent [keeping] months in full and folds everything older
 *   into one summary row at the top. Nothing is dropped: the summary carries the
 *   summed drink days, grams and over-limit days, and an average weighted by the
 *   days each month contributed.
 *
 * WHY NOT WHEN IT WOULD SAVE NOTHING
 *   Folding a single month into a summary row costs a row and buys none, and it
 *   turns a real month into a span of one. With [keeping] + 1 months or fewer the
 *   table is returned unchanged.
 */
object MonthRollup {

    /** Months shown in full. Six is a half year, which is what a reader scans. */
    const val KEEP = 6

    /**
     * Returns [months] with everything older than the last [keeping] folded into a
     * single leading summary row.
     *
     * @param months Ascending by month, as [PdfReportData.from] produces them.
     * @param keeping How many months stay in full. Returned unchanged when there
     *        are [keeping] + 1 or fewer, where a summary would fold one month into
     *        a span of one and cost a row to do it.
     * @return At most [keeping] + 1 rows, still ascending, the summary first.
     */
    fun capped(months: List<MonthStat>, keeping: Int = KEEP): List<MonthStat> {
        if (months.size <= keeping + 1) return months
        val rolled = months.dropLast(keeping)
        val grams = rolled.sumOf { it.totalGrams }
        val days = rolled.sumOf { it.effectiveDays }
        val summary = MonthStat(
            monthKey = rolled.last().monthKey,
            drinkDays = rolled.sumOf { it.drinkDays },
            totalGrams = grams,
            avgPerCalendarDay = if (days > 0) grams / days else 0.0,
            daysOverDailyLimit = rolled.sumOf { it.daysOverDailyLimit },
            effectiveDays = days,
            rollupFromKey = rolled.first().monthKey,
        )
        return listOf(summary) + months.takeLast(keeping)
    }
}

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
    /**
     * Inclusive first day of the reported period, and the one the header prints.
     *
     * The window the caller asked for when it passed both bounds to [from];
     * otherwise the first day that carries an entry. It is not necessarily a day
     * with entries: a period may open on dry days, and they belong in it.
     */
    val firstDate: String,
    /**
     * Inclusive last day of the reported period. Set like [firstDate], except
     * that a window ending on the running day ends on the day before it until
     * that day has seen alcohol — see the reporting-window block in [from].
     */
    val lastDate: String,
    /** Calendar days in `[firstDate, lastDate]`, inclusive. The denominator. */
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
         * @param entries     Consumption entries for the (inclusive) date range. Must be
         *                    non-empty; the caller checks this before calling.
         * @param drinks      Drink catalogue, used to map each entry to its category.
         * @param settings    Current limits, weight and day-change configuration.
         * @param periodStart The user-chosen INCLUSIVE start of the export range
         *                    ("YYYY-MM-DD"), or `null` when the caller has no explicit
         *                    range. Together with [periodEnd] it makes the REPORTED
         *                    PERIOD the window the user asked for instead of the span
         *                    of the entries in it — see the reporting-window block
         *                    below.
         * @param periodEnd   The user-chosen INCLUSIVE end of the export range
         *                    ("YYYY-MM-DD"), or `null` when the caller has no explicit
         *                    range (legacy behaviour: the streaks anchor at the real
         *                    logical today). Anchors the abstinence streaks — see the
         *                    streak block below for why a HISTORICAL range must not
         *                    anchor at today (v0.81.0 QA fix) — and, with
         *                    [periodStart], bounds the reporting window.
         * @return A fully computed [PdfReportData].
         */
        fun from(
            entries: List<ConsumptionEntry>,
            drinks: List<DrinkDefinition>,
            settings: AppSettings,
            periodStart: String? = null,
            periodEnd: String? = null,
            locale: Locale = Locale.getDefault(),
        ): PdfReportData {
            val drinkMap = drinks.associateBy { it.id }

            // Group once; reused for every per-day / per-month aggregate below.
            val byDate = entries.groupBy { it.logicalDate }

            // The real logical day. Needed twice: once by the reporting window
            // immediately below, once by the streak anchor further down.
            val today = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)

            // ── The reporting window ────────────────────────────────────────────
            //
            // WHAT [firstDate, lastDate] MEANS, AND WHY IT IS NOT THE ENTRY SPAN.
            //   Every denominator in this file — totalDays, abstinentDays, the
            //   per-day series behind the medians and the rolling peak, the clipped
            //   first/last month, the chart's time axis — is derived from these two
            //   dates, and the report prints them as its period. Deriving them from
            //   the entries answered a question nobody asked: someone who exports
            //   July and drank from the 10th to the 20th got a report over 11 days,
            //   with no abstinent days and a g/day figure divided by 11, while the
            //   Statistics screen divided the same July by 31. The export dialog
            //   knows the window; it just never reached the arithmetic.
            //
            //   The window therefore applies when the caller passes BOTH bounds.
            //   A caller that passes neither (or only periodEnd, as the historical
            //   streak anchor did before this) keeps the entry span, so the shared
            //   vectors and every legacy call read exactly as they did.
            //
            // THE LAST DAY. A window ending today ends on a day that is still
            //   running, and an unfinished day must not be divided by: it would
            //   deflate the average and be counted as abstinent before it has had
            //   the chance to become anything. This is the same rule
            //   [DayResolver.windowDays] applies for the Statistics screen — a day
            //   that has already seen alcohol counts, an empty one waits — so the
            //   report and the screen agree about today. Expressed here as a date
            //   rather than a count, because the aggregates need a bound, not a
            //   length; the two are pinned against each other in PdfReportDataTest.
            val firstDate: String
            val lastDate: String
            if (periodStart != null && periodEnd != null) {
                val todayIsDrinkDay = periodEnd == today &&
                    AlcoholCalculator.isDrinkDay(byDate[periodEnd]?.sumOf { it.gramsAlcohol } ?: 0.0)
                val windowEnd = if (periodEnd == today && !todayIsDrinkDay) {
                    DayResolver.formatDate(DayResolver.parseDate(periodEnd).minusDays(1))
                } else {
                    periodEnd
                }
                firstDate = periodStart
                // Dropping the unfinished day can empty a window that the user did
                // pick — exporting "today only" before the first drink of the day.
                // A report over zero days states nothing, so the raw window stands
                // in that one case and the running day is reported as it is.
                lastDate = if (windowEnd < periodStart) periodEnd else windowEnd
            } else {
                firstDate = entries.minOf { it.logicalDate }
                lastDate = entries.maxOf { it.logicalDate }
            }
            val limitInfo = AlcoholCalculator.getLimitInfo(settings)

            // Calendar span of the period (inclusive), used for averages and abstinent days.
            val totalDays = LocalDate.parse(firstDate)
                .datesUntil(LocalDate.parse(lastDate).plusDays(1))
                .count().toInt()

            // One summary per recorded day, built before every figure that rests on
            // it. Shared with the limit-violation counter → identical figures to the
            // Statistics screen.
            val daySummaries = byDate.map { (date, es) ->
                DaySummary(date, es.sumOf { it.gramsAlcohol }, es.size)
            }
            // The days that saw alcohol. A day of alcohol-free drinks has a summary
            // row and belongs to the reporting period, but it is not a drink day:
            // it counts as abstinent, it is not in the drink-day divisor, and it
            // does not interrupt a streak (AlcoholCalculator.isDrinkDay).
            val drinkDates = AlcoholCalculator.drinkDates(daySummaries)

            val drinkDays = drinkDates.size
            val abstinentDays = (totalDays - drinkDays).coerceAtLeast(0)
            val totalGrams = entries.sumOf { it.gramsAlcohol }
            val avgPerDay = if (totalDays > 0) totalGrams / totalDays else 0.0
            val avgPerDrink = if (drinkDays > 0) totalGrams / drinkDays else 0.0
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
            //    EVERY month the period touches gets a row, including the ones that
            //    saw no drinking. Listing only the months with entries left a table
            //    whose rows did not add up to the period above it — a reader of a
            //    January-to-June report that skips April cannot tell an abstinent
            //    month from a missing one, and the abstinent days in the KPIs
            //    counted April all along. A dry month is a statement in its own
            //    right, and in a report meant for a conversation it is often the
            //    statement that matters.
            //
            //    Period bounds as LocalDate, reused to clip partial first/last months.
            val periodStartDate = LocalDate.parse(firstDate)
            val periodEndExclusive = LocalDate.parse(lastDate).plusDays(1)
            val byMonth = byDate.entries.groupBy { it.key.substring(0, 7) } // "YYYY-MM"
            val monthKeys = generateSequence(periodStartDate.withDayOfMonth(1)) { month ->
                month.plusMonths(1).takeIf { it.isBefore(periodEndExclusive) }
            }.map { it.toString().substring(0, 7) }.toList()
            val months = monthKeys
                .map { monthKey ->
                    val days = byMonth[monthKey].orEmpty()
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
                        drinkDays = days.count { (_, es) ->
                            AlcoholCalculator.isDrinkDay(es.sumOf { e -> e.gramsAlcohol })
                        },
                        totalGrams = mGrams,
                        avgPerCalendarDay = mGrams / effDays,
                        daysOverDailyLimit = mOver,
                        effectiveDays = effDays,
                    )
                }
                .let { MonthRollup.capped(it) }

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
                // The hour the drink was logged at, in the frame it was logged
                // in. Reading it in the CURRENT device frame moved every bar of
                // a travelled or daylight-saving-crossed history by an hour.
                val hour = DayResolver.localDateTime(e.timestampMillis, e.utcOffsetSeconds).hour
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
            // Drink days only: a 0.0 g day in this list would pull the median of the
            // drinking down to a figure no drinking day produced.
            val perDrinkDayTotals = daySummaries
                .filter { AlcoholCalculator.isDrinkDay(it.totalGrams) }
                .map { it.totalGrams }
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
            //    The app has no configurable week start, so the column order follows
            //    the REPORT's locale (Mon-first in most of Europe, Sun-first in the
            //    US) — the same locale PdfReportBuilder uses for the column NAMES.
            //    Reading the device default here instead put Sunday-first columns
            //    under Greek and Russian headings in the 0.84.0 store assets, and
            //    would do the same for anyone whose device language differs from the
            //    language they picked in the app. iOS passes its report locale the
            //    same way (ReportData.swift: `firstDayOfWeekIso(locale: locale)`).
            val ws = DayResolver.firstDayOfWeekIso(locale)
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
            //    the report is scoped to [firstDate, lastDate], and the streaks run
            //    over the DRINK days in it. When the period opens on a day of
            //    alcohol-free entries, the dry run before the first drink is left
            //    uncounted rather than measured from a start the user never declared
            //    — the conservative reading, and the one the parameterless call has
            //    always given.
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
            //
            //    The anchor and the reporting window read the same periodEnd but
            //    ask different things of it. The window asks whether the last day
            //    is FINISHED, and drops it while it is not. The anchor asks whether
            //    the report ends in the PAST, and clamps the streaks to the period
            //    when it does. A range ending today therefore keeps the real-today
            //    anchor while the window may already have dropped that day: the
            //    streaks still count only completed dry days, so both readings
            //    agree on what a finished day is.
            val streakAnchor = if (periodEnd != null && periodEnd < today) {
                DayResolver.formatDate(DayResolver.parseDate(periodEnd).plusDays(1))
            } else {
                today
            }
            val longest = DayResolver.computeLongestAbstinence(drinkDates, streakAnchor)
            val current = DayResolver.computeCurrentAbstinence(drinkDates, streakAnchor)

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
