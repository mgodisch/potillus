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
package de.godisch.potillus.util

import de.godisch.potillus.domain.AlcoholCalculator
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
    val daysOverDailyLimit: Int
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
    val percent: Int
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

    // ── Monthly breakdown & trend ──────────────────────────────────────────────
    /** Ascending by [MonthStat.monthKey]. The trend chart is shown only when ≥ 2. */
    val months: List<MonthStat>,

    // ── Category breakdown ──────────────────────────────────────────────────────
    /** Descending by grams. */
    val categories: List<CategoryStat>,

    // ── Time-of-day pattern ─────────────────────────────────────────────────────
    val avgFirstDrinkHour: Double,
    val avgLastDrinkHour: Double,
    val percentBefore17: Int,
    val percentAfter17: Int,

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
    val currentAbstinence: Int
) {
    companion object {

        /** Daily-life convenience: the binge threshold lives on AlcoholCalculator. */
        val bingeThreshold: Double get() = AlcoholCalculator.BINGE_THRESHOLD

        /**
         * Computes the full report dataset for [entries] in the chosen period.
         *
         * @param entries  Consumption entries for the (inclusive) date range. Must be
         *                 non-empty; the caller checks this before calling.
         * @param drinks   Drink catalogue, used to map each entry to its category.
         * @param settings Current limits, weight and day-change configuration.
         * @return A fully computed [PdfReportData].
         */
        fun from(
            entries: List<ConsumptionEntry>,
            drinks: List<DrinkDefinition>,
            settings: AppSettings
        ): PdfReportData {
            val drinkMap = drinks.associateBy { it.id }

            // Group once; reused for every per-day / per-month aggregate below.
            val byDate = entries.groupBy { it.logicalDate }

            val firstDate = entries.minOf { it.logicalDate }
            val lastDate  = entries.maxOf { it.logicalDate }
            val limitInfo = AlcoholCalculator.getLimitInfo(settings)

            // Calendar span of the period (inclusive), used for averages and abstinent days.
            val totalDays = LocalDate.parse(firstDate)
                .datesUntil(LocalDate.parse(lastDate).plusDays(1))
                .count().toInt()

            val drinkDays     = byDate.size
            val abstinentDays = (totalDays - drinkDays).coerceAtLeast(0)
            val totalGrams    = entries.sumOf { it.gramsAlcohol }
            val avgPerDay     = if (totalDays > 0) totalGrams / totalDays else 0.0
            val avgPerDrink   = if (drinkDays > 0) totalGrams / drinkDays else 0.0

            // Shared limit-violation counter → identical figures to the Statistics screen.
            val daySummaries = byDate.map { (date, es) ->
                DaySummary(date, es.sumOf { it.gramsAlcohol }, es.size)
            }
            val violations = AlcoholCalculator.countLimitViolations(
                summaries           = daySummaries,
                dailyLimitGrams     = limitInfo.limitGrams,
                weeklyLimitGrams    = limitInfo.weeklyLimitGrams,
                maxDrinkDaysPerWeek = limitInfo.maxDrinkDaysPerWeek
            )
            val binge     = AlcoholCalculator.BINGE_THRESHOLD
            val bingeDays = byDate.count { (_, es) -> es.sumOf { it.gramsAlcohol } > binge }

            // ── Monthly aggregates (ascending). Unlike the old canvas exporter we do
            //    NOT truncate to a row budget here: the HTML report paginates
            //    automatically, so all months are emitted and flow across pages.
            val months = byDate.entries
                .groupBy { it.key.substring(0, 7) }   // "YYYY-MM"
                .toSortedMap()
                .map { (monthKey, days) ->
                    val mDate  = LocalDate.parse("$monthKey-01")
                    val mDays  = mDate.lengthOfMonth()
                    val mGrams = days.sumOf { it.value.sumOf { e -> e.gramsAlcohol } }
                    val mOver  = days.count { it.value.sumOf { e -> e.gramsAlcohol } > limitInfo.limitGrams }
                    MonthStat(
                        monthKey            = monthKey,
                        drinkDays           = days.size,
                        totalGrams          = mGrams,
                        avgPerCalendarDay   = mGrams / mDays,
                        daysOverDailyLimit  = mOver
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

            // ── Time-of-day pattern.
            val times = entries.map { e ->
                val ldt = LocalDateTime.ofInstant(Instant.ofEpochMilli(e.timestampMillis), ZoneId.systemDefault())
                ldt.hour + ldt.minute / 60.0
            }
            val firstTs = byDate.mapValues { (_, es) -> es.minOf { it.timestampMillis } }
            val lastTs  = byDate.mapValues { (_, es) -> es.maxOf { it.timestampMillis } }
            val avgFirst = if (firstTs.isNotEmpty()) firstTs.values.map(::tsToHour).average() else 0.0
            val avgLast  = if (lastTs.isNotEmpty())  lastTs.values.map(::tsToHour).average()  else 0.0
            val pctBefore17 = if (times.isNotEmpty())
                Math.round(times.count { it < 17.0 }.toDouble() / times.size * 100).toInt() else 0
            val pctAfter17 = 100 - pctBefore17

            // ── Weekday profile, rotated to start at the locale's first weekday.
            //    The app no longer has a configurable week start, so the column order
            //    follows the device locale (Mon-first in most of Europe, Sun-first in
            //    the US, etc.) via DayResolver.firstDayOfWeekIso().
            val ws = DayResolver.firstDayOfWeekIso()
            val weekdayOrder = (0..6).map { i -> (ws - 1 + i) % 7 + 1 }   // ISO 1..7
            val dayTotals = Array(7) { mutableListOf<Double>() }
            byDate.forEach { (dateStr, es) ->
                val col = (LocalDate.parse(dateStr).dayOfWeek.value - ws + 7) % 7  // 0 = week-start
                dayTotals[col].add(es.sumOf { it.gramsAlcohol })
            }
            val weekdayAverages = dayTotals.map { list -> if (list.isEmpty()) null else list.average() }

            // ── Abstinence streaks (shared DayResolver logic).
            val allDates = byDate.keys.sorted()
            val today    = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
            val longest  = DayResolver.computeLongestAbstinence(allDates)
            val current  = DayResolver.computeCurrentAbstinence(allDates, today)

            return PdfReportData(
                firstDate         = firstDate,
                lastDate          = lastDate,
                totalDays         = totalDays,
                limitInfo         = limitInfo,
                weightKg          = settings.weightKg,
                totalGrams        = totalGrams,
                avgPerDay         = avgPerDay,
                avgPerDrinkDay    = avgPerDrink,
                drinkDays         = drinkDays,
                abstinentDays     = abstinentDays,
                violations        = violations,
                bingeDays         = bingeDays,
                months            = months,
                categories        = categories,
                avgFirstDrinkHour = avgFirst,
                avgLastDrinkHour  = avgLast,
                percentBefore17   = pctBefore17,
                percentAfter17    = pctAfter17,
                weekdayOrder      = weekdayOrder,
                weekdayAverages   = weekdayAverages,
                longestAbstinence = longest,
                currentAbstinence = current
            )
        }

        /** Converts a Unix-ms timestamp to fractional local hours (14:30 → 14.5). */
        private fun tsToHour(ts: Long): Double {
            val ldt = LocalDateTime.ofInstant(Instant.ofEpochMilli(ts), ZoneId.systemDefault())
            return ldt.hour + ldt.minute / 60.0
        }
    }
}
