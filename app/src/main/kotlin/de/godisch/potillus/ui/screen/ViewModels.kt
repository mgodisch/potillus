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
// ViewModels.kt – Package-level overview for the ui.screen package
// =============================================================================
//
// This package contains one ViewModel per top-level screen:
//   • TodayViewModel    – live entry list, BAC estimate, weekly summary,
//                         traffic-light capacity per drink definition.
//   • CalendarViewModel – monthly / yearly navigation, day selection,
//                         entry detail view for any historical date.
//   • StatsViewModel    – aggregated statistics, trend calculation,
//                         per-category breakdown, abstinence streaks.
//   • DrinksViewModel   – drink catalogue: add, edit, delete, guard FK.
//   • SettingsViewModel – preferences, CSV / PDF / JSON export,
//                         backup import (REPLACE and MERGE modes).
//
// SHARED PATTERNS (all ViewModels follow these conventions):
//
//   Flow → StateFlow via stateIn(WhileSubscribed(5_000)):
//     The upstream Room / DataStore Flow is converted to a hot StateFlow so
//     Compose can collect it without restarting the database query on every
//     recomposition. WhileSubscribed(5_000) keeps the upstream alive for
//     5 s after the last subscriber disappears (handles orientation changes
//     without re-querying the database on every rotation).
//
//   @Immutable UiState data classes:
//     All properties are val; List fields are never mutated after
//     construction. The @Immutable annotation lets the Compose compiler skip
//     recomposition for subtrees that receive the same UiState instance.
//
//   Manual DI (no Hilt / Koin):
//     ViewModels receive injected interfaces (IEntryRepository,
//     IDrinkRepository, IAppPreferences, IBackupRepository). The concrete
//     factory is in MainActivity.MainContent. This trades framework
//     convenience for zero build-time overhead and makes the dependency
//     graph transparent to readers. See PotillusApp.kt for the singleton graph.
//
//   Log guards:
//     All android.util.Log calls are wrapped in if (BuildConfig.DEBUG) so
//     that R8 compiles them away in release builds and they never appear in
//     logcat on production devices.
// =============================================================================
