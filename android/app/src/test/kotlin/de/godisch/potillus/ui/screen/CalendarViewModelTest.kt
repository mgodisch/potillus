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
package de.godisch.potillus.ui.screen

// =============================================================================
// CalendarViewModelTest.kt – Unit tests for CalendarViewModel
// =============================================================================
//
// SCOPE:
//   These tests exercise the *navigation and selection* layer of CalendarViewModel
//   (month/year navigation, day selection, entry add/update/delete) without
//   touching the Android framework. The reactive DB queries are covered by
//   FakeEntryRepository, which re-emits whenever the in-memory store changes.
//
// SETUP: same dispatcher pattern as TodayViewModelTest.
//   UnconfinedTestDispatcher runs coroutines eagerly, so launched coroutines in
//   addEntry/deleteEntry complete before the next assertion line.
//
// TURBINE:
//   StateFlow.test { } collects emissions in a background coroutine. awaitItem()
//   suspends until the next emission arrives. cancelAndIgnoreRemainingEvents()
//   tears down the collector without failing for unconsumed items.
// =============================================================================

import app.cash.turbine.test
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class CalendarViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    private lateinit var entryRepo: FakeEntryRepository
    private lateinit var drinkRepo: FakeDrinkRepository
    private lateinit var prefs: FakeAppPreferences

    /** Creates a new ViewModel wired to the current fake dependencies. */
    private fun makeVm() = CalendarViewModel(entryRepo, drinkRepo, prefs)

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        entryRepo = FakeEntryRepository()
        drinkRepo = FakeDrinkRepository()
        prefs = FakeAppPreferences(AppSettings(dayChangeHour = 4, dayChangeMinute = 0))
    }

    @After fun tearDown() = Dispatchers.resetMain()

    // ── Initial state ─────────────────────────────────────────────────────────

    /**
     * On construction the ViewModel starts in MONTH view and
     * pre-selects the logical "today" so the day-detail panel opens populated.
     * The pre-selection is seeded asynchronously from settings, so the first
     * emission may still carry the default (null) selection before "today" lands;
     * we therefore await until the selection is populated.
     *
     * With an empty entry repository, the selected day has no entries.
     */
    @Test fun `initial state pre-selects logical today with empty entries`() = runTest {
        val vm = makeVm()
        val today = DayResolver.today(4, 0) // matches the day-change time in setUp
        vm.uiState.test {
            var state = awaitItem()
            while (state.selectedDate == null) state = awaitItem()
            assertEquals(CalendarViewMode.MONTH, state.viewMode)
            assertEquals(today, state.selectedDate)
            assertTrue(state.selectedEntries.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── View mode ─────────────────────────────────────────────────────────────

    /**
     * Calling toggleViewMode() flips the state between MONTH and YEAR.
     *
     * Verifies that the `_viewMode` StateFlow is exposed through `uiState`
     * and that the combine pipeline re-emits on every change.
     */
    @Test fun `toggleViewMode switches between MONTH and YEAR`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            assertEquals(CalendarViewMode.MONTH, awaitItem().viewMode)

            vm.toggleViewMode() // MONTH -> YEAR
            // The async "today" pre-selection can interleave an extra MONTH
            // emission here, so drain until the view mode actually flips.
            var s = awaitItem()
            while (s.viewMode != CalendarViewMode.YEAR) s = awaitItem()
            assertEquals(CalendarViewMode.YEAR, s.viewMode)

            vm.toggleViewMode() // YEAR -> MONTH
            s = awaitItem()
            while (s.viewMode != CalendarViewMode.MONTH) s = awaitItem()
            assertEquals(CalendarViewMode.MONTH, s.viewMode)

            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Month navigation ──────────────────────────────────────────────────────

    /**
     * prevPeriod() in MONTH mode moves the displayed month back by one.
     *
     * Verifies that the navigation state is reflected in the emitted uiState
     * and that the ViewModel uses `YearMonth` arithmetic correctly.
     */
    @Test fun `prevPeriod moves month back by one`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            val initial = awaitItem().currentMonth

            vm.prevPeriod()
            val after = awaitItem().currentMonth

            assertEquals(initial.minusMonths(1), after)
            cancelAndIgnoreRemainingEvents()
        }
    }

    /**
     * nextPeriod() in MONTH mode advances the displayed month by one.
     */
    @Test fun `nextPeriod moves month forward by one`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            val initial = awaitItem().currentMonth

            vm.nextPeriod()
            val after = awaitItem().currentMonth

            assertEquals(initial.plusMonths(1), after)
            cancelAndIgnoreRemainingEvents()
        }
    }

    /**
     * In YEAR mode, nextPeriod() advances by 12 months (= 1 year).
     * The ViewModel advances `_month` by 12 months rather than maintaining a
     * separate `_year` StateFlow to avoid a momentary inconsistency between the two.
     */
    @Test fun `nextPeriod in YEAR mode advances by one year`() = runTest {
        val vm = makeVm()
        vm.toggleViewMode() // MONTH -> YEAR (applied before collection)
        vm.uiState.test {
            // uiState is a conflated StateFlow; currentYear is identical in every
            // pre-navigation emission (it defaults to the real current year), so
            // capture it from the first item regardless of how the mode change is
            // collapsed.
            val yearBefore = awaitItem().currentYear

            vm.nextPeriod()
            // Await until the year actually advances, tolerating any extra
            // conflated emission from the mode change settling.
            var yearAfter = awaitItem().currentYear
            while (yearAfter == yearBefore) yearAfter = awaitItem().currentYear

            assertEquals(yearBefore + 1, yearAfter)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Date selection ────────────────────────────────────────────────────────

    /**
     * selectDate() updates the selectedDate in uiState.
     *
     * This is important for AddEditEntryDialog: the dialog uses the selected date
     * as the logicalDate for new entries. If selectDate() were broken, entries would
     * be assigned to today instead of the chosen calendar day.
     */
    @Test fun `selectDate updates selectedDate in uiState`() = runTest {
        val vm = makeVm()
        vm.uiState.test {
            awaitItem() // initial (selectedDate = null)

            vm.selectDate("2026-03-15")
            assertEquals("2026-03-15", awaitItem().selectedDate)

            vm.selectDate(null)
            assertNull(awaitItem().selectedDate)

            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── Entry mutations ───────────────────────────────────────────────────────

    /**
     * addEntry() with a valid drink and a pre-selected date persists the entry to
     * the repository and the new entry appears in selectedEntries.
     *
     * TEACHING NOTE:
     *   This test verifies the critical calendar-specific contract: the logicalDate
     *   of the new entry must be the *selected calendar day*, NOT derived from the
     *   timestamp via DayResolver. A drink added to a past calendar day must stay
     *   on that day even if the user enters a timestamp that crosses the day-change
     *   boundary.
     */
    @Test fun `addEntry with selected date stores entry on correct logical date`() = runTest {
        val drink = DrinkDefinition(id = 1, name = "Pils", volumeMl = 500, alcoholPercent = 5.0)
        drinkRepo = FakeDrinkRepository(listOf(drink))
        val vm = makeVm()

        vm.selectDate("2026-01-10")
        vm.uiState.test {
            awaitItem() // initial state with selected date

            val ts = System.currentTimeMillis()
            vm.addEntry(drink, 500, ts, note = "")

            val state = awaitItem()
            assertEquals(1, state.selectedEntries.size)
            assertEquals("2026-01-10", state.selectedEntries.first().logicalDate)
            cancelAndIgnoreRemainingEvents()
        }
    }

    /**
     * addEntry() with invalid volumeMl (≤ 0) is silently rejected and does NOT
     * add an entry to the repository. This mirrors the guard in TodayViewModel.
     */
    @Test fun `addEntry with invalid volumeMl is rejected`() = runTest {
        val drink = DrinkDefinition(id = 1, name = "Pils", volumeMl = 500, alcoholPercent = 5.0)
        drinkRepo = FakeDrinkRepository(listOf(drink))
        val vm = makeVm()

        vm.selectDate("2026-01-10")
        vm.addEntry(drink, volumeMl = 0, timestampMillis = System.currentTimeMillis(), note = "")

        assertTrue("Entry with volumeMl=0 must be rejected", entryRepo.allEntries.isEmpty())
    }

    /**
     * deleteEntry() removes the entry from the repository and it no longer
     * appears in selectedEntries.
     */
    @Test fun `deleteEntry removes entry from repository`() = runTest {
        val drink = DrinkDefinition(id = 1, name = "Pils", volumeMl = 500, alcoholPercent = 5.0)
        drinkRepo = FakeDrinkRepository(listOf(drink))
        val vm = makeVm()

        vm.selectDate("2026-01-10")
        val ts = System.currentTimeMillis()
        vm.addEntry(drink, 500, ts, note = "")

        vm.uiState.test {
            val stateWithEntry = awaitItem()
            assertEquals(1, stateWithEntry.selectedEntries.size)

            val entry = stateWithEntry.selectedEntries.first()
            vm.deleteEntry(entry)

            val stateEmpty = awaitItem()
            assertTrue(stateEmpty.selectedEntries.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }
}
