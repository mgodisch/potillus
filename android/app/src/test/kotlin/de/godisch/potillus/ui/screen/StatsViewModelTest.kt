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
// StatsViewModelTest.kt – Unit tests for StatsViewModel
// =============================================================================
//
// SCOPE:
//   These tests exercise the statistical computations exposed by StatsViewModel:
//   period selector, totalGrams, average, days-over-limit counts, abstinent days,
//   streaks, and trend percentage.
//
//   All tests use fixed date strings so they do not depend on the wall-clock
//   date. The FakeAppPreferences is initialised with statsFromDate set to a
//   known past date so the ViewModel has a well-defined recording start.
//
// TURBINE:
//   StateFlow.test { } + awaitItem() is used throughout. Because
//   UnconfinedTestDispatcher runs coroutines eagerly, the ViewModel's
//   flatMapLatest pipeline completes synchronously and the first awaitItem()
//   reflects the fully-computed state.
// =============================================================================

import app.cash.turbine.ReceiveTurbine
import app.cash.turbine.test
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.fake.FakeAppPreferences
import de.godisch.potillus.fake.FakeDrinkRepository
import de.godisch.potillus.fake.FakeEntryRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

@OptIn(ExperimentalCoroutinesApi::class)
class StatsViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    private lateinit var entryRepo: FakeEntryRepository
    private lateinit var drinkRepo: FakeDrinkRepository
    private lateinit var prefs:     FakeAppPreferences

    // StringProvider stub: returns the resource ID as a decimal string. The export
    // status messages are not asserted by value, only that they are set/cleared.
    private val testStrings: StringProvider = StringProvider { id, _ -> id.toString() }

    /** Creates a new ViewModel wired to the current fake dependencies. */
    private fun makeVm() = StatsViewModel(
        entryRepo  = entryRepo,
        drinkRepo  = drinkRepo,
        prefs      = prefs,
        // CSV/PDF export lives in StatsViewModel. A dummy Application
        // context is fine here: the tested paths (empty-range guard) never touch
        // MediaStore. getString only localises status messages.
        appContext = android.app.Application(),
        getString  = testStrings
    )

    /**
     * Converts an ISO-8601 date string to a Unix timestamp at midnight local time.
     * Used to create ConsumptionEntry values with a deterministic timestampMillis.
     */
    private fun dateToMillis(date: String): Long =
        LocalDate.parse(date)
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

    /** Convenience function: creates a minimal ConsumptionEntry for a given date and grams. */
    private fun entry(
        id: Long,
        date: String,
        grams: Double,
        drinkId: Long = 1L,
        category: DrinkCategory = DrinkCategory.BEER
    ) = ConsumptionEntry(
        id              = id,
        drinkId         = drinkId,
        drinkName       = "TestDrink",
        volumeMl        = 500,
        alcoholPercent  = 5.0,
        gramsAlcohol    = grams,
        timestampMillis = dateToMillis(date),
        logicalDate     = date
    )

    /**
     * Returns the first *computed* [StatsUiState], skipping the seed.
     *
     * `uiState` is a `stateIn(..., SharingStarted.WhileSubscribed, StatsUiState())`,
     * so a fresh collector is first handed the default `StatsUiState()` seed and only
     * afterwards the value the upstream `combine` computes. Depending on coroutine
     * scheduling, Turbine may observe that seed as a distinct first item. Tests that
     * assert on *computed* values must therefore skip any leading seed emission rather
     * than trust that the very first item is already the computed one. This helper
     * loops until it sees a state that differs from the default seed.
     *
     * It is safe for the data-bearing tests here because their computed state always
     * differs from the default (e.g. non-zero `totalGrams`), so the loop terminates.
     */
    private suspend fun ReceiveTurbine<StatsUiState>.awaitComputed(): StatsUiState {
        var state = awaitItem()
        while (state == StatsUiState()) state = awaitItem()
        return state
    }

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        entryRepo = FakeEntryRepository()
        drinkRepo = FakeDrinkRepository()
        // Use a fixed statsFromDate so streak calculations are deterministic.
        // day-change boundary at 04:00; default daily limit = 20 g.
        prefs = FakeAppPreferences(
            AppSettings(
                dayChangeHour = 4,
                dayChangeMinute = 0,
                statsFromDate = "2026-01-01"
            )
        )
    }

    @After fun tearDown() = Dispatchers.resetMain()

    // ── Initial state ─────────────────────────────────────────────────────────

    /**
     * With no entries in the repository the ViewModel emits an all-zero state
     * and the default WEEK period.
     *
     * This verifies that the flatMapLatest pipeline does not crash on an empty
     * data set and that initial values are sane defaults (not NaN / infinity).
     */
    @Test fun `initial state is all zeros with WEEK period`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            val state = awaitItem()
            assertEquals(StatsPeriod.WEEK, state.period)
            assertEquals(0.0, state.totalGrams, 0.001)
            assertEquals(0.0, state.avgPerDay, 0.001)
            assertEquals(0, state.daysOverDailyLimit)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Period selector ───────────────────────────────────────────────────────

    /**
     * setPeriod() updates the period field in the emitted state.
     *
     * The ViewModel uses `_period` as one of the combine inputs; changing it
     * must trigger a new flatMapLatest evaluation and a new emission.
     */
    @Test fun `setPeriod switches the active period`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            awaitItem()   // initial WEEK

            vm.setPeriod(StatsPeriod.MONTH)
            assertEquals(StatsPeriod.MONTH, awaitItem().period)

            vm.setPeriod(StatsPeriod.YEAR)
            assertEquals(StatsPeriod.YEAR, awaitItem().period)

            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── totalGrams and days-over-daily-limit ─────────────────────────────────

    /**
     * When entries are added that exceed the daily limit, daysOverDailyLimit
     * reflects the correct count.
     *
     * Default daily limit = 20 g. An entry with 25 g on a single day should
     * produce daysOverDailyLimit = 1.
     *
     * TEACHING NOTE:
     *   This test is intentionally independent of the wall-clock date. It adds
     *   an entry on a date within the current week's range by using
     *   FakeEntryRepository directly (bypassing the DayResolver path).
     *   The ViewModel's flatMapLatest reacts to the FakeEntryRepository emission
     *   and re-computes the stats.
     */
    @Test fun `single over-limit day is counted correctly`() = runTest {
        // Use today's date as the logical date so it falls in the current WEEK period.
        // Date the entry with the LOGICAL today — the same day-change-shifted date the
        // ViewModel derives its period from (see DayResolver.resolve). Using
        // LocalDate.now() instead puts the entry one calendar day outside the period
        // whenever the build runs between midnight and dayChangeHour (04:00 here), so
        // `current` would be empty and totalGrams 0. The args must match setUp()'s
        // AppSettings(dayChangeHour = 4, dayChangeMinute = 0).
        val today = DayResolver.today(4, 0)
        entryRepo.add(entry(id = 1, date = today, grams = 25.0))

        val vm = makeVm()
        vm.uiState.test {
            // Read the settled state, not the seed: stateIn(WhileSubscribed) seeds
            // collectors with the default StatsUiState() before the upstream produces
            // the computed value. awaitComputed() skips any leading seed emission(s).
            val state = awaitComputed()
            assertEquals(25.0, state.totalGrams, 0.001)
            assertEquals(1, state.daysOverDailyLimit)
            cancelAndIgnoreRemainingEvents()
        }
    }

    /**
     * A drink logged TODAY makes today a confirmed drink day, so it must join the
     * statistics period immediately: avgPerDay divides totalGrams by the completed
     * days PLUS today (effectivePeriodDays = abstinent days + drink days), not by
     * the completed days alone. Regression for the avgPerDay off-by-one that
     * surfaced only on days where a drink had already been logged.
     *
     * The assertion is wall-clock independent: it checks the invariant
     * avgPerDay == totalGrams / (abstinentDays + drinkDays) rather than an absolute
     * value, so it holds whatever weekday the test runs on.
     */
    @Test fun `drink today extends the effective period for avgPerDay`() = runTest {
        // Logical today, not LocalDate.now() (see the over-limit-day test for why).
        val today = DayResolver.today(4, 0)
        entryRepo.add(entry(id = 1, date = today, grams = 24.0))

        val vm = makeVm()
        vm.uiState.test {
            // Settled state, not the seed (see note in the over-limit-day test).
            val state = awaitComputed()
            assertEquals(1, state.dataPoints.size)            // today counted as a drink day
            // drinkDays == 1, so the effective period is abstinentDays + 1 (today).
            val effectivePeriodDays = state.abstinentDays + 1
            assertEquals(24.0 / effectivePeriodDays, state.avgPerDay, 0.001)
            assertTrue("today must extend the period (no divide-by-zero)", state.avgPerDay > 0.0)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Category breakdown ────────────────────────────────────────────────────

    /**
     * categoryBreakdown groups entries by DrinkCategory and sums their grams.
     *
     * Two entries from different categories should produce two separate map entries.
     * This verifies the join between the entry repository and the drink repository:
     * DrinkCategory is looked up via the drink map built inside the ViewModel.
     */
    @Test fun `categoryBreakdown sums grams per drink category`() = runTest {
        val beer = DrinkDefinition(id = 1, name = "Pils", volumeMl = 500, alcoholPercent = 5.0, category = DrinkCategory.BEER)
        val wine = DrinkDefinition(id = 2, name = "Wein", volumeMl = 150, alcoholPercent = 13.0, category = DrinkCategory.WINE)
        drinkRepo = FakeDrinkRepository(listOf(beer, wine))

        // Logical today, not LocalDate.now() (see the over-limit-day test for why).
        val today = DayResolver.today(4, 0)
        entryRepo.add(entry(id = 1, date = today, grams = 19.73, drinkId = 1, category = DrinkCategory.BEER))
        entryRepo.add(entry(id = 2, date = today, grams = 15.41, drinkId = 2, category = DrinkCategory.WINE))

        val vm = makeVm()
        vm.uiState.test {
            // Settled state, not the seed (see note in the over-limit-day test).
            val state = awaitComputed()
            // Each category must appear with its correct total
            assertEquals(19.73, state.categoryBreakdown[DrinkCategory.BEER] ?: 0.0, 0.01)
            assertEquals(15.41, state.categoryBreakdown[DrinkCategory.WINE] ?: 0.0, 0.01)
            assertTrue("No other categories expected", state.categoryBreakdown.size == 2)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Trend calculation ─────────────────────────────────────────────────────

    /**
     * trendPercent is 0.0 when there are no entries (previous period = 0 g).
     *
     * The ViewModel's computeTrend() returns 0.0 when previous == 0 to avoid
     * division by zero. This test ensures that the guard is active.
     */
    @Test fun `trendPercent is zero when previous period is empty`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            assertEquals(0.0, awaitItem().trendPercent, 0.001)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Export status (CSV/PDF export) ─────────────

    /**
     * Exporting an empty date range must surface an error status without touching
     * MediaStore (the empty-range guard returns before any I/O), and
     * clearExportStatus() must reset it. entryRepo is empty in setUp, so any range
     * yields no entries.
     */
    @Test fun `exportCsv with empty range sets error then clearExportStatus resets`() = runTest(dispatcher) {
        val vm = makeVm()
        vm.exportStatus.test {
            assertEquals("initial export status is null", null, awaitItem())
            vm.exportCsv("2024-01-01", "2024-01-01")   // no entries → ExportStatus.Err
            assertTrue("empty-range export sets an error status", awaitItem() is ExportStatus.Err)
            vm.clearExportStatus()
            assertEquals("clearExportStatus resets to null", null, awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }
}
