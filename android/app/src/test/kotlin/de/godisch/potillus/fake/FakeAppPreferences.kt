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
package de.godisch.potillus.fake

import de.godisch.potillus.data.prefs.IAppPreferences
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

// See FakeEntryRepository.kt for the rationale behind Fake vs Mock.

class FakeAppPreferences(
    initial: AppSettings = AppSettings()
) : IAppPreferences {

    private val _settings = MutableStateFlow(initial)
    override val settingsFlow: Flow<AppSettings> = _settings

    // Expose current value for synchronous assertions in tests.
    val currentSettings: AppSettings get() = _settings.value

    // ── IAppPreferences ──────────────────────────────────────────────────────

    override suspend fun setTheme(mode: ThemeMode)   = _settings.update { it.copy(themeMode = mode) }
    override suspend fun setBiometric(v: Boolean)     = _settings.update { it.copy(biometricEnabled = v) }
    override suspend fun setLanguage(lang: String)    = _settings.update { it.copy(language = lang) }
    override suspend fun setStatsFromDate(date: String) = _settings.update { it.copy(statsFromDate = date) }

    // Mirror the coerceIn guards from AppPreferences so behaviour is consistent.
    override suspend fun setDailyLimit(g: Double)          = _settings.update { it.copy(dailyLimitGrams = g.coerceIn(1.0, 500.0)) }
    override suspend fun setWeeklyLimit(g: Double)         = _settings.update { it.copy(weeklyLimitGrams = g.coerceIn(1.0, 3500.0)) }
    override suspend fun setWeightKg(kg: Double)           = _settings.update { it.copy(weightKg = kg.coerceIn(1.0, 500.0)) }
    override suspend fun setMaxDrinkDaysPerWeek(days: Int) = _settings.update { it.copy(maxDrinkDaysPerWeek = days.coerceIn(1, 7)) }

    override suspend fun setDayChangeTime(hour: Int, minute: Int) =
        _settings.update { it.copy(dayChangeHour = hour, dayChangeMinute = minute) }

    private val _infoYear = MutableStateFlow(0)
    override val infoDialogShownYear: Flow<Int> = _infoYear
    override suspend fun setInfoDialogShownYear(year: Int) { _infoYear.value = year }
}
