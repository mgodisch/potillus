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
// ReportExportTest.kt — SEMI-AUTOMATIC per-locale PDF report export
// =============================================================================
//
// WHAT THIS PRODUCES
//   The two report pages that the store pipeline needs (07_report_page_1 /
//   08_report_page_2) are rasterized by `make screenshots-pdf` from a per-locale
//   source PDF `fastlane/report-pdf/potillus_report_<locale>.pdf`. Extracting them
//   by hand is tedious. This test drives the export ONCE per locale so a human
//   only has to confirm the system "Save as PDF" dialog — the file name is even
//   pre-filled with the locale (see WHY THE LOCALE FILE NAME below).
//
// WHY "SEMI-AUTOMATIC" (and not fully silent)
//   The production export goes through the platform print framework on purpose:
//   a WebView produces a PrintDocumentAdapter and PrintManager.print() hands it
//   to the SYSTEM print UI, where the user picks "Save as PDF" (see
//   util/WebViewPdfPrinter). Driving that adapter silently to a file needs a
//   non-public-API hack, and automating the system dialog itself is fragile
//   because its buttons are localized — and we run through 21 languages. So this
//   test does the two robust things only: it TRIGGERS the export, then BLOCKS
//   until the app is in the foreground again (i.e. until the human has confirmed
//   or cancelled the dialog), and advances to the next locale. The human owns the
//   dialog; the automation never has to read a localized label.
//
// WHY THE LOCALE FILE NAME (test-only, production untouched)
//   The print framework offers the print-job name as the default file name in the
//   "Save as PDF" dialog. Production (StatsViewModel.exportPdf) uses a timestamped
//   name via PdfReportBuilder.jobName(Instant.now()) and is NOT changed. This test
//   instead calls the print path directly with jobName = "potillus_report_<loc>.pdf",
//   so the dialog pre-fills exactly the name the store pipeline expects and the
//   human only taps "Save". The locale name therefore lives entirely in this
//   androidTest source set.
//
// HOW IT IS INVOKED (and why it is inert otherwise)
//   Only the dedicated `make report-pdfs` target runs it, once per locale:
//
//       adb shell am instrument -w \
//         -e class de.godisch.potillus.screenshot.ReportExportTest \
//         -e reportExport true -e testLocale <locale> \
//         de.godisch.potillus.debug.test/androidx.test.runner.AndroidJUnitRunner
//
//   Because it needs a human at the device, it must NEVER run in the ordinary
//   `connectedDebugAndroidTest` / `make test-device` gate or during
//   `make screenshots` (screengrab selects this whole package). The guard is a
//   single Assume in [setUp]: without `-e reportExport true` the test is SKIPPED
//   (a JUnit assumption failure, not an error), so no Activity is launched and no
//   dialog opens. That keeps the exclusion self-contained here — no build.gradle
//   or Screengrabfile change is needed.
//
// LOCALE + DATA
//   The report language comes from a Context configured for the requested
//   `testLocale` (PdfReportBuilder reads strings and the formatting locale from
//   the Context), so it is deterministic and independent of the device language.
//   The report content is the canonical demo fixture (../fastlane/demo-backup.json)
//   seeded exactly like ScreenshotTest, so these PDFs match the committed de/en
//   reports (two pages -> 07/08).
// =============================================================================

import android.content.Context
import android.content.res.Configuration
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import de.godisch.potillus.MainActivity
import de.godisch.potillus.PotillusApp
import de.godisch.potillus.util.BackupManager
import de.godisch.potillus.util.PdfReportBuilder
import de.godisch.potillus.util.WebViewPdfPrinter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale

@RunWith(AndroidJUnit4::class)
@ScreenshotOnly
class ReportExportTest {

    private lateinit var app: PotillusApp
    private lateinit var device: UiDevice

    /**
     * Prepares the run and, first of all, GUARDS it: unless the caller passed
     * `-e reportExport true`, the Assume fails and the whole test is skipped
     * before anything else happens (no Activity, no dialog). This is what keeps
     * the human-in-the-loop export out of the ordinary test and screenshot runs.
     *
     * When the guard passes, the setup mirrors ScreenshotTest.setUp so the report
     * is filled with the same canonical demo data:
     *   1. Await the one-shot preset prepopulation, then seed the demo fixture via
     *      the real repository path (racing that async seeding would duplicate the
     *      preset drinks — see ScreenshotTest for the full rationale).
     *   2. Enable AppSettings.allowScreenshots so MainActivity clears FLAG_SECURE
     *      for the run (keeps the print preview/thumbnail from being a black
     *      secure-window capture; confined to the debug build and reset by
     *      screengrab's data-clear between locales).
     */
    @Before
    fun setUp() {
        // GUARD: only the explicit `make report-pdfs` invocation sets this.
        assumeTrue(
            "ReportExportTest runs only when invoked with -e reportExport true",
            InstrumentationRegistry.getArguments().getString("reportExport")?.toBoolean() == true
        )

        app    = ApplicationProvider.getApplicationContext()
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

        val json = InstrumentationRegistry.getInstrumentation()
            .context.assets.open(DEMO_BACKUP_ASSET)
            .bufferedReader()
            .use { it.readText() }
        val parsed = BackupManager.parseBackupJson(json)
        check(parsed.error == null) { "Demo backup fixture failed to parse: ${parsed.error}" }

        runBlocking {
            // Force the preset drinks to land before the import takes its
            // name-dedup snapshot, so presets are matched by name instead of
            // duplicated (identical to ScreenshotTest.setUp step 1a).
            withTimeout(READY_TIMEOUT_MS) {
                app.drinkRepository.drinks.first { it.size >= parsed.drinks.size }
            }
            app.backupRepository.importReplace(parsed.drinks, parsed.entries)
            app.appPreferences.setAllowScreenshots(true)
        }
    }

    /**
     * Builds the localized report HTML from the demo data, launches [MainActivity]
     * (the print dialog needs an Activity context and a foreground window), opens
     * the system "Save as PDF" dialog with a locale-named print job, and then
     * blocks until the human has finished in the dialog and the app is foreground
     * again — at which point the instrumentation returns and `make report-pdfs`
     * advances to the next locale.
     */
    @Test
    fun exportLocalizedReport() {
        val loc = reportLocaleTag()
        val ctx = localizedContext()

        // Assemble the report exactly like StatsViewModel.exportPdf, but over the
        // FULL demo history (the report derives its period from the entries it is
        // given) and with a Context pinned to the target locale so strings and
        // number/date formatting are deterministic.
        val html = runBlocking {
            val settings = app.appPreferences.settingsFlow.first()
            val entries  = app.entryRepository.getInRange(RANGE_FROM, RANGE_TO)
            check(entries.isNotEmpty()) { "Demo fixture produced no entries for '$loc'." }
            val drinks   = app.drinkRepository.drinks.first()
            PdfReportBuilder.buildHtml(ctx, entries, drinks, settings)
        }

        val jobName = "potillus_report_$loc.pdf"

        ActivityScenario.launch(MainActivity::class.java).use {
            // A launched ActivityScenario is RESUMED; give the first frame a moment
            // to settle, then open the print dialog from the Activity (main thread).
            device.waitForIdle()
            it.onActivity { activity ->
                WebViewPdfPrinter.print(activity, html, jobName)
            }
            awaitHumanConfirmation(loc, jobName)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Blocks while the human works the system print / "Save as PDF" dialog.
     *
     * The mechanism deliberately avoids reading any localized dialog text: it only
     * watches whether the app-under-test package owns the foreground window.
     *   1. After [WebViewPdfPrinter.print] the WebView lays the HTML out
     *      asynchronously and PrintManager then opens the system print UI, which
     *      backgrounds our Activity — so the app package goes AWAY from the screen.
     *   2. When the human has saved (or cancelled) and the dialog closes, our
     *      Activity returns to the foreground — the app package is BACK.
     * A generous return timeout means there is no time pressure at the device.
     */
    private fun awaitHumanConfirmation(loc: String, jobName: String) {
        val pkg = InstrumentationRegistry.getInstrumentation().targetContext.packageName
        // Surface a clear prompt in the instrumentation log / console.
        println("report-pdfs[$loc]: tap \"Save as PDF\" -> \"$jobName\" -> Save (name is pre-filled).")
        // 1) Dialog should take over the screen shortly (we leave the foreground).
        device.wait(Until.gone(By.pkg(pkg)), DIALOG_APPEAR_TIMEOUT_MS)
        // 2) Wait until the app is foreground again = the human is done with this one.
        device.wait(Until.hasObject(By.pkg(pkg)), HUMAN_TIMEOUT_MS)
        device.waitForIdle()
    }

    /**
     * The locale tag used BOTH for the file name and for content localization,
     * taken from the `testLocale` instrumentation argument that `make report-pdfs`
     * passes (one of the store-locale directory names, e.g. "de-DE", "fr",
     * "zh-CN"). screengrab-style callers may spell it "de_DE"; normalize to '-'.
     * Falls back to the device locale if the argument is somehow absent.
     */
    private fun reportLocaleTag(): String {
        val raw = InstrumentationRegistry.getArguments().getString("testLocale")
        return raw?.replace('_', '-') ?: Locale.getDefault().toLanguageTag()
    }

    /**
     * A Context whose resources resolve in the run's target locale, so
     * [PdfReportBuilder.buildHtml] renders both its strings and its
     * locale-formatted numbers/dates in that language, independent of the device
     * language (Android resolves e.g. "zh-CN" to values-zh-rCN just as it does at
     * runtime). Mirrors ScreenshotTest.localizedContext.
     */
    private fun localizedContext(): Context {
        val base   = ApplicationProvider.getApplicationContext<Context>()
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(reportLocaleTag()))
        return base.createConfigurationContext(config)
    }

    private companion object {
        /** Demo fixture file name inside the (generated) androidTest assets. */
        const val DEMO_BACKUP_ASSET = "demo-backup.json"

        /** Wide date window so getInRange returns the ENTIRE demo history. */
        const val RANGE_FROM = "0001-01-01"
        const val RANGE_TO   = "9999-12-31"

        // ── Timing constants ──────────────────────────────────────────────────
        /** Preset-prepopulation await guard (matches ScreenshotTest). */
        const val READY_TIMEOUT_MS = 15_000L
        /** How long to wait for the print dialog to take over the screen. */
        const val DIALOG_APPEAR_TIMEOUT_MS = 20_000L
        /** How long the human may take per locale in the dialog (no time pressure). */
        const val HUMAN_TIMEOUT_MS = 300_000L
    }
}
