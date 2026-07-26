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
package de.godisch.potillus.l10n

import android.content.Context
import androidx.core.os.LocaleListCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import de.godisch.potillus.R
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

// =============================================================================
// INSTRUMENTED TEST — Android's own plural resolution against the shared vectors
// =============================================================================
//
// WHAT THIS CLOSES
//   test-vectors/plural-days.json carries a day count, the plural category it
//   selects, and the word that comes out, for all 21 languages. The iOS side
//   asserts its DayPlural against that file. On its own that proves only that the
//   Swift port agrees with the file — and both were written in the same sitting,
//   from the same reading of CLDR, so agreeing proves little.
//
//   This test is the other end. It asks the PLATFORM: it builds a Context for each
//   language and calls getQuantityString, which resolves through Android's own
//   CLDR data and the translated <plurals name="days">. If a rule was written down
//   wrong, the two ends disagree here rather than shipping a real word of the right
//   language in the wrong place — the kind of mistake no reviewer of this
//   repository could catch by reading.
//
// WHY IT MUST BE INSTRUMENTED
//   getQuantityString needs android.content.res, and resolving a language other
//   than the device's needs a configuration-overridden Context. Neither exists on
//   the plain JVM, which is why the JVM suite cannot host this.
//
// WHERE THE FILE COMES FROM
//   app/build.gradle.kts copies test-vectors/plural-days.json into the generated
//   androidTest assets (`copyInstrumentationFixtures`), so this reads it by name
//   exactly like the screenshot suite reads its fixture.
// =============================================================================

/** Holds Android's plural resolution to `test-vectors/plural-days.json`. */
@RunWith(AndroidJUnit4::class)
class PluralDaysInstrumentedTest {

    private companion object {
        const val VECTOR_ASSET = "plural-days.json"
    }

    private fun vectors(): JSONObject {
        val json = InstrumentationRegistry.getInstrumentation()
            .context.assets.open(VECTOR_ASSET)
            .bufferedReader()
            .use { it.readText() }
        return JSONObject(json)
    }

    /**
     * A [Context] whose resources resolve in [tag].
     *
     * The tag is the bare language the vector uses — `"de"`, `"pt-BR"`,
     * `"zh-Hans"`. Android maps those onto its own qualifier directories
     * (`values-pt-rBR`, `values-zh-rCN`), which is part of what this test checks:
     * a language whose resources did not resolve would fall back to English and
     * fail loudly here rather than quietly in a report.
     */
    private fun contextFor(tag: String): Context {
        val app = ApplicationProvider.getApplicationContext<Context>()
        return app.localizedContextFor(LocaleListCompat.forLanguageTags(tag))
    }

    @Test
    fun everyLanguageResolvesTheVectorsWord() {
        val cases = vectors().getJSONObject("cases")
        var checked = 0
        for (tag in cases.keys()) {
            val resources = contextFor(tag).resources
            val list = cases.getJSONArray(tag)
            for (i in 0 until list.length()) {
                val case = list.getJSONObject(i)
                val count = case.getInt("count")
                assertEquals(
                    "$tag at $count",
                    case.getString("expected"),
                    resources.getQuantityString(R.plurals.days, count, count),
                )
                checked++
            }
        }
        // A vector file that failed to load would leave the loops empty and the
        // test green, which is the one outcome this must not have.
        assertEquals("every language in the vectors must have been exercised", 21, cases.length())
        assertEquals("21 languages times 17 counts", 21 * 17, checked)
    }
}
