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

import android.content.res.Configuration
import androidx.activity.ComponentActivity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
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
     * Pin the locale to US for each test — at TWO levels.
     *
     * [LimitBar] now formats the consumed-grams figure for the *per-app* locale
     * via `Context.formattingLocale()` (see l10n/NumberFormat.kt), so the on-screen
     * number matches the language the user picked in-app (e.g. "20,0 g" on a German
     * locale). That is correct UI behaviour, but it makes a hard-coded expected
     * string ("20.0 g") device-dependent.
     *
     * Crucially, `formattingLocale()` reads the **Context configuration** locale,
     * which `Locale.setDefault()` does NOT affect — so pinning the JVM default
     * alone (as this test did before the per-app-locale change) is no longer
     * sufficient and the test failed on a comma-decimal device. The decisive pin
     * is therefore in [setThemedContent], which provides a US-configured Context
     * through `LocalContext`. The `Locale.setDefault(US)` below is kept as a
     * belt-and-suspenders measure for any remaining `getDefault()`-based
     * formatting in the rendered tree.
     */
    @Before fun setUp() {
        originalLocale = Locale.getDefault()
        Locale.setDefault(Locale.US)
    }

    @After fun tearDown() {
        Locale.setDefault(originalLocale)
    }

    /**
     * Renders [content] wrapped in [PotillusTheme], with `LocalContext` overridden
     * by a US-configured Context so that `Context.formattingLocale()` — and hence
     * every number `LimitBar` formats — is deterministically US ("20.0 g"),
     * independent of the test device's locale.
     */
    private fun setThemedContent(content: @Composable () -> Unit) {
        composeTestRule.setContent {
            val base = LocalContext.current
            // Read the base Configuration via LocalConfiguration.current (the
            // Compose-sanctioned API) rather than base.resources.configuration,
            // which the LocalContextConfigurationRead lint rule forbids. Copying
            // the base config preserves density/screen fields; only the locale is
            // overridden, and createConfigurationContext (a method call on the
            // Context, not a configuration read) builds the US-locale Context.
            val baseConfig = LocalConfiguration.current
            val usContext = remember(base, baseConfig) {
                val cfg = Configuration(baseConfig).apply { setLocale(Locale.US) }
                base.createConfigurationContext(cfg)
            }
            CompositionLocalProvider(LocalContext provides usContext) {
                PotillusTheme { content() }
            }
        }
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
                caption = "weekly",
                leftSuffix = "(week)",
            )
        }
        composeTestRule.onNodeWithText("12.5 g (week)").assertIsDisplayed()
    }
}
