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

import android.content.Context
import de.godisch.potillus.R
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

// =============================================================================
// PdfReportBuilder – turns report DATA into report HTML
// =============================================================================
//
// This is the bridge between the three layers of the v0.61.0 PDF redesign:
//
//     PdfReportData.from(...)        →  WHAT the report says (pure numbers)
//     PdfReportBuilder.buildHtml(...) →  HOW it reads: labels + formatting + HTML
//     WebViewPdfPrinter.print(...)    →  HOW it becomes a PDF (system print dialog)
//
// buildHtml() does three things and nothing else:
//   1. Resolve every localised LABEL via Android string resources (so the report
//      respects the user's language) and FORMAT every number for display.
//   2. Pack those strings into the scalar and repeat-row maps that the HTML
//      template expects (the placeholder/​block contract is documented inside
//      assets/report_template.html).
//   3. Load that template from the APK assets and expand it with SimpleTemplate.
//
// It performs NO drawing and NO file/printer I/O, so it stays free of Canvas and
// WebView and is cheap to reason about. The arithmetic lives entirely in
// PdfReportData; this file never recomputes a statistic.
// =============================================================================

object PdfReportBuilder {

    /** Asset path of the editable report layout (see that file's header for the contract). */
    private const val TEMPLATE_ASSET = "report_template.html"

    // Formatters use the default locale so dates/months match the rest of the app.
    private val DATE_FMT     = DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT).withLocale(Locale.getDefault())
    private val MONTH_FMT    = DateTimeFormatter.ofPattern("MMM yyyy", Locale.getDefault())
    private val JOBNAME_FMT  = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm").withZone(ZoneId.systemDefault())

    /**
     * Builds a job/file name for the report, e.g. `potillus_report_20260603_1430`.
     * Used as the print-job name; print services derive the saved PDF's file name
     * from it. Capture [Instant.now] once so name and content share a timestamp.
     */
    fun jobName(now: Instant = Instant.now()): String =
        "potillus_report_${JOBNAME_FMT.format(now)}"

    /**
     * Renders the full two-page report as a self-contained HTML string.
     *
     * @param context  Context for asset loading and string-resource localisation.
     * @param entries  Consumption entries for the period (must be non-empty).
     * @param drinks   Drink catalogue for category look-ups.
     * @param settings Current user preferences (limits, weight, week start, …).
     * @return Complete HTML ready to be loaded into a WebView for printing.
     */
    fun buildHtml(
        context: Context,
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>,
        settings: AppSettings
    ): String {
        val d = PdfReportData.from(entries, drinks, settings)

        val scalars = HashMap<String, String>()
        val repeats = HashMap<String, List<Map<String, String>>>()

        // ── Header & footers ──────────────────────────────────────────────────
        scalars["TITLE"]      = context.getString(R.string.pdf_title)
        scalars["FOOTER1"]    = context.getString(R.string.pdf_footer1)
        scalars["FOOTER2"]    = context.getString(R.string.pdf_footer2)
        scalars["GPL_FOOTER"] = GplNotice.PDF_FOOTER

        // ── Section titles ─────────────────────────────────────────────────────
        scalars["SECTION_KPIS"]       = context.getString(R.string.pdf_section_kpis)
        scalars["SECTION_MONTHS"]     = context.getString(R.string.pdf_section_months)
        scalars["SECTION_TREND"]      = context.getString(R.string.pdf_section_trend)
        scalars["SECTION_CATEGORIES"] = context.getString(R.string.pdf_section_categories)
        scalars["SECTION_DAYTIME"]    = context.getString(R.string.pdf_section_daytime)
        scalars["SECTION_WEEKDAY"]    = context.getString(R.string.pdf_section_weekday)
        scalars["SECTION_RISK"]       = context.getString(R.string.pdf_section_risk)

        // ── Metadata block (page 1) ─────────────────────────────────────────────
        val perDay  = context.getString(R.string.pdf_unit_g_per_day)
        val perWeek = context.getString(R.string.pdf_unit_g_per_week)
        scalars["META_EXPORT_LABEL"] = context.getString(R.string.pdf_meta_export_date)
        scalars["META_EXPORT_VALUE"] = LocalDate.now().format(DATE_FMT)
        scalars["META_PERIOD_LABEL"] = context.getString(R.string.pdf_meta_period)
        scalars["META_PERIOD_VALUE"] =
            "${LocalDate.parse(d.firstDate).format(DATE_FMT)} – ${LocalDate.parse(d.lastDate).format(DATE_FMT)}"
        scalars["META_LIMIT_LABEL"]  = context.getString(R.string.pdf_meta_limit)
        scalars["META_LIMIT_VALUE"]  =
            "${d.limitInfo.limitGrams.fmt1()} $perDay · ${d.limitInfo.weeklyLimitGrams.fmt1()} $perWeek · " +
            "${d.limitInfo.maxDrinkDaysPerWeek} ${context.getString(R.string.pdf_meta_drink_days_suffix)}"
        scalars["META_WEIGHT_LABEL"] = context.getString(R.string.pdf_meta_weight)
        scalars["META_WEIGHT_VALUE"] = if (d.weightKg > 0) "${d.weightKg.fmt1()} kg" else "–"

        // ── KPI tiles ────────────────────────────────────────────────────────────
        // Order and warn flags reproduce the original report exactly.
        repeats["KPIS"] = listOf(
            kpi(context.getString(R.string.pdf_kpi_total),         "${d.totalGrams.fmt1()} g"),
            kpi(context.getString(R.string.pdf_kpi_avg_day),       "${d.avgPerDay.fmt1()} g"),
            kpi(context.getString(R.string.pdf_kpi_avg_drink_day), "${d.avgPerDrinkDay.fmt1()} g"),
            kpi(context.getString(R.string.pdf_kpi_drink_days),    "${d.drinkDays}"),
            kpi(context.getString(R.string.pdf_kpi_abstinent_days),"${d.abstinentDays}"),
            kpi(context.getString(R.string.pdf_kpi_over_daily, d.limitInfo.limitGrams.fmt0()),
                "${d.violations.daysOverDailyLimit}", d.violations.daysOverDailyLimit > 0),
            kpi(context.getString(R.string.pdf_kpi_over_weekly, d.limitInfo.weeklyLimitGrams.fmt0()),
                "${d.violations.daysOverWeeklyLimit}", d.violations.daysOverWeeklyLimit > 0),
            kpi(context.getString(R.string.pdf_kpi_over_drink_days, d.limitInfo.maxDrinkDaysPerWeek),
                "${d.violations.daysOverDrinkDayLimit}", d.violations.daysOverDrinkDayLimit > 0),
            kpi(context.getString(R.string.pdf_kpi_binge, PdfReportData.bingeThreshold.fmt0()),
                "${d.bingeDays}", d.bingeDays > 0)
        )

        // ── Monthly table ──────────────────────────────────────────────────────
        scalars["COL_MONTH"]      = context.getString(R.string.pdf_col_month)
        scalars["COL_DRINK_DAYS"] = context.getString(R.string.pdf_col_drink_days)
        scalars["COL_TOTAL_G"]    = context.getString(R.string.pdf_col_total_g)
        scalars["COL_AVG_G_DAY"]  = context.getString(R.string.pdf_col_avg_g_day)
        scalars["COL_OVER_DAILY"] = context.getString(R.string.pdf_col_over_daily)
        repeats["MONTHS"] = d.months.map { m ->
            mapOf(
                "M_MONTH"      to LocalDate.parse("${m.monthKey}-01").format(MONTH_FMT),
                "M_DRINK_DAYS" to "${m.drinkDays}",
                "M_TOTAL"      to m.totalGrams.fmt1(),
                "M_AVG"        to m.avgPerCalendarDay.fmt1(),
                "M_OVER"       to if (m.daysOverDailyLimit > 0) "${m.daysOverDailyLimit}" else "–",
                "M_ROW_CLASS"  to if (m.daysOverDailyLimit > 0) "warn" else ""
            )
        }

        // ── Trend bar chart (only with ≥ 2 months) ──────────────────────────────
        val showTrend = d.months.size >= 2
        scalars["TREND_DISPLAY"] = if (showTrend) "block" else "none"
        if (showTrend) {
            val limit  = d.limitInfo.limitGrams
            val maxAvg = d.months.maxOf { it.avgPerCalendarDay }
            // Headroom of 10% so the tallest bar / limit line never touches the top.
            val maxVal = maxOf(maxAvg, limit) * 1.1
            scalars["LIMIT_LINE_PCT"] = pct(limit, maxVal).fmt0()
            repeats["BARS"] = d.months.map { m ->
                mapOf(
                    // "YYYY-MM" → "MM.YY" (e.g. 2026-01 → "01.26")
                    "BAR_LABEL"      to "${m.monthKey.substring(5, 7)}.${m.monthKey.substring(2, 4)}",
                    "BAR_HEIGHT_PCT" to pct(m.avgPerCalendarDay, maxVal).coerceAtLeast(2.0).fmt0(),
                    "BAR_CLASS"      to if (m.avgPerCalendarDay > limit) "bar over" else "bar"
                )
            }
        } else {
            repeats["BARS"] = emptyList()
        }

        // ── Category table ───────────────────────────────────────────────────────
        scalars["CAT_HEAD_NAME"] = context.getString(R.string.category)
        scalars["CAT_HEAD_G"]    = "g"
        scalars["CAT_HEAD_PCT"]  = "%"
        repeats["CATEGORIES"] = d.categories.map { c ->
            mapOf(
                "C_NAME" to categoryLabel(context, c.categoryName),
                "C_G"    to c.grams.fmt1(),
                "C_PCT"  to "${c.percent} %"
            )
        }

        // ── Time-of-day pattern ────────────────────────────────────────────────
        scalars["DT_FIRST_LABEL"]  = context.getString(R.string.pdf_meta_first_drink)
        scalars["DT_FIRST_VALUE"]  = hourToStr(d.avgFirstDrinkHour)
        scalars["DT_LAST_LABEL"]   = context.getString(R.string.pdf_meta_last_drink)
        scalars["DT_LAST_VALUE"]   = hourToStr(d.avgLastDrinkHour)
        scalars["DT_BEFORE_LABEL"] = context.getString(R.string.pdf_meta_before_18)
        scalars["DT_BEFORE_VALUE"] = "${d.percentBefore17} %"
        scalars["DT_AFTER_LABEL"]  = context.getString(R.string.pdf_meta_after_18)
        scalars["DT_AFTER_VALUE"]  = "${d.percentAfter17} %"

        // ── Weekday profile ────────────────────────────────────────────────────
        repeats["WEEKDAY_HEAD"] = d.weekdayOrder.map { iso ->
            mapOf("WD_NAME" to DayOfWeek.of(iso)
                .getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(2))
        }
        repeats["WEEKDAY_VAL"] = d.weekdayAverages.map { avg ->
            mapOf("WD_VALUE" to (avg?.fmt1() ?: "–"))
        }

        // ── Binge & abstinence streaks ───────────────────────────────────────────
        val daysSuffix = context.getString(R.string.pdf_days_suffix)
        scalars["RISK_BINGE_LABEL"]   = context.getString(R.string.pdf_meta_binge_days, PdfReportData.bingeThreshold.fmt0())
        scalars["RISK_BINGE_VALUE"]   = "${d.bingeDays}"
        scalars["RISK_LONGEST_LABEL"] = context.getString(R.string.pdf_meta_longest_abstinence)
        scalars["RISK_LONGEST_VALUE"] = "${d.longestAbstinence} $daysSuffix"
        scalars["RISK_CURRENT_LABEL"] = context.getString(R.string.pdf_meta_current_abstinence)
        scalars["RISK_CURRENT_VALUE"] = "${d.currentAbstinence} $daysSuffix"

        val template = context.assets.open(TEMPLATE_ASSET).bufferedReader().use { it.readText() }
        return SimpleTemplate.render(template, scalars, repeats)
    }

    // ── small presentation helpers ───────────────────────────────────────────────

    /** Builds one KPI tile row for the KPIS repeat block. */
    private fun kpi(label: String, value: String, warn: Boolean = false): Map<String, String> =
        mapOf("KPI_LABEL" to label, "KPI_VALUE" to value, "KPI_CLASS" to if (warn) "kpi warn" else "kpi")

    /** Maps a [de.godisch.potillus.domain.model.DrinkCategory] enum name to its localised label. */
    private fun categoryLabel(context: Context, name: String): String = context.getString(
        when (name) {
            "BEER"      -> R.string.category_beer
            "WINE"      -> R.string.category_wine
            "SPIRITS"   -> R.string.category_spirits
            "LONGDRINK" -> R.string.category_longdrink
            "LIQUEUR"   -> R.string.category_liqueur
            else        -> R.string.category_other
        }
    )

    /** Percentage of [value] relative to [max] (0 when [max] is non-positive). */
    private fun pct(value: Double, max: Double): Double = if (max > 0) value / max * 100.0 else 0.0

    /** Formats fractional hours as "HH:MM" (14.5 → "14:30"). */
    private fun hourToStr(h: Double): String {
        val hh = h.toInt()
        val mm = Math.round((h - hh) * 60).toInt()
        return "%02d:%02d".format(hh, mm)
    }

    /** One-decimal display formatting (default locale, matching the rest of the app). */
    private fun Double.fmt1() = "%.1f".format(this)

    /** Zero-decimal display formatting. */
    private fun Double.fmt0() = "%.0f".format(this)
}
