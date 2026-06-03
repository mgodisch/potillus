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
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.data.repository.IEntryRepository
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.util.CsvExporter
import de.godisch.potillus.util.ExportResult
import de.godisch.potillus.util.PdfReportBuilder
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

// ════════════════════════════════════════════════════════════════════════════
// STATS
// ════════════════════════════════════════════════════════════════════════════

enum class StatsPeriod { WEEK, MONTH, YEAR }

@Immutable
data class StatsUiState(
    val period: StatsPeriod                       = StatsPeriod.WEEK,
    val dataPoints: List<DaySummary>              = emptyList(),
    val totalGrams: Double                        = 0.0,
    val avgPerDay: Double                         = 0.0,
    val avgPerDrinkDay: Double                    = 0.0,
    /** Days whose own total exceeds the daily gram limit. */
    val daysOverDailyLimit: Int                   = 0,
    /** Consumption days on/after the week's weekly-gram-limit was reached. */
    val daysOverWeeklyLimit: Int                  = 0,
    /** Consumption days beyond the allowed number of drink days in their week. */
    val daysOverDrinkDayLimit: Int                = 0,
    val abstinentDays: Int                        = 0,
    val currentStreak: Int                        = 0,
    val longestStreak: Int                        = 0,
    val trendPercent: Double                      = 0.0,
    val limitInfo: LimitInfo                      = LimitInfo(20.0, 100.0, 5),
    /** Grams of alcohol consumed per category in the selected period. */
    val categoryBreakdown: Map<DrinkCategory, Double> = emptyMap(),
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

    private val _period = MutableStateFlow(StatsPeriod.WEEK)

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
            // CSV building + MediaStore writes are blocking I/O, so they
            // must not run on the Main dispatcher.
            val result = withContext(Dispatchers.IO) {
                CsvExporter.export(appContext, entries, drinks)
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
            // HTML assembly (template fill) is CPU work, not UI work → off the main thread.
            val html = withContext(Dispatchers.Default) {
                runCatching { PdfReportBuilder.buildHtml(appContext, entries, drinks, settings) }
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
                val from = todayDate.with(TemporalAdjusters.previousOrSame(DayOfWeek.of(settings.weekStartDay)))
                val pf   = from.minusWeeks(1)
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

            // Guard: effectiveFrom > to when the user has set statsFromDate to a
            // future date. datesUntil() throws IllegalArgumentException when start > end,
            // so we clamp totalDays to 0 and skip the calculation.
            //
            // half-open interval [effectiveFrom, to) is INTENTIONAL:
            //   datesUntil(to) excludes `to` (the current logical day), so the
            //   in-progress day is NOT counted as a completed day for averaging or
            //   abstinence. `drinkDays` (current.size) DOES include today if a drink
            //   was logged, so on a day with a drink-today `abstinentDays =
            //   totalDays - drinkDays` can be one below zero; `coerceAtLeast(0)` below
            //   absorbs exactly that one-day overlap. Do not "fix" this by making the
            //   interval inclusive — that would count the unfinished day and shift
            //   avgPerDay / abstinentDays for every period.
            val totalDays = if (effectiveFrom <= to)
                DayResolver.parseDate(effectiveFrom).datesUntil(DayResolver.parseDate(to)).count().toInt()
            else 0

            val totalGrams = current.sumOf { it.totalGrams }
            val drinkDays  = current.size

            val categoryBreakdown = periodEntries
                .groupBy { e -> drinkMap[e.drinkId]?.category ?: DrinkCategory.OTHER }
                .mapValues { (_, es) -> es.sumOf { it.gramsAlcohol } }
                .filter { it.value > 0.0 }

            // All three limits are evaluated together over the period's days.
            // Daily is a per-day check; weekly and drink-day are accumulated per
            // week (delimited by the configured week start).
            val violations = AlcoholCalculator.countLimitViolations(
                summaries           = current,
                dailyLimitGrams     = limitInfo.limitGrams,
                weeklyLimitGrams    = limitInfo.weeklyLimitGrams,
                maxDrinkDaysPerWeek = limitInfo.maxDrinkDaysPerWeek,
                weekStartDay        = settings.weekStartDay
            )

            StatsUiState(
                period            = period,
                dataPoints        = current,
                totalGrams        = totalGrams,
                avgPerDay         = if (totalDays > 0) totalGrams / totalDays else 0.0,
                avgPerDrinkDay    = if (drinkDays > 0) totalGrams / drinkDays else 0.0,
                daysOverDailyLimit    = violations.daysOverDailyLimit,
                daysOverWeeklyLimit   = violations.daysOverWeeklyLimit,
                daysOverDrinkDayLimit = violations.daysOverDrinkDayLimit,
                abstinentDays     = (totalDays - drinkDays).coerceAtLeast(0),
                // Pass statsFloor so the streak starts at the recording-start date
                // when there are no drink entries yet (implicit abstinence assumption).
                currentStreak     = DayResolver.computeCurrentAbstinence(streakDates, today, statsFloor),
                longestStreak     = DayResolver.computeLongestAbstinence(streakDates, today, statsFloor),
                trendPercent      = computeTrend(totalGrams, previous.sumOf { it.totalGrams }),
                limitInfo         = limitInfo,
                categoryBreakdown = categoryBreakdown,
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
