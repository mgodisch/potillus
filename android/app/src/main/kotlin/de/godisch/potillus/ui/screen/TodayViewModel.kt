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
// TodayViewModel.kt – ViewModel for the Today screen
// =============================================================================
//
// RESPONSIBILITIES:
//   - Exposes [TodayUiState] as a [StateFlow] derived from live DB queries.
//   - Combines the entry list, drink catalogue, weekly summaries, and a
//     periodic ticker (for BAC decay) into a single @Immutable snapshot.
//   - Delegates persistence to [IEntryRepository] / [IDrinkRepository].
//   - Never holds a Context reference (only injected interfaces).
//
// See ViewModels.kt (package overview) for the shared Flow → StateFlow
// pattern, @Immutable contract, manual-DI rationale, and Log-guard rule.
// =============================================================================

import android.util.Log
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.godisch.potillus.BuildConfig
import de.godisch.potillus.data.prefs.IAppPreferences
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.data.repository.IEntryRepository
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.Trend
import de.godisch.potillus.domain.model.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

// ════════════════════════════════════════════════════════════════════════════
// TODAY
// ════════════════════════════════════════════════════════════════════════════

// @Immutable: all properties are val; List instances are always emptyList() /
// listOf() and are never mutated after construction. The annotation lets the
// Compose compiler skip recomposition when the same instance is re-emitted
// without rebuilding individual collection elements. All subsequent *UiState
// classes in this file follow the same contract.
@Immutable
data class TodayUiState(
    val entries: List<ConsumptionEntry>  = emptyList(),
    val totalGrams: Double               = 0.0,
    val limitInfo: LimitInfo             = LimitInfo(20.0, 100.0, 5),
    /** Number of distinct days in the trailing 7-day window with ≥1 entry (today included if applicable). */
    val drinkDaysThisWeek: Int           = 0,
    val weeklyTotalGrams: Double         = 0.0,
    val weeklyRangeLabel: String         = "",
    /**
     * Average grams per day for the current calendar month so far: the month's
     * cumulated grams divided by the number of days elapsed (1st of month …
     * today, inclusive). Matches the current month's bar in the year-view chart.
     */
    val monthlyAvgPerDay: Double         = 0.0,
    /**
     * Trend of [monthlyAvgPerDay] vs. the per-day average over the whole period
     * from the configured statistics start date up to the day before this month
     * (FLAT when there is no such baseline or the two are equal at 0.1 g).
     */
    val monthTrend: Trend                = Trend.FLAT,
    /** Localized standalone name of the current month (e.g. "June" / "Juni"). */
    val currentMonthLabel: String        = "",
    val bacPermille: Double?             = null,
    val favorites: List<DrinkDefinition> = emptyList(),
    val settings: AppSettings            = AppSettings()
)

@OptIn(ExperimentalCoroutinesApi::class)
class TodayViewModel(
    private val entryRepo: IEntryRepository,
    private val drinkRepo: IDrinkRepository,
    private val prefs: IAppPreferences
) : ViewModel() {

    /**
     * Emits [Unit] immediately, then once per [TICK_INTERVAL_MS].
     *
     * WHY a ticker?
     *   BAC declines continuously over time, but without a ticker [uiState]
     *   would only update when the database emits a new row – i.e. when the
     *   user adds or deletes an entry. Between DB events [System.currentTimeMillis]
     *   would be frozen at the value captured during the last emission, so the
     *   displayed BAC would not change even as hours passed.
     *
     * WHY combined INSIDE flatMapLatest (not outside)?
     *   If the ticker were placed outside the flatMapLatest, each tick would
     *   restart the whole flatMapLatest lambda: all upstream DB queries would
     *   be cancelled and re-subscribed every minute, causing a visible flicker.
     *   Placing it inside means only the combine recalculates; the DB Flows
     *   remain active and undisturbed.
     *
     * WHY 60 seconds?
     *   BAC changes roughly 0.15 ‰/h = 0.0025 ‰/min. A one-minute resolution
     *   is imperceptible for the user but keeps battery impact negligible
     *   (one wakeup per minute vs continuous). Shorter intervals would not add
     *   meaningful accuracy.
     */
    private val ticker: Flow<Unit> = flow {
        while (true) {
            emit(Unit)
            delay(TICK_INTERVAL_MS)
        }
    }

    companion object {
        /** How often the BAC display refreshes. See [ticker] KDoc for rationale. */
        const val TICK_INTERVAL_MS = 60_000L

        private const val TAG = "TodayViewModel"
    }

    /**
     * Exposed separately so CalendarScreen can show the full drink list via its own ViewModel.
     *
     * PATTERN: Flow → StateFlow via [stateIn]
     *   A [Flow] is cold: it starts from scratch for each collector and stops when
     *   the collector cancels. [stateIn] converts it to a hot [StateFlow] that:
     *     - stays active as long as there is at least one subscriber
     *       ([SharingStarted.WhileSubscribed])
     *     - holds the latest value so new subscribers get it immediately
     *     - exposes it as a stable reference that Compose can collect without
     *       restarting the upstream query on every recomposition
     *
     *   `WhileSubscribed(5_000)`:
     *     The upstream Flow keeps running for 5 seconds after the last subscriber
     *     disappears (e.g. screen is backgrounded). This brief window handles
     *     orientation changes and navigation without restarting the DB query.
     *     After 5 s without a subscriber the Flow is cancelled to free resources.
     *
     *   The third argument (`emptyList()`) is the initial value emitted before the
     *   database returns its first result. Compose shows this immediately so the
     *   UI renders without blocking on I/O.
     */
    val drinks: StateFlow<List<DrinkDefinition>> = drinkRepo.drinks
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /**
     * The drink to pre-select when the user opens the add-entry dialog from the
     * generic "+" button: the drink of the most recently logged entry (across all
     * days), or the first catalogue drink if there is no history yet, or null if
     * the catalogue is still loading / empty.
     *
     * Derived reactively from the most-recent entry and the drink catalogue so it
     * stays correct as the user logs more drinks.
     */
    val lastUsedDrink: StateFlow<DrinkDefinition?> = combine(
        entryRepo.mostRecentEntry(),
        drinkRepo.drinks
    ) { recent, drinks ->
        drinks.firstOrNull { it.id == recent?.drinkId } ?: drinks.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /**
     * UI state flow.
     *
     * Derived entirely from [prefs.settingsFlow] as the outer stream so that "today"
     * (which depends on the day-change time stored in settings) is always recalculated
     * when settings change.
     */
    val uiState: StateFlow<TodayUiState> = prefs.settingsFlow.flatMapLatest { settings ->
        val today     = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
        val limitInfo = AlcoholCalculator.getLimitInfo(settings)
        // Rolling 7-day window: today plus the previous six calendar days (inclusive).
        // This replaces the former fixed calendar week so the "weekly" gram total and
        // drink-day count never reset on a weekday boundary. The field names below
        // keep the historical "weekly*" spelling to avoid churn; they now denote the
        // trailing-7-day figures.
        val windowEnd   = DayResolver.parseDate(today)
        val windowStart = windowEnd.minusDays(6)
        // First day of the calendar month that contains "today"; used for the
        // "month total" figure shown next to today's total on the summary card.
        val monthStart  = windowEnd.withDayOfMonth(1)
        // Reference window for the Today trend arrow: the per-day average over the
        // whole time from the configured statistics start date up to the day before
        // this month. The daily-summary query below is widened to start there.
        val monthStr     = DayResolver.formatDate(monthStart)
        val prevEnd      = monthStart.minusDays(1)         // last day before this month
        val statsFloor   = settings.statsFromDate          // "" = not configured
        // A baseline only exists when the statistics start lies before this month.
        val hasBaseline  = statsFloor.isNotEmpty() && statsFloor < monthStr
        val historyFrom  = if (hasBaseline) statsFloor else monthStr
        val baselineDays = if (hasBaseline)
            (prevEnd.toEpochDay() - DayResolver.parseDate(statsFloor).toEpochDay() + 1).toInt() else 0
        // Localized, standalone month name for the card caption ("Ø <month>").
        // Standalone form is the grammatically correct one for a bare label in
        // languages with cases (e.g. ru/cs/pl/el). Derived from the logical
        // "today" (via monthStart), not LocalDate.now(), so the day-change hour is
        // respected around month boundaries.
        //
        // WHY forLanguageTag(settings.language) instead of Locale.getDefault()?
        //   AppCompatDelegate.setApplicationLocales() changes only the per-app
        //   Context configuration, not the JVM-wide Locale.getDefault(). A user
        //   who picks "Français" in Settings but has a German system locale would
        //   see a German month name next to the French UI labels. Using the BCP-47
        //   tag stored in [AppSettings.language] matches the same locale that the
        //   string resources are resolved in, so labels and values agree. Falls
        //   back to Locale.getDefault() when no language has been stored yet (empty
        //   string sentinel on first launch before applyLanguageOnFirstLaunch runs).
        val formattingLocale = if (settings.language.isNotEmpty())
            Locale.forLanguageTag(settings.language) else Locale.getDefault()
        val monthLabel  = monthStart.month.getDisplayName(TextStyle.FULL_STANDALONE, formattingLocale)
        val fmt       = DateTimeFormatter.ofPattern("d.M.")
        val weekLabel = "${windowStart.format(fmt)}–${windowEnd.format(fmt)}"

        combine(
            entryRepo.getEntriesForDate(today),
            drinkRepo.drinks,
            entryRepo.getDailySummaries(DayResolver.formatDate(windowStart), DayResolver.formatDate(windowEnd)),
            entryRepo.getDailySummaries(historyFrom, DayResolver.formatDate(windowEnd)),
            ticker
        ) { entries, drinks, weeklySummaries, historySummaries, _ ->
            val totalGrams = entries.sumOf { it.gramsAlcohol }

            // BAC calculation: only use entries with actual alcohol (> 0 %) so that
            // alcohol-free entries don't push the "first drink" timestamp earlier than
            // the real drinking episode started.
            val alcoholEntries = entries.filter { it.alcoholPercent > 0.0 }
            val nowMillis      = System.currentTimeMillis()
            val bac: Double? = if (settings.weightKg > 0 && alcoholEntries.isNotEmpty()) {
                val firstTs      = alcoholEntries.minOf { it.timestampMillis }
                val hoursElapsed = (nowMillis - firstTs) / AlcoholCalculator.MILLIS_PER_HOUR
                AlcoholCalculator.calculateBAC(totalGrams, settings.weightKg, hoursElapsed)
            } else null

            // Split the widened query into this month and everything before it
            // (within the baseline window). The current month uses the superposition
            // rule; the baseline is its summed grams over the full day count from the
            // statistics start to the day before this month. Trend.of yields FLAT
            // when there is no baseline or the two are equal at 0.1 g.
            val curMonth     = historySummaries.filter { it.date >= monthStr }
            val curMonthAvg  = run {
                val days = DayResolver.effectivePeriodDays(
                    from            = monthStr,
                    today           = today,
                    todayIsDrinkDay = curMonth.any { it.date == today }
                )
                if (days > 0) curMonth.sumOf { it.totalGrams } / days else 0.0
            }
            val baselineSum  = historySummaries.filter { it.date < monthStr }.sumOf { it.totalGrams }
            val baselineAvg  = if (baselineDays > 0) baselineSum / baselineDays else 0.0

            TodayUiState(
                entries           = entries,
                totalGrams        = totalGrams,
                limitInfo         = limitInfo,
                drinkDaysThisWeek = weeklySummaries.count { it.totalGrams > 0.0 },
                weeklyTotalGrams  = weeklySummaries.sumOf { it.totalGrams },
                weeklyRangeLabel  = weekLabel,
                // Per-day average for the current month (app-wide superposition rule),
                // plus its trend versus the all-time-before-this-month baseline.
                monthlyAvgPerDay  = curMonthAvg,
                monthTrend        = Trend.of(curMonthAvg, baselineAvg),
                currentMonthLabel = monthLabel,
                bacPermille       = bac,
                favorites         = drinks.filter { it.isFavorite },
                settings          = settings
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TodayUiState())

    /**
     * Logs a new consumption entry for the current logical day.
     *
     * Invalid input (non-positive volume or timestamp) is rejected as a
     * belt-and-suspenders guard even though the UI validates first.
     *
     * @param drink           The selected drink definition.
     * @param volumeMl        Serving volume in millilitres (> 0).
     * @param timestampMillis Consumption time as epoch milliseconds (> 0).
     * @param note            Optional free-text note.
     */
    fun addEntry(drink: DrinkDefinition, volumeMl: Int, timestampMillis: Long, note: String) {
        // Input guard: the UI validates before calling, but we reject invalid
        // values here as a belt-and-suspenders measure to prevent corrupt data
        // from entering the database regardless of the call-site.
        if (volumeMl <= 0 || timestampMillis <= 0) {
            if (BuildConfig.DEBUG) {
                Log.w(TAG, "addEntry: rejected invalid input (volumeMl=$volumeMl, timestampMillis=$timestampMillis)")
            }
            return
        }
        viewModelScope.launch {
            // Read the current settings from the already-active StateFlow
            // value instead of calling prefs.settingsFlow.first(). Both approaches
            // are correct, but settingsFlow.first() triggers an additional collection
            // on the DataStore flow even though uiState is already collecting it.
            // uiState.value.settings is always up-to-date because uiState is a hot
            // StateFlow backed by SharingStarted.WhileSubscribed – the same settings
            // emission that TodayViewModel uses for BAC calculation is the one we read
            // here. Skipping the extra first() call eliminates a redundant upstream
            // subscription and a minor coroutine overhead on every button tap.
            entryRepo.addFromDrink(drink, volumeMl, timestampMillis, note, uiState.value.settings)
        }
    }

    /**
     * Persists edits to an existing [entry], recomputing derived values from the
     * current settings. @param entry The modified consumption entry.
     */
    fun updateEntry(entry: ConsumptionEntry) {
        // Same rationale as addEntry – read from the hot StateFlow.
        viewModelScope.launch { entryRepo.updateEntry(entry, uiState.value.settings) }
    }

    /** Deletes [entry] from the database. @param entry The entry to remove. */
    fun deleteEntry(entry: ConsumptionEntry) {
        viewModelScope.launch { entryRepo.delete(entry) }
    }
}
