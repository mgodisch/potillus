/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
// AppViewModelFactory.kt – Manual ViewModelProvider.Factory for the whole app
// =============================================================================
//
// WHY a dedicated factory class?
//   Previously this factory was an anonymous object defined inline inside the
//   MainContent composable in MainActivity.kt. Defining it inline has two
//   drawbacks for a teaching app:
//     1. The dependency graph is buried inside a UI file, making it hard to find
//        during code review or when onboarding a new developer.
//     2. Every recomposition of MainContent would re-evaluate the `remember { }`
//        block, which in turn checks all ViewModel class entries. Extracting the
//        factory to a named class makes the graph explicit and centralised.
//
// MANUAL DI (no Hilt / Koin):
//   This factory is the app's entire dependency-injection mechanism.
//   It maps each ViewModel class to its constructor. The concrete implementations
//   (AppDatabase, repositories, AppPreferences) are created once as lazy
//   properties in [PotillusApp] and passed here.
//
//   Trade-off vs. Hilt:
//     + No annotation processing overhead, no generated code to read.
//     + The full dependency graph is visible in one place (this file).
//     - Each new ViewModel requires a new `when` branch here AND a new
//       lazy property in PotillusApp.
//     - There is no compile-time verification that all required dependencies
//       are provided; a missing branch throws at runtime.
//
//   For a single-developer teaching app this trade-off is acceptable.
//   Adding Hilt would be the natural next step as the project grows.
//
// USAGE:
//   Pass [AppViewModelFactory] to the [viewModel()] composable:
//     val vm = viewModel<TodayViewModel>(factory = factory)
//   The ViewModelProvider caches the created ViewModel in the ViewModelStore
//   of the nearest [ViewModelStoreOwner] (the Activity by default), so each
//   ViewModel is created at most once per Activity lifecycle.
// =============================================================================

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import de.godisch.potillus.ui.screen.*

/**
 * Manual [ViewModelProvider.Factory] that wires all ViewModels to their
 * dependencies from [PotillusApp].
 *
 * Registered once in [MainActivity.MainContent] via `remember { }` so it
 * is created at most once per Activity lifecycle.
 *
 * @param app  The singleton [PotillusApp] that owns all shared dependencies.
 */
class AppViewModelFactory(private val app: PotillusApp) : ViewModelProvider.Factory {

    /**
     * Creates the requested ViewModel.
     *
     * Each branch passes exactly the interfaces the ViewModel declares in its
     * constructor. Concrete implementations are resolved from [PotillusApp].
     *
     * Adding a new ViewModel requires:
     *   1. A new `else if` branch here.
     *   2. A new `lazy` property in [PotillusApp] for any new dependency.
     *
     * @throws IllegalArgumentException if [modelClass] is not registered here.
     */
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = when (modelClass) {
        TodayViewModel::class.java    ->
            TodayViewModel(
                entryRepo  = app.entryRepository,
                drinkRepo  = app.drinkRepository,
                prefs      = app.appPreferences
            ) as T

        CalendarViewModel::class.java ->
            CalendarViewModel(
                entryRepo  = app.entryRepository,
                drinkRepo  = app.drinkRepository,
                prefs      = app.appPreferences
            ) as T

        StatsViewModel::class.java    ->
            StatsViewModel(
                entryRepo  = app.entryRepository,
                drinkRepo  = app.drinkRepository,
                prefs      = app.appPreferences,
                // CSV/PDF export is owned by StatsViewModel; it needs
                // the Application context for MediaStore I/O and a StringProvider
                // for localised status messages (same pattern as SettingsViewModel).
                appContext = app.applicationContext,
                getString  = StringProvider { id, args -> app.getString(id, *args) }
            ) as T

        DrinksViewModel::class.java   ->
            DrinksViewModel(drinkRepo = app.drinkRepository) as T

        SettingsViewModel::class.java ->
            SettingsViewModel(
                getString  = StringProvider { id, args -> app.getString(id, *args) },
                // Pass applicationContext explicitly – see SettingsViewModel KDoc for
                // the rationale why applicationContext is safe in a ViewModel.
                appContext  = app.applicationContext,
                prefs      = app.appPreferences,
                entryRepo  = app.entryRepository,
                drinkRepo  = app.drinkRepository,
                backupRepo = app.backupRepository
            ) as T

        else -> throw IllegalArgumentException(
            "Unknown ViewModel class: ${modelClass.name}. " +
            "Register it in AppViewModelFactory."
        )
    }
}
