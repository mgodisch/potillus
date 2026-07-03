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
 *
 * INSTRUMENTED TEST — Context.formattingLocale() / Context.localizedContextFor()
 * (the transformation behind Context.perAppLocalizedContext())
 *
 * WHY THIS FILE EXISTS (teaching note)
 *   formattingLocale() reads the locale from a Context's *configuration* rather
 *   than from Locale.getDefault(), which is what makes the PDF report's month
 *   names follow the in-app language. That logic depends on a real Android
 *   Configuration, so it cannot be exercised by a plain JVM test — it belongs in
 *   the instrumented suite. The test builds a configuration-overridden Context
 *   and asserts the helper reports that Context's locale, not the device default.
 *
 * RUNNING
 *   ./gradlew connectedDebugAndroidTest   (requires a connected device/emulator)
 */
package de.godisch.potillus.l10n

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import androidx.core.os.LocaleListCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class LocaleFormattingInstrumentedTest {

    /**
     * A Context whose configuration carries an explicit locale must report exactly
     * that locale from [formattingLocale], regardless of the device's system
     * locale. French is used as a fixed, device-independent expectation.
     */
    @Test
    fun formattingLocale_reflectsConfigurationLocale() {
        val base: Context = ApplicationProvider.getApplicationContext()

        val config = Configuration(base.resources.configuration).apply {
            setLocales(LocaleList(Locale.FRENCH))
        }
        val localized = base.createConfigurationContext(config)

        assertEquals(Locale.FRENCH.language, localized.formattingLocale().language)
    }

    /**
     * With an EMPTY locale list, [localizedContextFor] must be a strict no-op —
     * the SAME context instance comes back, so callers pay nothing on the
     * first-launch path before language detection has run. (The empty list is
     * exactly what [perAppLocalizedContext] feeds it when nothing is stored.)
     */
    @Test
    fun localizedContextFor_isNoOpForEmptyLocaleList() {
        val app: Context = ApplicationProvider.getApplicationContext()
        assertSame(app, app.localizedContextFor(LocaleListCompat.getEmptyLocaleList()))
    }

    /**
     * With a non-empty locale list, [localizedContextFor] must yield a context
     * whose [formattingLocale] IS that locale — the regression guard for the
     * API 30–32 gap where the raw Application context keeps the SYSTEM locale.
     *
     * WHY THE TEST TARGETS [localizedContextFor] WITH AN EXPLICIT LIST rather
     * than driving [perAppLocalizedContext] through
     * `AppCompatDelegate.setApplicationLocales`: on API 33+ the delegate
     * reaches the framework `LocaleManager` only through ACTIVE
     * AppCompatDelegate instances — in an activity-less instrumented test the
     * set call is a silent no-op and the get call returns the empty list, so
     * that arrangement can never pass on modern devices (it failed with
     * "expected fr, was <device language>" on an API 35 device). The explicit
     * list exercises the actual transformation deterministically on every API
     * level, without touching global or persisted device state.
     */
    @Test
    fun localizedContextFor_carriesRequestedLocale() {
        val app: Context = ApplicationProvider.getApplicationContext()
        val localized = app.localizedContextFor(LocaleListCompat.forLanguageTags("fr"))
        assertEquals(Locale.FRENCH.language, localized.formattingLocale().language)
    }
}
