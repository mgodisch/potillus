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
//   ../fastlane/potillus_report_<de|en>.pdf files by the `make screenshots`
//   Makefile target AFTER this suite runs (see android/Makefile). The numeric
//   filename prefixes guarantee the Play console lists all eight assets 1..8 in
//   lexicographic order.
//
// HOW IT FITS THE FASTLANE SCREENGRAB FLOW
//   `fastlane screengrab` (see ../fastlane/Screengrabfile + ../fastlane/Fastfile)
//   installs the app + this test APK, then for EACH locale (de-DE, en-US):
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
import androidx.test.uiautomator.UiDevice
import de.godisch.potillus.MainActivity
import de.godisch.potillus.PotillusApp
import de.godisch.potillus.R
import de.godisch.potillus.domain.LocaleDetector
import de.godisch.potillus.domain.model.ThemeMode
import de.godisch.potillus.l10n.SupportedLocales
import de.godisch.potillus.util.BackupManager
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import tools.fastlane.screengrab.Screengrab
import tools.fastlane.screengrab.UiAutomatorScreenshotStrategy
import tools.fastlane.screengrab.locale.LocaleTestRule
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

    // ── Capture timing constants ──────────────────────────────────────────────
    private val readyTimeoutMs = 15_000L
    private val uiTimeoutMs     = 8_000L

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
        app    = ApplicationProvider.getApplicationContext()
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

            // Today is the pager start page, so it is already on screen.
            Screengrab.screenshot("01_today")

            navigateToTab(R.string.calendar)
            Screengrab.screenshot("02_calendar")

            navigateToTab(R.string.statistics)
            Screengrab.screenshot("03_statistics")
        }

        // ── DARK phase: Drinks, Add-drink dialog, Settings ────────────────────
        applyTheme(ThemeMode.NIGHT)
        ActivityScenario.launch(MainActivity::class.java).use {
            waitUntilReady()

            navigateToTab(R.string.drinks)
            waitUntilDrinksLoaded()
            Screengrab.screenshot("04_drinks")

            openAddDrinkDialog()
            Screengrab.screenshot("05_add_drink")
            dismissDialog()

            openSettings()
            Screengrab.screenshot("06_settings")
        }
    }

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
     * Blocks until the Drinks list has actually rendered its rows, rather than only
     * until Compose is idle.
     *
     * WHY THIS IS NEEDED
     *   DrinksViewModel.uiState is a StateFlow seeded with an EMPTY DrinksUiState()
     *   that is filled only once its backing Room Flow emits (it is built with
     *   stateIn(..., DrinksUiState())). composeRule.waitForIdle() returns as soon as
     *   Compose has no pending recomposition or animation work, which can happen
     *   BEFORE that first database emission arrives — capturing then yields the
     *   empty-state screen ("No drinks defined yet."), the cause of the
     *   intermittently blank 04_drinks shot (empty in one locale run, populated in
     *   the other — the signature of a race).
     *
     *   We wait until the empty-state label (R.string.no_drinks) is gone, i.e. the
     *   real list has replaced it. This asserts only that loading finished, not how
     *   many rows exist, so it stays correct if the demo fixture changes. The
     *   preceding navigateToTab() already idles on the composed (still-empty) screen,
     *   so the label is present when we start waiting and its disappearance is a
     *   reliable "data has loaded" signal.
     */
    private fun waitUntilDrinksLoaded() {
        val emptyLabel = label(R.string.no_drinks)
        composeRule.waitUntil(uiTimeoutMs) {
            composeRule.onAllNodes(hasText(emptyLabel)).fetchSemanticsNodes().isEmpty()
        }
        composeRule.waitForIdle()
    }

    /**
     * Opens the "Add drink" dialog from the Drinks screen by tapping the FAB
     * (identified by its localized contentDescription) and waits until the dialog
     * title (a Text node carrying the same localized string) is present.
     */
    private fun openAddDrinkDialog() {
        val addDrink = label(R.string.add_drink)
        composeRule.onNode(hasContentDescription(addDrink) and hasClickAction()).performClick()
        composeRule.waitUntil(uiTimeoutMs) {
            composeRule.onAllNodes(hasText(addDrink)).fetchSemanticsNodes().isNotEmpty()
        }
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
     * (the only clickable node with that text). Waits for the Settings screen's
     * Back button to appear so the screen is fully laid out before capture.
     */
    private fun openSettings() {
        composeRule.onNode(hasContentDescription(label(R.string.menu)) and hasClickAction())
            .performClick()
        composeRule.waitForIdle()

        composeRule.onNode(hasText(label(R.string.settings)) and hasClickAction())
            .performClick()

        val backLabel = label(R.string.back)
        composeRule.waitUntil(uiTimeoutMs) {
            composeRule.onAllNodes(hasContentDescription(backLabel)).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.waitForIdle()
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
     * Builds a Context whose resources resolve in the run's target locale, or the
     * default app context when no `testLocale` was provided (non-screengrab runs).
     */
    private fun localizedContext(): Context {
        val base = ApplicationProvider.getApplicationContext<Context>()
        val raw  = screengrabLocaleArg() ?: return base
        // screengrab passes locales as "en_US" or "en-US"; forLanguageTag wants '-'.
        val tag = raw.replace('_', '-')
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(tag))
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
        val locale = if (raw != null) Locale.forLanguageTag(raw.replace('_', '-'))
                     else Locale.getDefault()
        return LocaleDetector.detect(locale, SupportedLocales.TAGS)
    }

    private companion object {
        /** Demo fixture file name inside the (generated) androidTest assets. */
        const val DEMO_BACKUP_ASSET = "demo-backup.json"
    }
}
