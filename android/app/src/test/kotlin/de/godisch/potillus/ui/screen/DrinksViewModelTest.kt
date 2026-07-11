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

import app.cash.turbine.test
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.fake.FakeDrinkRepository
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

@OptIn(ExperimentalCoroutinesApi::class)
class DrinksViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private lateinit var drinkRepo: FakeDrinkRepository

    @Before fun setUp() {
        Dispatchers.setMain(dispatcher)
        drinkRepo = FakeDrinkRepository()
    }

    @After fun tearDown() = Dispatchers.resetMain()

    // ── uiState ───────────────────────────────────────────────────────────────

    @Test fun `uiState reflects initial drinks from repository`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        drinkRepo = FakeDrinkRepository(listOf(beer))
        val vm = DrinksViewModel(drinkRepo)

        vm.uiState.test {
            val state = awaitItem()
            assertEquals(1, state.drinks.size)
            assertEquals("Lager", state.drinks.first().name)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `uiState updates when drink is added`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)

        vm.uiState.test {
            awaitItem() // initial empty state
            vm.addDrink("Wine", 150, 13.0, DrinkCategory.WINE)
            val state = awaitItem()
            assertEquals(1, state.drinks.size)
            assertEquals("Wine", state.drinks.first().name)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── addDrink – valid input ────────────────────────────────────────────────

    @Test fun `addDrink with valid data persists drink`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("Craft IPA", 330, 6.5, DrinkCategory.BEER)

        // Verify persistence through the reactive uiState (the ViewModel's public
        // surface); the repository updates flow back into it once the launched
        // coroutine runs under the test dispatcher.
        vm.uiState.test {
            // Drain the (possible) empty stateIn seed emission, then assert the
            // drink is present. Robust regardless of emission ordering.
            var drinks = awaitItem().drinks
            while (drinks.isEmpty()) drinks = awaitItem().drinks
            assertEquals(1, drinks.size)
            assertEquals("Craft IPA", drinks.first().name)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `addDrink trims whitespace from name`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("  Weizen  ", 500, 5.4, DrinkCategory.BEER)

        vm.uiState.test {
            val name = awaitItem().drinks.firstOrNull()?.name
            assertEquals("Weizen", name)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── addDrink – invalid input guards (QA-01) ───────────────────────────────

    @Test fun `addDrink with blank name is rejected`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("   ", 500, 5.0, DrinkCategory.BEER)

        vm.uiState.test {
            assertTrue("Blank name should be rejected", awaitItem().drinks.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `addDrink with volumeMl=0 is rejected`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("Beer", 0, 5.0, DrinkCategory.BEER)

        vm.uiState.test {
            assertTrue("volumeMl=0 should be rejected", awaitItem().drinks.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `addDrink with negative alcoholPercent is rejected`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("Beer", 500, -1.0, DrinkCategory.BEER)

        vm.uiState.test {
            assertTrue("Negative alcoholPercent should be rejected", awaitItem().drinks.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `addDrink with alcoholPercent above 100 is rejected`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("Beer", 500, 101.0, DrinkCategory.BEER)

        vm.uiState.test {
            assertTrue("alcoholPercent > 100 should be rejected", awaitItem().drinks.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `addDrink with NaN alcoholPercent is rejected`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        vm.addDrink("Beer", 500, Double.NaN, DrinkCategory.BEER)

        vm.uiState.test {
            assertTrue("NaN alcoholPercent should be rejected", awaitItem().drinks.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `addDrink with name exceeding max length is rejected`() = runTest(dispatcher) {
        val vm = DrinksViewModel(drinkRepo)
        val long = "A".repeat(101)
        vm.addDrink(long, 500, 5.0, DrinkCategory.BEER)

        vm.uiState.test {
            assertTrue("Name > 100 chars should be rejected", awaitItem().drinks.isEmpty())
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ── deleteDrink ───────────────────────────────────────────────────────────

    @Test fun `deleteDrink with no entries deletes the drink`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        drinkRepo = FakeDrinkRepository(listOf(beer))
        drinkRepo.entryCounts = mapOf(1L to 0)
        val vm = DrinksViewModel(drinkRepo)

        vm.deleteDrink(beer)

        vm.uiState.test {
            assertTrue(
                "Drink should be deleted when it has no entries",
                awaitItem().drinks.isEmpty(),
            )
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test fun `deleteDrink with entries emits DeleteBlocked event`() = runTest(dispatcher) {
        val beer = DrinkDefinition(id = 1, name = "Lager", volumeMl = 500, alcoholPercent = 5.0)
        drinkRepo = FakeDrinkRepository(listOf(beer))
        drinkRepo.entryCounts = mapOf(1L to 3)
        val vm = DrinksViewModel(drinkRepo)

        vm.events.test {
            vm.deleteDrink(beer)
            val event = awaitItem()
            assertTrue(
                "Should emit DeleteBlocked when drink has entries",
                event is DrinksEvent.DeleteBlocked,
            )
            val blocked = event as DrinksEvent.DeleteBlocked
            assertEquals("Lager", blocked.drinkName)
            assertEquals(3, blocked.entryCount)
            cancelAndIgnoreRemainingEvents()
        }
    }
}
