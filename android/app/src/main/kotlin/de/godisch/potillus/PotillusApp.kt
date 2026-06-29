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
package de.godisch.potillus

// =============================================================================
// PotillusApp.kt – Application class (app entry point)
// =============================================================================
//
// WHY AN APPLICATION CLASS?
//   Android creates an Application instance before any Activity or Service.
//   It lives as long as the app process runs and is therefore the right place
//   for objects that must exist for the entire app lifetime.
//
// WITHOUT A DI FRAMEWORK:
//   Libraries like Hilt (Google) or Koin automate dependency management but
//   add build complexity. For a single-user app, manual management here is
//   sufficient.
//
// KOTLIN "by lazy { }":
//   Lazy initialisation: the object is created on FIRST ACCESS, not at app
//   startup (which would slow cold start). Thread-safe by default
//   (LazyThreadSafetyMode.SYNCHRONIZED).
// =============================================================================

import android.app.Application
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.data.db.AppDatabase
import de.godisch.potillus.data.prefs.AppPreferences
import de.godisch.potillus.data.prefs.IAppPreferences
import de.godisch.potillus.data.repository.BackupRepository
import de.godisch.potillus.data.repository.DrinkRepository
import de.godisch.potillus.data.repository.EntryRepository
import de.godisch.potillus.data.repository.IBackupRepository
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.data.repository.IEntryRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import de.godisch.potillus.domain.LocaleDetector
import de.godisch.potillus.l10n.SupportedLocales
import java.time.LocalDate
import java.util.Locale

/**
 * Application class for Libellus Potionis (Potillus).
 *
 * Exposes all shared singleton objects as properties.
 * Registered in AndroidManifest.xml via android:name=".PotillusApp".
 */
class PotillusApp : Application() {

    /**
     * Long-lived coroutine scope tied to the application process lifetime.
     *
     * Used wherever a coroutine must outlive any single ViewModel – for example
     * the Room database prepopulation callback. SupervisorJob ensures that a
     * failure in one child coroutine does not cancel its siblings.
     *
     * WHY no default dispatcher?
     *   The scope deliberately does not pin a default dispatcher so that each
     *   consumer can choose the correct one explicitly:
     *     - `launch(Dispatchers.IO)` for database / file I/O.
     *     - `launch(Dispatchers.Main)` for UI-thread operations (e.g. locale change).
     *     - `launch(Dispatchers.Default)` for CPU-intensive work.
     *
     *   Previously this scope defaulted to `Dispatchers.IO`, which worked but was
     *   misleading: callers that needed `Dispatchers.Main` had to switch manually
     *   (as `applyLanguageOnFirstLaunch` does), and a reader unfamiliar with that
     *   call would assume it runs on IO. Omitting the default makes the dispatcher
     *   choice explicit at every launch site and avoids surprises.
     */
    val applicationScope: CoroutineScope = CoroutineScope(SupervisorJob())

    /**
     * Room database singleton.
     *
     * Lazy: created on first access.
     * AppDatabase.getInstance() itself enforces a single instance via
     * double-checked locking in AppDatabase.kt.
     *
     * The [applicationScope] is passed so that the prepopulation callback
     * can launch coroutines that are properly scoped to the process lifetime.
     */
    val database: AppDatabase by lazy {
        AppDatabase.getInstance(this, applicationScope)
    }

    /** DataStore preferences – "this" is the Application context (same lifetime as the process). */
    val appPreferences: IAppPreferences by lazy { AppPreferences(this) }

    /** Repository for drink definitions. Accessing this triggers database initialisation. */
    val drinkRepository: IDrinkRepository by lazy { DrinkRepository(database.drinkDao()) }

    /** Repository for consumption entries. */
    val entryRepository: IEntryRepository by lazy { EntryRepository(database.entryDao()) }

    /**
     * Transactional backup import repository.
     *
     * Owns the database transaction that spans the `entries` and `drinks`
     * tables during backup import. Injected into [SettingsViewModel] so
     * the ViewModel no longer needs a direct [AppDatabase] reference.
     */
    val backupRepository: IBackupRepository by lazy {
        BackupRepository(database.entryDao(), database.drinkDao(), database)
    }

    // ── Annual info dialog ──────────────────────────────────────────────────────
    //   Shown at most once per calendar year, and ONLY when the app is opened on
    //   December 27th (device-local date). If the app is not opened that day, the
    //   dialog is simply skipped for the year — it is never caught up later. The
    //   decision is made once per process start in [checkAnnualInfoDialog]; the
    //   "shown year" is persisted via [IAppPreferences.infoDialogShownYear].
    private val _infoDialog = MutableStateFlow(false)

    /** Emits `true` when the annual info dialog should be shown. Observed by `MainActivity`. */
    val infoDialog: StateFlow<Boolean> = _infoDialog.asStateFlow()

    /** Clears [infoDialog] after the user has tapped OK. */
    fun dismissInfoDialog() { _infoDialog.value = false }

    /**
     * Process entry point. Runs the one-shot startup tasks that must happen
     * before the first Activity reads settings: first-launch language detection
     * and the annual info dialog.
     *
     * They run on [Dispatchers.IO] because they read DataStore; the few
     * UI-thread calls inside switch dispatcher explicitly via [withContext].
     */
    override fun onCreate() {
        super.onCreate()
        // Explicitly choose Dispatchers.IO for the DataStore read inside
        // applyLanguageOnFirstLaunch(). Without a default dispatcher on applicationScope,
        // every consumer must specify the dispatcher at the launch site.
        applicationScope.launch(Dispatchers.IO) {
            // applyLanguageOnFirstLaunch() needs the startup settings snapshot.
            val startupSettings = appPreferences.settingsFlow.first()
            applyLanguageOnFirstLaunch(startupSettings)
            checkAnnualInfoDialog()
        }
    }

    /**
     * Decides whether to show the annual info dialog. It is shown only when the
     * device-local date is December 27th and the dialog has not already been shown
     * this calendar year (tracked via [IAppPreferences.infoDialogShownYear]). The
     * "shown year" is persisted immediately so the dialog appears at most once per
     * year and is never caught up if Dec 27 is missed. Runs once per process start
     * on Dispatchers.IO (the DataStore read/write is suspending).
     */
    private suspend fun checkAnnualInfoDialog() {
        val today = LocalDate.now()
        if (today.monthValue == 12 && today.dayOfMonth == 27) {
            if (appPreferences.infoDialogShownYear.first() != today.year) {
                appPreferences.setInfoDialogShownYear(today.year)
                _infoDialog.value = true
            }
        }
    }

    /**
     * On the very first launch (no language stored yet), derive the preferred language
     * from the system locale and persist it. Falls back to "en" if the system language
     * is not among the supported ones.
     *
     * This ensures the UI locale matches what the user sees at first start, without
     * waiting for the user to open Settings.
     *
     * CANDIDATE SET – derived from [SupportedLocales.ALL], never hard-coded:
     *   The candidate set is taken directly from [SupportedLocales.TAGS] rather
     *   than a hand-maintained `setOf(…)`. A hard-coded list inevitably drifts out
     *   of sync with the translations: a user whose system language has a complete
     *   translation would still receive English on first launch merely because the
     *   list was never updated for that locale. Deriving from the single source of
     *   truth covers every locale automatically, including future additions, with
     *   no further change to this function.
     *
     * MATCHING STRATEGY:
     *   Delegated to [de.godisch.potillus.domain.LocaleDetector.detect], which is a
     *   pure, Android-free function and therefore unit-testable on the JVM without a
     *   device (see [de.godisch.potillus.domain.LocaleDetectorTest]). The strategy
     *   (full-tag → base-language → "en") is documented in LocaleDetector.kt.
     *
     * THREAD: called on Dispatchers.IO; [AppCompatDelegate.setApplicationLocales]
     * switches to Dispatchers.Main via [withContext] for the one UI call that
     * requires the main thread.
     *
     * @param startupSettings Settings snapshot captured in [onCreate] before any
     *                        startup write; its [AppSettings.language] is the
     *                        "already chosen?" signal.
     */
    private suspend fun applyLanguageOnFirstLaunch(startupSettings: AppSettings) {
        val stored = startupSettings.language
        if (stored.isNotEmpty()) return          // already set, nothing to do

        // Delegate the pure locale-matching logic to LocaleDetector so it can be
        // unit-tested independently of this Android Application subclass.
        val chosen = LocaleDetector.detect(Locale.getDefault(), SupportedLocales.TAGS)

        appPreferences.setLanguage(chosen)
        // AppCompatDelegate.setApplicationLocales() internally calls
        // Activity.recreate() and must run on the Main thread. The surrounding
        // coroutine runs on Dispatchers.IO (applicationScope), so we switch
        // dispatcher for just this call and return to IO afterwards.
        withContext(Dispatchers.Main) {
            AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(chosen))
        }
    }
}
