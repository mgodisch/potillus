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
package de.godisch.potillus.data.prefs

// =============================================================================
// IAppPreferences.kt – Contract for user settings persistence
// =============================================================================
//
// Decouples ViewModels from the concrete AppPreferences implementation, which
// requires a DataStore (and therefore an Android Context) to instantiate.
// FakeAppPreferences implements this interface in-memory for unit tests.
// =============================================================================

import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ThemeMode
import kotlinx.coroutines.flow.Flow

/** Contract for all user-settings read/write operations used by the ViewModel layer. */
interface IAppPreferences {

    /** Reactive stream emitting a fresh [AppSettings] snapshot on every change. */
    val settingsFlow: Flow<AppSettings>

    /** Persists the UI [mode] (light / dark / follow system). */
    suspend fun setTheme(mode: ThemeMode)

    /** Persists the daily pure-alcohol limit [g] in grams (implementation clamps the range). */
    suspend fun setDailyLimit(g: Double)

    /** Persists the weekly pure-alcohol limit [g] in grams (implementation clamps the range). */
    suspend fun setWeeklyLimit(g: Double)

    /** Persists the maximum number of drink days per week [days] (clamped to 1–7). */
    suspend fun setMaxDrinkDaysPerWeek(days: Int)

    /** Enables/disables the biometric app lock. */
    suspend fun setBiometric(v: Boolean)

    /** Clears or re-sets [WindowManager.LayoutParams.FLAG_SECURE] for the app window. */
    suspend fun setAllowScreenshots(v: Boolean)

    /** Enables/disables the alternative (glyph) style of the traffic-light capacity indicator. */
    suspend fun setAlternativeStatusSymbols(v: Boolean)

    /** Persists the UI language BCP-47 tag [lang] (empty = follow system). */
    suspend fun setLanguage(lang: String)

    /** Persists the body weight [kg] (implementation clamps the range). */
    suspend fun setWeightKg(kg: Double)

    /** Persists the day-change [hour]/[minute] atomically (single transaction). */
    suspend fun setDayChangeTime(hour: Int, minute: Int)

    /** Persists the statistics start date [date] ("YYYY-MM-DD"). */
    suspend fun setStatsFromDate(date: String)
}
