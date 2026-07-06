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
package de.godisch.potillus.ui.screen

// =============================================================================
// SettingsViewModel.kt – Settings, exports and backup import
// =============================================================================
//
// RESPONSIBILITIES:
//   - Reads and writes all user preferences via [IAppPreferences].
//   - Orchestrates CSV, PDF, and JSON export (delegates I/O to the util layer).
//   - Runs backup import in REPLACE or MERGE mode via [IBackupRepository].
//   - Exposes [SettingsUiState] with export/share status for the UI banner.
//
// WHY ViewModel (not AndroidViewModel)?
//   This is a plain ViewModel, not an AndroidViewModel: string resolution is
//   injected via [StringProvider] instead of calling getString() on a Context,
//   which keeps the ViewModel framework-agnostic and unit-testable without
//   Robolectric.
//
//   The Application context for export I/O is injected as [appContext] too, so
//   no Context parameter is needed on any export/import call-site.
//
// BackupRepository:
//   The database transaction that spans entries + drinks is owned by
//   [IBackupRepository], not inlined here, so this ViewModel holds no
//   AppDatabase reference.
//
// See ViewModels.kt (package overview) for the shared Flow → StateFlow
// pattern, @Immutable contract, manual-DI rationale, and Log-guard rule.
// =============================================================================

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.godisch.potillus.BuildConfig
import de.godisch.potillus.R
import de.godisch.potillus.data.prefs.IAppPreferences
import de.godisch.potillus.data.repository.IBackupRepository
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.data.repository.IEntryRepository
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.l10n.perAppLocalizedContext
import de.godisch.potillus.util.AndroidIoBound
import de.godisch.potillus.util.BackupManager
import de.godisch.potillus.util.ExportResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Functional interface for Android string resource resolution.
 *
 * WHY inject this instead of extending [AndroidViewModel]?
 *   [AndroidViewModel] carries an [Application] and forces subclasses to
 *   declare it in the constructor, which leaks the Android framework into
 *   unit tests. By injecting a [StringProvider] lambda the ViewModel stays
 *   framework-agnostic: production code passes `app::getString`; tests pass
 *   a lambda that returns the resource ID as a string (sufficient for
 *   asserting which error message was set).
 */
fun interface StringProvider {
    /**
     * Resolves the string resource [id], formatting it with [args] if it
     * contains placeholders.
     *
     * @param id   Android string resource id.
     * @param args Optional format arguments for `%s` / `%d` placeholders.
     * @return The resolved (and formatted) localised string.
     */
    operator fun invoke(@StringRes id: Int, vararg args: Any): String
}

enum class ImportMode { REPLACE, MERGE }

/**
 * Typed export/import status shown in the Settings screen as a dismissible banner.
 *
 * The message is already localised (built from string resources in SettingsViewModel)
 * so the UI can display it without needing the original string resource ID.
 *
 * WHY a sealed class instead of a single String?
 *   Callers can use `when (status)` to apply different visual treatments:
 *   [Done] gets a success (green) tint; [Err] gets an error (red) tint.
 *   Using a typed hierarchy is more robust than an ad-hoc boolean flag.
 */
sealed class ExportStatus {
    data class Done(val message: String) : ExportStatus()
    data class Err(val message: String) : ExportStatus()
}

@Immutable
data class SettingsUiState(
    val settings: AppSettings = AppSettings(),
    val exportStatus: ExportStatus? = null,
    /** Non-null when an export has succeeded and the file should be shared immediately. */
    val shareTarget: ExportResult? = null,
)

class SettingsViewModel(
    private val getString: StringProvider,
    /**
     * Application context, used solely for MediaStore and ContentResolver access
     * during CSV, PDF, and backup export/import operations.
     *
     * WHY applicationContext and not Activity context?
     *   A ViewModel must not hold a reference to an Activity or Fragment context.
     *   Activities are destroyed and re-created on configuration changes (rotation,
     *   language switch), and a ViewModel outlives them. Holding an Activity context
     *   would prevent the garbage collector from reclaiming it → memory leak.
     *
     *   The [Application] context (and any context obtained via
     *   [Context.getApplicationContext]) is safe because it is a singleton that
     *   lives for the entire process lifetime – exactly as long as the ViewModel's
     *   ViewModelStore. It does not hold a reference to any UI component.
     *
     *   The caller ([MainActivity.MainContent]) passes `app.applicationContext`
     *   explicitly, which makes the decision visible at the injection site rather
     *   than buried inside the ViewModel.
     */
    private val appContext: Context,
    private val prefs: IAppPreferences,
    private val entryRepo: IEntryRepository,
    private val drinkRepo: IDrinkRepository,
    private val backupRepo: IBackupRepository,
) : ViewModel() {

    companion object {
        private const val TAG = "SettingsViewModel"
    }

    private val _exportStatus = MutableStateFlow<ExportStatus?>(null)
    private val _shareTarget = MutableStateFlow<ExportResult?>(null)

    val uiState: StateFlow<SettingsUiState> = combine(
        prefs.settingsFlow,
        _exportStatus,
        _shareTarget,
    ) { settings, status, share ->
        SettingsUiState(settings, status, share)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SettingsUiState())

    // ── Preference setters ────────────────────────────────────────────────────
    // Each setter is a thin, fire-and-forget delegate to IAppPreferences, launched
    // on viewModelScope so the suspend write runs off the caller's thread and is
    // cancelled automatically when the ViewModel is cleared. Value clamping (e.g.
    // weight / limit ranges) lives in AppPreferences, not here, so every call-site
    // (UI, tests, future callers) shares the same validation.

    /** Persists the selected [ThemeMode] (light / dark / follow system). */
    fun setThemeMode(m: ThemeMode) = viewModelScope.launch { prefs.setTheme(m) }

    /** Persists the day-change time (hour [h], minute [m]) atomically. */
    fun setDayChangeTime(h: Int, m: Int) = viewModelScope.launch { prefs.setDayChangeTime(h, m) }

    /** Persists the daily pure-alcohol limit in grams [g] (clamped in AppPreferences). */
    fun setDailyLimit(g: Double) = viewModelScope.launch { prefs.setDailyLimit(g) }

    /** Persists the weekly pure-alcohol limit in grams [g] (clamped in AppPreferences). */
    fun setWeeklyLimit(g: Double) = viewModelScope.launch { prefs.setWeeklyLimit(g) }

    /** Persists the maximum number of drink days per week [days] (1–7). */
    fun setMaxDrinkDaysPerWeek(days: Int) = viewModelScope.launch { prefs.setMaxDrinkDaysPerWeek(days) }

    /** Enables/disables the biometric app lock. */
    fun setBiometric(v: Boolean) = viewModelScope.launch { prefs.setBiometric(v) }

    /** Clears or re-sets FLAG_SECURE to allow/block screenshots and screen recordings. */
    fun setAllowScreenshots(v: Boolean) = viewModelScope.launch { prefs.setAllowScreenshots(v) }

    /** Persists the UI language BCP-47 tag [lang] (empty = follow system). */
    fun setLanguage(lang: String) = viewModelScope.launch { prefs.setLanguage(lang) }

    /** Persists the user's body weight in kilograms [kg] (clamped in AppPreferences). */
    fun setWeightKg(kg: Double) = viewModelScope.launch { prefs.setWeightKg(kg) }

    /** Persists the statistics start date [date] ("YYYY-MM-DD"). */
    fun setStatsFromDate(date: String) = viewModelScope.launch { prefs.setStatsFromDate(date) }

    /** Dismisses the export/import status banner. */
    fun clearExportStatus() {
        _exportStatus.value = null
    }

    /** Clears the pending share target after the share sheet has been launched. */
    fun clearShareTarget() {
        _shareTarget.value = null
    }

    // NOTE: CSV and PDF export live in StatsViewModel — data export now
    // lives on the Statistics screen, next to the statistics it exports. The JSON
    // backup export/import below stays here, as it concerns the whole data set
    // rather than the statistics view.

    /**
     * Exports all drinks and entries to a JSON backup file in shared storage and,
     * on success, sets [shareTarget] so the screen can offer a share sheet.
     * Updates [exportStatus] with the result.
     */
    @AndroidIoBound
    fun exportBackup() {
        viewModelScope.launch {
            val entries = entryRepo.getAll()
            val drinks = drinkRepo.drinks.first()
            val result = withContext(Dispatchers.IO) {
                BackupManager.exportToJson(appContext, drinks, entries)
            }
            _exportStatus.value = if (result != null) {
                _shareTarget.value = result
                ExportStatus.Done(result.fileName)
            } else {
                ExportStatus.Err(str(R.string.backup_failed))
            }
        }
    }

    /**
     * Imports a JSON backup from [uri] using the given [mode].
     *
     * Parsing/validation errors are mapped to a localised message; the actual
     * write (which spans both tables in one transaction) is delegated to
     * [backupRepo]. Updates [exportStatus] with a success or error message.
     *
     * @param uri  The content URI the user picked.
     * @param mode REPLACE (wipe then import) or MERGE (add, skipping duplicates).
     */
    @AndroidIoBound
    fun importBackup(uri: Uri, mode: ImportMode) {
        viewModelScope.launch {
            // Reading the file (ContentResolver query + up to MAX_BACKUP_BYTES of
            // stream I/O) and parsing the JSON are blocking, potentially heavy
            // operations. viewModelScope dispatches on Dispatchers.Main.immediate,
            // so they MUST be moved off the main thread to avoid an ANR on large
            // backups — mirroring exportBackup() above, which already wraps its
            // I/O in withContext(Dispatchers.IO).
            val result = withContext(Dispatchers.IO) {
                BackupManager.importFromJson(appContext, uri)
            }
            if (result.error != null) {
                _exportStatus.value = ExportStatus.Err(localiseImportError(result.error))
                return@launch
            }

            // the transaction that spans entries + drinks is owned
            // by BackupRepository, keeping this ViewModel free of AppDatabase.
            try {
                val stats = when (mode) {
                    ImportMode.REPLACE -> backupRepo.importReplace(result.drinks, result.entries)
                    ImportMode.MERGE -> backupRepo.importMerge(result.drinks, result.entries)
                }
                _exportStatus.value = ExportStatus.Done(
                    if (mode == ImportMode.REPLACE) {
                        quantityStr(R.plurals.import_success_replace, stats.imported, stats.imported)
                    } else {
                        quantityStr(R.plurals.import_success_merge, stats.imported, stats.imported, stats.skipped)
                    },
                )
            } catch (e: Exception) {
                if (BuildConfig.DEBUG) Log.e(TAG, "importBackup: unexpected error", e)
                _exportStatus.value = ExportStatus.Err(str(R.string.import_error_read, ""))
            }
        }
    }

    /** Resolves string resource [id] formatted with [args] via the injected [StringProvider]. */
    private fun str(@StringRes id: Int, vararg args: Any): String = getString(id, *args)

    /**
     * Resolves plural resource [id] for [quantity], formatted with [args].
     *
     * Resolves through [perAppLocalizedContext] rather than the raw
     * [appContext]: on API 30–32 the Application context keeps the SYSTEM
     * locale (AppCompat's per-app-language back-port only localizes Activity
     * contexts), so a raw `appContext.resources` lookup would pick the wrong
     * language — and, for languages with richer plural rules than the system
     * one, potentially the wrong CLDR plural form. The wrapper is applied per
     * call so a runtime language switch is always reflected. [quantity] selects
     * the CLDR plural form; pass the count(s) again in [args] to fill the `%d`
     * placeholders. For messages with two numbers (e.g. import_success_merge)
     * the plural form is chosen by the FIRST count, which is the only one that
     * governs an inflected word in the en/de sources.
     */
    private fun quantityStr(@PluralsRes id: Int, quantity: Int, vararg args: Any): String = appContext.perAppLocalizedContext().resources.getQuantityString(id, quantity, *args)

    /** Maps a [BackupManager.ImportError] to a localised, user-facing message. */
    private fun localiseImportError(error: BackupManager.ImportError): String = when (error) {
        is BackupManager.ImportError.CouldNotRead -> str(R.string.import_error_could_not_read)
        is BackupManager.ImportError.FileEmpty -> str(R.string.import_error_empty)
        is BackupManager.ImportError.InvalidJson -> str(R.string.import_error_invalid_json)
        is BackupManager.ImportError.FileTooLarge -> str(R.string.import_error_file_too_large, error.maxBytes / 1_024 / 1_024)
        is BackupManager.ImportError.VersionTooHigh -> str(R.string.import_error_version_too_high, error.found, error.max)
        is BackupManager.ImportError.ReadError -> str(R.string.import_error_read, error.detail ?: "")
    }
}
