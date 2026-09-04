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
import android.content.res.Resources
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import de.godisch.potillus.data.db.AppDatabase
import de.godisch.potillus.data.prefs.AppPreferences
import de.godisch.potillus.data.prefs.IAppPreferences
import de.godisch.potillus.data.repository.BackupRepository
import de.godisch.potillus.data.repository.DrinkRepository
import de.godisch.potillus.data.repository.EntryRepository
import de.godisch.potillus.data.repository.IBackupRepository
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.data.repository.IEntryRepository
import de.godisch.potillus.data.repository.RoomTransactor
import de.godisch.potillus.domain.LocaleDetector
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.l10n.SupportedLocales
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
    val entryRepository: IEntryRepository by lazy {
        EntryRepository(
            dao = database.entryDao(),
            keyDao = database.logicalDayKeyDao(),
            transactor = RoomTransactor(database),
        )
    }

    /**
     * Transactional backup import repository.
     *
     * Owns the database transaction that spans the `entries` and `drinks`
     * tables during backup import. Injected into [SettingsViewModel] so
     * the ViewModel no longer needs a direct [AppDatabase] reference.
     */
    val backupRepository: IBackupRepository by lazy {
        BackupRepository(
            database.entryDao(),
            database.drinkDao(),
            database.logicalDayKeyDao(),
            database,
        )
    }

    /**
     * Process entry point. Runs the one-shot startup task that must happen
     * before the first Activity reads settings: the system-language detection.
     *
     * It runs on [Dispatchers.IO] because it reads DataStore; the few
     * UI-thread calls inside switch dispatcher explicitly via [withContext].
     */
    override fun onCreate() {
        super.onCreate()
        // Explicitly choose Dispatchers.IO for the DataStore read inside
        // applySystemLanguage(). Without a default dispatcher on applicationScope,
        // every consumer must specify the dispatcher at the launch site.
        applicationScope.launch(Dispatchers.IO) {
            // applySystemLanguage() needs the startup settings snapshot.
            val startupSettings = appPreferences.settingsFlow.first()
            applySystemLanguage(startupSettings)
        }
        applicationScope.launch(Dispatchers.IO) {
            keepLogicalDaysAligned()
        }
    }

    /**
     * Keeps `entries.logicalDate` in step with the day-change setting, for as
     * long as the process lives.
     *
     * WHY A COLLECTION AND NOT A SINGLE READ. The logical day is derived from the
     * day-change time, so moving that setting changes what every screen should
     * show — retroactively, which is the point of the whole design. Reading the
     * setting once at startup would postpone the effect to the next launch and
     * leave the app showing days that no longer follow from the setting the user
     * is looking at.
     *
     * WHY IT IS CHEAP TO RUN ON EVERY EMISSION. `settingsFlow` emits for any
     * preference the user touches, most of which have nothing to do with days.
     * [IEntryRepository.realignDays] compares the setting against the key first
     * and returns having read one row when they agree, which is almost always.
     *
     * WHY IT IS SAFE TO START BEFORE ANYTHING ELSE. The first emission usually
     * finds the key unset — a fresh `MIGRATION_3_4` leaves it that way — and does
     * the initial derivation, including the repair of pre-0.85.0 calendar
     * entries. If the preference store cannot be read at all, the flow does not
     * emit, nothing runs, and the app shows the days as stored: what the previous
     * release showed permanently. Nothing is guessed and nothing is lost, because
     * the old `logicalDate` stays until a run completes.
     *
     * THREAD: Dispatchers.IO. The collection reads DataStore and the realignment
     * writes the database; neither belongs on the main thread, and the settings
     * screen stays responsive while a large rewrite runs.
     */
    private suspend fun keepLogicalDaysAligned() {
        appPreferences.settingsFlow.collect { settings ->
            entryRepository.realignDays(settings)
        }
    }

    /**
     * While no language is chosen (`language == ""`, the "(System)" state),
     * derive the UI language from the SYSTEM locale on every launch and apply it
     * as the per-app locale — without persisting it. Falls back to "en" if the
     * system language is not among the supported ones.
     *
     * NOT PERSISTED, SINCE THE v0.86.0 REVIEW. Until then this ran once and wrote
     * the detected tag into the preferences, so "(System)" was never the state
     * after the first start: a phone switched from German to French kept a
     * German app, while iOS — which leaves the choice empty and resolves at
     * runtime — followed. Both now do the same: an empty choice follows the
     * system, on every launch, and a backup written here carries "" like an iOS
     * one. The detection still runs through [LocaleDetector], because the
     * platform's own resource matching would not fold `nn` onto `nb` or pick
     * `zh-TW` for `zh-Hant-HK`.
     *
     * THE SYSTEM LOCALE, NOT `Locale.getDefault()`. AppCompat sets the process
     * default to the per-app locale it applied last time, so reading it back
     * would detect last launch's answer instead of the phone's language.
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
    private suspend fun applySystemLanguage(startupSettings: AppSettings) {
        val stored = startupSettings.language
        if (stored.isNotEmpty()) return // chosen explicitly; AppCompat restores it itself

        val chosen = detectSystemLanguage()
        // AppCompatDelegate.setApplicationLocales() internally calls
        // Activity.recreate() and must run on the Main thread. The surrounding
        // coroutine runs on Dispatchers.IO (applicationScope), so we switch
        // dispatcher for just this call and return to IO afterwards.
        withContext(Dispatchers.Main) {
            AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(chosen))
        }
    }

    companion object {
        /**
         * The supported language the phone's SYSTEM locale maps to, via
         * [LocaleDetector]. Used at launch while no language is chosen, and by
         * the Settings picker when the user returns to "(System)", so both
         * paths apply the same tag. Reads `Resources.getSystem()` rather than
         * `Locale.getDefault()`; see [applySystemLanguage].
         */
        fun detectSystemLanguage(): String =
            LocaleDetector.detect(Resources.getSystem().configuration.locales[0], SupportedLocales.TAGS)
    }
}
