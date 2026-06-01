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
import androidx.annotation.VisibleForTesting
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
import de.godisch.potillus.l10n.SupportedLocales
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

    // ── Device-transfer warning ──────────────────────────────────────
    //
    // PROBLEM:
    //   data_extraction_rules.xml includes potillus_db_key (the Keystore-sealed
    //   passphrase) and potillus_settings.preferences_pb in the
    //   device-to-device transfer.
    //   Both files are encrypted with Android Keystore keys. On many OEM devices
    //   (non-Pixel especially) hardware-backed Keystore keys do NOT migrate during
    //   a cable transfer. The result: the app opens with a blank database and factory-
    //   default settings — all data is silently inaccessible, with no error message.
    //
    // DETECTION HEURISTIC:
    //   A "failed transfer" looks like: the package was installed recently (within
    //   INSTALL_RECENCY_MS) AND the DataStore still has its default values
    //   (language empty, weightKg == 0.0). On a genuine first install these
    //   conditions also hold, so this is a heuristic — not a definitive diagnosis.
    //   We intentionally avoid false-positive prevention by showing a non-alarming,
    //   easily dismissible info message.
    //
    // HOW IT IS CONSUMED:
    //   MainActivity observes deviceTransferWarning. When true, it shows a
    //   one-time, dismissible SnackBar/Dialog:
    //     "Some settings could not be restored from your previous device.
    //      If this is a new installation, you can ignore this. Otherwise,
    //      please re-import your backup via Settings → Restore Backup."
    //   The flag is cleared on dismiss (dismissDeviceTransferWarning()).

    private val _deviceTransferWarning = MutableStateFlow(false)

    /**
     * Emits `true` when a possible device-transfer Keystore migration failure
     * is detected. Observed by `MainActivity` to show a one-time, dismissible
     * info message. Call [dismissDeviceTransferWarning] after the user has read it.
     */
    val deviceTransferWarning: StateFlow<Boolean> = _deviceTransferWarning.asStateFlow()

    /** Clears [deviceTransferWarning] after the user has dismissed the info message. */
    fun dismissDeviceTransferWarning() { _deviceTransferWarning.value = false }

    /**
     * Process entry point. Runs the one-shot startup tasks that must happen
     * before the first Activity reads settings: first-launch language detection
     * and the device-transfer failure heuristic.
     *
     * Both run on [Dispatchers.IO] because they read DataStore; the few
     * UI-thread calls inside switch dispatcher explicitly via [withContext].
     */
    override fun onCreate() {
        super.onCreate()
        // Explicitly choose Dispatchers.IO for the DataStore read inside
        // applyLanguageOnFirstLaunch(). Without a default dispatcher on applicationScope,
        // every consumer must specify the dispatcher at the launch site.
        applicationScope.launch(Dispatchers.IO) {
            // Read the startup settings snapshot ONCE, BEFORE any startup
            // task mutates DataStore, and share it between both tasks.
            //
            // WHY: applyLanguageOnFirstLaunch() WRITES `language` on first launch.
            // If checkForDeviceTransferFailure() read settings AFTER it, the
            // `language.isEmpty()` half of its heuristic would already be false, so
            // the device-transfer warning could never fire — the device-transfer safety net
            // was silently dead. Capturing the pre-write snapshot restores the
            // intended behaviour. (As originally designed, the warning also shows on
            // a genuine first install — the message is worded to be safe to ignore
            // in that case. A future refinement could distinguish "DataStore file
            // present but un-decryptable" from "no file yet" to suppress the
            // first-install case.)
            val startupSettings = appPreferences.settingsFlow.first()
            applyLanguageOnFirstLaunch(startupSettings)
            checkForDeviceTransferFailure(startupSettings)
        }
    }

    /**
     * Checks whether the current install might be a device-transfer where the
     * Android Keystore keys did not migrate.
     *
     * The check is intentionally conservative: it only sets [deviceTransferWarning]
     * when the package was installed very recently AND DataStore still holds default
     * values. A genuine first install also satisfies these conditions, so the message
     * is worded to be safe to dismiss ("if this is a new installation, ignore this").
     *
     * Receives the startup settings snapshot taken in [onCreate] BEFORE
     * [applyLanguageOnFirstLaunch] runs, so the `language.isEmpty()` signal is not
     * masked by the first-launch language write. The pure decision lives in
     * [shouldWarnDeviceTransfer] so it can be unit-tested without an Android runtime.
     *
     * Called once per app process start, on Dispatchers.IO.
     *
     * @param startupSettings The settings snapshot captured before any startup write.
     */
    private fun checkForDeviceTransferFailure(startupSettings: AppSettings) {
        // Only check briefly after install; after that the user has clearly interacted
        // and would have noticed missing data themselves.
        val installMs = try {
            packageManager.getPackageInfo(packageName, 0).firstInstallTime
        } catch (_: Exception) {
            return   // cannot read install time → skip check
        }
        val ageMs = System.currentTimeMillis() - installMs
        if (shouldWarnDeviceTransfer(ageMs, INSTALL_RECENCY_MS, startupSettings.language, startupSettings.weightKg)) {
            _deviceTransferWarning.value = true
        }
    }

    companion object {
        /**
         * Maximum age of the package installation (in ms) within which a
         * "possible device transfer" heuristic is active.
         * 15 minutes covers the typical cable-based transfer setup duration.
         */
        private const val INSTALL_RECENCY_MS = 15L * 60 * 1_000   // 15 minutes

        /**
         * Pure decision function for the device-transfer warning.
         *
         * Returns `true` when ALL hold:
         *  - the install is recent: [installAgeMs] is within `[0, recencyWindowMs]`
         *    (a negative age from a backwards clock adjustment is treated as
         *    "not recent" rather than firing spuriously),
         *  - the stored UI [language] is still empty (DataStore never written), and
         *  - the stored [weightKg] is still the unset default (`0.0`).
         *
         * Factored out of [checkForDeviceTransferFailure] so the heuristic can be
         * exercised by a plain JVM unit test (no Android Context, no Application
         * instance) — see `PotillusAppHeuristicTest`.
         *
         * @param installAgeMs    Milliseconds since first install.
         * @param recencyWindowMs Upper bound of the "recent install" window.
         * @param language        Stored UI-language tag ("" = never set).
         * @param weightKg        Stored body weight (0.0 = unset).
         */
        @VisibleForTesting
        internal fun shouldWarnDeviceTransfer(
            installAgeMs: Long,
            recencyWindowMs: Long,
            language: String,
            weightKg: Double
        ): Boolean =
            installAgeMs in 0..recencyWindowMs && language.isEmpty() && weightKg == 0.0
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
     *   1. Exact full-tag match on the IETF language tag returned by
     *      [Locale.toLanguageTag] (e.g. "zh-CN", "pt-BR").
     *      This picks the most specific variant when one exists.
     *   2. Base-language match on [Locale.language] alone (e.g. "zh" → "zh-CN"
     *      is NOT done here; a user running "zh-HK" would get English rather than
     *      "zh-CN" unless their full tag matches).  The invariant is: only offer a
     *      locale we explicitly ship, never a best-guess sibling.
     *   3. Fall back to "en" (the base locale) if neither step matched.
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

        val systemLocale = Locale.getDefault()
        // IETF full tag, e.g. "zh-CN", "pt-BR", "de", "ar"
        val systemFullTag = systemLocale.toLanguageTag()
        // Base language only, e.g. "zh", "pt", "de", "ar"
        val systemBaseLang = systemLocale.language

        // Step 1: exact full-tag match (covers region variants like pt-BR, zh-CN, zh-TW).
        // Step 2: base-language match (covers de, fr, es, id, ar, hi, …).
        // Step 3: fall back to English.
        val chosen = SupportedLocales.TAGS
            .firstOrNull { it.equals(systemFullTag, ignoreCase = true) }
            ?: SupportedLocales.TAGS
                .firstOrNull { it.equals(systemBaseLang, ignoreCase = true) }
            ?: "en"

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
