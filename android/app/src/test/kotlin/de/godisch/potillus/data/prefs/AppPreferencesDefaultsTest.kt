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
package de.godisch.potillus.data.prefs

import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.mutablePreferencesOf
import de.godisch.potillus.domain.model.AppSettings
import org.junit.Test
import kotlin.test.assertEquals

// =============================================================================
// AppPreferencesDefaultsTest – what a fresh install is handed
// =============================================================================
//
// WHAT IS UNDER TEST
//   toAppSettings(installDate) maps a raw DataStore snapshot onto AppSettings.
//   On the very first launch that snapshot is EMPTY, so this mapping alone
//   decides what every new user starts with — the daily and weekly limits above
//   all, which decide what the app then says about their drinking.
//
// WHY A WHOLE-VALUE ASSERTION
//   The bug this test exists for was not a wrong line, it was a second list.
//   The mapping restated the defaults that AppSettings already declared, the two
//   drifted, and a fresh install got 100 g/week and 5 drink days while the data
//   class said 80 and 4 — for long enough that the report screenshots showed it.
//   Asserting field by field would repeat the mistake in a third place, so the
//   assertion compares the whole object: a field added tomorrow with a
//   hand-written fallback fails here the moment it disagrees with AppSettings,
//   without anyone remembering to extend this file.
//
// WHY THIS RUNS ON THE PLAIN JVM (no device, no Context)
//   toAppSettings is a pure function over a Preferences map. The install date is
//   a parameter precisely so that the package manager stays out of it.
// =============================================================================

/** Pins the settings a first launch produces. */
class AppPreferencesDefaultsTest {

    private companion object {
        /** Any date works; the test only needs it to be distinguishable. */
        const val INSTALL_DATE = "2026-01-15"
    }

    /**
     * An empty store yields exactly `AppSettings()`, save for the statistics start
     * date, which is documented to begin at the install date instead.
     */
    @Test
    fun `defaults are the data class defaults`() {
        assertEquals(
            AppSettings(statsFromDate = INSTALL_DATE),
            emptyPreferences().toAppSettings(INSTALL_DATE),
            "the first-run defaults must come from AppSettings, not from a second list",
        )
    }

    /**
     * The two fields that had drifted, called out by name. The assertion above
     * already covers them; these two lines exist so a future reader sees which
     * values the app actually ships, without opening two files.
     */
    @Test
    fun `a fresh install starts at eighty grams per week over four drink days`() {
        val settings = emptyPreferences().toAppSettings(INSTALL_DATE)

        assertEquals(80.0, settings.weeklyLimitGrams, 0.0)
        assertEquals(4, settings.maxDrinkDaysPerWeek)
    }

    /** A stored value still wins over the default it replaces. */
    @Test
    fun `a stored value overrides its default`() {
        val stored = mutablePreferencesOf(
            AppPreferences.KEY_WEEKLY_LIMIT to 137.0,
            AppPreferences.KEY_MAX_DRINK_DAYS to 6,
            AppPreferences.KEY_STATS_FROM to "2026-03-01",
        )

        val settings = stored.toAppSettings(INSTALL_DATE)

        assertEquals(137.0, settings.weeklyLimitGrams, 0.0)
        assertEquals(6, settings.maxDrinkDaysPerWeek)
        assertEquals("2026-03-01", settings.statsFromDate, "an explicit floor beats the install date")
    }
}
