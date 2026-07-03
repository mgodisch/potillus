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
package de.godisch.potillus.ui.screen

// =============================================================================
// StatsViewModel.kt – ViewModel for the Stats screen
// =============================================================================
//
// RESPONSIBILITIES:
//   - Exposes [StatsUiState] with aggregated statistics for the selected
//     period (WEEK / MONTH / YEAR): totals, averages, streaks, trend, and
//     per-category breakdown.
//   - Combines three upstream Flows (period selector, settings, all dates)
//     via a named intermediate [StatsParams] value, then switches to four
//     inner DB Flows with flatMapLatest.
//
// See ViewModels.kt (package overview) for the shared Flow → StateFlow
// pattern, @Immutable contract, and manual-DI rationale.
// =============================================================================

import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.godisch.potillus.R
import de.godisch.potillus.data.prefs.IAppPreferences
import de.godisch.potillus.l10n.perAppLocalizedContext
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.data.repository.IEntryRepository
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.ChartBucket
import de.godisch.potillus.domain.ChartBucketing
import de.godisch.potillus.domain.ChartGranularity
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.Trend
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.util.CsvExporter
import de.godisch.potillus.util.ExportResult
import de.godisch.potillus.util.PdfReportBuilder
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate

// ════════════════════════════════════════════════════════════════════════════
// STATS
// ════════════════════════════════════════════════════════════════════════════

enum class StatsPeriod { WEEK, MONTH, YEAR }

@Immutable
data class StatsUiState(
    // Default = MONTH: MUST match the ViewModel's initial `_period` value and
    // the stateIn seed below, so that `StatsUiState()` IS the seed state. Tests
    // (StatsViewModelTest.awaitComputed) rely on `state == StatsUiState()`
    // identifying the not-yet-computed seed; a diverging default here would make
    // the seed look like a computed value.
    val period: StatsPeriod                       = StatsPeriod.MONTH,
    val dataPoints: List<DaySummary>              = emptyList(),
    /** Gap-free, time-axis bucket series for the consumption chart (incl. abstinent buckets). */
    val chartBuckets: List<ChartBucket>           = emptyList(),
    /** Bucket width of [chartBuckets]: DAILY for WEEK/MONTH, MONTHLY for YEAR. */
    val chartGranularity: ChartGranularity        = ChartGranularity.DAILY,
    val totalGrams: Double                        = 0.0,
    val avgPerDay: Double                         = 0.0,
    val avgPerDrinkDay: Double                    = 0.0,
    /** Days whose own total exceeds the daily gram limit. */
    val daysOverDailyLimit: Int                   = 0,
    /** Consumption days whose trailing-7-day gram total exceeded the limit. */
    val daysOverWeeklyLimit: Int                  = 0,
    /** Consumption days exceeding the allowed drink days within their trailing 7-day window. */
    val daysOverDrinkDayLimit: Int                = 0,
    val abstinentDays: Int                        = 0,
    val currentStreak: Int                        = 0,
    val longestStreak: Int                        = 0,
    val trendPercent: Double                      = 0.0,
    /**
     * Direction of [avgPerDay] versus the previous period's per-day average
     * (FLAT when equal at 0.1 g or there is no previous value). Drives the trend
     * arrow/colour; see [Trend].
     */
    val trend: Trend                              = Trend.FLAT,
    val limitInfo: LimitInfo                      = LimitInfo(20.0, 100.0, 5),
    /** Grams of alcohol consumed per category in the selected period. */
    val categoryBreakdown: Map<DrinkCategory, Double> = emptyMap(),
    /** Pure-alcohol grams per hour-of-day bucket (index 0..23) for the time-of-day chart. */
    /** Average grams per day in each of eight 3-hour buckets (0–3, 3–6 … 21–24). */
    val hourBucketAverages: List<Double>          = List(8) { 0.0 },
    /** ISO weekday numbers (1=Mon..7=Sun) in display order (locale's first weekday first). */
    val weekdayOrder: List<Int>                   = emptyList(),
    /** Average grams per weekday in [weekdayOrder] order; null = weekday never a drink day. */
    val weekdayAverages: List<Double?>            = emptyList(),
    // Defaults for the export date-range dialog (CSV/PDF export lives on this
    // screen). `today` is the logical current day; `statsFromDate`
    // is the configured statistics-start floor (empty when unset).
    val today: String                             = "",
    val statsFromDate: String                     = ""
)

/**
 * One-shot request to print a PDF report, emitted by [StatsViewModel.exportPdf].
 *
 * Carries the fully rendered report [html] (see [de.godisch.potillus.util.PdfReportBuilder])
 * and the [jobName] used for the print job. The screen consumes it once, opens the
 * system print dialog via [de.godisch.potillus.util.WebViewPdfPrinter], then calls
 * [StatsViewModel.clearPrintRequest].
 */
data class PdfPrintRequest(
    val html: String,
    val jobName: String
)

@OptIn(ExperimentalCoroutinesApi::class)
class StatsViewModel(
    private val entryRepo: IEntryRepository,
    private val drinkRepo: IDrinkRepository,
    private val prefs: IAppPreferences,
    // Injected for CSV/PDF export (data export lives with the statistics view).
    // appContext is the Application context (safe to hold in a ViewModel — see the
    // SettingsViewModel KDoc); getString localises export status messages.
    private val appContext: Context,
    private val getString: StringProvider
) : ViewModel() {

    // MONTH is the default: on first open it gives a meaningful overview without
    // the user having to switch away from a too-narrow week view. WEEK and YEAR
    // remain available via the period selector in the statistics screen.
    private val _period = MutableStateFlow(StatsPeriod.MONTH)

    // ── Export (CSV / PDF) ────────────────────────────────────────────────
    // Data export belongs with the
    // statistics it exports. Backup (JSON) import/export stays in Settings.
    // Exposed as independent flows (not folded into StatsUiState) so the heavy
    // stats combine/flatMapLatest pipeline below is left untouched.
    private val _exportStatus = MutableStateFlow<ExportStatus?>(null)
    val exportStatus: StateFlow<ExportStatus?> = _exportStatus.asStateFlow()

    /** Set after a successful export so the screen can open a share sheet once. */
    private val _shareTarget = MutableStateFlow<ExportResult?>(null)
    val shareTarget: StateFlow<ExportResult?> = _shareTarget.asStateFlow()

    /** Clears the transient status banner (called after its auto-dismiss delay). */
    fun clearExportStatus() { _exportStatus.value = null }

    /** Clears the pending share target after the chooser has been shown. */
    fun clearShareTarget() { _shareTarget.value = null }

    // ── PDF print request (one-shot) ──────────────────────────────────────
    // The PDF report is rendered to HTML here and then handed to the screen,
    // which loads it into a WebView and opens the system print dialog (Weg 2 /
    // v0.61.0). Unlike CSV/JSON, the PDF path does NOT write a file itself and
    // therefore sets no [shareTarget]: the system print UI owns saving/sharing.
    private val _printRequest = MutableStateFlow<PdfPrintRequest?>(null)
    val printRequest: StateFlow<PdfPrintRequest?> = _printRequest.asStateFlow()

    /** Clears the pending print request after the screen has opened the print dialog. */
    fun clearPrintRequest() { _printRequest.value = null }

    /**
     * Exports entries within the given inclusive date range as a CSV file in
     * shared storage and, on success, sets [shareTarget] so the screen can offer
     * a share sheet. Errors and the result file name are reported via
     * [exportStatus].
     *
     * @param from Start date inclusive ("YYYY-MM-DD").
     * @param to   End date inclusive ("YYYY-MM-DD").
     */
    fun exportCsv(from: String, to: String) {
        viewModelScope.launch {
            // Delegate the date filter to SQLite via getInRange() so the
            // index on logicalDate is used instead of loading all rows into memory.
            val entries = entryRepo.getInRange(from, to)
            if (entries.isEmpty()) {
                _exportStatus.value = ExportStatus.Err(str(R.string.export_no_entries))
                return@launch
            }
            val drinks = drinkRepo.drinks.first()
            // Wrap the Application context so the CSV column headers resolve in
            // the per-app language on ALL supported API levels: on API 30–32 the
            // raw appContext keeps the SYSTEM locale (see perAppLocalizedContext).
            // Captured before withContext because AppCompatDelegate's stored
            // locale list is conventionally accessed from the main thread.
            val exportContext = appContext.perAppLocalizedContext()
            // CSV building + MediaStore writes are blocking I/O, so they
            // must not run on the Main dispatcher.
            val result = withContext(Dispatchers.IO) {
                CsvExporter.export(exportContext, entries, drinks)
            }
            _exportStatus.value = if (result != null) {
                _shareTarget.value = result
                ExportStatus.Done(result.fileName)
            } else {
                ExportStatus.Err(str(R.string.export_failed))
            }
        }
    }

    /**
     * Renders entries within the given inclusive date range into the HTML report
     * and emits a [printRequest] so the screen can open the system print dialog
     * ("Save as PDF" or a real printer). Errors are reported via [exportStatus].
     *
     * @param from Start date inclusive ("YYYY-MM-DD").
     * @param to   End date inclusive ("YYYY-MM-DD").
     */
    fun exportPdf(from: String, to: String) {
        viewModelScope.launch {
            val settings = prefs.settingsFlow.first()
            val entries  = entryRepo.getInRange(from, to)
            if (entries.isEmpty()) {
                _exportStatus.value = ExportStatus.Err(str(R.string.export_no_entries))
                return@launch
            }
            val drinks  = drinkRepo.drinks.first()
            val jobName = PdfReportBuilder.jobName(Instant.now())
            // Same per-app-locale wrapping as in exportCsv: every label, date and
            // number format of the report is resolved from this context.
            val reportContext = appContext.perAppLocalizedContext()
            // HTML assembly (template fill) is CPU work, not UI work → off the main thread.
            val html = withContext(Dispatchers.Default) {
                runCatching { PdfReportBuilder.buildHtml(reportContext, entries, drinks, settings) }
                    .getOrNull()
            }
            if (html != null) {
                _printRequest.value = PdfPrintRequest(html, jobName)
            } else {
                _exportStatus.value = ExportStatus.Err(str(R.string.export_failed))
            }
        }
    }

    /** Localises a string resource via the injected [StringProvider]. */
    private fun str(@StringRes id: Int, vararg args: Any): String = getString(id, *args)


    /**
     * Intermediate value that bridges the outer `combine` and the downstream `flatMapLatest`
     * in [uiState].
     *
     * WHY a named data class instead of [Triple]?
     *   [Triple] was used here previously because only three values needed to cross the
     *   combine → flatMapLatest boundary. Named properties are more readable and
     *   refactoring-safe: positional `.first`/`.second`/`.third` give no hint about which
     *   value is which, and adding a fourth parameter would require restructuring the whole
     *   pipeline. The same rationale that motivated [CalendarParams] applies here.
     *
     * WHY a private nested class (not file-level)?
     *   [StatsParams] is an implementation detail of [StatsViewModel] and has no meaning
     *   outside it. Nesting it keeps the declaration close to the only site that uses it.
     */
    private data class StatsParams(
        val period:   StatsPeriod,
        val settings: AppSettings,
        val allDates: List<String>
    )

    @OptIn(ExperimentalCoroutinesApi::class)
    val uiState: StateFlow<StatsUiState> = combine(
        _period,
        prefs.settingsFlow,
        entryRepo.getAllDatesFlow()
    ) { period, settings, allDates ->
        StatsParams(period, settings, allDates)
    }.flatMapLatest { params ->
        val (period, settings, allDates) = params
        val today     = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
        val todayDate = DayResolver.parseDate(today)
        val limitInfo = AlcoholCalculator.getLimitInfo(settings)
        val fmt       = DayResolver.DATE_FORMATTER

        val (from, to, prevFrom, prevTo) = when (period) {
            StatsPeriod.WEEK -> {
                // Rolling 7-day window ending today (inclusive): today + previous 6 days.
                // The previous window is the seven days immediately before it, so the
                // trend percentage compares two adjacent, equal-length 7-day spans.
                val from = todayDate.minusDays(6)
                val pf   = from.minusDays(7)
                arrayOf(from.format(fmt), today, pf.format(fmt), from.minusDays(1).format(fmt))
            }
            StatsPeriod.MONTH -> {
                val from = todayDate.withDayOfMonth(1)
                val pf   = from.minusMonths(1)
                arrayOf(from.format(fmt), today, pf.format(fmt), from.minusDays(1).format(fmt))
            }
            StatsPeriod.YEAR -> {
                val from = todayDate.withDayOfYear(1)
                val pf   = from.minusYears(1)
                arrayOf(from.format(fmt), today, pf.format(fmt), from.minusDays(1).format(fmt))
            }
        }

        // Apply the global statistics start date as a lower bound.
        val statsFloor    = settings.statsFromDate
        val effectiveFrom = if (statsFloor.isNotEmpty() && statsFloor > from) statsFloor else from
        val streakDates   = if (statsFloor.isNotEmpty()) allDates.filter { it >= statsFloor } else allDates

        combine(
            entryRepo.getDailySummaries(effectiveFrom, to),
            entryRepo.getDailySummaries(prevFrom, prevTo),
            entryRepo.getEntriesForPeriod(effectiveFrom, to),
            drinkRepo.drinks
        ) { current, previous, periodEntries, drinks ->
            val drinkMap = drinks.associateBy { it.id }

            val totalGrams = current.sumOf { it.totalGrams }
            // Drink days in the period, INCLUDING today if a drink was logged today
            // (the daily-summary query is inclusive of `to`, which equals today).
            val drinkDays  = current.size

            // Effective period length for the per-day rate and the abstinent-day count.
            //
            // Today is in superposition until it resolves: logging a drink today makes
            // it a confirmed DRINK day, so it joins the period immediately (with the
            // amount consumed so far). With no drink yet, today stays out until it
            // finishes. This is the app-wide per-day rule, centralised in
            // DayResolver.effectivePeriodDays and shared with the Today card and the
            // chart's current bucket so all three agree. It also returns 0 for an
            // empty/inverted range (effectiveFrom > to), avoiding a divide-by-zero.
            //
            // Everything derived from it is consistent: `totalGrams` (which includes
            // today's drinks) is divided by a period that includes today exactly when
            // those drinks exist, and `abstinentDays` never counts the unfinished day
            // (effectivePeriodDays − drinkDays = completed dry days).
            val todayIsDrinkDay     = current.any { it.date == to }
            val effectivePeriodDays = DayResolver.effectivePeriodDays(effectiveFrom, to, todayIsDrinkDay)

            val categoryBreakdown = periodEntries
                .groupBy { e -> drinkMap[e.drinkId]?.category ?: DrinkCategory.OTHER }
                .mapValues { (_, es) -> es.sumOf { it.gramsAlcohol } }
                .filter { it.value > 0.0 }

            // Hour-of-day histogram: grams of pure alcohol per clock hour (0..23),
            // built from the period's individual entries. Drives the Statistics
            // screen's 24-bar time-of-day chart (the same series the PDF uses).
            val hourlyGrams = DoubleArray(24)
            periodEntries.forEach { e ->
                val hour = LocalDateTime
                    .ofInstant(Instant.ofEpochMilli(e.timestampMillis), ZoneId.systemDefault())
                    .hour
                hourlyGrams[hour] += e.gramsAlcohol
            }
            // Collapse the 24 clock hours into eight 3-hour buckets (0–3, 3–6 … 21–24)
            // and express each as the AVERAGE grams per day in the period (sum in the
            // bucket ÷ effectivePeriodDays), so the eight bars sum to the overall
            // average grams/day. divisor ≥ 1 guards the empty-period edge case.
            val periodDaysDiv = effectivePeriodDays.coerceAtLeast(1)
            val hourBucketAverages = (0 until 8).map { b ->
                var sum = 0.0
                for (h in b * 3 until b * 3 + 3) sum += hourlyGrams[h]
                sum / periodDaysDiv
            }

            // Weekday profile: average grams on each weekday, rotated so the first
            // column is the locale's first weekday. Computed from the daily summaries
            // (one total per day), mirroring PdfReportData so screen and PDF agree.
            val weekStartIso = DayResolver.firstDayOfWeekIso()
            val weekdayOrder = (0..6).map { i -> (weekStartIso - 1 + i) % 7 + 1 }   // ISO 1..7
            val weekdayTotals = Array(7) { mutableListOf<Double>() }
            current.forEach { s ->
                val col = (LocalDate.parse(s.date, fmt).dayOfWeek.value - weekStartIso + 7) % 7
                weekdayTotals[col].add(s.totalGrams)
            }
            val weekdayAverages = weekdayTotals.map { if (it.isEmpty()) null else it.average() }

            // All three limits are evaluated together over the period's days.
            // Daily is a per-day check; the gram and drink-day limits use a gliding
            // 7-day window (see AlcoholCalculator.countLimitViolations).
            val violations = AlcoholCalculator.countLimitViolations(
                summaries           = current,
                dailyLimitGrams     = limitInfo.limitGrams,
                weeklyLimitGrams    = limitInfo.weeklyLimitGrams,
                maxDrinkDaysPerWeek = limitInfo.maxDrinkDaysPerWeek
            )

            // Consumption-over-time chart series. WEEK/MONTH show one bar per day;
            // YEAR aggregates into monthly buckets (≤ 12 bars), so a year reads as
            // one bar per calendar month rather than ~52 weekly bars. The series
            // spans the full period [effectiveFrom, to], so abstinent days appear as
            // zero buckets (rendered as a green tick) on a real time axis.
            //
            // NOTE: this is the ON-SCREEN granularity only. The PDF export picks its
            // own granularity from the chosen span via
            // ChartBucketing.granularityForSpan() (a one-year span there stays
            // WEEKLY, i.e. ~52 bars); the two are intentionally independent.
            val chartGranularity =
                if (period == StatsPeriod.YEAR) ChartGranularity.MONTHLY else ChartGranularity.DAILY
            val chartBuckets =
                ChartBucketing.bucketize(current, effectiveFrom, to, chartGranularity, inProgressDay = to)

            // Trend vs the previous period, on a PER-DAY-AVERAGE basis (never totals)
            // so an in-progress period compares fairly against a full previous one.
            // The current average already uses the superposition rule (effective
            // days); the previous period is complete, so it is divided by its full
            // day count [prevFrom, prevTo]. A non-positive previous average means
            // "no comparable previous value" → Trend.FLAT (shown as "–").
            val avgPerDay     = if (effectivePeriodDays > 0) totalGrams / effectivePeriodDays else 0.0
            val prevSum       = previous.sumOf { it.totalGrams }
            val prevDays      = (DayResolver.parseDate(prevTo).toEpochDay() -
                                 DayResolver.parseDate(prevFrom).toEpochDay() + 1).toInt()
            val prevAvgPerDay = if (prevDays > 0) prevSum / prevDays else 0.0
            val trend         = Trend.of(avgPerDay, prevAvgPerDay)

            StatsUiState(
                period            = period,
                dataPoints        = current,
                chartBuckets      = chartBuckets,
                chartGranularity  = chartGranularity,
                totalGrams        = totalGrams,
                avgPerDay         = avgPerDay,
                avgPerDrinkDay    = if (drinkDays > 0) totalGrams / drinkDays else 0.0,
                daysOverDailyLimit    = violations.daysOverDailyLimit,
                daysOverWeeklyLimit   = violations.daysOverWeeklyLimit,
                daysOverDrinkDayLimit = violations.daysOverDrinkDayLimit,
                abstinentDays     = (effectivePeriodDays - drinkDays).coerceAtLeast(0),
                // Pass statsFloor so the streak starts at the recording-start date
                // when there are no drink entries yet (implicit abstinence assumption).
                currentStreak     = DayResolver.computeCurrentAbstinence(streakDates, today, statsFloor),
                longestStreak     = DayResolver.computeLongestAbstinence(streakDates, today, statsFloor),
                trendPercent      = computeTrend(avgPerDay, prevAvgPerDay),
                trend             = trend,
                limitInfo         = limitInfo,
                categoryBreakdown = categoryBreakdown,
                hourBucketAverages = hourBucketAverages,
                weekdayOrder      = weekdayOrder,
                weekdayAverages   = weekdayAverages,
                today             = today,
                statsFromDate     = statsFloor
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), StatsUiState())

    /** Selects the statistics aggregation period [p] (week / month / year …). */
    fun setPeriod(p: StatsPeriod) { _period.value = p }

    /**
     * Returns the percentage change from [previous] to [current].
     *
     * Guards against division by zero: if [previous] is ≤ 0 the trend is
     * reported as 0 % (there is no meaningful baseline to compare against).
     *
     * @param current  The current period's value.
     * @param previous The preceding period's value (the baseline).
     * @return         Signed percentage change, or 0.0 when no baseline exists.
     */
    private fun computeTrend(current: Double, previous: Double): Double {
        if (previous <= 0) return 0.0
        return ((current - previous) / previous) * 100.0
    }
}
