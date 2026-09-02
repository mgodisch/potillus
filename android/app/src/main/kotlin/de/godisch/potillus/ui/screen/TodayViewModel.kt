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
import de.godisch.potillus.l10n.shortDayMonthPattern
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
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
    val entries: List<ConsumptionEntry> = emptyList(),
    val totalGrams: Double = 0.0,
    // Derived from AppSettings, not restated: this seed is what the screen shows
    // for the instant before the first real emission, and a literal here drifted
    // from the shipped defaults once already (0.84.0 QA round).
    val limitInfo: LimitInfo = AlcoholCalculator.getLimitInfo(AppSettings()),
    /** Number of distinct days in the trailing 7-day window with ≥1 entry (today included if applicable). */
    val drinkDaysThisWeek: Int = 0,
    val weeklyTotalGrams: Double = 0.0,
    val weeklyRangeLabel: String = "",
    /**
     * Average grams per day for the current calendar month so far: the month's
     * cumulated grams divided by the number of days elapsed (1st of month …
     * today, inclusive). Matches the current month's bar in the year-view chart.
     */
    val monthlyAvgPerDay: Double = 0.0,
    /**
     * Trend of [monthlyAvgPerDay] vs. the per-day average over the whole period
     * from the configured statistics start date up to the day before this month
     * (FLAT when there is no such baseline or the two are equal at 0.1 g).
     */
    val monthTrend: Trend = Trend.FLAT,
    /**
     * Completed alcohol-free days up to, but not including, today (see
     * [de.godisch.potillus.domain.DayResolver.computeCurrentAbstinence]). Zero
     * whenever alcohol was logged today, so a value above zero always means
     * today stands at 0.0 g and at least one full dry day lies behind it. The
     * same figure the Statistics screen shows as the current abstinence.
     */
    val currentAbstinence: Int = 0,
    /** Localized standalone name of the current month (e.g. "June" / "Juni"). */
    val currentMonthLabel: String = "",
    val bacPermille: Double? = null,
    val favorites: List<DrinkDefinition> = emptyList(),
    val settings: AppSettings = AppSettings(),
)

@OptIn(ExperimentalCoroutinesApi::class)
class TodayViewModel(
    private val entryRepo: IEntryRepository,
    private val drinkRepo: IDrinkRepository,
    private val prefs: IAppPreferences,
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
     * WHERE it is used (twice, with different jobs):
     *   1. OUTSIDE the flatMapLatest, combined with the settings, it re-derives
     *      the logical day once per minute so the whole pipeline rolls over at
     *      the configured day-change time even while the screen stays open.
     *      `distinctUntilChanged` swallows the tick unless the day (or the
     *      settings) actually changed, so this does NOT restart the DB queries
     *      every minute — only at the boundary (see [uiState]).
     *   2. INSIDE the flatMapLatest's combine it recalculates the BAC snapshot
     *      each minute. Placing this role inside means only the combine lambda
     *      re-runs; the DB Flows remain active and undisturbed, avoiding the
     *      visible flicker a full restart would cause.
     *
     * WHY 60 seconds?
     *   BAC changes roughly 0.15 ‰/h = 0.0025 ‰/min. A one-minute resolution
     *   is imperceptible for the user but keeps battery impact negligible
     *   (one wakeup per minute vs continuous). Shorter intervals would not add
     *   meaningful accuracy. It also bounds the day-rollover latency to one
     *   minute, matching the resolution of the day-change setting itself.
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
        drinkRepo.drinks,
    ) { recent, drinks ->
        drinks.firstOrNull { it.id == recent?.drinkId } ?: drinks.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /**
     * UI state flow.
     *
     * The OUTER stream pairs [prefs.settingsFlow] with the [ticker] and derives
     * the logical day from both, so "today" is recalculated when the settings
     * change (the day-change time lives there) AND once per minute while the
     * screen is subscribed. `distinctUntilChanged` then swallows every tick on
     * which neither the settings nor the resulting day string actually changed,
     * so the flatMapLatest below — and with it all DB queries — restarts exactly
     * twice a day at most (day rollover) plus on real settings edits.
     *
     * WHY the day must be an INPUT of flatMapLatest (v0.79.0 QA fix):
     *   "today" used to be computed once inside the flatMapLatest lambda, which
     *   was keyed on settings alone. With the screen continuously subscribed
     *   across the configured day boundary (the 04:00 default exists precisely
     *   for late evenings), every date-scoped query — today's entries, the
     *   7-day window, the month total — stayed pinned to the PREVIOUS day:
     *   a drink logged after the boundary was correctly stored under the new
     *   logical date and therefore invisible on the Today screen until the
     *   subscriber count dropped to zero for > 5 s (WhileSubscribed) or the
     *   settings changed.
     */
    val uiState: StateFlow<TodayUiState> = combine(prefs.settingsFlow, ticker) { settings, _ ->
        settings to DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
    }.distinctUntilChanged().flatMapLatest { (settings, today) ->
        val limitInfo = AlcoholCalculator.getLimitInfo(settings)
        // Rolling 7-day window: today plus the previous six calendar days (inclusive).
        // This replaces the former fixed calendar week so the "weekly" gram total and
        // drink-day count never reset on a weekday boundary. The field names below
        // keep the historical "weekly*" spelling to avoid churn; they now denote the
        // trailing-7-day figures.
        val windowEnd = DayResolver.parseDate(today)
        val windowStart = windowEnd.minusDays(6)
        // First day of the calendar month that contains "today"; used for the
        // "month total" figure shown next to today's total on the summary card.
        val monthStart = windowEnd.withDayOfMonth(1)
        // Reference window for the Today trend arrow: the per-day average over the
        // whole time from the configured statistics start date up to the day before
        // this month. The daily-summary query below is widened to start there.
        val monthStr = DayResolver.formatDate(monthStart)
        val prevEnd = monthStart.minusDays(1) // last day before this month
        val statsFloor = settings.statsFromDate // "" = not configured
        // A baseline only exists when the statistics start lies before this month.
        val hasBaseline = statsFloor.isNotEmpty() && statsFloor < monthStr
        // Lower bound of the CURRENT month's figures. Normally the 1st of the
        // month — but a statistics start date INSIDE the running month clips it
        // (v0.81.0 QA fix): before this, a mid-month floor was silently ignored
        // here, so the card's monthly average included entries and days the user
        // had excluded, contradicting the setting's documented contract
        // ("Entries before this date are ignored in all statistics", see
        // R.string.stats_from_desc) and disagreeing with the Statistics screen's
        // MONTH view, which clips correctly. `monthFromStr` feeds the widened
        // query's lower bound (when no earlier baseline exists), the curMonth
        // filter and the effective-day divisor below, so sum, filter and divisor
        // always cover the identical span.
        val monthFromStr = if (statsFloor.isNotEmpty() && statsFloor > monthStr) statsFloor else monthStr
        val historyFrom = if (hasBaseline) statsFloor else monthFromStr
        val baselineDays = if (hasBaseline) {
            (prevEnd.toEpochDay() - DayResolver.parseDate(statsFloor).toEpochDay() + 1).toInt()
        } else {
            0
        }
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
        //   back to Locale.getDefault() while no language is chosen — the "(System)"
        //   state, which since v0.86.0 is the normal one (PotillusApp.applySystemLanguage
        //   no longer writes the detected tag into the preferences). The UI then
        //   runs in LocaleDetector's fold of the system language and the numbers in
        //   the system locale itself; the two differ only where the fold does (nn →
        //   nb, zh-Hant-HK → zh-TW), and those pairs format alike.
        //
        // RELATION TO Context.formattingLocale():
        //   Elsewhere the per-app formatting locale is read from a Context's
        //   configuration via [de.godisch.potillus.l10n.formattingLocale]. This
        //   ViewModel deliberately holds NO Context (see the class header — it is
        //   kept Context-free so it stays JVM-unit-testable), so it reads the same
        //   per-app locale from its persisted SOURCE instead: [AppSettings.language]
        //   and AppCompatDelegate's application locales are written together by
        //   the Settings picker, so a CHOSEN tag here and Context.formattingLocale()
        //   elsewhere resolve to the same locale. They are two views of one value,
        //   not two independent sources — do not "reconcile" them by injecting a
        //   Context. (For the empty choice see the fallback note above.)
        val formattingLocale = if (settings.language.isNotEmpty()) {
            Locale.forLanguageTag(settings.language)
        } else {
            Locale.getDefault()
        }
        val monthLabel = monthStart.month.getDisplayName(TextStyle.FULL_STANDALONE, formattingLocale)
        // Weekly range label ("28.6–4.7" / "6/28–7/4"): the day/month ORDER and
        // SEPARATOR follow the same per-app locale as the month name above.
        // shortDayMonthPattern derives them from the locale's SHORT date pattern
        // (see l10n/DatePatterns.kt) — the previously hard-coded "d.M." showed
        // the European order for every language, including en-US/ja/zh.
        val fmt = DateTimeFormatter.ofPattern(shortDayMonthPattern(formattingLocale), formattingLocale)
        val weekLabel = "${windowStart.format(fmt)}–${windowEnd.format(fmt)}"

        combine(
            // TWO logical days, not one. The screen shows today's rows, but the
            // blood-alcohol estimate must not fall off a cliff at the day-change
            // time: someone who drank until three in the morning is not sober at
            // four. Yesterday plus today spans at least 24 and at most 48 hours,
            // which covers any dose that can still be showing — beyond that even
            // a heavy evening has been eliminated, and calculateBAC clamps such
            // doses to nothing anyway, so a wider span would only cost rows.
            // The query is the one the Calendar screen already uses, over the
            // indexed logicalDate column; today's rows are filtered out below.
            entryRepo.getEntriesForPeriod(DayResolver.formatDate(windowEnd.minusDays(1)), today),
            drinkRepo.drinks,
            entryRepo.getDailySummaries(DayResolver.formatDate(windowStart), DayResolver.formatDate(windowEnd)),
            entryRepo.getDailySummaries(historyFrom, DayResolver.formatDate(windowEnd)),
            // The ticker keeps its role as the BAC clock (see its KDoc) and carries
            // the drink-day dates along: the typed `combine` overloads stop at five
            // sources, and the streak needs the whole history, not just the queried
            // windows above. The date list changes only when an entry is written, so
            // the minute tick re-emits the previous list unchanged.
            combine(entryRepo.getDrinkDatesFlow(), ticker) { drinkDates, _ -> drinkDates },
        ) { recentEntries, drinks, weeklySummaries, historySummaries, drinkDates ->
            // The screen's own list and its gram total stay scoped to today: they
            // answer "how much have I had today", which is what the limits are
            // measured against. Only the estimate below reaches back further.
            val entries = recentEntries.filter { it.logicalDate == today }
            val totalGrams = entries.sumOf { it.gramsAlcohol }

            // Blood-alcohol estimate over both logical days. calculateBAC drops
            // alcohol-free doses itself, so nothing needs pre-filtering here; it
            // also drops doses that lie in the future, which a retroactively
            // entered drink can be.
            val nowMillis = System.currentTimeMillis()
            val bac: Double? = if (settings.weightKg > 0) {
                AlcoholCalculator.calculateBAC(
                    doses = recentEntries.map { AlcoholDose(it.timestampMillis, it.gramsAlcohol) },
                    weightKg = settings.weightKg,
                    nowMillis = nowMillis,
                    // Absent rather than zero: a reading of 0.0 ‰ would be a claim
                    // about the body, and the estimate is not one. The row goes
                    // away instead.
                ).takeIf { it > 0.0 }
            } else {
                null
            }

            // Split the widened query into this month and everything before it
            // (within the baseline window). The current month uses the superposition
            // rule; the baseline is its summed grams over the full day count from the
            // statistics start to the day before this month. Trend.of yields FLAT
            // when there is no baseline or the two are equal at 0.1 g.
            //
            // The current month's slice starts at monthFromStr — the 1st of the
            // month, or the statistics start date when that lies inside the
            // running month (see the monthFromStr derivation above). The baseline
            // split below can keep comparing against monthStr: when the floor is
            // mid-month there IS no baseline (hasBaseline is false, the query
            // starts at monthFromStr), so the `< monthStr` branch is empty anyway.
            val curMonth = historySummaries.filter { it.date >= monthFromStr }
            val curMonthAvg = run {
                val days = DayResolver.effectivePeriodDays(
                    from = monthFromStr,
                    today = today,
                    todayIsDrinkDay = curMonth.any {
                        it.date == today && AlcoholCalculator.isDrinkDay(it.totalGrams)
                    },
                )
                if (days > 0) curMonth.sumOf { it.totalGrams } / days else 0.0
            }
            val baselineSum = historySummaries.filter { it.date < monthStr }.sumOf { it.totalGrams }
            val baselineAvg = if (baselineDays > 0) baselineSum / baselineDays else 0.0

            TodayUiState(
                entries = entries,
                totalGrams = totalGrams,
                limitInfo = limitInfo,
                drinkDaysThisWeek = AlcoholCalculator.drinkDates(weeklySummaries).size,
                weeklyTotalGrams = weeklySummaries.sumOf { it.totalGrams },
                weeklyRangeLabel = weekLabel,
                // Per-day average for the current month (app-wide superposition rule),
                // plus its trend versus the all-time-before-this-month baseline.
                monthlyAvgPerDay = curMonthAvg,
                monthTrend = Trend.of(curMonthAvg, baselineAvg, hasBaseline = hasBaseline),
                currentMonthLabel = monthLabel,
                // Same call and same arguments as the Statistics screen's current
                // streak, so the two screens can only ever show one number. The
                // statistics start date is passed for the case with no alcohol on
                // record at all: the streak then runs from the day the user chose
                // to start counting.
                currentAbstinence = DayResolver.computeCurrentAbstinence(
                    sortedDates = drinkDates, // the floor is applied inside
                    today = today,
                    statsFrom = statsFloor,
                ),
                bacPermille = bac,
                favorites = drinks.filter { it.isFavorite },
                settings = settings,
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
            // Read the settings from prefs.settingsFlow.first(), NOT from
            // uiState.value.settings. uiState is a hot StateFlow, but its value
            // only reflects real settings AFTER the first combine emission; before
            // that (stateIn's initial value) it holds the AppSettings() DEFAULTS —
            // notably a 04:00 day-change time. An entry added through that window
            // would be filed under the wrong logical date. settingsFlow.first()
            // costs one short extra DataStore collection per button tap and is
            // always correct; CalendarViewModel.addEntry uses the same approach.
            val settings = prefs.settingsFlow.first()
            entryRepo.addFromDrink(drink, volumeMl, timestampMillis, note, settings)
        }
    }

    /**
     * Persists edits to an existing [entry], recomputing derived values from the
     * current settings. @param entry The modified consumption entry.
     */
    fun updateEntry(entry: ConsumptionEntry) {
        // Same rationale as addEntry – read the authoritative settings snapshot.
        viewModelScope.launch {
            entryRepo.updateEntry(entry, prefs.settingsFlow.first())
        }
    }

    /** Deletes [entry] from the database. @param entry The entry to remove. */
    fun deleteEntry(entry: ConsumptionEntry) {
        viewModelScope.launch { entryRepo.delete(entry) }
    }
}
