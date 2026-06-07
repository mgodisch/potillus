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
 *
 * INSTRUMENTED UI TEST — LimitBar
 *
 * WHY THIS FILE EXISTS (teaching note)
 *   This complements EntryListItemUiTest with a second stateless composable so
 *   the limit-progress widget — shown prominently on the Today screen — has UI
 *   coverage. [LimitBar] is a good target for the same reasons EntryListItem was:
 *   it is fully stateless (grams + limit + caption in, rendered text out), so the
 *   test is fast and deterministic with no ViewModel, database or coroutines.
 *
 *   The same Compose-test building blocks as EntryListItemUiTest apply; see that
 *   file's header for the createAndroidComposeRule / setContent / finder pattern
 *   and the v2-dispatcher note. All assertions here end in assertIsDisplayed(),
 *   which synchronises on idle, so no runOnIdle wrapper is needed.
 *
 * RUNNING
 *   ./gradlew connectedDebugAndroidTest   (requires a connected device/emulator)
 */
package de.godisch.potillus.ui.component

import androidx.activity.ComponentActivity
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import de.godisch.potillus.ui.theme.PotillusTheme
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class LimitBarUiTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var originalLocale: Locale

    /**
     * Pin the default locale to US for the duration of each test.
     *
     * [LimitBar] formats the consumed-grams figure with `"%.1f".format(...)`, which
     * honours [Locale.getDefault] — by design, so the on-screen number matches the
     * user's locale (e.g. "20,0 g" on a German device). That is correct UI
     * behaviour, but it makes a hard-coded expected string ("20.0 g") device-
     * dependent: this test failed on a comma-decimal device until the locale was
     * pinned. Fixing the locale here keeps the expected text deterministic while
     * still exercising the real formatting path — the same approach
     * `CsvExporterBuildTest` uses (it pins Locale.GERMANY instead).
     */
    @Before fun setUp() {
        originalLocale = Locale.getDefault()
        Locale.setDefault(Locale.US)
    }

    @After fun tearDown() {
        Locale.setDefault(originalLocale)
    }

    /** Renders [content] wrapped in [PotillusTheme] so theme colours resolve. */
    private fun setThemedContent(content: @Composable () -> Unit) {
        composeTestRule.setContent { PotillusTheme { content() } }
    }

    /** The consumed-grams label (one decimal) and the caption must both render. */
    @Test
    fun showsConsumedGramsAndCaption() {
        setThemedContent {
            LimitBar(totalGrams = 20.0, limitGrams = 30.0, caption = "of 30 g")
        }
        composeTestRule.onNodeWithText("20.0 g").assertIsDisplayed()
        composeTestRule.onNodeWithText("of 30 g").assertIsDisplayed()
    }

    /** A non-empty leftSuffix is appended to the consumed-grams label. */
    @Test
    fun appendsLeftSuffixToGramsLabel() {
        setThemedContent {
            LimitBar(
                totalGrams = 12.5,
                limitGrams = 100.0,
                caption    = "weekly",
                leftSuffix = "(week)"
            )
        }
        composeTestRule.onNodeWithText("12.5 g (week)").assertIsDisplayed()
    }
}
