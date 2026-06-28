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
package de.godisch.potillus.data.prefs

import android.content.Context
import androidx.datastore.core.CorruptionException
import androidx.datastore.core.DataStore
import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.Serializer
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.PreferencesSerializer
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import de.godisch.potillus.data.security.KeystoreSecretStore
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import java.io.InputStream
import java.io.OutputStream
import java.security.GeneralSecurityException
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import okio.Buffer

// =============================================================================
// AppPreferences.kt – Persistent user settings via encrypted Jetpack DataStore
// =============================================================================
//
// WHY DataStore INSTEAD OF SharedPreferences?
//   SharedPreferences has several known issues:
//     - apply() can block the main thread on ANR under pressure
//     - Not type-safe (getString/getInt – wrong key → wrong type at runtime)
//     - Not Flow-aware (requires listeners / callbacks)
//   DataStore (Preferences) fixes all three: it is coroutine-based, type-safe
//   via typed keys, and exposes a Flow<Preferences> for reactive collection.
//
// WHY ENCRYPTED?
//   DataStore writes a Protobuf file to the app's private storage. On a rooted
//   device or via ADB with USB debugging enabled, that file can be read in
//   plain text. This app stores health-sensitive data (body weight and
//   alcohol-limit preferences) so application-level encryption is appropriate
//   on top of Android's mandatory File-Based Encryption (FBE).
//
// ENCRYPTION APPROACH – AES-256-GCM via EncryptedPreferencesSerializer:
//   Rather than replacing DataStore with EncryptedSharedPreferences (which
//   loses the Flow API) or using a third-party library, we inject a custom
//   Serializer<Preferences> that encrypts the file bytes before writing and
//   decrypts them after reading. DataStore's own atomicity guarantees
//   (temp-file + rename) are fully preserved.
//
//   The AES-256-GCM key lives in the Android Keystore under the alias
//   "potillus_prefs_key". The on-disk format is:
//     [12-byte IV] || [AES-256-GCM ciphertext + 16-byte authentication tag]
//   A fresh IV is generated for every write, so ciphertexts are never repeated.
//
// KEY TYPES:
//   intPreferencesKey / doublePreferencesKey / booleanPreferencesKey / stringPreferencesKey
//   Each key is strongly typed – type mismatches cause compile errors, not crashes.
//
// ATOMICITY:
//   DataStore guarantees that each call to edit{} is atomic: either all writes
//   in a lambda succeed, or none are applied. This is important for
//   setDayChangeTime(), which writes two keys (hour + minute) together.
// =============================================================================

/**
 * DataStore [Serializer] that wraps [PreferencesSerializer] with AES-256-GCM.
 *
 * The symmetric key is generated once in the Android Keystore under [keyAlias]
 * and never leaves the secure hardware (or software Keystore emulation on
 * devices without a StrongBox). Each [writeTo] call generates a fresh 12-byte
 * IV; the on-disk format is `[IV (12 bytes)] || [GCM ciphertext + 16-byte tag]`.
 *
 * WHY wrap [PreferencesSerializer] instead of encrypting individual values?
 *   Field-level encryption would require changing every read/write call-site in
 *   [AppPreferences]. Wrapping the serializer encrypts the whole file atomically
 *   with zero changes to the business-logic layer, and DataStore's own atomicity
 *   guarantees (temp-file + rename) are preserved.
 *
 * WHY not use [androidx.security.crypto.EncryptedSharedPreferences]?
 *   EncryptedSharedPreferences is synchronous and requires a [callbackFlow]
 *   wrapper to replicate the DataStore Flow contract. That adds complexity and
 *   reasoning overhead without any security benefit over this approach.
 *
 * WHY [ReplaceFileCorruptionHandler] in the caller?
 *   If decryption fails (e.g. the Keystore key was deleted after a factory reset
 *   with re-use protection), we replace the file with empty preferences rather
 *   than crashing. The user loses their settings but the app stays functional.
 *
 * @param keyAlias  Keystore alias under which the AES-256-GCM key is stored.
 *                  A dedicated alias (separate from the DB passphrase key alias)
 *                  allows the two keys to be rotated independently.
 */
private class EncryptedPreferencesSerializer(
    keyAlias: String,
    override val defaultValue: Preferences = emptyPreferences()
) : Serializer<Preferences> {

    /**
     * Keystore-backed AES-256-GCM envelope helper. All cipher and key
     * handling lives in [KeystoreSecretStore]; this serializer only bridges
     * between DataStore's stream API and that helper.
     */
    private val store = KeystoreSecretStore(keyAlias)

    // WHY two different I/O types here?
    //   DataStoreFactory.create() requires Serializer<T>, whose interface uses
    //   Java InputStream / OutputStream (our public contract below).
    //   PreferencesSerializer internally uses Okio BufferedSource / BufferedSink
    //   (changed in DataStore 1.1.0). We bridge between the two via okio.Buffer,
    //   which implements both BufferedSource and BufferedSink and can be
    //   constructed from a plain ByteArray.

    /**
     * Decrypts the DataStore backing file and deserialises it to [Preferences].
     *
     * On-disk layout is `[12-byte IV] || [AES-256-GCM ciphertext + tag]`. An empty
     * file (first run) yields [defaultValue]. A decryption failure is surfaced as
     * a [CorruptionException] so the configured [ReplaceFileCorruptionHandler] can
     * reset the file instead of crashing the app.
     *
     * @param input The encrypted backing-file stream.
     * @return      The decrypted preferences snapshot.
     */
    override suspend fun readFrom(input: InputStream): Preferences {
        val bytes = withContext(Dispatchers.IO) { input.readBytes() }
        if (bytes.isEmpty()) return defaultValue
        return try {
            // Decrypt the [IV || ciphertext+tag] envelope via the shared helper.
            val plaintext = withContext(Dispatchers.Default) { store.open(bytes) }
            // Bridge: wrap plain bytes in an Okio Buffer so PreferencesSerializer
            // can read them via its BufferedSource-based API.
            PreferencesSerializer.readFrom(Buffer().apply { write(plaintext) })
        } catch (e: GeneralSecurityException) {
            throw CorruptionException("Preferences file could not be decrypted", e)
        }
    }

    /**
     * Serialises [t] and writes it to [output] encrypted with AES-256-GCM.
     *
     * A fresh 12-byte IV is generated for every write (so identical preferences
     * never produce identical ciphertext) and prepended to the output:
     * `[IV] || [ciphertext + tag]`.
     *
     * @param t      The preferences snapshot to persist.
     * @param output The backing-file output stream.
     */
    override suspend fun writeTo(t: Preferences, output: OutputStream) {
        // Bridge: let PreferencesSerializer write into an in-memory Okio Buffer,
        // then extract the raw bytes for encryption.
        val plainBuf = Buffer()
        PreferencesSerializer.writeTo(t, plainBuf)
        val plaintext = plainBuf.readByteArray()

        // Seal: the helper generates a fresh IV per call and returns IV || ciphertext+tag.
        val sealed = withContext(Dispatchers.Default) { store.seal(plaintext) }

        // Write the envelope to the DataStore backing file (Java OutputStream).
        withContext(Dispatchers.IO) { output.write(sealed) }
    }
}

/** Extension property that creates/returns the singleton DataStore for this Context. */
// NOTE: this is now a private AppPreferences-internal DataStore, not a
// Context extension delegate. The encrypted DataStore is created inside
// AppPreferences using DataStoreFactory.create() + EncryptedPreferencesSerializer.

/**
 * Reads and writes all user preferences via an encrypted Jetpack DataStore.
 *
 * Exposes a single [settingsFlow] that combines all keys into an [AppSettings]
 * snapshot so ViewModels need only one `collect` call to react to any change.
 *
 * The backing file is encrypted with AES-256-GCM via [EncryptedPreferencesSerializer];
 * the key is held in the Android Keystore under [PREFS_KEY_ALIAS].
 *
 * @param context  Application context (must outlive the DataStore instance).
 */
class AppPreferences(private val context: Context) : IAppPreferences {

    companion object {
        // ── Android Keystore alias ────────────────────────────────────────────
        // A dedicated alias (separate from the DB passphrase key alias used by
        // AppDatabase) so this key can be rotated independently.
        private const val PREFS_KEY_ALIAS = "potillus_prefs_key"

        // ── Typed preference keys ─────────────────────────────────────────────
        // The string argument is the key name in the underlying protobuf file.
        // Do NOT change existing key names after release – it would lose users'
        // current settings silently.
        //
        // WHY internal (not private)?
        //   internal visibility makes these keys accessible to the test source
        //   set of the same Gradle module, so unit tests can verify that the
        //   correct key name is used. They are NOT part of the IAppPreferences
        //   interface; callers always go through the typed set*/get* functions.
        internal val KEY_THEME          = stringPreferencesKey("theme_mode")
        internal val KEY_DAY_HOUR       = intPreferencesKey("day_change_hour")
        internal val KEY_DAY_MINUTE     = intPreferencesKey("day_change_minute")
        // KEY_DAILY_LIMIT keeps the historical key name "custom_limit_grams" so
        // that a user's previously configured daily limit survives the upgrade to
        // the always-on three-limit model.
        internal val KEY_DAILY_LIMIT    = doublePreferencesKey("custom_limit_grams")
        internal val KEY_WEEKLY_LIMIT   = doublePreferencesKey("weekly_limit_grams")
        // KEY_MAX_DRINK_DAYS keeps the historical key name "custom_max_drink_days".
        internal val KEY_MAX_DRINK_DAYS = intPreferencesKey("custom_max_drink_days")
        internal val KEY_BIOMETRIC      = booleanPreferencesKey("biometric_lock")
        internal val KEY_ALLOW_SCREENSHOTS = booleanPreferencesKey("allow_screenshots")
        internal val KEY_LANGUAGE       = stringPreferencesKey("language")
        internal val KEY_WEIGHT_KG      = doublePreferencesKey("weight_kg")
        internal val KEY_STATS_FROM     = stringPreferencesKey("stats_from_date")
        internal val KEY_INFO_YEAR      = intPreferencesKey("info_dialog_shown_year")
        // Removed in the three-limit refactor: "gender", "limit_mode" and
        // "weekly_gram_mode". Removed in the rolling-window refactor (v0.62.0):
        // "week_start_day" — the app no longer has a configurable first weekday and
        // uses a gliding 7-day window for all metrics; the calendar grid and PDF
        // weekday profile derive their first column from the device locale instead.
        // Any leftover values for those keys in an existing DataStore file are
        // simply ignored by settingsFlow below.
    }

    /**
     * The encrypted DataStore instance.
     *
     * WHY [DataStoreFactory.create] instead of the [preferencesDataStore] delegate?
     *   The delegate creates a plain-text DataStore. [DataStoreFactory.create]
     *   lets us inject [EncryptedPreferencesSerializer], which encrypts the file
     *   bytes before they hit the filesystem. All DataStore guarantees (atomicity
     *   via temp-file + rename, single-writer coroutine, Flow reactivity) are
     *   fully preserved.
     *
     * [ReplaceFileCorruptionHandler]: if decryption throws a [CorruptionException]
     *   (e.g. after a factory reset that deleted the Keystore key), the file is
     *   replaced with empty preferences rather than crashing the app.
     *
     * [preferencesDataStoreFile] produces the same path as the old delegate:
     *   `files/datastore/potillus_settings.preferences_pb` – so a future migration
     *   to a plain DataStore (if encryption is ever removed) is trivial.
     */
    private val dataStore: DataStore<Preferences> = DataStoreFactory.create(
        serializer        = EncryptedPreferencesSerializer(keyAlias = PREFS_KEY_ALIAS),
        corruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() },
        produceFile       = { context.preferencesDataStoreFile("potillus_settings") }
    )

    /**
     * The calendar date on which this app installation was first created on the device.
     *
     * Derived from [PackageManager.getPackageInfo.firstInstallTime], which is the
     * Unix timestamp when the APK was first installed (not updated). Falls back to
     * the current time if the package info is unavailable for any reason.
     *
     * KOTLIN "by lazy":
     *   The value is computed on first access and then cached for the lifetime
     *   of this AppPreferences instance. Thread-safe by default.
     *
     * Used as the default value for [AppSettings.statsFromDate] when the user
     * has not explicitly set a statistics start date.
     */
    private val installDate: String by lazy {
        val installMs = try {
            context.packageManager.getPackageInfo(context.packageName, 0).firstInstallTime
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
        Instant.ofEpochMilli(installMs)
            .atZone(ZoneId.systemDefault())
            .toLocalDate()
            .format(DayResolver.DATE_FORMATTER)
    }

    /**
     * Reactive stream of all settings as a single [AppSettings] snapshot.
     *
     * DataStore emits a new value whenever any key changes. The [map] operator
     * converts the raw [androidx.datastore.preferences.core.Preferences] map
     * into a typed [AppSettings] object.
     *
     * Default values (the `?:` fallbacks) are used the first time the app runs,
     * before any key has been written to DataStore. They match the defaults in
     * [AppSettings] to keep the initial state consistent. The one deliberate
     * exception is [AppSettings.statsFromDate], which falls back to the computed
     * [installDate] (a smarter default than the data class's empty-string sentinel)
     * so statistics start at the install date until the user picks another.
     *
     * [runCatching] is used for enum deserialization: if a future code change
     * removes an enum constant that was previously stored, parsing fails
     * silently and the default is used, rather than crashing the app.
     */
    override val settingsFlow: Flow<AppSettings> = dataStore.data.map { prefs ->
        AppSettings(
            themeMode           = runCatching { ThemeMode.valueOf(prefs[KEY_THEME] ?: "") }.getOrDefault(ThemeMode.SYSTEM),
            dayChangeHour       = prefs[KEY_DAY_HOUR]        ?: 4,
            dayChangeMinute     = prefs[KEY_DAY_MINUTE]      ?: 0,
            dailyLimitGrams     = prefs[KEY_DAILY_LIMIT]     ?: 20.0,
            weeklyLimitGrams    = prefs[KEY_WEEKLY_LIMIT]    ?: 100.0,
            maxDrinkDaysPerWeek = prefs[KEY_MAX_DRINK_DAYS]  ?: 5,
            biometricEnabled    = prefs[KEY_BIOMETRIC]           ?: false,
            allowScreenshots    = prefs[KEY_ALLOW_SCREENSHOTS]   ?: false,
            language            = prefs[KEY_LANGUAGE]        ?: "",
            weightKg            = prefs[KEY_WEIGHT_KG]       ?: 0.0,
            statsFromDate       = prefs[KEY_STATS_FROM]      ?: installDate
        )
    }

    /** Standalone (non-[AppSettings]) flow for the annual info-dialog year (0 = never). */
    override val infoDialogShownYear: Flow<Int> =
        dataStore.data.map { it[KEY_INFO_YEAR] ?: 0 }

    // ── Write functions ───────────────────────────────────────────────────────
    // Each function calls save{} which wraps DataStore's edit{} for a single key.
    // All are suspend functions – they must be called from a coroutine (typically
    // viewModelScope.launch in a ViewModel).
    //
    // These one-line overrides intentionally carry no KDoc of their own —
    // each inherits its contract documentation from the corresponding member of
    // [IAppPreferences] (Dokka renders inherited KDoc on overrides). The only
    // behaviour added here over the contract is range clamping, which is shown
    // inline via coerceIn(...) so the valid bounds are visible at a glance.

    override suspend fun setTheme(mode: ThemeMode)      = save { it[KEY_THEME]          = mode.name }
    override suspend fun setDailyLimit(g: Double)       = save { it[KEY_DAILY_LIMIT]    = g.coerceIn(1.0, 500.0) }
    override suspend fun setWeeklyLimit(g: Double)      = save { it[KEY_WEEKLY_LIMIT]   = g.coerceIn(1.0, 3500.0) }
    override suspend fun setBiometric(v: Boolean)          = save { it[KEY_BIOMETRIC]          = v }
    override suspend fun setAllowScreenshots(v: Boolean)   = save { it[KEY_ALLOW_SCREENSHOTS]  = v }
    override suspend fun setLanguage(lang: String)      = save { it[KEY_LANGUAGE]       = lang }
    override suspend fun setWeightKg(kg: Double)        = save { it[KEY_WEIGHT_KG]      = kg.coerceIn(1.0, 500.0) }
    override suspend fun setMaxDrinkDaysPerWeek(days: Int) = save { it[KEY_MAX_DRINK_DAYS] = days.coerceIn(1, 7) }
    override suspend fun setInfoDialogShownYear(year: Int)  = save { it[KEY_INFO_YEAR]      = year }

    /**
     * Writes day-change hour and minute in a single atomic transaction.
     *
     * DataStore's [edit] lambda is atomic: either both keys are written, or
     * neither is. This prevents the app from ever reading a state where the
     * hour has been updated but the minute has not (or vice versa), which
     * could temporarily assign a drink to the wrong logical date.
     *
     * @param hour    New day-change hour (0–23).
     * @param minute  New day-change minute (0–59).
     */
    override suspend fun setDayChangeTime(hour: Int, minute: Int) = save {
        it[KEY_DAY_HOUR]   = hour
        it[KEY_DAY_MINUTE] = minute
    }

    /**
     * Persists the statistics start date.
     *
     * @param date  ISO-8601 date string ("YYYY-MM-DD").
     */
    override suspend fun setStatsFromDate(date: String) = save { it[KEY_STATS_FROM] = date }

    /** Thin wrapper around [DataStore.edit] to reduce boilerplate in the setXxx functions. */
    private suspend fun save(block: (MutablePreferences) -> Unit) {
        dataStore.edit(block)
    }
}
