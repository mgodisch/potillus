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
package de.godisch.potillus.screenshot

// =============================================================================
// ScreenshotTest.kt — fully automated Play-Store screenshot capture
// =============================================================================
//
// WHAT THIS TEST PRODUCES
//   Six of the eight Play-Store phone screenshots, in capture (and therefore
//   Play-ordering) sequence:
//
//       01_today        Today screen            LIGHT  (ThemeMode.DAY)
//       02_calendar     Calendar screen         LIGHT
//       03_statistics   Statistics screen       LIGHT
//       04_drinks       Drinks screen           DARK   (ThemeMode.NIGHT)
//       05_add_drink    "Add drink" dialog      DARK
//       06_settings     Settings screen         DARK
//
//   The remaining two assets (07/08) are the two pages of the localized PDF
//   report; they are NOT screenshots and are rendered from the committed
//   ../fastlane/report-pdf/potillus_report_<de|en>.pdf files by the `make screenshots`
//   Makefile target AFTER this suite runs (see android/Makefile). The numeric
//   filename prefixes guarantee the Play console lists all eight assets 1..8 in
//   lexicographic order.
//
// HOW IT FITS THE FASTLANE SCREENGRAB FLOW
//   `fastlane screengrab` (see ../fastlane/Screengrabfile + ../fastlane/Fastfile)
//   installs the app + this test APK, then for EACH configured locale:
//     1. switches the device/app locale and re-runs this test,
//     2. LocaleTestRule applies the locale inside the test process,
//     3. Screengrab.screenshot(name) captures the current screen, and
//     4. screengrab pulls the PNGs into
//        ../fastlane/metadata/android/<locale>/images/phoneScreenshots/.
//   screengrab CLEARS app data between locales, so this test re-seeds the
//   database on every run (see [setUp]); it must never assume left-over state.
//
// WHY A FULL-SCREEN (UiAutomator) CAPTURE STRATEGY
//   The task requires a CLEAN system status bar (Android Demo Mode: clock 10:00,
//   full battery, full Wi-Fi, no notifications) to be visible IN the saved
//   image. Compose's in-process DecorView capture only draws the app window and
//   would crop the system bars out, so we install screengrab's
//   UiAutomatorScreenshotStrategy, which grabs the WHOLE screen.
//
// INTERACTION WITH FLAG_SECURE
//   MainActivity sets WindowManager.LayoutParams.FLAG_SECURE on every launch to
//   keep this health-sensitive app out of screenshots / Recents. A full-screen
//   UiAutomator capture of a FLAG_SECURE window yields a BLACK image. The app
//   already exposes a user setting that clears the flag — AppSettings
//   .allowScreenshots — so instead of weakening production code we set that
//   preference to `true` before launching (see [setUp]); MainActivity's live
//   settings collector then clears FLAG_SECURE for the duration of the run. The
//   change is confined to the debug build used for capture and is reset by
//   screengrab's data-clear between locales.
//
// DETERMINISM CHOICES
//   - Theme is fixed BEFORE each Activity launch (DAY for 01-03, NIGHT for
//     04-06) using two separate ActivityScenario launches, so the theme is
//     applied at first composition and there is no mid-run recomposition race.
//   - Navigation never relies on test tags (the production UI has none): nav
//     targets are selected by their localized label TEXT combined with a click
//     action, which uniquely identifies the merged NavigationBarItem and never
//     collides with the (non-clickable) TopAppBar title of the same text.
//   - Every capture goes through [capture], which enforces the two-stage
//     readiness contract described below. No screenshot is ever taken directly.
//
// THE TWO-STAGE READINESS CONTRACT (v0.81.0 QA fix)
//   A screenshot is only correct when BOTH of these hold:
//
//     (a) DATA-READY — the screen's ViewModel has emitted its first real value.
//         Every screen ViewModel exposes its state via
//         `stateIn(..., <UiState>())`, whose SEED is an all-empty snapshot shown
//         until the backing Room Flow emits. Waiting for a STATIC element (a nav
//         label, a section heading) therefore proves nothing: those are laid out
//         in the very first frame, seed data and all. The captures previously
//         waited exactly like that, so whether a run caught the seed frame or the
//         real one was pure timing luck — and the luck differed per locale,
//         because applyCaptureLanguage() recreates the Activity (and with it the
//         ViewModels) only in locales that differ from the device language. The
//         committed store assets showed the symptom directly: 14 of 21 locales
//         had a Today card reading "Ø" with 0.0 g/day instead of "Ø June" with
//         8.0 g/day, 6 of 21 had a Calendar with no day markers and no detail
//         card, and 7 of 21 had an EMPTY Drinks list. Each wait therefore now
//         keys on a POSITIVE, DATA-DERIVED marker that cannot exist in the seed
//         state (the month name in the Today caption, the day-detail label the
//         Calendar only renders once a day is selected, the fixture's period
//         total on Statistics, a drink row's edit icon on Drinks).
//
//     (b) FRAME-READY — the window that carries those nodes is actually the one
//         on the display. Compose's idling machinery answers questions about the
//         SEMANTICS tree; screengrab's UiAutomatorScreenshotStrategy grabs the
//         COMPOSITOR's surface. The two are not synchronized: a destination that
//         has composed (so its semantics, e.g. the Settings back arrow, are
//         already findable) may still be mid-transition on screen. That gap
//         explains the 9 of 21 `06_settings.png` assets that show the Drinks
//         screen. [capture] therefore additionally waits for the marker in the
//         DEVICE's accessibility tree via UiAutomator and then for the device to
//         go idle (no window updates), which is the observable signal that the
//         transition has finished.
//
//   Both stages FAIL LOUDLY on timeout (ComposeTimeoutException / an explicit
//   check()). That is the point: a red test is cheap, a silently wrong store
//   asset in 14 languages is not.
//
// WHY THE MARKERS ARE LOCALE-SAFE
//   Every expected string is resolved through the SAME sources production uses:
//   string resources via [localizedContext] (keyed on the detected app language
//   tag), month names via `TextStyle.FULL_STANDALONE` on that tag — exactly what
//   TodayViewModel does — and numbers via `Double.fmt1(locale)`, the app's own
//   formatter. A marker can therefore never drift from what the UI renders, in
//   any of the 21 shipped languages.
//
// HOW TO RUN
//   Normally via:   make screenshots         (drives demo mode + both locales)
//   Directly:       ./gradlew connectedDebugAndroidTest
//                   (captures in the device's current locale; no demo mode)
//   This suite is tagged @ScreenshotOnly so it can be excluded on demand — see
//   ScreenshotOnly.kt and `make test-device EXCLUDE_SCREENSHOTS=1`.
// =============================================================================

import android.content.Context
import android.content.res.Configuration
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.performClick
import androidx.core.os.LocaleListCompat
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.BySelector
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import de.godisch.potillus.MainActivity
import de.godisch.potillus.PotillusApp
import de.godisch.potillus.R
import de.godisch.potillus.domain.LocaleDetector
import de.godisch.potillus.domain.model.ThemeMode
import de.godisch.potillus.l10n.SupportedLocales
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.util.BackupManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import tools.fastlane.screengrab.Screengrab
import tools.fastlane.screengrab.UiAutomatorScreenshotStrategy
import tools.fastlane.screengrab.locale.LocaleTestRule
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

@RunWith(AndroidJUnit4::class)
@ScreenshotOnly
class ScreenshotTest {

    /**
     * Applies the locale that `fastlane screengrab` requests for this run (passed
     * as the `testLocale` instrumentation argument) so the captured UI is rendered
     * in that language. When the suite is run WITHOUT screengrab (e.g. a plain
     * `connectedDebugAndroidTest`), no `testLocale` is supplied and the rule is a
     * no-op, so capture simply happens in the device's current locale.
     */
    @get:Rule
    val localeTestRule = LocaleTestRule()

    /**
     * An EMPTY Compose rule: it hooks this test into Compose's idling/finder
     * machinery WITHOUT launching an Activity itself. We launch [MainActivity]
     * explicitly via [ActivityScenario] AFTER seeding data and fixing the theme,
     * which a content-launching rule (createAndroidComposeRule) would not allow,
     * because it starts the Activity at rule-application time — before our @Before
     * could prepare the database and preferences.
     */
    @get:Rule
    val composeRule = createEmptyComposeRule()

    private lateinit var app: PotillusApp
    private lateinit var device: UiDevice

    /**
     * The parsed demo fixture, kept for the whole test.
     *
     * The capture markers are derived FROM THE FIXTURE rather than hard-coded, so
     * they follow `fastlane/demo-backup.json` when it changes: the Statistics
     * marker is the fixture's own capture-month total, and the Drinks marker only
     * asserts that at least one imported drink row exists. See [capture].
     */
    private lateinit var fixture: BackupManager.ImportResult

    // ── Capture timing constants ──────────────────────────────────────────────
    private val readyTimeoutMs = 15_000L
    private val uiTimeoutMs = 8_000L

    /**
     * Prepares a clean, deterministic starting state for every run (screengrab
     * clears app data between locales, so this cannot assume anything survives):
     *
     *  1. Waits for the one-shot preset prepopulation to finish, THEN seeds the
     *     database from the canonical demo fixture (../fastlane/demo-backup.json,
     *     copied into the test APK assets at build time). Awaiting the presets first
     *     stops the import from racing the async PrepopulateCallback and inserting a
     *     duplicate copy of every preset drink.
     *  2. Clears FLAG_SECURE for the run by enabling AppSettings.allowScreenshots,
     *     so the full-screen UiAutomator capture is not black.
     *  3. Forces the displayed language to the one screengrab requested via the
     *     `testLocale` argument, by setting BOTH the app's `language` preference and
     *     its live per-app locale. This drives the same path as the in-app language
     *     picker, so the rendered UI language is deterministic and does NOT depend on
     *     the (here unreliable) system-locale switch — otherwise every locale run
     *     comes out in the device language.
     *  4. Clears the statistics start floor (AppSettings.statsFromDate) so the
     *     Statistics period spans the whole demo history instead of being clamped to
     *     the fresh-install default (the APK install date = the capture day).
     *  5. Installs the full-screen screenshot strategy (includes the demo-mode
     *     status bar).
     */
    @Before
    fun setUp() {
        // Pin the app's logical "today" to the demo fixture's last day BEFORE any
        // Activity is launched, so every date-relative screen (Today / Calendar /
        // Statistics) is captured from that fixed perspective — independent of the
        // physical device date, which the Makefile can only pin on emulator/rooted
        // builds. Cleared again in tearDown(). See ScreenshotClock.
        ScreenshotClock.pin()

        app = ApplicationProvider.getApplicationContext()
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

        // 0) Load the demo fixture text from the TEST APK assets via the
        //    instrumentation context (NOT the target context). It is seeded into the
        //    real Room database in step 1b below, so the running app shows it.
        val json = InstrumentationRegistry.getInstrumentation()
            .context.assets.open(DEMO_BACKUP_ASSET)
            .bufferedReader()
            .use { it.readText() }

        val parsed = BackupManager.parseBackupJson(json)
        check(parsed.error == null) { "Demo backup fixture failed to parse: ${parsed.error}" }
        fixture = parsed

        runBlocking {
            // 1a) DETERMINISTIC PRESET PREPOPULATION (fixes duplicate drink rows).
            //     The built-in preset drinks are inserted by Room's PrepopulateCallback
            //     in a coroutine launched on the application scope when the database
            //     file is first created (see AppDatabase.PrepopulateCallback). In a
            //     screenshot run the FIRST database access is the importReplace() below,
            //     so that async seeding and the import race each other: if
            //     importReplace() takes its name-deduplication snapshot before the
            //     presets are in place, it re-inserts every preset under a fresh id AND
            //     the seeding inserts them again → each preset appears twice on the
            //     Drinks screen. Touching the drinks Flow here forces the database open
            //     and suspends until the single preset set has fully landed, so
            //     importReplace() reliably matches the presets by name and reuses their
            //     ids instead of duplicating them.
            //
            //     The demo fixture intentionally mirrors the preset set, so the backup's
            //     drink count equals the number of presets; we wait until at least that
            //     many rows are present. withTimeout guards against a seeding stall.
            withTimeout(readyTimeoutMs) {
                app.drinkRepository.drinks.first { it.size >= parsed.drinks.size }
            }

            // 1b) Seed the demo data through the REAL repository path so the running app
            //     (which reads the same Room database) shows it.
            app.backupRepository.importReplace(parsed.drinks, parsed.entries)

            // 2) Clear FLAG_SECURE for the run so the full-screen capture is not black.
            app.appPreferences.setAllowScreenshots(true)

            // 3) RESET THE STATISTICS START FLOOR (fixes the one-bar statistics chart).
            //    AppSettings.statsFromDate defaults to the APK's install date when unset
            //    (AppPreferences.installDate). screengrab reinstalls the app per locale,
            //    so that default is the capture day; the demo backup carries no settings,
            //    so the floor stays there. StatsViewModel clamps the period start to this
            //    floor, collapsing e.g. the "Month" window to the single capture day —
            //    exactly the lone last-day bar seen on 03_statistics while the Calendar
            //    (which does not clamp) still shows the whole month. Clearing the floor
            //    lets the statistics period span the full demo history again.
            app.appPreferences.setStatsFromDate("")

            // 4) PIN THE STORED LANGUAGE PREFERENCE to the language screengrab asked
            //    for. This also makes PotillusApp.applyLanguageOnFirstLaunch a no-op
            //    (it only acts while the preference is empty), so the app's own
            //    first-launch detection cannot race us and pick the device language.
            //
            //    NOTE: the LIVE per-app locale is intentionally NOT applied here.
            //    screengrab's LocaleTestRule only flips the SYSTEM locale (which did not
            //    change the rendered language on the capture device), and on API 33+
            //    AppCompatDelegate.setApplicationLocales() is applied ASYNCHRONOUSLY by
            //    the framework — so applying it before the Activity exists did not affect
            //    the freshly launched Activity's FIRST frame (it still drew in the device
            //    language, and waitUntilReady then timed out waiting for the target-
            //    language label). Instead the live locale is applied AFTER each Activity
            //    launch, from waitUntilReady() -> applyCaptureLanguage(), with the Activity
            //    already in the foreground — mirroring the in-app language picker, which
            //    recreates the visible Activity into the requested language reliably.
            app.appPreferences.setLanguage(targetLanguageTag())
        }

        // 5) Full-screen capture so the cleaned demo-mode status bar is included.
        Screengrab.setDefaultScreenshotStrategy(UiAutomatorScreenshotStrategy())
    }

    /**
     * Clears the pinned capture clock so the fixed "today" cannot leak into other
     * instrumented tests that share this process (the pin lives in the shared
     * [de.godisch.potillus.domain.DayResolver] singleton).
     */
    @After
    fun tearDown() {
        ScreenshotClock.unpin()
    }

    /**
     * Captures all six in-app screenshots in two theme phases (three LIGHT, then
     * three DARK), each phase using its own [MainActivity] launch so the theme is
     * fixed before the first frame is drawn.
     */
    @Test
    fun captureStoreScreenshots() {
        // ── LIGHT phase: Today, Calendar, Statistics ──────────────────────────
        applyTheme(ThemeMode.DAY)
        ActivityScenario.launch(MainActivity::class.java).use {
            waitUntilReady()

            // Today is the pager start page, so it is already on screen. Its marker
            // is the summary card's average caption WITH the month name: the seed
            // state renders the same string with an empty month ("Ø "), so the
            // month's presence proves the first DB emission has landed.
            capture("01_today", avgOfMonthCaption())

            navigateToTab(R.string.calendar)
            // The day-detail label below the month grid is rendered only once
            // CalendarUiState.selectedDate is non-null, which happens with the first
            // emission; the seed state shows the bare grid without markers.
            capture("02_calendar", label(R.string.no_entries_day))

            // The Statistics tab renders `nav_statistics` (a short synonym of the
            // screen title), so the tab must be located by that label — in some
            // locales (e.g. fr: "Stats") it differs from `statistics`.
            navigateToTab(R.string.nav_statistics)
            // Marker: the "Total in Period" VALUE for the capture month, computed
            // from the fixture and formatted exactly as the screen formats it. The
            // seed state shows "0.0 g" there.
            capture("03_statistics", expectedPeriodTotalText())
        }

        // ── DARK phase: Drinks, Add-drink dialog, Settings ────────────────────
        applyTheme(ThemeMode.NIGHT)
        ActivityScenario.launch(MainActivity::class.java).use {
            waitUntilReady()

            navigateToTab(R.string.drinks)
            // Marker: a drink row's edit icon. It exists per row and only once the
            // drinks Flow has emitted; the seed state shows the "no drinks" label
            // instead. Using a per-row icon keeps the marker independent of the
            // fixture's drink NAMES and of LazyColumn's viewport (the first row is
            // always composed).
            captureByDescription("04_drinks", label(R.string.edit_drink))

            openAddDrinkDialog()
            capture("05_add_drink", label(R.string.add_drink))
            dismissDialog()

            openSettings()
            // Marker: the Settings top-bar Back arrow — the only node in the app
            // with this contentDescription besides the document viewer, which this
            // suite never opens.
            captureByDescription("06_settings", label(R.string.back))
        }
    }

    // ── Capture ───────────────────────────────────────────────────────────────

    /**
     * Captures [name] once the screen is both DATA-READY and FRAME-READY, keyed on
     * a marker TEXT that only the loaded screen can render. See the file header's
     * "two-stage readiness contract" for the full rationale.
     *
     * @param name   screengrab asset name (also the PNG's basename).
     * @param marker localized text that exists on the finished screen and NOT in
     *               its `stateIn` seed state.
     */
    private fun capture(name: String, marker: String) =
        captureWhen(name, hasText(marker), By.text(marker))

    /**
     * Same contract as [capture], but keyed on a `contentDescription` instead of a
     * text node — used where the loaded state is proven by an ICON (the Drinks
     * rows' edit pencil, the Settings back arrow) rather than by a string.
     *
     * @param name   screengrab asset name.
     * @param marker localized contentDescription of the marker node.
     */
    private fun captureByDescription(name: String, marker: String) =
        captureWhen(name, hasContentDescription(marker), By.desc(marker))

    /**
     * The shared implementation of the readiness contract.
     *
     * Stage (a) DATA-READY: block until Compose's semantics tree contains at least
     * one node matching [semantics]. `waitUntil` drives the test clock, so pending
     * recompositions and animations are advanced while we wait, and it THROWS on
     * timeout — a screenshot is never taken from a screen that failed to load.
     *
     * Stage (b) FRAME-READY: block until UiAutomator sees the same marker in the
     * DEVICE's accessibility tree (i.e. the window carrying it is the one attached
     * to the display), then wait for the device to stop reporting window updates.
     * Only then does the compositor's surface — which is what
     * `UiAutomatorScreenshotStrategy` grabs — reliably show this screen. Without
     * this stage a destination could be captured while its predecessor was still
     * being drawn.
     *
     * @param name      screengrab asset name.
     * @param semantics Compose matcher for stage (a).
     * @param selector  equivalent UiAutomator selector for stage (b).
     */
    private fun captureWhen(name: String, semantics: SemanticsMatcher, selector: BySelector) {
        composeRule.waitUntil(readyTimeoutMs) {
            composeRule.onAllNodes(semantics).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.waitForIdle()
        check(device.wait(Until.hasObject(selector), uiTimeoutMs)) {
            "Screen for '$name' never became visible on the device (marker: $selector)"
        }
        device.waitForIdle()
        Screengrab.screenshot(name)
    }

    /**
     * The Today card's average caption exactly as the card renders it for the
     * pinned capture date, e.g. `Ø June` / `Ø Juni` / `Ø 6月`.
     *
     * It mirrors [de.godisch.potillus.ui.screen.TodayViewModel]'s own derivation:
     * the STANDALONE month name of the logical today, resolved in the app language
     * tag (not `Locale.getDefault()`), substituted into `R.string.avg_of_month`.
     * The seed state substitutes an empty string there, which is precisely why this
     * caption is a sound data-ready marker.
     */
    private fun avgOfMonthCaption(): String {
        val month = LocalDate.parse(ScreenshotClock.SCREENSHOT_DATE).month
        val monthName = month.getDisplayName(TextStyle.FULL_STANDALONE, captureLocale())
        return localizedContext().getString(R.string.avg_of_month, monthName)
    }

    /**
     * The Statistics screen's "Total in Period" value for the default MONTH period,
     * formatted the way `StatsScreen` formats it (`Double.fmt1(locale) + " g"`).
     *
     * The grams are summed from the fixture's entries whose logical date falls in
     * the capture month, so the marker follows the demo data instead of pinning a
     * magic number. Summation-order differences against the ViewModel's per-day
     * SQL sums cannot matter: `%.1f` rounds far above the floating-point noise.
     */
    private fun expectedPeriodTotalText(): String {
        val monthPrefix = ScreenshotClock.SCREENSHOT_DATE.substring(0, 7) // "YYYY-MM"
        val total = fixture.entries
            .filter { it.logicalDate.startsWith(monthPrefix) }
            .sumOf { it.gramsAlcohol }
        check(total > 0.0) {
            "Demo fixture has no entries in the capture month $monthPrefix — no Statistics marker"
        }
        return "${total.fmt1(captureLocale())} g"
    }

    /** The [Locale] the app renders this run in — see [targetLanguageTag]. */
    private fun captureLocale(): Locale = Locale.forLanguageTag(targetLanguageTag())

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Persists [mode] and blocks until the preferences flow re-emits it, so the
     * next Activity launch is guaranteed to observe the intended theme at first
     * composition (no reliance on a post-launch recomposition race).
     */
    private fun applyTheme(mode: ThemeMode) = runBlocking {
        app.appPreferences.setTheme(mode)
        app.appPreferences.settingsFlow.first { it.themeMode == mode }
    }

    /**
     * Waits until the navigation surface is present (the localized "Today" label
     * has been laid out), i.e. MainActivity has passed its LOADING/biometric gate
     * and rendered the main UI. The demo data carries no biometric lock, so the
     * gate resolves to READY without a prompt.
     */
    private fun waitUntilReady() {
        applyCaptureLanguage()
        val todayLabel = label(R.string.today)
        composeRule.waitUntil(readyTimeoutMs) {
            composeRule.onAllNodes(hasText(todayLabel)).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.waitForIdle()
    }

    /**
     * Applies the run's target language to the LIVE per-app locale, with the
     * Activity already in the foreground.
     *
     * This mirrors the in-app language picker (the one path known to switch the
     * rendered language reliably on the capture device): with a visible Activity,
     * AppCompatDelegate.setApplicationLocales() recreates it into the new language.
     * It is called from waitUntilReady() right after each launch; the subsequent
     * waitUntil() then absorbs the asynchronous recreate (API 33+ applies the locale
     * off the calling thread). When the language already matches — the device locale,
     * or a second launch in the same run — this is a harmless no-op.
     */
    private fun applyCaptureLanguage() {
        val locales = LocaleListCompat.forLanguageTags(targetLanguageTag())
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            AppCompatDelegate.setApplicationLocales(locales)
        }
    }

    /**
     * Taps a bottom-navigation tab identified by its localized label.
     *
     * The matcher `hasText(label) and hasClickAction()` targets the MERGED
     * NavigationBarItem (which exposes both the label text and the click action);
     * the TopAppBar title of the same text is a separate, non-clickable node, so
     * the selection is unambiguous. After the tap we wait for Compose to go idle,
     * which also lets the pager's scroll animation settle.
     */
    private fun navigateToTab(labelRes: Int) {
        composeRule.onNode(hasText(label(labelRes)) and hasClickAction()).performClick()
        composeRule.waitForIdle()
    }

    /**
     * Opens the "Add drink" dialog from the Drinks screen by tapping the FAB
     * (identified by its localized contentDescription).
     *
     * The dialog's own readiness is asserted by the subsequent [capture] call,
     * which waits for the dialog title (a Text node carrying the same localized
     * string as the FAB's description) and for the dialog window to be on screen.
     *
     * BREADCRUMB: `waitUntilDrinksLoaded()` used to live next to this helper. It
     * waited for the DISAPPEARANCE of the "no drinks" empty-state label — an
     * absence condition that is satisfied VACUOUSLY while the Drinks page has not
     * been composed yet, so it never fired its timeout and let the empty screen be
     * captured in 7 of 21 locales. It was replaced in the v0.81.0 QA round by the
     * positive marker in [captureByDescription] ("04_drinks").
     */
    private fun openAddDrinkDialog() {
        val addDrink = label(R.string.add_drink)
        composeRule.onNode(hasContentDescription(addDrink) and hasClickAction()).performClick()
        composeRule.waitForIdle()
    }

    /** Dismisses the currently shown dialog with the system Back gesture. */
    private fun dismissDialog() {
        device.pressBack()
        composeRule.waitForIdle()
    }

    /**
     * Opens the Settings screen via the top-bar overflow menu: tap the menu icon
     * (localized contentDescription "Menu"), then the "Settings" dropdown entry
     * (the only clickable node with that text).
     *
     * It deliberately does NOT wait for the Settings screen here. Waiting for the
     * back arrow's SEMANTICS only proves that the destination has composed, not
     * that it is drawn — which is how 9 of 21 locales captured the Drinks screen
     * under the name `06_settings`. The wait now lives in [captureByDescription],
     * which additionally requires the marker to be visible in the device's own
     * accessibility tree and the device to be idle.
     */
    private fun openSettings() {
        composeRule.onNode(hasContentDescription(label(R.string.menu)) and hasClickAction())
            .performClick()
        composeRule.waitForIdle()

        composeRule.onNode(hasText(label(R.string.settings)) and hasClickAction())
            .performClick()
    }

    /**
     * Resolves a string resource in the locale requested for this run.
     *
     * Labels are looked up through a configuration-localized Context derived from
     * the `testLocale` instrumentation argument (when present), so they always
     * match the language screengrab is currently capturing — independent of the
     * process default locale.
     */
    private fun label(resId: Int): String = localizedContext().getString(resId)

    /**
     * Builds a Context whose resources resolve in the run's target APP language,
     * or the default app context when no `testLocale` was provided
     * (non-screengrab runs).
     *
     * Resolution goes through [targetLanguageTag] — the DETECTED app tag — and
     * deliberately NOT through the raw store-locale argument: the two differ for
     * Norwegian (store code `no-NO` vs resource tag `nb`), and Android's
     * resource matcher does not bridge that pair, so raw-code resolution fell
     * back to ENGLISH labels while the live app (switched via the same detector
     * in [applyCaptureLanguage]) rendered Norwegian — waitUntilReady() then
     * waited for a label that could never appear (surfaced by the v0.79.0
     * store-locale migration). Resolving expected labels and switching the app
     * through ONE tag removes the divergence by construction, for every present
     * and future store code.
     */
    private fun localizedContext(): Context {
        val base = ApplicationProvider.getApplicationContext<Context>()
        if (screengrabLocaleArg() == null) return base
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(targetLanguageTag()))
        return base.createConfigurationContext(config)
    }

    /**
     * Reads the locale screengrab requested for this run from the instrumentation
     * arguments, or null on a plain `connectedDebugAndroidTest` run.
     *
     * fastlane screengrab passes it as `-e testLocale <locale>` — camelCase, with a
     * CAPITAL L (this is visible in the `am instrument` line screengrab logs).
     * Instrumentation argument keys are CASE-SENSITIVE, so reading "testlocale"
     * (lower-case) silently returned null and every locale run fell back to the
     * device locale — making both stores' captures come out in the device language.
     * We read the exact key screengrab sends and, defensively, also accept the
     * lower-case spelling so a future screengrab casing change cannot re-break this.
     */
    private fun screengrabLocaleArg(): String? {
        val args = InstrumentationRegistry.getArguments()
        return args.getString("testLocale") ?: args.getString("testlocale")
    }

    /**
     * Resolves screengrab's requested `testLocale` instrumentation argument to one of
     * the app's supported language tags (e.g. "de-DE" → "de", "en-US" → "en").
     *
     * Reuses the production matching logic in [LocaleDetector.detect] against
     * [SupportedLocales.TAGS] — the same single source of truth the in-app language
     * picker uses — so the screenshot language can never drift from the set of
     * languages the app actually ships. When no `testLocale` is supplied (a plain
     * connectedDebugAndroidTest run), the device's default locale is used instead.
     */
    private fun targetLanguageTag(): String {
        val raw = screengrabLocaleArg()
        val locale = if (raw != null) {
            Locale.forLanguageTag(raw.replace('_', '-'))
        } else {
            Locale.getDefault()
        }
        return LocaleDetector.detect(locale, SupportedLocales.TAGS)
    }

    private companion object {
        /** Demo fixture file name inside the (generated) androidTest assets. */
        const val DEMO_BACKUP_ASSET = "demo-backup.json"
    }
}
