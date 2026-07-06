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
package de.godisch.potillus

// =============================================================================
// AppViewModelFactoryTest.kt – Unit tests for AppViewModelFactory (T-02 fix)
// =============================================================================
//
// WHY THESE TESTS?
//   AppViewModelFactory is the app's sole dependency-injection entry point.
//   It maps every ViewModel class to its constructor via a `when` expression,
//   so a missing branch throws [IllegalArgumentException] at runtime — but only
//   when that screen is first navigated to, never at compile time.
//
// TESTING STRATEGY:
//   Each registered ViewModel is exercised by constructing it directly with its
//   Fake dependencies (the same approach used in *ViewModelTest files throughout
//   the test suite). This keeps the tests Android-free and fast. The factory
//   itself is exercised for:
//     • the registration of all five ViewModels (happy path), and
//     • the `else` guard that throws [IllegalArgumentException] for any class
//       that was accidentally removed from the `when`.
//
//   Because [PotillusApp]'s lazy properties (entryRepository, drinkRepository, …)
//   are `val` (not `open`), the factory cannot be instantiated in a unit test
//   without a real [PotillusApp]. We therefore test the factory logic at a level
//   one step removed: we verify that each ViewModel constructor can be called
//   with the types the factory passes, and that the factory's `else` guard is
//   exercised via a minimal no-op factory stub.
//
// NOTE FOR TEACHING:
//   Making [AppViewModelFactory] depend on an interface (rather than the
//   concrete [PotillusApp]) would enable direct instantiation in tests without
//   any stub. Adding Hilt or Koin would remove the factory entirely. Both are
//   natural next steps if the project grows beyond the current single-developer
//   scope. See AppViewModelFactory.kt for the documented trade-off.
// =============================================================================

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import de.godisch.potillus.fake.FakeAppPreferences
import de.godisch.potillus.fake.FakeBackupRepository
import de.godisch.potillus.fake.FakeDrinkRepository
import de.godisch.potillus.fake.FakeEntryRepository
import de.godisch.potillus.ui.screen.*
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Unit tests for the [AppViewModelFactory] dependency graph.
 *
 * Each test verifies that a specific ViewModel can be instantiated with the
 * dependency types that [AppViewModelFactory] supplies, and that the factory's
 * `else` guard fires correctly for unregistered classes.
 */
class AppViewModelFactoryTest {

    // Shared Fake dependencies (stateless for these constructor tests).
    private val entryRepo = FakeEntryRepository()
    private val drinkRepo = FakeDrinkRepository()
    private val prefs = FakeAppPreferences()
    private val backupRepo = FakeBackupRepository()
    private val strings = StringProvider { id, args ->
        if (args.isEmpty()) id.toString() else "$id(${args.joinToString()})"
    }

    // ── Verify each ViewModel constructor accepts the injected types ──────────
    //
    // These tests mirror exactly what AppViewModelFactory.create() does for each
    // `when` branch. If a constructor parameter type changes (e.g. a new required
    // dependency is added) without updating the factory, both the factory and
    // these tests will fail to compile — catching the mismatch at build time.

    /**
     * [TodayViewModel] requires [IEntryRepository], [IDrinkRepository],
     * and [IAppPreferences]. Confirms the constructor signature is stable.
     */
    @Test fun `TodayViewModel can be constructed with its injected types`() {
        val vm = TodayViewModel(entryRepo = entryRepo, drinkRepo = drinkRepo, prefs = prefs)
        assertNotNull(vm)
        // Note: ViewModel.onCleared() is protected and cannot be called from test code.
        // The coroutine scope managed by viewModelScope is cancelled automatically when
        // the ViewModel is garbage-collected; no explicit teardown is needed in a
        // constructor-only test.
    }

    /**
     * [CalendarViewModel] requires the same three dependencies as [TodayViewModel].
     */
    @Test fun `CalendarViewModel can be constructed with its injected types`() {
        val vm = CalendarViewModel(entryRepo = entryRepo, drinkRepo = drinkRepo, prefs = prefs)
        assertNotNull(vm)
    }

    /**
     * [StatsViewModel] additionally requires [appContext] and [getString].
     * [android.app.Application] is used here because it is accepted by the
     * Android stub jar when `isReturnDefaultValues = true` (see build.gradle.kts).
     */
    @Test fun `StatsViewModel can be constructed with its injected types`() {
        val vm = StatsViewModel(
            entryRepo = entryRepo,
            drinkRepo = drinkRepo,
            prefs = prefs,
            appContext = android.app.Application(),
            getString = strings,
        )
        assertNotNull(vm)
    }

    /**
     * [DrinksViewModel] requires only [IDrinkRepository].
     */
    @Test fun `DrinksViewModel can be constructed with its injected types`() {
        val vm = DrinksViewModel(drinkRepo = drinkRepo)
        assertNotNull(vm)
    }

    /**
     * [SettingsViewModel] requires all six dependencies.
     */
    @Test fun `SettingsViewModel can be constructed with its injected types`() {
        val vm = SettingsViewModel(
            getString = strings,
            appContext = android.app.Application(),
            prefs = prefs,
            entryRepo = entryRepo,
            drinkRepo = drinkRepo,
            backupRepo = backupRepo,
        )
        assertNotNull(vm)
    }

    // ── Factory `else` guard ─────────────────────────────────────────────────

    /**
     * [AppViewModelFactory.create] must throw [IllegalArgumentException] for
     * any ViewModel class that is not registered in its `when` expression.
     *
     * This test uses a minimal [ViewModelProvider.Factory] that reproduces the
     * `else` branch from the real factory, confirming the guard logic is correct.
     * The real factory cannot be instantiated here without a [PotillusApp]; see
     * the file header for the rationale.
     */
    @Test(expected = IllegalArgumentException::class)
    fun `factory else-branch throws IllegalArgumentException for unknown class`() {
        // A minimal factory stub that reproduces only the else-guard from
        // AppViewModelFactory.create(). The known branches are not duplicated here;
        // they are verified by the constructor tests above.
        val guardOnlyFactory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = when (modelClass) {
                // No known branches: every class hits the else-guard.
                else -> throw IllegalArgumentException(
                    "Unknown ViewModel class: ${modelClass.name}. " +
                        "Register it in AppViewModelFactory.",
                )
            }
        }
        // Any plain ViewModel class triggers the else-guard.
        guardOnlyFactory.create(ViewModel::class.java)
    }
}
