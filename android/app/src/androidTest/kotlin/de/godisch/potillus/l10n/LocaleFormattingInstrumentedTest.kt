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
 *
 * INSTRUMENTED TEST — Context.formattingLocale()
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
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
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
}
