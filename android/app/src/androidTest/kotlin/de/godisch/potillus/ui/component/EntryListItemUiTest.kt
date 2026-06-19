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
 * INSTRUMENTED UI TEST — EntryListItem
 *
 * WHY THIS FILE EXISTS (teaching note)
 *   The project already has a strong JVM unit-test suite for the domain and
 *   ViewModel layers, but no *instrumented* tests that render real Compose UI.
 *   This file demonstrates the canonical pattern for a Compose UI test and acts
 *   as a template for testing further composables.
 *
 * WHAT IS UNDER TEST
 *   [EntryListItem] is a good first target because it is completely STATELESS:
 *   it takes a [ConsumptionEntry] plus two callbacks and renders them, holding
 *   no ViewModel, database, or DataStore. That makes it fast and deterministic
 *   to test in isolation — no SQLCipher, no Keystore, no coroutines.
 *
 * HOW COMPOSE UI TESTS WORK (the three building blocks)
 *   1. [createAndroidComposeRule] — a JUnit @Rule that launches an empty test
 *      Activity ([ComponentActivity], supplied by the `ui-test-manifest`
 *      artifact, wired as a debugImplementation in build.gradle.kts) and hosts a
 *      composition inside it. (The bare createComposeRule() is a thin wrapper over
 *      this; the explicit variant launches the Activity via an ActivityScenario,
 *      which proved more reliable on-device — the wrapper failed with
 *      "No compose hierarchies found".)
 *   2. `composeTestRule.setContent { ... }` — sets the composable to render.
 *      We wrap the component in [PotillusTheme] so MaterialTheme.colorScheme and
 *      the app's custom colour helpers (e.g. dangerRedColor) resolve correctly.
 *   3. Finders + assertions/actions — `onNodeWithText`, `onNodeWithContentDescription`,
 *      then `assertIsDisplayed()` / `performClick()`.
 *
 * SYNCHRONISATION (v2 testing APIs — Compose 1.11 / BOM 2026.04.01)
 *   Starting with this BOM the Compose test framework enables its *v2* testing
 *   APIs by default, which changes the default test dispatcher from
 *   UnconfinedTestDispatcher (runs coroutines/recompositions eagerly) to
 *   StandardTestDispatcher (queues them until the virtual clock advances). The
 *   practical rule of thumb:
 *     - Finders that end in an assertion on a *node* (e.g. `assertIsDisplayed()`)
 *       are safe as-is: the finder synchronises (waits for idle) before it reads
 *       the tree, so a queued initial composition is flushed for us.
 *     - When a test asserts on state held OUTSIDE the composition — here a plain
 *       Kotlin `var` mutated by a click callback — there is no implicit idle
 *       sync, so under v2 the click may still be queued when we read the counter.
 *       We therefore wrap the assertion in `composeTestRule.runOnIdle { }`, which
 *       first waits for the UI to become idle (draining the queued click) and
 *       then runs the assertion on the main thread. Under the old v1 dispatcher
 *       this was unnecessary because everything ran eagerly; the wrapper is the
 *       forward-compatible pattern and is harmless under either dispatcher.
 *
 * RUNNING
 *   ./gradlew connectedDebugAndroidTest   (requires a connected device/emulator)
 */
package de.godisch.potillus.ui.component

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import de.godisch.potillus.R
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.ui.theme.PotillusTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * UI tests for the [EntryListItem] composable.
 */
@RunWith(AndroidJUnit4::class)
class EntryListItemUiTest {

    /**
     * Hosts the composition under test in an empty [ComponentActivity] (supplied
     * by the `ui-test-manifest` artifact). We use createAndroidComposeRule rather
     * than the bare createComposeRule(): the former launches the host Activity
     * explicitly via an ActivityScenario, which reliably establishes a Compose
     * hierarchy on real devices. The bare rule was observed to fail on-device with
     * "No compose hierarchies found".
     *
     * This uses the v2 factory (androidx.compose.ui.test.junit4.v2): since Compose
     * 1.11 the v1 factories are deprecated. v2 establishes the test environment on
     * a StandardTestDispatcher (queued coroutines) instead of v1's
     * UnconfinedTestDispatcher (immediate execution); the assertions that depend on
     * recomposition are already wrapped in runOnIdle {} to stay correct under it.
     * Only the environment factory changed — the finders, actions, setContent and
     * runOnIdle below are the same APIs as before.
     */
    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    /** Application [Context], used only to resolve localised content descriptions. */
    private val context: Context = ApplicationProvider.getApplicationContext()

    /** A representative entry reused across the test cases. */
    private val sampleEntry = ConsumptionEntry(
        id              = 1L,
        drinkId         = 10L,
        drinkName       = "Pilsner",
        volumeMl        = 500,
        alcoholPercent  = 4.9,
        gramsAlcohol    = 19.3,
        timestampMillis = 1_700_000_000_000L,
        logicalDate     = "2026-05-29",
        note            = "after work"
    )

    /**
     * Renders [content] wrapped in [PotillusTheme] so theme-dependent colours
     * and typography are available to the composable under test.
     */
    private fun setThemedContent(content: @androidx.compose.runtime.Composable () -> Unit) {
        composeTestRule.setContent { PotillusTheme { content() } }
    }

    /** The drink name and the (non-blank) note must both be visible. */
    @Test
    fun displaysDrinkNameAndNote() {
        setThemedContent {
            EntryListItem(entry = sampleEntry, onEdit = {}, onDelete = {})
        }

        composeTestRule.onNodeWithText("Pilsner").assertIsDisplayed()
        composeTestRule.onNodeWithText("after work").assertIsDisplayed()
    }

    /** Tapping the edit (pencil) icon must invoke the onEdit callback exactly once. */
    @Test
    fun tappingEdit_invokesOnEdit() {
        var editClicks = 0
        setThemedContent {
            EntryListItem(entry = sampleEntry, onEdit = { editClicks++ }, onDelete = {})
        }

        // The edit IconButton exposes the localised "edit_entry" string as its
        // content description, so we locate it the same way an accessibility
        // service (or a real user with TalkBack) would.
        composeTestRule
            .onNodeWithContentDescription(context.getString(R.string.edit_entry))
            .performClick()

        // The counter is plain state outside the composition, so we must wait for
        // the UI to be idle (v2 StandardTestDispatcher queues the click) before
        // reading it. runOnIdle waits, then runs the assertion on the main thread.
        composeTestRule.runOnIdle {
            assertTrue("onEdit should be invoked exactly once", editClicks == 1)
        }
    }

    /** Tapping the delete (trash) icon must invoke the onDelete callback exactly once. */
    @Test
    fun tappingDelete_invokesOnDelete() {
        var deleteClicks = 0
        setThemedContent {
            EntryListItem(entry = sampleEntry, onEdit = {}, onDelete = { deleteClicks++ })
        }

        composeTestRule
            .onNodeWithContentDescription(context.getString(R.string.delete))
            .performClick()

        // See tappingEdit_invokesOnEdit: drain the queued click before asserting
        // on the out-of-composition counter under the v2 test dispatcher.
        composeTestRule.runOnIdle {
            assertTrue("onDelete should be invoked exactly once", deleteClicks == 1)
        }
    }
}
