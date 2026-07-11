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
package de.godisch.potillus.ui.nav

// =============================================================================
// AppNav.kt – Navigation graph and bottom navigation bar
// =============================================================================
//
// JETPACK NAVIGATION (compose-navigation 2.8+, type-safe routes):
//   Navigation 2.8 replaces string routes with @Serializable Kotlin objects.
//   Benefits over string routes:
//     - Compile-time safety: a typo in a navigate() call is a build error, not
//       a runtime crash.
//     - No magic strings that must match between declaration and call site.
//     - Proper support for route arguments via @Serializable data classes
//       (not yet used here, but available without boilerplate if needed).
//
// WHY sealed interface instead of sealed class?
//   The route type (@Serializable sealed interface Screen) is used purely as
//   a navigation contract; it carries no constructor parameters or shared
//   state. A sealed interface is lighter (no abstract class overhead) and
//   signals that Screen is a marker type rather than a base class.
//
// MainPage:
//   Separates navigation concerns from UI concerns (title, icon). The four
//   main screens are pages of a HorizontalPager (not separate NavHost routes),
//   identified by their pager index.
//
// MAIN-SCREEN NAVIGATION (HorizontalPager):
//   The four top-level screens (Today, Calendar, Statistics, Drinks) live in a
//   bounded HorizontalPager inside the Home destination. Swiping moves between
//   adjacent screens; the pager is NOT circular, so the first/last screens have
//   no further page to swipe to. The bottom bar tab follows the current page,
//   and tapping a tab animates to that page.
//
// TWO NAVHOST DESTINATIONS:
//   Only Home (the pager + bottom bar) and Settings are NavHost routes. Settings
//   is pushed on top of Home via the gear icon and has no bottom bar; Back/Up
//   returns to Home on the page the user left.
// =============================================================================

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.compose.*
import de.godisch.potillus.R
import de.godisch.potillus.ui.screen.*
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

// ── Route definitions ─────────────────────────────────────────────────────────

/**
 * Type-safe navigation routes for all top-level destinations.
 *
 * Each object is annotated with [@Serializable] so that Navigation 2.8+ can
 * serialise and deserialise them to and from the back-stack. Using `data object`
 * (rather than plain `object`) ensures each subtype has correct equality and
 * [toString] semantics, which Navigation uses internally.
 *
 * WHY sealed interface?
 *   A sealed interface imposes no class hierarchy overhead; Screen is purely a
 *   navigation marker. The interface is sealed so the compiler can verify
 *   exhaustive when-expressions wherever a Screen is switched on.
 */
@Serializable
sealed interface Screen {
    /** The four swipeable top-level screens, hosted together in a HorizontalPager. */
    @Serializable data object Home : Screen

    /** Settings, opened via the overflow menu and pushed on top of [Home]. */
    @Serializable data object Settings : Screen

    /** In-app user guide ("Help"), pushed on top of [Home] from the overflow menu. */
    @Serializable data object Help : Screen

    /**
     * Copyright viewer ("Copyright"), pushed on top of [Home] from the overflow
     * menu. Displays the build-time concatenation of `COPYING.md` (the project's
     * short copyright/licence notice) and the full GPL text from `LICENSE.md`,
     * bundled as the single raw resource `R.raw.copyright`.
     */
    @Serializable data object Copyright : Screen
}

// ── Bottom-bar metadata ───────────────────────────────────────────────────────

/**
 * UI metadata for one pager page / bottom-bar tab.
 *
 * The page is identified by its position in [mainPages] (the pager index), so —
 * unlike the former NavItem — it no longer carries a navigation route object:
 * the four main screens are pages of a [HorizontalPager], not separate NavHost
 * destinations.
 *
 * @param titleRes  String resource for the bottom-bar label / accessibility text.
 * @param icon      Material icon shown in the [NavigationBar].
 */
private data class MainPage(val titleRes: Int, val icon: ImageVector)

// The four swipeable screens, in pager/tab order. Settings is intentionally NOT
// here: it is opened via a gear action in each screen's top bar and pushed as a
// separate destination (no bottom bar).
private val mainPages = listOf(
    MainPage(R.string.today, Icons.Default.Today),
    MainPage(R.string.calendar, Icons.Default.CalendarMonth),
    // Statistics uses a dedicated, deliberately short label (`nav_statistics`)
    // rather than the full screen title (`statistics`): the tab is a narrow
    // column under an icon, and long translations (e.g. French "Statistiques")
    // would otherwise wrap onto two lines. In most locales `nav_statistics`
    // repeats the full word; only overflowing ones shorten it (fr -> "Stats").
    MainPage(R.string.nav_statistics, Icons.Default.BarChart),
    MainPage(R.string.drinks, Icons.Default.LocalBar),
)

// ── Navigation composable ─────────────────────────────────────────────────────

/**
 * Root composable. The navigation graph has just two destinations:
 *   - [Screen.Home]     – the four swipeable main screens + bottom bar.
 *   - [Screen.Settings] – pushed on top of Home via the gear icon (no bottom bar).
 */
@Composable
fun AppNavigation(
    todayVm: TodayViewModel,
    calendarVm: CalendarViewModel,
    statsVm: StatsViewModel,
    drinksVm: DrinksViewModel,
    settingsVm: SettingsViewModel,
    /**
     * Runs a biometric prompt to authorise a sensitive toggle and calls back with
     * the result. Threaded through from [MainActivity] to [SettingsScreen], where
     * it guards the biometric-lock switch.
     */
    onAuthenticate: (onResult: (Boolean) -> Unit) -> Unit,
    /**
     * Locks the app immediately (overflow-menu "Lock app"). Forwarded to the four
     * main screens, which pass it to their shared [AppOverflowMenu].
     */
    onLockApp: () -> Unit,
) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Screen.Home,
    ) {
        composable<Screen.Home> {
            MainPagerHost(
                todayVm = todayVm,
                calendarVm = calendarVm,
                statsVm = statsVm,
                drinksVm = drinksVm,
                // Push each overflow-menu destination on top so the system Back
                // button / Up arrow returns to Home on whichever page it was
                // opened from.
                onOpenSettings = { navController.navigate(Screen.Settings) { launchSingleTop = true } },
                onOpenHelp = { navController.navigate(Screen.Help) { launchSingleTop = true } },
                onOpenCopyright = { navController.navigate(Screen.Copyright) { launchSingleTop = true } },
                onLockApp = onLockApp,
            )
        }
        composable<Screen.Settings> {
            SettingsScreen(
                settingsVm,
                onBack = { navController.navigateUp() },
                onAuthenticate = onAuthenticate,
            )
        }
        composable<Screen.Help> {
            // The user guide is Markdown and locale-resolved (raw/raw-xx).
            DocumentViewerScreen(
                titleRes = R.string.help,
                rawRes = R.raw.usersguide,
                renderAsMarkdown = true,
                onBack = { navController.navigateUp() },
            )
        }
        composable<Screen.Copyright> {
            // The copyright document (COPYING.md + LICENSE.md, joined at build
            // time into raw/copyright.md) is intentionally NOT locale-qualified:
            // it always uses the default raw/ copy, so the legal text is shown
            // verbatim in English regardless of the in-app language. It is
            // rendered as Markdown because COPYING.md uses Markdown headings and
            // links; the GPL body below it degrades gracefully as plain prose.
            DocumentViewerScreen(
                titleRes = R.string.copyright,
                rawRes = R.raw.copyright,
                renderAsMarkdown = true,
                onBack = { navController.navigateUp() },
            )
        }
    }
}

/**
 * Hosts the four top-level screens in a bounded [HorizontalPager] with a
 * [NavigationBar] below.
 *
 * NAVIGATION BEHAVIOUR:
 *   - Swiping left/right moves between adjacent screens.
 *   - The pager is NOT circular (the default): swiping right on the first page
 *     (Today) or left on the last page (Drinks) does nothing.
 *   - Tapping a bottom-bar item animates to that page; the selected item follows
 *     the current page when the user swipes.
 *
 * Each page is a full screen with its own top bar (including the Settings gear).
 * The pager content is padded by the Scaffold's [innerPadding] so it never sits
 * under the bottom navigation bar.
 */
@Composable
private fun MainPagerHost(
    todayVm: TodayViewModel,
    calendarVm: CalendarViewModel,
    statsVm: StatsViewModel,
    drinksVm: DrinksViewModel,
    onOpenSettings: () -> Unit,
    onOpenHelp: () -> Unit,
    onOpenCopyright: () -> Unit,
    /** Forwarded to each page's [AppOverflowMenu] for the "Lock app" entry. */
    onLockApp: () -> Unit,
) {
    val pagerState = rememberPagerState(pageCount = { mainPages.size })
    val scope = rememberCoroutineScope()

    Scaffold(
        // Each page's own Scaffold handles the top inset; this one only owns the
        // bottom bar, so content insets are zero (matches the previous behaviour).
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            NavigationBar {
                mainPages.forEachIndexed { index, page ->
                    NavigationBarItem(
                        icon = { Icon(page.icon, contentDescription = null) },
                        // Android-standard bottom bar: label under the icon. Each
                        // page carries its own fully-translated label string; the
                        // Statistics tab uses a short synonym (see `mainPages`) so
                        // long translations do not wrap.
                        label = { Text(stringResource(page.titleRes)) },
                        // Highlight the tab for the page currently shown by the
                        // pager — this updates automatically when the user swipes.
                        selected = pagerState.currentPage == index,
                        // animateScrollToPage runs in a coroutine; the pager
                        // enforces the bounds (no wrap-around).
                        onClick = { scope.launch { pagerState.animateScrollToPage(index) } },
                    )
                }
            }
        },
    ) { innerPadding ->
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize().padding(innerPadding),
        ) { page ->
            when (page) {
                0 -> TodayScreen(todayVm, onOpenSettings = onOpenSettings, onOpenHelp = onOpenHelp, onOpenCopyright = onOpenCopyright, onLockApp = onLockApp)
                1 -> CalendarScreen(calendarVm, onOpenSettings = onOpenSettings, onOpenHelp = onOpenHelp, onOpenCopyright = onOpenCopyright, onLockApp = onLockApp)
                2 -> StatsScreen(statsVm, onOpenSettings = onOpenSettings, onOpenHelp = onOpenHelp, onOpenCopyright = onOpenCopyright, onLockApp = onLockApp)
                3 -> DrinksScreen(drinksVm, todayVm, onOpenSettings = onOpenSettings, onOpenHelp = onOpenHelp, onOpenCopyright = onOpenCopyright, onLockApp = onLockApp)
            }
        }
    }
}
