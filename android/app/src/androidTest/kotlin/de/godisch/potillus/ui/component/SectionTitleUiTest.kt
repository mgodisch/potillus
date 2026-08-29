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
 * INSTRUMENTED UI TEST — SectionTitle
 *
 * WHY THIS FILE EXISTS (teaching note)
 *   [SectionTitle] exists for a property that is invisible on screen: the
 *   HEADING role it declares to assistive technology. A screenshot review
 *   cannot catch its loss, and neither can a reader — the title looks exactly
 *   the same either way. So the role needs a test, and this is the smallest
 *   one that covers it: the composable is stateless (a string in, one node
 *   out), so no ViewModel, database or coroutine is involved.
 *
 *   The Compose-test building blocks are the ones EntryListItemUiTest and
 *   LimitBarUiTest use; see the former's header for the
 *   createAndroidComposeRule / setContent / finder pattern.
 *
 * HOW THE ROLE IS ASSERTED
 *   `heading()` sets [SemanticsProperties.Heading], a key whose value type is
 *   `Unit` — the key's PRESENCE is the whole statement, so there is no value to
 *   compare and [SemanticsMatcher.keyIsDefined] is the matcher that fits. The
 *   negative case is asserted too, against a plain [Text], because a matcher
 *   that passes on everything would prove nothing.
 *
 * RUNNING
 *   ./gradlew connectedDebugAndroidTest   (requires a connected device/emulator)
 */
package de.godisch.potillus.ui.component

import androidx.activity.ComponentActivity
import androidx.compose.material3.Text
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import de.godisch.potillus.ui.theme.PotillusTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SectionTitleUiTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    /** The title renders its text unchanged — no description replaces it. */
    @Test
    fun showsItsText() {
        composeTestRule.setContent { PotillusTheme { SectionTitle("Streaks & trend") } }
        composeTestRule.onNodeWithText("Streaks & trend").assertIsDisplayed()
    }

    /** The rendered node carries the heading role, which is the point of it. */
    @Test
    fun announcesItselfAsHeading() {
        composeTestRule.setContent { PotillusTheme { SectionTitle("Time of day") } }
        composeTestRule.onNodeWithText("Time of day")
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
    }

    /**
     * A plain [Text] does NOT carry the role. Without this case the assertion
     * above would still pass if `keyIsDefined` were somehow true for every node,
     * and the test would guard nothing.
     */
    @Test
    fun plainTextIsNotAHeading() {
        composeTestRule.setContent { PotillusTheme { Text("Just a line") } }
        composeTestRule.onNodeWithText("Just a line")
            .assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Heading))
    }
}
