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
// TodayViewModelTest.kt – Unit tests for TodayViewModel
// =============================================================================
//
// SETUP:
//   viewModelScope uses Dispatchers.Main.immediate. On the JVM there is no
//   Main dispatcher by default, so we install a TestDispatcher in @Before and
//   reset it in @After. UnconfinedTestDispatcher runs coroutines eagerly
//   (inline, without yielding), which means launched coroutines complete
//   before the next line of test code. This simplifies assertions: no need for
//   explicit advanceUntilIdle() after most operations.
//
// TURBINE:
//   StateFlow.test { } collects the flow in a background coroutine for the
//   duration of the block. awaitItem() suspends until the next emission.
//   cancelAndIgnoreRemainingEvents() tears down the collector cleanly.
// =============================================================================

import app.cash.turbine.test
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
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
class TodayViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    // Test helpers – recreated per test for isolation.
    private lateinit var entryRepo: FakeEntryRepository
    private lateinit var drinkRepo: FakeDrinkRepository
    private lateinit var prefs: FakeAppPreferences

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        entryRepo = FakeEntryRepository()
        drinkRepo = FakeDrinkRepository()
        prefs = FakeAppPreferences(AppSettings(dayChangeHour = 4, dayChangeMinute = 0))
    }

    @After fun tearDown() = Dispatchers.resetMain()

    // ── uiState ───────────────────────────────────────────────────────────────

    @Test fun `uiState initial emission has no entries and zero grams`() = runTest(dispatcher) {
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)
        vm.uiState.test {
            val state = awaitItem()
            assertTrue("Expected empty entries on first emission", state.entries.isEmpty())
            assertEquals(0.0, state.totalGrams, 0.001)
            assertNull("BAC should be null when weight is not set", state.bacPermille)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `uiState totalGrams reflects added entries`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        val now = System.currentTimeMillis()
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)

        vm.uiState.test {
            awaitItem() // initial empty state
            vm.addEntry(beer, 500, now, "")
            val state = awaitItem()
            // 500 ml × 5 % × 0.789 g/ml ≈ 19.73 g
            assertTrue("totalGrams should be > 0 after adding entry", state.totalGrams > 0.0)
            assertEquals(1, state.entries.size)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `uiState BAC is non-null when weight is set and entry exists`() = runTest(dispatcher) {
        prefs = FakeAppPreferences(AppSettings(weightKg = 75.0, dayChangeHour = 4))
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        val now = System.currentTimeMillis()
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)

        vm.uiState.test {
            awaitItem()
            vm.addEntry(beer, 500, now, "")
            val state = awaitItem()
            assertTrue(
                "BAC should be non-null when weight is set and entry exists",
                state.bacPermille != null,
            )
            assertTrue("BAC should be positive", state.bacPermille!! > 0.0)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── addEntry ──────────────────────────────────────────────────────────────

    @Test fun `addEntry with valid data persists entry in repository`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        val now = System.currentTimeMillis()
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)

        vm.addEntry(beer, 500, now, "after work")

        assertEquals(1, entryRepo.allEntries.size)
        assertEquals("after work", entryRepo.allEntries.first().note)
        assertEquals(beer.id, entryRepo.allEntries.first().drinkId)
    }

    @Test fun `addEntry with volumeMl=0 is rejected by guard`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)

        vm.addEntry(beer, 0, System.currentTimeMillis(), "")

        assertTrue("Guard should reject volumeMl=0", entryRepo.allEntries.isEmpty())
    }

    @Test fun `addEntry with timestampMillis=0 is rejected by guard`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)

        vm.addEntry(beer, 500, 0L, "")

        assertTrue("Guard should reject timestampMillis=0", entryRepo.allEntries.isEmpty())
    }

    // ── deleteEntry ───────────────────────────────────────────────────────────

    @Test fun `deleteEntry removes entry from repository`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        val now = System.currentTimeMillis()
        val vm = TodayViewModel(entryRepo, drinkRepo, prefs)

        vm.addEntry(beer, 500, now, "")
        assertEquals(1, entryRepo.allEntries.size)

        val entry = entryRepo.allEntries.first()
        vm.deleteEntry(entry)
        assertTrue("Entry should be removed after deleteEntry", entryRepo.allEntries.isEmpty())
    }

    // ── Statistics start date inside the running month (v0.81.0 QA fix) ───────

    /**
     * The Today card's monthly average honours a statistics start date that lies
     * INSIDE the running month (v0.81.0 QA regression test).
     *
     * Scenario: the floor is set to two days ago; an old entry from five days ago
     * (same month, before the floor) still exists. Before the fix the card's
     * month anchor stayed at the 1st of the month, so the pre-floor entry's grams
     * entered the sum AND the pre-floor days entered the divisor — contradicting
     * the setting's contract ("Entries before this date are ignored in all
     * statistics", R.string.stats_from_desc) and disagreeing with the Statistics
     * screen's MONTH view, which clips correctly. After the fix the month figures
     * cover exactly [floor … today]: 10 g over the 2 completed days = 5 g/day.
     *
     * The wall clock is pinned mid-June (12:00 UTC, the same safety margin the
     * PdfReportDataTest streak tests use) so today resolves to June 20th or 21st
     * depending on the runner's zone — either way all derived dates (today−5 …
     * today) stay inside one calendar month, keeping the expectation exact
     * without depending on the zone.
     */
    @Test fun `monthly average honours a mid-month statistics start date`() = runTest(dispatcher) {
        DayResolver.clockOverride = java.time.Clock.fixed(
            java.time.Instant.parse("2026-06-20T12:00:00Z"),
            java.time.ZoneOffset.UTC,
        )
        try {
            val today = DayResolver.today(4, 0)
            val todayDate = java.time.LocalDate.parse(today)
            val floor = todayDate.minusDays(2).toString()
            val preFloorDay = todayDate.minusDays(5).toString()
            val inRangeDay = todayDate.minusDays(1).toString()
            prefs = FakeAppPreferences(
                AppSettings(dayChangeHour = 4, dayChangeMinute = 0, statsFromDate = floor),
            )
            // Pre-floor grams that must NOT enter the monthly average …
            entryRepo.add(monthEntry(id = 1, date = preFloorDay, grams = 60.0))
            // … and the in-range grams that alone define it.
            entryRepo.add(monthEntry(id = 2, date = inRangeDay, grams = 10.0))

            val vm = TodayViewModel(entryRepo, drinkRepo, prefs)
            vm.uiState.test {
                // Skip the seed and any intermediate emission until the computed
                // state (non-zero average) arrives.
                var state = awaitItem()
                while (state.monthlyAvgPerDay == 0.0) state = awaitItem()
                // effectivePeriodDays(from = floor, today, todayIsDrinkDay=false)
                // = the 2 completed days [floor, today-1]; 10 g / 2 d = 5 g/day.
                assertEquals(5.0, state.monthlyAvgPerDay, 0.001)
                cancelAndIgnoreRemainingEvents()
            }
        } finally {
            DayResolver.clockOverride = null // never leak the pin to other tests
        }
    }

    /** Minimal [ConsumptionEntry] on a given logical [date] for the floor test. */
    private fun monthEntry(id: Long, date: String, grams: Double) = ConsumptionEntry(
        id = id,
        drinkId = 1L,
        drinkName = "TestDrink",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = grams,
        timestampMillis = java.time.LocalDate.parse(date)
            .atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli(),
        logicalDate = date,
    )

    // ── Logical-day rollover while subscribed (v0.79.0 QA regression) ─────────

    /**
     * A mutable fixed clock: [DayResolver.clockOverride] accepts any
     * [java.time.Clock]; this one lets the test move the wall clock forward
     * WITHOUT re-pinning (re-assigning clockOverride would not help anyway —
     * the ViewModel pipeline captured the resolver, not the clock instance).
     */
    private class MutableClock(var now: java.time.Instant) : java.time.Clock() {
        override fun getZone(): java.time.ZoneId = java.time.ZoneOffset.UTC
        override fun withZone(zone: java.time.ZoneId): java.time.Clock = this
        override fun instant(): java.time.Instant = now
    }

    /**
     * THE v0.79.0 rollover regression: with the Today screen continuously
     * subscribed across the configured day-change time (04:00), the pipeline
     * must re-anchor to the NEW logical day on the next ticker beat — the old
     * pipeline computed "today" once per settings emission, so entries logged
     * after the boundary were stored under the new date but stayed invisible.
     *
     * Virtual time (runTest) drives the once-per-minute ticker: advancing the
     * scheduler by one minute fires the tick that re-derives the day.
     */
    @Test fun `uiState rolls over to the new logical day while subscribed`() = runTest(dispatcher) {
        val clock = MutableClock(java.time.Instant.parse("2026-06-10T20:00:00Z"))
        DayResolver.clockOverride = clock
        try {
            // Logical "today" at 20:00 UTC with an 04:00 day-change is 2026-06-10.
            val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
            val vm = TodayViewModel(entryRepo, drinkRepo, prefs)
            vm.uiState.test {
                awaitItem() // initial empty state for 2026-06-10

                // One beer late in the evening → visible on the 10th.
                vm.addEntry(beer, 500, clock.now.toEpochMilli(), "")
                assertEquals(1, awaitItem().entries.size)

                // The night moves past the 04:00 boundary: 05:00 UTC on the 11th.
                // Nothing may emit yet — the pipeline notices on the next tick.
                clock.now = java.time.Instant.parse("2026-06-11T05:00:00Z")
                testScheduler.advanceTimeBy(61_000)
                testScheduler.runCurrent()

                // The pipeline re-anchored: the new logical day has no entries.
                val rolled = expectMostRecentItem()
                assertTrue(
                    "Yesterday's entry must not be shown after the rollover",
                    rolled.entries.isEmpty(),
                )

                // A drink logged AFTER the boundary lands on 2026-06-11 and must
                // be visible — this is the entry the old pipeline lost.
                vm.addEntry(beer, 500, clock.now.toEpochMilli(), "")
                assertEquals(1, expectMostRecentItem().entries.size)

                cancelAndIgnoreRemainingEvents()
            }
        } finally {
            DayResolver.clockOverride = null // never leak the pin to other tests
        }
    }
}
