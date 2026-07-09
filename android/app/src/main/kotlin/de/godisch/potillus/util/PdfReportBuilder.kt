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
package de.godisch.potillus.util

import android.content.Context
import android.os.Build
import de.godisch.potillus.BuildConfig
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.ChartBucket
import de.godisch.potillus.domain.ChartGranularity
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.l10n.fmt0
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.l10n.monthYearFormatter
import de.godisch.potillus.l10n.shortDayMonthPattern
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import kotlin.math.roundToInt

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

    // Formatters that produce user-visible, locale-sensitive text (long dates,
    // month+year labels) must follow the PER-APP locale, not the system
    // locale. They are therefore NOT created here as object-level fields: an
    // object field is initialised once at class load and would freeze whatever
    // locale happened to be active then — and it could only ever capture
    // Locale.getDefault() (the system locale) anyway. Instead buildHtml() derives
    // the locale from its Context (see formattingLocale()) and builds these
    // formatters per call. Only the locale-INDEPENDENT job-name formatter (a
    // purely numeric timestamp pattern) is safe to keep as a shared constant.
    private val JOBNAME_FMT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm").withZone(ZoneId.systemDefault())

    /**
     * Builds a job/file name for the report, e.g. `potillus_report_20260603_1430.pdf`.
     *
     * Used as the print-job name; print services derive the saved PDF's file name
     * from it. Capture [Instant.now] once so name and content share a timestamp.
     *
     * WHY THE EXPLICIT `.pdf` SUFFIX?
     *   The Android print framework offers the job name verbatim as the default
     *   file name in the system "Save as PDF" dialog. Without an extension the
     *   dialog showed a bare name (e.g. `potillus_report_20260603_1430`), which
     *   looked unfinished and hid the file type from the user. Appending `.pdf`
     *   makes the dialog pre-fill a complete, recognisable file name.
     */
    fun jobName(now: Instant = Instant.now()): String = "potillus_report_${JOBNAME_FMT.format(now)}.pdf"

    /**
     * Renders the full two-page report as a self-contained HTML string.
     *
     * @param context   Context for asset loading and string-resource localisation.
     * @param entries   Consumption entries for the period (must be non-empty).
     * @param drinks    Drink catalogue for category look-ups.
     * @param settings  Current user preferences (limits, weight, week start, …).
     * @param periodEnd The user-chosen inclusive end of the export range
     *                  ("YYYY-MM-DD"), or `null` when no explicit range exists.
     *                  Forwarded to [PdfReportData.from], which uses it to anchor
     *                  the abstinence streaks so a HISTORICAL report does not
     *                  count post-period days as abstinent (v0.81.0 QA fix; see
     *                  the streak block there).
     * @return Complete HTML ready to be loaded into a WebView for printing.
     */
    fun buildHtml(
        context: Context,
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>,
        settings: AppSettings,
        periodEnd: String? = null,
    ): String {
        val d = PdfReportData.from(entries, drinks, settings, periodEnd)

        // Locale for all value formatting in this report. We take it from the
        // Context (which already reflects the per-app language, exactly like the
        // string resources resolved below) rather than from Locale.getDefault(),
        // so the formatted dates/months agree with their localized labels. The
        // two locale-sensitive formatters are built here, once per report.
        val locale = context.formattingLocale()
        val dateFmt = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)
        // monthYearFormatter (NOT a literal "MMM yyyy"): CJK reports need the
        // year-first order ("2026年6月") and inflected languages the standalone
        // month form — both are CLDR data, see l10n/LocaleSupport.kt.
        val monthFmt = monthYearFormatter(locale, abbreviated = true)
        // Compact day+month formatter for the chart's x-axis tick labels. The
        // pattern is DERIVED from the locale (day/month order and separator, see
        // l10n/DatePatterns.kt) instead of the previously hard-coded European
        // "d.M." — which showed "28.6" even in en-US/ja/zh reports.
        val dayMonthFmt = DateTimeFormatter.ofPattern(shortDayMonthPattern(locale), locale)

        // Locale-bound number formatters for this report. Every formatted number
        // below must use the SAME per-app `locale` as the dates/months above,
        // otherwise the decimal separator would silently follow the *system*
        // locale (see l10n/NumberFormat.kt for the pitfall). These zero-argument
        // local shims capture `locale` and delegate to the shared l10n helpers
        // (`Double.fmt1(Locale)` / `Double.fmt0(Locale)`), so the many call sites
        // below stay terse — `x.fmt1()` — while remaining locale-correct. The
        // arity differs from the shared helpers, so `this.fmt1(locale)` resolves
        // unambiguously to the imported one (no recursion).
        /** One-decimal display formatting in this report's per-app [locale]. */
        fun Double.fmt1(): String = this.fmt1(locale)

        /** Zero-decimal display formatting in this report's per-app [locale]. */
        fun Double.fmt0(): String = this.fmt0(locale)

        val scalars = HashMap<String, String>()
        val repeats = HashMap<String, List<Map<String, String>>>()

        // ── Document language (CJK glyph-orthography hint) ────────────────────
        // Fills the template's root <html lang="{{REPORT_LANG}}"> with this
        // report's BCP-47 tag. WHY THIS MATTERS: the report is rendered by a
        // WebView (Blink), whose CJK font fallback picks the glyph ORTHOGRAPHY
        // (Simplified vs Traditional Han, Japanese kanji, Korean hanja) from the
        // document language. Han-unified code points are shared across zh/ja/ko
        // but prefer region-specific glyph shapes; with no lang hint Blink
        // defaults to Simplified-Chinese forms, so a Japanese, Korean or
        // Traditional-Chinese report would render Chinese-style glyphs for those
        // shared characters. Emitting the per-app locale here pins the correct
        // orthography deterministically, on every device. This uses the SAME
        // per-app `locale` (never Locale.getDefault()) as every date/number/label
        // formatter in this report, so the glyph forms agree with the text; Latin
        // locales are unaffected. `toLanguageTag()` yields exactly the BCP-47
        // form Blink expects (e.g. "zh-TW", "ja", "en-US").
        scalars["REPORT_LANG"] = locale.toLanguageTag()

        // ── Header & footers ──────────────────────────────────────────────────
        scalars["TITLE"] = context.getString(R.string.pdf_title)
        scalars["FOOTER1"] = context.getString(R.string.pdf_footer1)
        // Footer 2 is intentionally English-only (never localised) and now also
        // carries the GPL / no-warranty notice that used to be a separate running
        // footer (GPL_FOOTER), which has been removed. The version is shortened to
        // MAJOR.MINOR.PATCH — the debug build's "-debug" suffix is stripped — so the
        // printed line reads cleanly regardless of build type.
        val appVersion = BuildConfig.VERSION_NAME.substringBefore("-")
        // Build.VERSION.RELEASE is the user-facing Android version string (e.g. "14").
        // On the rare device where it is null/blank we fall back to the numeric API
        // level so the footer never shows an empty version.
        val androidVersion = Build.VERSION.RELEASE?.takeIf { it.isNotBlank() }
            ?: Build.VERSION.SDK_INT.toString()
        // DELIBERATELY NOT LOCALIZED: this is the report's licence/warranty
        // notice. Like the bundled COPYING/LICENSE documents (see the Makefile
        // note on raw/copyright.md), legal boilerplate is kept in its original
        // English so its meaning never depends on translation quality; the GPL's
        // warranty disclaimer in particular is quoted, not paraphrased.
        scalars["FOOTER2"] = "Created with Libellus Potionis v$appVersion on Android $androidVersion, " +
            "free software under the GNU GPL v3, WITHOUT ANY WARRANTY."

        // ── Section titles ─────────────────────────────────────────────────────
        scalars["SECTION_KPIS"] = context.getString(R.string.pdf_section_kpis)
        scalars["SECTION_MONTHS"] = context.getString(R.string.pdf_section_months)
        scalars["SECTION_TREND"] = context.getString(R.string.pdf_section_trend)
        scalars["SECTION_CATEGORIES"] = context.getString(R.string.pdf_section_categories)
        scalars["SECTION_DAYTIME"] = context.getString(R.string.pdf_section_daytime)
        scalars["SECTION_WEEKDAY"] = context.getString(R.string.pdf_section_weekday)
        scalars["SECTION_RISK"] = context.getString(R.string.pdf_section_risk)

        // ── Metadata block (page 1) ─────────────────────────────────────────────
        val perDay = context.getString(R.string.pdf_unit_g_per_day)
        val perWeek = context.getString(R.string.pdf_unit_g_per_week)
        scalars["META_EXPORT_LABEL"] = context.getString(R.string.pdf_meta_export_date)
        // Read through DayResolver.clock() so the report's "export date" is pinned
        // in screenshot runs (report pages 07/08) instead of showing the real date;
        // in production the clock is the real system clock, so this is unchanged.
        scalars["META_EXPORT_VALUE"] = LocalDate.now(DayResolver.clock()).format(dateFmt)
        scalars["META_PERIOD_LABEL"] = context.getString(R.string.pdf_meta_period)
        scalars["META_PERIOD_VALUE"] =
            "${LocalDate.parse(d.firstDate).format(dateFmt)} – ${LocalDate.parse(d.lastDate).format(dateFmt)}"
        scalars["META_LIMIT_LABEL"] = context.getString(R.string.pdf_meta_limit)
        scalars["META_LIMIT_VALUE_DAY"] = "${d.limitInfo.limitGrams.fmt1()} $perDay"
        scalars["META_LIMIT_VALUE_7DAYS"] = "${d.limitInfo.weeklyLimitGrams.fmt1()} $perWeek"
        scalars["META_LIMIT_VALUE_DDAYS"] = "${d.limitInfo.maxDrinkDaysPerWeek} ${context.getString(R.string.pdf_meta_drink_days_suffix)}"
        scalars["META_WEIGHT_LABEL"] = context.getString(R.string.pdf_meta_weight)
        scalars["META_WEIGHT_VALUE"] = if (d.weightKg > 0) "${d.weightKg.roundToInt()} kg" else "–"

        // ── KPI tiles ────────────────────────────────────────────────────────────
        // Order and warn flags reproduce the original report exactly.
        repeats["KPIS"] = listOf(
            kpi(context.getString(R.string.pdf_kpi_abstinent_days), "${d.abstinentDays}"),
            kpi(context.getString(R.string.pdf_meta_longest_abstinence), "${d.longestAbstinence}"),
            kpi(context.getString(R.string.pdf_kpi_drink_days), "${d.drinkDays}"),
            kpi(context.getString(R.string.pdf_kpi_total), "${d.totalGrams.fmt1()} g"),

            kpi(
                context.getString(R.string.pdf_kpi_over_daily, d.limitInfo.limitGrams.fmt0()),
                "${d.violations.daysOverDailyLimit}",
                d.violations.daysOverDailyLimit > 0,
            ),
            kpi(
                context.getString(R.string.pdf_kpi_over_weekly, d.limitInfo.weeklyLimitGrams.fmt0()),
                "${d.violations.daysOverWeeklyLimit}",
                d.violations.daysOverWeeklyLimit > 0,
            ),
            kpi(
                context.getString(R.string.pdf_kpi_over_drink_days, d.limitInfo.maxDrinkDaysPerWeek),
                "${d.violations.daysOverDrinkDayLimit}",
                d.violations.daysOverDrinkDayLimit > 0,
            ),
            kpi(
                context.getString(R.string.pdf_kpi_binge, PdfReportData.bingeThreshold.fmt0()),
                "${d.bingeDays}",
                d.bingeDays > 0,
            ),

            kpi(context.getString(R.string.pdf_kpi_max_day), "${d.maxPerDay.fmt1()} g", AlcoholCalculator.isOverLimit(d.maxPerDay, d.limitInfo.limitGrams)),
            kpi(context.getString(R.string.pdf_kpi_max_7days), "${d.maxPer7Days.fmt1()} g", AlcoholCalculator.isOverLimit(d.maxPer7Days, d.limitInfo.weeklyLimitGrams)),
            kpi(context.getString(R.string.pdf_kpi_avg_drink_days_month), d.avgDrinkDaysPerMonth.fmt1()),
            kpi(context.getString(R.string.pdf_kpi_median_drink_days_month), d.medianDrinkDaysPerMonth.fmt1()),

            kpi(context.getString(R.string.pdf_kpi_avg_day), "${d.avgPerDay.fmt1()} g"),
            kpi(context.getString(R.string.pdf_kpi_median_day), "${d.medianPerDay.fmt1()} g"),
            kpi(context.getString(R.string.pdf_kpi_avg_drink_day), "${d.avgPerDrinkDay.fmt1()} g"),
            kpi(context.getString(R.string.pdf_kpi_median_drink_day), "${d.medianPerDrinkDay.fmt1()} g"),
        )

        // ── Monthly table ──────────────────────────────────────────────────────
        scalars["COL_MONTH"] = context.getString(R.string.pdf_col_month)
        scalars["COL_DRINK_DAYS"] = context.getString(R.string.pdf_col_drink_days)
        scalars["COL_TOTAL_G"] = context.getString(R.string.pdf_col_total_g)
        scalars["COL_AVG_G_DAY"] = context.getString(R.string.pdf_col_avg_g_day)
        scalars["COL_OVER_DAILY"] = context.getString(R.string.pdf_col_over_daily)
        repeats["MONTHS"] = d.months.map { m ->
            mapOf(
                "M_MONTH" to LocalDate.parse("${m.monthKey}-01").format(monthFmt),
                "M_DRINK_DAYS" to "${m.drinkDays}",
                "M_TOTAL" to m.totalGrams.fmt1(),
                "M_AVG" to m.avgPerCalendarDay.fmt1(),
                "M_OVER" to if (m.daysOverDailyLimit > 0) "${m.daysOverDailyLimit}" else "–",
                "M_ROW_CLASS" to if (m.daysOverDailyLimit > 0) "warn" else "",
            )
        }

        // ── Trend bar chart (only with ≥ 2 months) ──────────────────────────────
        // ── Consumption-over-time chart (always shown) ──────────────────────────
        // Replaces the former monthly-average trend chart. Bars are the per-day
        // average within each bucket (day / week / month, chosen by span length);
        // abstinent buckets carry a green tick instead of a bar. The dashed line is
        // the daily limit. Labels are thinned for dense series (see chartLabelIndices).
        scalars["TREND_DISPLAY"] = "block"
        run {
            val limit = d.limitInfo.limitGrams
            val maxAvg = d.chartBuckets.maxOfOrNull { it.avgPerDay } ?: 0.0
            // Headroom of 10% so the tallest bar / limit line never touches the top.
            val maxVal = maxOf(maxAvg, limit) * 1.1
            scalars["LIMIT_LINE_PCT"] = pct(limit, maxVal).fmt0()

            val labelIdx = chartLabelIndices(d.chartBuckets.size)
            repeats["BARS"] = d.chartBuckets.map { b ->
                mapOf(
                    "BAR_HEIGHT_PCT" to if (b.isAbstinent) {
                        "0"
                    } else {
                        pct(b.avgPerDay, maxVal).coerceAtLeast(2.0).fmt0()
                    },
                    "BAR_CLASS" to if (AlcoholCalculator.isOverLimit(b.avgPerDay, limit)) "bar over" else "bar",
                    // On-top value, same convention as the page-2 hour/weekday charts:
                    // the bucket's per-day average (one decimal), blank for abstinent
                    // (zero-consumption) buckets so the green tick stands alone.
                    "BAR_VALUE" to if (b.isAbstinent) "" else b.avgPerDay.fmt1(),
                    // Green abstinence tick shown only for zero-consumption buckets.
                    "BAR_TICK_DISPLAY" to if (b.isAbstinent) "block" else "none",
                )
            }
            // X-axis labels live in their OWN row BELOW the baseline (like the
            // hour/weekday charts), so a label is never overlapped by its bar and
            // the trend chart is laid out consistently with the page-2 charts.
            repeats["BARSLABELS"] = d.chartBuckets.mapIndexed { i, b ->
                mapOf("BAR_LABEL" to if (i in labelIdx) chartBucketLabel(d.chartGranularity, b, monthFmt, dayMonthFmt) else "")
            }
        }

        // ── Category table + donut ───────────────────────────────────────────────
        scalars["CAT_HEAD_NAME"] = context.getString(R.string.category)
        scalars["CAT_HEAD_G"] = "g"
        scalars["CAT_HEAD_PCT"] = "%"
        repeats["CATEGORIES"] = d.categories.map { c ->
            mapOf(
                "C_NAME" to categoryLabel(context, c.categoryName),
                "C_COLOR" to categoryColor(c.categoryName), // swatch = donut colour
                "C_G" to c.grams.fmt1(),
                "C_PCT" to "${c.percent} %",
            )
        }
        // Donut slices (same data, rendered as an SVG ring beside the table). We use
        // the classic stroke-dasharray technique on concentric <circle>s: with radius
        // 15.9155 the circumference is ~100, so a slice's dash length is simply its
        // percentage. PIE_OFFSET = 25 − cumulative rotates the slice so the ring fills
        // clockwise starting at 12 o'clock. Fractions are taken from grams (not the
        // rounded integer percents) so the segments butt up exactly.
        run {
            val totalCat = d.categories.sumOf { it.grams }
            var cumulative = 0.0

            // SVG attributes must use a '.' decimal separator regardless of the device
            // locale. String.format()/Double.format() honour the *default* locale, so a
            // German device would emit "40,00" — and SVG treats both ',' and ' ' as list
            // separators, turning stroke-dasharray="40,00 60,00" into four values
            // (40 0 60 0): a zero gap that paints the whole ring. Locale.ROOT fixes it.
            fun svg(x: Double): String = String.format(java.util.Locale.ROOT, "%.2f", x)
            repeats["PIE_SLICES"] = d.categories.map { c ->
                val fraction = if (totalCat > 0) c.grams / totalCat * 100.0 else 0.0
                val slice = mapOf(
                    "PIE_FILL" to categoryColor(c.categoryName),
                    "PIE_DASH" to svg(fraction),
                    "PIE_GAP" to svg(100.0 - fraction),
                    "PIE_OFFSET" to svg(25.0 - cumulative),
                )
                cumulative += fraction
                slice
            }
        }

        // ── Time-of-day pattern: 24-bar hour-of-day chart. Bars and axis labels are
        //    emitted as two separate repeat blocks (HBARS / HLABELS) so the labels can
        //    sit in their own row *below* the baseline instead of inside the plot area.
        //    Every hour 0..23 is now labelled (no thinning). Section title set above.
        run {
            val maxHour = d.hourlyGrams.maxOrNull() ?: 0.0
            // 15 % headroom so the value printed above the tallest bar still fits.
            val ceiling = maxHour * 1.15
            val days = d.totalDays.coerceAtLeast(1)
            repeats["HBARS"] = d.hourlyGrams.map { grams ->
                mapOf(
                    // 0 grams → no bar; otherwise at least a 2% sliver so a small-but-
                    // nonzero hour stays visible.
                    "H_HEIGHT_PCT" to (
                        if (grams <= 0.0) {
                            "0"
                        } else {
                            pct(grams, ceiling).coerceAtLeast(2.0).fmt0()
                        }
                        ),
                    // Average grams per calendar day in this clock hour (blank for an
                    // hour that never saw any drinking).
                    "H_VALUE" to (if (grams <= 0.0) "" else (grams / days).fmt1()),
                )
            }
            repeats["HLABELS"] = (0..23).map { hour -> mapOf("H_LABEL" to "$hour") }
        }

        // ── Weekday profile: bar chart (analogous to the hour chart). WDBARS carries
        //    each bar's height and the average value printed above it; WDLABELS is the
        //    weekday-name axis row. Heights are scaled against maxWeekday × 1.15 so the
        //    value label above the tallest bar still fits inside the plot height.
        run {
            val maxWeekday = d.weekdayAverages.filterNotNull().maxOrNull() ?: 0.0
            val ceiling = maxWeekday * 1.15
            repeats["WDBARS"] = d.weekdayAverages.map { avg ->
                mapOf(
                    "WD_HEIGHT_PCT" to (
                        if (avg == null || avg <= 0.0) {
                            "0"
                        } else {
                            pct(avg, ceiling).coerceAtLeast(2.0).fmt0()
                        }
                        ),
                    // Value above the bar; blank for a weekday that was never a drink day.
                    "WD_VALUE" to (avg?.fmt1() ?: ""),
                )
            }
            repeats["WDLABELS"] = d.weekdayOrder.map { iso ->
                mapOf(
                    "WD_NAME" to DayOfWeek.of(iso)
                        .getDisplayName(TextStyle.SHORT, locale).take(2),
                )
            }
        }

        // ── Binge & abstinence streaks ───────────────────────────────────────────
        scalars["RISK_BINGE_LABEL"] = context.getString(R.string.pdf_meta_binge_days, PdfReportData.bingeThreshold.fmt0())
        scalars["RISK_BINGE_VALUE"] = "${d.bingeDays}"
        scalars["RISK_LONGEST_LABEL"] = context.getString(R.string.pdf_meta_longest_abstinence)
        // Properly pluralized "N day(s)" via the shared `days` plural resource, so
        // the English report no longer prints "1 Days" (and every locale uses its
        // own plural rules).
        scalars["RISK_LONGEST_VALUE"] = context.resources.getQuantityString(
            R.plurals.days,
            d.longestAbstinence,
            d.longestAbstinence,
        )
        scalars["RISK_CURRENT_LABEL"] = context.getString(R.string.pdf_meta_current_abstinence)
        scalars["RISK_CURRENT_VALUE"] = context.resources.getQuantityString(
            R.plurals.days,
            d.currentAbstinence,
            d.currentAbstinence,
        )

        val template = context.assets.open(TEMPLATE_ASSET).bufferedReader().use { it.readText() }
        return SimpleTemplate.render(template, scalars, repeats)
    }

    // ── small presentation helpers ───────────────────────────────────────────────

    /** Builds one KPI tile row for the KPIS repeat block. */
    private fun kpi(label: String, value: String, warn: Boolean = false): Map<String, String> = mapOf("KPI_LABEL" to label, "KPI_VALUE" to value, "KPI_CLASS" to if (warn) "kpi warn" else "kpi")

    /** Maps a [de.godisch.potillus.domain.model.DrinkCategory] enum name to its localised label. */
    private fun categoryLabel(context: Context, name: String): String = context.getString(
        when (name) {
            "BEER" -> R.string.category_beer
            "WINE" -> R.string.category_wine
            "SPIRITS" -> R.string.category_spirits
            "LONGDRINK" -> R.string.category_longdrink
            "LIQUEUR" -> R.string.category_liqueur
            else -> R.string.category_other
        },
    )

    /**
     * Hex colour for a [DrinkCategory] name, matching the on-screen donut palette
     * (de.godisch.potillus.ui.component.categoryColors) so the PDF donut and the app
     * use the same colours. Escape-safe (no `< > & " '`), so it can flow through
     * SimpleTemplate into an SVG `stroke`/CSS `background`.
     */
    private fun categoryColor(name: String): String = when (name) {
        "BEER" -> "#F59E0B" // amber-500
        "WINE" -> "#9333EA" // purple-600
        "SPIRITS" -> "#EF4444" // red-500
        "LONGDRINK" -> "#3B82F6" // blue-500
        "LIQUEUR" -> "#10B981" // emerald-500
        else -> "#6B7280" // gray-500 (OTHER)
    }

    /** Percentage of [value] relative to [max] (0 when [max] is non-positive). */
    private fun pct(value: Double, max: Double): Double = if (max > 0) value / max * 100.0 else 0.0

    /**
     * Indices of the buckets that should carry an x-axis label. For a short
     * series (≤ 12 bars) every bucket is labelled; for longer series a small,
     * evenly spaced subset (~8 labels) keeps the axis readable. The first and
     * last buckets are always included.
     */
    private fun chartLabelIndices(n: Int): Set<Int> {
        if (n <= 0) return emptySet()
        if (n <= 12) return (0 until n).toSet()
        val target = 8
        val step = ((n - 1).toFloat() / (target - 1)).coerceAtLeast(1f)
        return (0 until target)
            .map { (it * step).toInt().coerceAtMost(n - 1) }
            .toSortedSet()
            .apply { add(n - 1) }
    }

    /**
     * Formats one bucket's first day into a short axis label, chosen by
     * granularity: locale-ordered day-and-month for daily/weekly buckets ("5.6" / "6/5"), month-and-year
     * for monthly buckets ("Jun 2026").
     *
     * @param monthFmt The per-app-locale month+year formatter built in [buildHtml]
     *                 via [monthYearFormatter] (abbreviated month, locale field order);
     *                 passed in (rather than held as a shared field) so the month
     *                 name follows the in-app language, not the system locale.
     * @param dayMonthFmt The per-app-locale compact day+month formatter built in
     *                 [buildHtml] from [shortDayMonthPattern]; carries the
     *                 locale's day/month ORDER ("28.6" vs "6/28") for the
     *                 daily/weekly tick labels.
     */
    private fun chartBucketLabel(
        granularity: ChartGranularity,
        b: ChartBucket,
        monthFmt: DateTimeFormatter,
        dayMonthFmt: DateTimeFormatter,
    ): String {
        val ld = LocalDate.parse(b.labelDate)
        return when (granularity) {
            ChartGranularity.DAILY, ChartGranularity.WEEKLY -> ld.format(dayMonthFmt)
            ChartGranularity.MONTHLY -> ld.format(monthFmt)
        }
    }
}
