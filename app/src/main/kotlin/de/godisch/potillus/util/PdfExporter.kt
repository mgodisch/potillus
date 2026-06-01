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

import android.content.ContentValues
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.Environment
import android.provider.MediaStore
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import java.io.IOException
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import kotlin.math.roundToInt

// =============================================================================
// PdfExporter – 2-page clinical summary (DIN A4, duplex-ready)
// =============================================================================

object PdfExporter {

    // A4 at 72 dpi: 595 × 842 pt
    private const val W              = 595f
    private const val H              = 842f
    private const val MARGIN         = 50f
    private const val CW             = W - 2 * MARGIN   // 495
    private const val FOOTER_RESERVE = 30f  // pts reserved for the footer at the bottom of each page

    private val EXPORT_FMT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm").withZone(ZoneId.systemDefault())
    private val DATE_FMT   = DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.SHORT).withLocale(java.util.Locale.getDefault())
    private val MONTH_FMT  = DateTimeFormatter.ofPattern("MMM yyyy")

    // Colours
    private val C_BLACK = Color.rgb(20, 20, 20)
    private val C_GREY  = Color.rgb(100, 100, 100)
    private val C_LGREY = Color.rgb(220, 220, 220)
    private val C_RED   = Color.rgb(200, 50, 50)
    private val C_BLUE  = Color.rgb(30, 80, 160)
    private val C_WHITE = Color.WHITE

    /**
     * Renders a 2-page clinical PDF report to the Downloads folder.
     *
     * @param context   Context for string resources and MediaStore access.
     * @param entries   All consumption entries for the requested date range.
     *                  Must be non-empty (the caller is responsible for checking).
     * @param drinks    Full drink catalogue for category look-ups.
     * @param settings  Current user preferences (gender, limit mode, weight, …).
     * @return [ExportResult] with filename and MediaStore URI on success, null on I/O error.
     *         The caller is responsible for checking that [entries] is non-empty before
     *         calling this function (an empty list causes an immediate null return).
     */
    fun export(
        context: Context,
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>,
        settings: AppSettings
    ): ExportResult? {
        if (entries.isEmpty()) return null

        val drinkMap = drinks.associateBy { it.id }

        // Compute byDate once here and pass it to both page functions.
        // Previously drawPage1 and drawPage2 each called entries.groupBy independently,
        // iterating the full entry list twice for no reason.
        val byDate   = entries.groupBy { it.logicalDate }
        val doc      = PdfDocument()

        try {
            // Page 1
            val p1info = PdfDocument.PageInfo.Builder(W.toInt(), H.toInt(), 1).create()
            val page1  = doc.startPage(p1info)
            drawPage1(page1.canvas, context, entries, drinks, drinkMap, settings, byDate)
            doc.finishPage(page1)

            // Page 2
            val p2info = PdfDocument.PageInfo.Builder(W.toInt(), H.toInt(), 2).create()
            val page2  = doc.startPage(p2info)
            drawPage2(page2.canvas, context, entries, drinkMap, settings, byDate)
            doc.finishPage(page2)

            // Save to MediaStore Downloads.
            // capture Instant.now() once so the file name and the
            // internal timestamp are guaranteed to be identical even on slow devices.
            val now      = Instant.now()
            val fileName = "potillus_report_${EXPORT_FMT.format(now)}.pdf"
            val cv = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv)
                ?: return null

            // Mirror CsvExporter's error handling: delete the orphaned
            // MediaStore entry if writing fails, so Downloads is never polluted
            // with a zero-byte or partial PDF file.
            return try {
                resolver.openOutputStream(uri)?.use { doc.writeTo(it) }
                ExportResult(fileName, uri, "application/pdf")
            } catch (e: IOException) {
                resolver.delete(uri, null, null) // remove the empty placeholder
                null
            }
        } catch (e: IOException) {
            return null
        } finally {
            doc.close()
        }
    }

    // =========================================================================
    // PAGE 1 – overview, KPIs, monthly table, trend sparkline
    // =========================================================================

    /**
     * Renders page 1: header, metadata block, KPI grid, monthly table, and trend sparkline.
     *
     * @param c        Target canvas (PDF page 1).
     * @param context  Context for string resources.
     * @param entries  All consumption entries (used for KPI aggregates).
     * @param drinks   Full drink catalogue (passed through to the category column).
     * @param drinkMap Pre-built map of drink ID → [DrinkDefinition] for O(1) look-up.
     * @param settings Current user preferences.
     * @param byDate   Pre-grouped map of logical date → entries, shared with [drawPage2]
     *                 to avoid recomputing the groupBy on the same list twice.
     */
    private fun drawPage1(
        c: Canvas,
        context: Context,
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>,
        drinkMap: Map<Long, DrinkDefinition>,
        settings: AppSettings,
        byDate: Map<String, List<ConsumptionEntry>>
    ) {
        var y = MARGIN

        // Header bar
        y = drawHeader(c, y, context.getString(R.string.pdf_title), page = "1 / 2")

        // Metadata block
        val firstDate = entries.minOf { it.logicalDate }
        val lastDate  = entries.maxOf { it.logicalDate }
        val genderStr = context.getString(if (settings.gender == Gender.MALE) R.string.male else R.string.female)
        val limitMode = when (settings.limitMode) {
            LimitMode.WHO    -> "WHO"
            LimitMode.DHS    -> "DHS"
            LimitMode.CUSTOM -> context.getString(R.string.pdf_meta_custom_limit)
        }
        val limitGrams = AlcoholCalculator.getLimitInfo(settings).limitGrams

        y = drawMeta(c, y, listOf(
            context.getString(R.string.pdf_meta_export_date) to LocalDate.now().format(DATE_FMT),
            context.getString(R.string.pdf_meta_period)      to "${parseDate(firstDate).format(DATE_FMT)} – ${parseDate(lastDate).format(DATE_FMT)}",
            context.getString(R.string.pdf_meta_gender)      to genderStr,
            context.getString(R.string.pdf_meta_limit)       to "$limitMode (${limitGrams.fmt1()} ${context.getString(R.string.pdf_unit_g_per_day)})",
            context.getString(R.string.pdf_meta_weight)      to if (settings.weightKg > 0) "${settings.weightKg.fmt1()} kg" else "–"
        ))

        // KPI grid
        y += 10f
        y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_kpis))

        // byDate is passed in — no re-grouping here
        val totalDays   = LocalDate.parse(firstDate).datesUntil(LocalDate.parse(lastDate).plusDays(1)).count().toInt()
        val drinkDays   = byDate.size
        val abstDays    = (totalDays - drinkDays).coerceAtLeast(0)
        val totalGrams  = entries.sumOf { it.gramsAlcohol }
        val avgPerDay   = if (totalDays > 0) totalGrams / totalDays else 0.0
        val avgDrinkDay = if (drinkDays > 0) totalGrams / drinkDays else 0.0

        val whoLimit  = if (settings.gender == Gender.FEMALE) AlcoholCalculator.WHO_LIMIT_FEMALE else AlcoholCalculator.WHO_LIMIT_MALE
        val dhsLimit  = if (settings.gender == Gender.FEMALE) AlcoholCalculator.DHS_LIMIT_FEMALE else AlcoholCalculator.DHS_LIMIT_MALE
        val binge     = AlcoholCalculator.bingeThreshold(settings.gender)
        val overWho   = byDate.count { (_, es) -> es.sumOf { it.gramsAlcohol } > whoLimit }
        val overDhs   = byDate.count { (_, es) -> es.sumOf { it.gramsAlcohol } > dhsLimit }
        val bingeDays = byDate.count { (_, es) -> es.sumOf { it.gramsAlcohol } > binge }

        y = drawKpiGrid(c, y, listOf(
            KPI(context.getString(R.string.pdf_kpi_total),          "${totalGrams.fmt1()} g"),
            KPI(context.getString(R.string.pdf_kpi_avg_day),        "${avgPerDay.fmt1()} g"),
            KPI(context.getString(R.string.pdf_kpi_avg_drink_day),  "${avgDrinkDay.fmt1()} g"),
            KPI(context.getString(R.string.pdf_kpi_drink_days),     "$drinkDays"),
            KPI(context.getString(R.string.pdf_kpi_abstinent_days), "$abstDays"),
            KPI(context.getString(R.string.pdf_kpi_over_who, whoLimit.fmt0()), "$overWho", overWho > 0),
            KPI(context.getString(R.string.pdf_kpi_over_dhs, dhsLimit.fmt0()), "$overDhs", overDhs > 0),
            KPI(context.getString(R.string.pdf_kpi_binge, binge.fmt0()),       "$bingeDays", bingeDays > 0)
        ))

        // Monthly table
        y += 10f
        y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_months))

        val byMonth = byDate.entries
            .groupBy { it.key.substring(0, 7) }
            .toSortedMap()

        val tableHeaders = listOf(
            context.getString(R.string.pdf_col_month),
            context.getString(R.string.pdf_col_drink_days),
            context.getString(R.string.pdf_col_total_g),
            context.getString(R.string.pdf_col_avg_g_day),
            "> DHS"
        )
        val colW = floatArrayOf(100f, 70f, 70f, 70f, 70f)

        // Reserve space for the sparkline when enough months are available
        val sparklineHeight  = 10f + 16f + 78f
        val sparklinePossible = byMonth.size >= 2
        val budgetBottom     = H - FOOTER_RESERVE - (if (sparklinePossible) sparklineHeight else 0f)

        val rowH     = 15f
        val maxRows  = ((budgetBottom - y - 18f) / rowH).toInt().coerceAtLeast(1)

        // Show most recent months when truncation is needed
        val allMonths     = byMonth.entries.toList()
        val truncated     = allMonths.size > maxRows
        val visibleMonths = if (truncated) allMonths.takeLast(maxRows) else allMonths

        y = drawTableHeader(c, y, tableHeaders, colW)
        visibleMonths.forEach { (monthKey, days) ->
            val mDate  = LocalDate.parse("$monthKey-01")
            val mDays  = mDate.lengthOfMonth()
            val mGrams = days.sumOf { it.value.sumOf { e -> e.gramsAlcohol } }
            val mOver  = days.count { it.value.sumOf { e -> e.gramsAlcohol } > dhsLimit }
            y = drawTableRow(c, y, listOf(
                mDate.format(MONTH_FMT),
                "${days.size}",
                mGrams.fmt1(),
                (mGrams / mDays).fmt1(),
                if (mOver > 0) "$mOver" else "–"
            ), colW, mOver > 0)
        }

        if (truncated) {
            val noteP = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_GREY; textSize = 7.5f }
            c.drawText(
                context.getString(R.string.pdf_months_truncated, visibleMonths.size, allMonths.size),
                MARGIN + 4f, y + 10f, noteP
            )
            y += 14f
        }

        // Trend sparkline
        if (byMonth.size >= 2) {
            y += 10f
            y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_trend))
            val monthAvgs = visibleMonths.map { (k, days) ->
                val mDate  = LocalDate.parse("$k-01")
                val mDays  = mDate.lengthOfMonth()
                val mGrams = days.sumOf { it.value.sumOf { e -> e.gramsAlcohol } }
                k.substring(5, 7) + "." + k.substring(2, 4) to mGrams / mDays
            }
            y = drawSparkline(c, y, monthAvgs, dhsLimit)
        }

        drawFooter(c, context.getString(R.string.pdf_footer1))
    }

    // =========================================================================
    // PAGE 2 – categories, time-of-day patterns, weekday profile, streaks
    // =========================================================================

    /**
     * Renders page 2: category breakdown, time-of-day patterns, weekday profile,
     * binge-drinking statistics, and abstinence streaks.
     *
     * @param c        Target canvas (PDF page 2).
     * @param context  Context for string resources.
     * @param entries  All consumption entries.
     * @param drinkMap Pre-built map of drink ID → [DrinkDefinition] for O(1) look-up.
     * @param settings Current user preferences.
     * @param byDate   Pre-grouped map of logical date → entries, shared with [drawPage1]
     *                 to avoid recomputing the groupBy on the same list twice.
     */
    private fun drawPage2(
        c: Canvas,
        context: Context,
        entries: List<ConsumptionEntry>,
        drinkMap: Map<Long, DrinkDefinition>,
        settings: AppSettings,
        byDate: Map<String, List<ConsumptionEntry>>
    ) {
        var y = MARGIN

        y = drawHeader(c, y, context.getString(R.string.pdf_title), page = "2 / 2")

        // Category breakdown table
        y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_categories))

        val catLabel = mapOf(
            "BEER"      to context.getString(R.string.category_beer),
            "WINE"      to context.getString(R.string.category_wine),
            "SPIRITS"   to context.getString(R.string.category_spirits),
            "LONGDRINK" to context.getString(R.string.category_longdrink),
            "LIQUEUR"   to context.getString(R.string.category_liqueur),
            "OTHER"     to context.getString(R.string.category_other)
        )

        val totalGrams = entries.sumOf { it.gramsAlcohol }.coerceAtLeast(0.01)
        val catGrams   = mutableMapOf<String, Double>()
        entries.forEach { e ->
            val cat   = drinkMap[e.drinkId]?.category?.name ?: "OTHER"
            val group = catLabel[cat] ?: context.getString(R.string.category_other)
            catGrams[group] = (catGrams[group] ?: 0.0) + e.gramsAlcohol
        }

        val catHeaders = listOf(context.getString(R.string.category), "g", "%")
        val catColW    = floatArrayOf(200f, 100f, 100f)
        y = drawTableHeader(c, y, catHeaders, catColW)
        catGrams.entries.sortedByDescending { it.value }.forEach { (cat, g) ->
            val pct = (g / totalGrams * 100).roundToInt()
            y = drawTableRow(c, y, listOf(cat, g.fmt1(), "$pct %"), catColW, false)
        }

        // Time-of-day consumption pattern
        y += 12f
        y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_daytime))

        val times  = entries.map { e ->
            val ldt = java.time.LocalDateTime.ofInstant(Instant.ofEpochMilli(e.timestampMillis), ZoneId.systemDefault())
            ldt.hour + ldt.minute / 60.0
        }
        // byDate is passed in from export() — no re-grouping here
        val firstTs = byDate.mapValues { (_, es) -> es.minOf { it.timestampMillis } }
        val lastTs  = byDate.mapValues { (_, es) -> es.maxOf { it.timestampMillis } }

        val avgFirst    = if (firstTs.isNotEmpty()) firstTs.values.map { tsToHour(it) }.average() else 0.0
        val avgLast     = if (lastTs.isNotEmpty())  lastTs.values.map  { tsToHour(it) }.average() else 0.0
        val pctBefore17 = (times.count { it < 17.0 }.toDouble() / times.size * 100).roundToInt()
        val pctAfter17  = 100 - pctBefore17

        y = drawMeta(c, y, listOf(
            context.getString(R.string.pdf_meta_first_drink) to hourToStr(avgFirst),
            context.getString(R.string.pdf_meta_last_drink)  to hourToStr(avgLast),
            context.getString(R.string.pdf_meta_before_18)   to "$pctBefore17 %",
            context.getString(R.string.pdf_meta_after_18)    to "$pctAfter17 %"
        ))

        // Weekday profile
        y += 12f
        y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_weekday))

        // Weekday columns rotated to start at the configured first day of the week
        // (settings.weekStartDay, ISO 1..7). Defaults to Monday, matching the prior
        // fixed layout.
        val ws = settings.weekStartDay
        val dayNames = (0..6).map { i ->
            DayOfWeek.of((ws - 1 + i) % 7 + 1)
                .getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.getDefault())
                .take(2)
        }
        val dayTotals = Array(7) { mutableListOf<Double>() }
        byDate.forEach { (dateStr, es) ->
            val col = (LocalDate.parse(dateStr).dayOfWeek.value - ws + 7) % 7  // 0 = week-start
            dayTotals[col].add(es.sumOf { it.gramsAlcohol })
        }
        val dayColW = FloatArray(8) { if (it < 7) 58f else 49f }
        val dayRow  = dayTotals.map { list -> if (list.isEmpty()) "–" else list.average().fmt1() } + listOf("")
        y = drawTableHeader(c, y, dayNames + listOf(""), dayColW)
        y = drawTableRow(c, y, dayRow, dayColW, false)

        // Binge-drinking & streaks
        y += 12f
        y = drawSectionTitle(c, y, context.getString(R.string.pdf_section_risk))

        val binge         = AlcoholCalculator.bingeThreshold(settings.gender)
        val bingeDays     = byDate.count { (_, es) -> es.sumOf { it.gramsAlcohol } > binge }
        val allDates      = byDate.keys.sorted()
        val today         = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
        val longestStreak = DayResolver.computeLongestAbstinence(allDates)
        val currentStreak = DayResolver.computeCurrentAbstinence(allDates, today)
        val daysSuffix    = context.getString(R.string.pdf_days_suffix)

        y = drawMeta(c, y, listOf(
            context.getString(R.string.pdf_meta_binge_days, binge.fmt0())  to "$bingeDays",
            context.getString(R.string.pdf_meta_longest_abstinence)         to "$longestStreak $daysSuffix",
            context.getString(R.string.pdf_meta_current_abstinence)         to "$currentStreak $daysSuffix"
        ))

        drawFooter(c, context.getString(R.string.pdf_footer2))
    }

    // =========================================================================
    // Drawing helpers
    // =========================================================================

    /**
     * Draws the blue header bar spanning the full page width.
     *
     * The bar is 38pt tall and contains the [title] on the left and the [page]
     * label (e.g. "1 / 2") on the right, both in white.
     *
     * @param c      Target canvas (one PDF page).
     * @param y      Current vertical cursor position before the header.
     * @param title  Main heading text (e.g. the localised pdf_title string).
     * @param page   Page indicator string (e.g. "1 / 2", "2 / 2").
     * @return       Updated vertical cursor position after the header.
     */
    private fun drawHeader(c: Canvas, y: Float, title: String, page: String): Float {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_BLUE; style = Paint.Style.FILL }
        c.drawRect(0f, 0f, W, 38f, p)
        p.apply { color = C_WHITE; textSize = 15f; isFakeBoldText = true }
        c.drawText(title, MARGIN, 25f, p)
        p.apply { textSize = 10f; isFakeBoldText = false }
        c.drawText(page, W - MARGIN - 30f, 25f, p)
        return y + 30f
    }

    /**
     * Draws a bold uppercase section heading followed by a light-grey underline.
     *
     * Used to introduce each logical section on both pages (KPIs, months, categories, …).
     *
     * @param c      Target canvas.
     * @param y      Cursor position for the title baseline.
     * @param title  Section heading text (will be uppercased automatically).
     * @return       Updated vertical cursor position after the heading and underline.
     */
    private fun drawSectionTitle(c: Canvas, y: Float, title: String): Float {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_BLUE; textSize = 11f; isFakeBoldText = true }
        c.drawText(title.uppercase(), MARGIN, y, p)
        val lp = Paint().apply { color = C_LGREY; strokeWidth = 1f }
        c.drawLine(MARGIN, y + 3f, W - MARGIN, y + 3f, lp)
        return y + 16f
    }

    /**
     * Draws a two-column key–value metadata block.
     *
     * [items] are laid out in rows of two pairs: each row occupies one line.
     * Keys are rendered in grey, values in near-black bold.  The layout uses
     * fixed column widths (half of [CW]) so the block aligns with the page margins.
     *
     * @param c      Target canvas.
     * @param y      Starting vertical cursor position.
     * @param items  List of (label, value) string pairs.
     * @return       Updated vertical cursor position after the last row.
     */
    private fun drawMeta(c: Canvas, y: Float, items: List<Pair<String, String>>): Float {
        var cy = y
        val keyP = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_GREY; textSize = 9f }
        val valP = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_BLACK; textSize = 9f; isFakeBoldText = true }
        items.chunked(2).forEach { row ->
            row.forEachIndexed { i, (k, v) ->
                val x = MARGIN + i * (CW / 2)
                c.drawText(k, x, cy, keyP)
                c.drawText(v, x + 120f, cy, valP)
            }
            cy += 13f
        }
        return cy
    }

    private data class KPI(val label: String, val value: String, val warn: Boolean = false)

    /**
     * Draws a 4-column grid of KPI tiles.
     *
     * Each tile shows a large [KPI.value] on top and a small [KPI.label] below it.
     * If [KPI.warn] is `true` the tile background turns light-red and the value is
     * coloured red, drawing the reader's attention to the concerning metric.
     *
     * Tiles are arranged in rows of 4; overflow creates additional rows.
     *
     * @param c     Target canvas.
     * @param y     Starting vertical cursor position.
     * @param kpis  List of [KPI] data objects (value, label, warn flag).
     * @return      Updated vertical cursor position after the last row of tiles.
     */
    private fun drawKpiGrid(c: Canvas, y: Float, kpis: List<KPI>): Float {
        var cy = y
        val cellW = CW / 4
        val cellH = 36f
        kpis.chunked(4).forEach { row ->
            row.forEachIndexed { i, kpi ->
                val x      = MARGIN + i * cellW
                val bg     = Paint().apply { color = if (kpi.warn) Color.rgb(255, 240, 240) else Color.rgb(245, 247, 252); style = Paint.Style.FILL }
                val border = Paint().apply { color = C_LGREY; style = Paint.Style.STROKE; strokeWidth = 0.5f }
                c.drawRect(x + 2f, cy, x + cellW - 2f, cy + cellH, bg)
                c.drawRect(x + 2f, cy, x + cellW - 2f, cy + cellH, border)
                val valP   = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (kpi.warn) C_RED else C_BLUE; textSize = 14f; isFakeBoldText = true }
                val labP   = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_GREY; textSize = 7.5f }
                c.drawText(kpi.value, x + 6f, cy + 20f, valP)
                c.drawText(kpi.label, x + 6f, cy + 31f, labP)
            }
            cy += cellH + 4f
        }
        return cy + 4f
    }

    /**
     * Draws a single-row table header with a light-blue background.
     *
     * Column labels are drawn in bold blue. Each column's x-offset is the
     * cumulative sum of the preceding entries in [colW].
     *
     * @param c        Target canvas.
     * @param y        Starting vertical cursor position.
     * @param headers  Column label strings in left-to-right order.
     * @param colW     Width of each column in points; must have the same length as [headers].
     * @return         Updated vertical cursor position after the header row.
     */
    private fun drawTableHeader(c: Canvas, y: Float, headers: List<String>, colW: FloatArray): Float {
        val bg = Paint().apply { color = Color.rgb(230, 235, 245); style = Paint.Style.FILL }
        c.drawRect(MARGIN, y, W - MARGIN, y + 16f, bg)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_BLUE; textSize = 8f; isFakeBoldText = true }
        var x = MARGIN + 4f
        headers.forEachIndexed { i, h ->
            c.drawText(h, x, y + 11f, p)
            x += colW[i]
        }
        return y + 18f
    }

    /**
     * Draws a single data row with a bottom separator line.
     *
     * If [warn] is `true`, the row background turns light-red and the text colour
     * switches to [C_RED], consistent with the KPI tile warning style.
     *
     * @param c      Target canvas.
     * @param y      Starting vertical cursor position.
     * @param cells  Cell text values in left-to-right order.
     * @param colW   Column widths in points; must have the same length as [cells].
     * @param warn   When `true`, the row is highlighted in red.
     * @return       Updated vertical cursor position after the row and its separator line.
     */
    private fun drawTableRow(c: Canvas, y: Float, cells: List<String>, colW: FloatArray, warn: Boolean): Float {
        if (warn) {
            val bg = Paint().apply { color = Color.rgb(255, 245, 245); style = Paint.Style.FILL }
            c.drawRect(MARGIN, y, W - MARGIN, y + 14f, bg)
        }
        val p   = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (warn) C_RED else C_BLACK; textSize = 8f }
        val sep = Paint().apply { color = C_LGREY; strokeWidth = 0.5f }
        var x = MARGIN + 4f
        cells.forEachIndexed { i, cell ->
            c.drawText(cell, x, y + 10f, p)
            x += colW[i]
        }
        c.drawLine(MARGIN, y + 14f, W - MARGIN, y + 14f, sep)
        return y + 15f
    }

    /**
     * Draws a bar-chart sparkline for monthly average consumption.
     *
     * Each bar represents one month's average grams per calendar day.
     * A dashed horizontal line marks the [limitG] threshold; bars that exceed
     * it are coloured [C_RED], those below are [C_BLUE].  Month labels are drawn
     * below each bar (e.g. "01.26" for January 2026).
     *
     * The chart height is fixed at 60pt; [limitG] is always within the visible
     * range because [maxVal] is `max(dataMax, limitG) × 1.1`.
     *
     * @param c       Target canvas.
     * @param y       Starting vertical cursor position for the chart top.
     * @param points  List of (label, value) pairs, one per visible month.
     *                Labels are short month identifiers (e.g. "01.26").
     *                Values are average grams per calendar day.
     * @param limitG  Daily limit in grams; determines bar colour and the reference line position.
     * @return        Updated vertical cursor position after the chart and its x-axis labels.
     */
    private fun drawSparkline(c: Canvas, y: Float, points: List<Pair<String, Double>>, limitG: Double): Float {
        if (points.isEmpty()) return y
        val chartH = 60f
        val chartW = CW
        val maxVal = maxOf(points.maxOf { it.second }, limitG) * 1.1
        val stepX  = chartW / points.size
        val barW   = (stepX * 0.6f).coerceAtLeast(4f)

        val limitY = y + chartH - (limitG / maxVal * chartH).toFloat()
        val limitP = Paint().apply {
            color = Color.rgb(220, 120, 50); strokeWidth = 1f
            pathEffect = android.graphics.DashPathEffect(floatArrayOf(6f, 4f), 0f)
        }
        c.drawLine(MARGIN, limitY, MARGIN + chartW, limitY, limitP)

        points.forEachIndexed { i, (label, value) ->
            val barH  = (value / maxVal * chartH).toFloat().coerceAtLeast(2f)
            val left  = MARGIN + i * stepX + (stepX - barW) / 2
            val top   = y + chartH - barH
            val barP  = Paint().apply { color = if (value > limitG) C_RED else C_BLUE; style = Paint.Style.FILL }
            c.drawRoundRect(left, top, left + barW, y + chartH, 2f, 2f, barP)
            val labP  = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_GREY; textSize = 7f }
            c.drawText(label, MARGIN + i * stepX + stepX / 2 - 8f, y + chartH + 10f, labP)
        }
        return y + chartH + 18f
    }

    /**
     * Draws a full-width separator line and a disclaimer/footer [text] near the bottom of the page.
     *
     * The line is drawn at y = [H] − 25pt; the text baseline is at [H] − 12pt.
     * Both positions are hard-coded relative to the A4 page height [H] so the
     * footer always appears at the same absolute position regardless of page content.
     *
     * @param c     Target canvas.
     * @param text  Footer disclaimer string (localised via string resources in the caller).
     */
    private fun drawFooter(c: Canvas, text: String) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_GREY; textSize = 7.5f }
        c.drawLine(MARGIN, H - 25f, W - MARGIN, H - 25f, Paint().apply { color = C_LGREY })
        c.drawText(text, MARGIN, H - 12f, p)
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    /** Parses an ISO-8601 "YYYY-MM-DD" string to a [LocalDate]. */
    private fun parseDate(s: String): LocalDate = LocalDate.parse(s)

    /**
     * Converts a Unix millisecond timestamp to fractional hours in local time.
     *
     * E.g. 14:30 local → 14.5.  Used to compute average first/last drink time.
     *
     * @param ts  Unix epoch milliseconds (UTC).
     * @return    Hour of day in local time as a decimal fraction (0.0–23.999…).
     */
    private fun tsToHour(ts: Long): Double {
        val ldt = java.time.LocalDateTime.ofInstant(Instant.ofEpochMilli(ts), ZoneId.systemDefault())
        return ldt.hour + ldt.minute / 60.0
    }
    /**
     * Formats fractional hours as "HH:MM".
     *
     * E.g. 14.5 → "14:30".  Minutes are rounded to the nearest whole minute.
     *
     * @param h  Fractional hour value (0.0–23.999…).
     * @return   Zero-padded time string in "HH:MM" format.
     */
    private fun hourToStr(h: Double): String {
        val hh = h.toInt()
        val mm = ((h - hh) * 60).roundToInt()
        return "%02d:%02d".format(hh, mm)
    }

    /** Formats a [Double] with 1 decimal place (e.g. `19.6`). */
    private fun Double.fmt1() = "%.1f".format(this)

    /** Formats a [Double] with 0 decimal places (e.g. `20`). */
    private fun Double.fmt0() = "%.0f".format(this)
}
