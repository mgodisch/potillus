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
// CalendarViewModel.kt – ViewModel for the Calendar screen
// =============================================================================
//
// RESPONSIBILITIES:
//   - Manages month / year navigation state and day selection.
//   - Exposes [CalendarUiState] built from a two-stage flatMapLatest chain:
//     Stage 1 loads daily summaries for the visible period;
//     Stage 2 loads individual entries for the selected date only when needed.
//   - Keeps the two DB queries independent so that tapping a day does not
//     re-trigger the heavier period query.
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
import de.godisch.potillus.domain.model.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
// ════════════════════════════════════════════════════════════════════════════
// CALENDAR
// ════════════════════════════════════════════════════════════════════════════

enum class CalendarViewMode { MONTH, YEAR }

/**
 * UI state for the Calendar screen.
 *
 * NOTE: CalendarUiState intentionally contains no BAC estimate field.
 * The Widmark formula computes BAC as a function of *hours elapsed since the
 * first drink* – a value that is only meaningful relative to *now*. For any
 * historical date in the calendar, there is no sensible "now" to anchor the
 * elapsed-time calculation, so displaying a BAC would be misleading.
 * BAC is shown only on the Today screen, where the elapsed time is always
 * (System.currentTimeMillis() − firstDrinkTimestamp).
 */
@Immutable
data class CalendarUiState(
    val viewMode: CalendarViewMode              = CalendarViewMode.MONTH,
    val currentMonth: YearMonth                 = YearMonth.now(),
    val currentYear: Int                        = LocalDate.now().year,
    /** Logical today as a LocalDate, respecting the configured day-change time. */
    val today: LocalDate                        = LocalDate.now(),
    val daySummaries: Map<String, DaySummary>   = emptyMap(),
    val selectedDate: String?                   = null,
    val selectedEntries: List<ConsumptionEntry> = emptyList(),
    val totalGramsSelected: Double              = 0.0,
    val limitInfo: LimitInfo                    = LimitInfo(20.0, 100.0, 5),
    /**
     * First weekday for month-grid alignment (ISO 1 = Monday … 7 = Sunday).
     * Derived from the device locale via [DayResolver.firstDayOfWeekIso] — the app
     * no longer exposes a user setting for this. Affects only the visual column
     * order of the calendar, not any consumption metric.
     */
    val weekStartDay: Int                       = 1
)

/**
 * Intermediate value that bridges the `combine` operator and the downstream `flatMapLatest`.
 *
 * WHY does this class exist?
 *   [CalendarViewModel.uiState] is built from a chain of two operators:
 *   1. `combine(5 flows) { … }` – merges navigation state, selected date, and settings
 *      into a single object. combine() produces a non-Flow value, so it cannot be
 *      directly piped into a Flow<…> operator.
 *   2. `.flatMapLatest { params -> entryRepo.getDailySummaries(…) }` – switches to a
 *      new database-query Flow whenever any of the 5 upstream flows changes.
 *
 *   `flatMapLatest` receives a *value* (not a Flow), transforms it into a *new Flow*,
 *   and subscribes to that inner Flow – cancelling the previous subscription whenever
 *   a new value arrives. The lambda of flatMapLatest must return a Flow<…>, which is
 *   why the combine result is a CalendarParams *value* (not a Flow<CalendarUiState>).
 *
 * WHY a data class instead of a Pair/Triple?
 *   Named properties are far more readable and refactoring-safe than positional
 *   `.first`, `.second`, `.third`, etc.
 */
private data class CalendarParams(
    val mode: CalendarViewMode,
    val month: YearMonth,
    val year: Int,
    val today: LocalDate,
    val selDate: String?,
    val limitInfo: LimitInfo,
    val from: String,
    val to: String,
    val weekStart: Int
)

@OptIn(ExperimentalCoroutinesApi::class)
class CalendarViewModel(
    private val entryRepo: IEntryRepository,
    private val drinkRepo: IDrinkRepository,
    private val prefs: IAppPreferences
) : ViewModel() {

    companion object {
        private const val TAG = "CalendarViewModel"
    }

    private val _viewMode     = MutableStateFlow(CalendarViewMode.MONTH)
    // Note: _month uses the current calendar date for initial navigation.
    // It is intentionally NOT derived from DayResolver, because the user always
    // wants to start navigating from the current calendar month/year, regardless of
    // whether the logical "today" has crossed midnight yet.
    //
    // The year is derived from _month rather than stored as a separate
    // MutableStateFlow. Keeping a separate _year caused a synchronisation gap:
    // when switching from YEAR mode (year=2025) back to MONTH mode and then to
    // YEAR mode again, _month and _year could disagree if prevPeriod/nextPeriod
    // had advanced one but not the other. Deriving currentYear = _month.value.year
    // makes the two values structurally consistent with zero extra state.
    private val _month        = MutableStateFlow(YearMonth.now())
    private val _selectedDate = MutableStateFlow<String?>(null)

    init {
        // UX: open the Calendar with the current day already selected, so the
        // day-detail panel shows today's entries immediately instead of an empty
        // "nothing selected" state. We read the day-change settings once (the
        // logical "today" depends on the configured day-change time) and seed the
        // selection. This is a one-time default: selectDate()/clearSelection()
        // remain fully in control afterwards, and navigating to another month does
        // not re-trigger it.
        viewModelScope.launch {
            val settings = prefs.settingsFlow.first()
            _selectedDate.value =
                DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
        }
    }

    val drinks: StateFlow<List<DrinkDefinition>> = drinkRepo.drinks
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val uiState: StateFlow<CalendarUiState> = combine(
        _viewMode, _month, _selectedDate, prefs.settingsFlow
    ) { mode, month, selDate, settings ->
        val todayStr  = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
        val todayDate = DayResolver.parseDate(todayStr)
        // year is always derived from the current _month value so both
        // are structurally consistent without a separate StateFlow.
        val year = month.year
        val (from, to) = when (mode) {
            CalendarViewMode.MONTH -> DayResolver.formatDate(month.atDay(1)) to DayResolver.formatDate(month.atEndOfMonth())
            CalendarViewMode.YEAR  -> "$year-01-01" to "$year-12-31"
        }
        CalendarParams(mode, month, year, todayDate, selDate, AlcoholCalculator.getLimitInfo(settings), from, to, DayResolver.firstDayOfWeekIso())
    }
    // ── Stage 1: load day summaries for the visible period ────────────────
    // flatMapLatest cancels the previous inner Flow and starts a new one every
    // time CalendarParams emits. This ensures that navigating to a different
    // month/year immediately re-queries the database for the new date range,
    // and the old query's results are discarded.
    .flatMapLatest { p ->
        entryRepo.getDailySummaries(p.from, p.to).map { summaries ->
            CalendarUiState(
                viewMode     = p.mode,
                currentMonth = p.month,
                currentYear  = p.year,
                today        = p.today,
                daySummaries = summaries.associateBy { it.date },
                selectedDate = p.selDate,
                limitInfo    = p.limitInfo,
                weekStartDay = p.weekStart
            )
        }
    }
    // ── Stage 2: if a date is selected, load its individual entries ───────
    // A second flatMapLatest is chained on top of Stage 1.
    // It receives a CalendarUiState (= "base") and:
    //   - If a date is selected: returns a new Flow that re-emits whenever
    //     entries for that date change (user adds/edits/deletes from here).
    //     base.copy(…) merges the entry list into the existing state without
    //     re-triggering Stage 1.
    //   - If no date is selected: wraps base in flowOf(base) – a Flow that
    //     emits exactly once and completes, effectively a no-op pass-through.
    // WHY two chained flatMapLatest?
    //   The two database queries (summaries and entries) have different
    //   triggering conditions: summaries reload when the date range changes;
    //   entries reload when the selected date changes OR when a new entry
    //   is added. Keeping them in separate stages avoids re-querying summaries
    //   just because the user tapped a day.
    .flatMapLatest { base ->
        val date = base.selectedDate
        if (date != null) {
            entryRepo.getEntriesForDate(date).map { entries ->
                base.copy(
                    selectedEntries    = entries,
                    totalGramsSelected = entries.sumOf { it.gramsAlcohol }
                )
            }
        } else {
            flowOf(base)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CalendarUiState())

    /**
     * Toggles between MONTH and YEAR calendar views and clears the current day
     * selection (a selection from one view is meaningless in the other).
     */
    fun toggleViewMode() {
        _viewMode.value     = if (_viewMode.value == CalendarViewMode.MONTH) CalendarViewMode.YEAR else CalendarViewMode.MONTH
        _selectedDate.value = null
    }

    /** Navigate to the previous month (MONTH mode) or previous year (YEAR mode). */
    fun prevPeriod() {
        // In YEAR mode, advance _month by 12 months so that _month.value.year
        // (which drives CalendarParams.year) updates atomically with the navigation.
        // Previously a separate _year StateFlow was decremented here; removing it
        // eliminates the gap where _month and _year could momentarily disagree.
        if (_viewMode.value == CalendarViewMode.MONTH) _month.value = _month.value.minusMonths(1)
        else _month.value = _month.value.minusYears(1)
    }

    /** Navigate to the next month (MONTH mode) or next year (YEAR mode). */
    fun nextPeriod() {
        if (_viewMode.value == CalendarViewMode.MONTH) _month.value = _month.value.plusMonths(1)
        else _month.value = _month.value.plusYears(1)
    }

    /** Selects (or, with `null`, clears) the calendar day [date] ("YYYY-MM-DD"). */
    fun selectDate(date: String?) { _selectedDate.value = date }

    /**
     * Logs a new entry on the currently selected calendar day.
     *
     * If no day is selected the entry falls back to today's logical date (this
     * should not happen via the normal UI flow and is logged in debug builds).
     *
     * @param drink           The selected drink definition.
     * @param volumeMl        Serving volume in millilitres (> 0).
     * @param timestampMillis Consumption time as epoch milliseconds (> 0).
     * @param note            Optional free-text note.
     */
    fun addEntry(drink: DrinkDefinition, volumeMl: Int, timestampMillis: Long, note: String) {
        // Same guard as TodayViewModel.addEntry – see there for rationale.
        if (volumeMl <= 0 || timestampMillis <= 0) {
            if (BuildConfig.DEBUG) {
                Log.w(TAG, "addEntry: rejected invalid input (volumeMl=$volumeMl, timestampMillis=$timestampMillis)")
            }
            return
        }
        viewModelScope.launch {
            val settings    = prefs.settingsFlow.first()
            // Log a warning when no date is selected and we fall back to
            // "today". On the Calendar screen this should not normally happen because
            // the UI only shows the Add-entry dialog when a day is selected. If it
            // does happen (e.g. a future deep-link bypasses the selection step), the
            // fallback is safe but worth flagging in debug builds so the caller can
            // be corrected without silent misbehaviour.
            val logicalDate = _selectedDate.value ?: run {
                val today = DayResolver.today(settings.dayChangeHour, settings.dayChangeMinute)
                if (BuildConfig.DEBUG) {
                    Log.w(TAG, "addEntry: no date selected, falling back to today ($today)")
                }
                today
            }
            entryRepo.addFromDrinkWithDate(drink, volumeMl, timestampMillis, note, logicalDate)
        }
    }

    /**
     * Updates a calendar entry, preserving its [ConsumptionEntry.logicalDate].
     *
     * Unlike [TodayViewModel.updateEntry], this does NOT recalculate logicalDate from
     * the timestamp, because calendar entries are deliberately assigned to a specific
     * date that may differ from the wall-clock date of the timestamp.
     */
    fun updateEntry(entry: ConsumptionEntry) {
        viewModelScope.launch { entryRepo.update(entry) }  // preserves logicalDate
    }

    /** Deletes [entry] from the database. @param entry The entry to remove. */
    fun deleteEntry(entry: ConsumptionEntry) {
        viewModelScope.launch { entryRepo.delete(entry) }
    }
}
