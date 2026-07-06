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
}
