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
package de.godisch.potillus.util

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.annotation.VisibleForTesting
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.domain.model.ThemeMode
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// =============================================================================
// BackupManager.kt – Full JSON backup and restore
// =============================================================================
//
// WHY JSON INSTEAD OF THE ROOM DATABASE FILE?
//   Exporting the raw SQLite file would be simpler but fragile:
//     - The schema might change between versions (migrations).
//     - The file is not human-readable or inspectable.
//   JSON is schema-flexible: old fields can be read with optXxx() defaults,
//   and new fields added in future versions are simply ignored by older ones.
//
// BACKUP VERSIONING:
//   The JSON root contains a "version" integer.
//   BACKUP_VERSION = 3 (current).
//   Format 1: same structure but without the "category" field on
//   drinks – optString("category", "OTHER") handles this transparently.
//   Format 2: adds the "category" field on drinks.
//   Format 3: adds a top-level "settings" object carrying the user's
//   preferences (theme, limits, day-change time, body weight, language, …).
//   A pre-v3 backup simply has no "settings" key; [parseBackupJson] then
//   returns a null [ImportResult.settings] and the caller leaves the local
//   settings untouched, so an old backup's drink/entry history still restores
//   exactly as before.
//   The importer rejects files with version > BACKUP_VERSION (written by a
//   newer app) to avoid silently truncating unknown fields.
//
// WHY ARE SETTINGS PART OF THE BACKUP AT ALL?
//   The preferences live in a SEPARATE, encrypted Jetpack DataStore
//   ([de.godisch.potillus.data.prefs.AppPreferences]) – not in the Room
//   database that supplies drinks/entries. Before format 3 the JSON backup only
//   mirrored the database, so a "restore" on a fresh install silently dropped
//   every preference (including the body weight that feeds the whole
//   blood-alcohol calculation). Format 3 closes that data-loss gap.
//
// SETTINGS RESTORE (also handled in SettingsViewModel, not here):
//   REPLACE – restores the backup's "settings" over the local preferences.
//   MERGE   – KEEPS the local preferences and ignores the backup's "settings";
//             a merge adds data only and must not surprise the user by
//             overwriting their current theme, limits or body weight.
//   A pre-v3 backup (no "settings" key) never changes settings in either mode.
//
// IMPORT MODES (handled in SettingsViewModel, not here):
//   REPLACE – delete all local data, then import everything from the backup.
//   MERGE   – keep local data, add backup entries that are not duplicates.
//             Duplicates are detected by (timestampMillis, drinkId) pairs.
//             MERGE also merges the backup's DRINK CATALOGUE: a backup drink whose
//             name is not present locally is inserted, INCLUDING a custom drink
//             that has no entries of its own. This is intentional — a merge brings
//             over the user's drink definitions too, not only consumption events —
//             and it is idempotent (a second merge re-matches the drink by name and
//             inserts nothing further). REPLACE likewise restores the full catalogue.
//
// KOTLIN "sealed class":
//   ImportError lists every possible failure as a distinct subtype.
//   The ViewModel switches on the type (is CouldNotRead, is InvalidJson, …)
//   to produce a localised error message without any string-matching or
//   generic exception messages leaking into the UI.
// =============================================================================

/** Serialises and deserialises the full drink+entry history as a JSON backup. */
object BackupManager {

    /**
     * Current backup format version.
     *
     * Increment this whenever a new field is added to the JSON structure that
     * CANNOT be read by an older app version, and add a migration note here.
     *
     * History:
     *   1 → initial format.
     *   2 → added the "category" field to drink objects.
     *   3 → added the top-level "settings" object (user preferences). Older
     *       apps that only know versions 1–2 reject a v3 file via the
     *       VersionTooHigh guard rather than silently dropping the settings.
     *
     * BACKWARD-COMPATIBILITY FLOOR: since the first F-Droid release (v0.77.4) the
     * importer is guaranteed to read every backup written by v0.77.4 or newer —
     * required fields via `getXxx`, optional/newer fields via `optXxx(key,
     * default)`, and files from a newer app rejected with [ImportError.VersionTooHigh].
     * See CONTRIBUTING.md §8 (compatibility guarantee) and §8.3.
     */
    private const val BACKUP_VERSION = 3

    /**
     * Maximum accepted backup file size (10 MB).
     *
     * WHY a size limit?
     *   [importFromJson] calls [BufferedReader.readText] which loads the entire
     *   file into the JVM heap before parsing. A maliciously crafted backup with
     *   millions of entries would cause an [OutOfMemoryError].
     *   10 MB is far larger than any legitimate backup (a year of daily entries
     *   produces roughly 500 KB) and serves as a hard safety cap.
     */
    private const val MAX_BACKUP_BYTES = 10L * 1_024 * 1_024 // 10 MB

    /** Timestamp format for the backup file name. */
    private val FILE_FMT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm").withZone(ZoneId.systemDefault())

    // ── Export ────────────────────────────────────────────────────────────────

    /**
     * Serialises [drinks] and [entries] to a JSON file in the Downloads folder.
     *
     * The produced JSON structure:
     * ```json
     * {
     *   "version": 3,
     *   "exportedAt": "2025-05-26T14:30:00Z",
     *   "drinks": [ { "id": 1, "name": "Pils 0,5 l", … }, … ],
     *   "entries": [ { "id": 1, "drinkId": 1, "gramsAlcohol": 19.6, … }, … ],
     *   "settings": { "themeMode": "SYSTEM", "weightKg": 82.0, … }
     * }
     * ```
     *
     * The file is written via MediaStore so no file-system permissions are
     * required on Android 10+.
     *
     * @param context  Context for ContentResolver access.
     * @param drinks   Current drink catalogue (including presets).
     * @param entries  All consumption entries.
     * @param settings Current user preferences snapshot to embed (format 3+).
     * @return [ExportResult] on success; `null` on I/O error.
     */
    @AndroidIoBound
    fun exportToJson(
        context: Context,
        drinks: List<DrinkDefinition>,
        entries: List<ConsumptionEntry>,
        settings: AppSettings,
    ): ExportResult? {
        // Capture Instant.now() once so the file name and the
        // "exportedAt" field in the JSON root are guaranteed to match exactly,
        // even on devices where the clock is adjusted between two calls.
        val now = Instant.now()
        val fileName = "potillus_backup_${FILE_FMT.format(now)}.json"

        val root = JSONObject().apply {
            // Non-evaluated GPLv3 notice. JSON has no comment syntax, so the
            // header is carried as a dedicated "_comment" array; importers
            // (including ours) read only the known keys and ignore it. See
            // GplNotice for the rationale.
            put("_comment", JSONArray(GplNotice.HEADER_LINES))
            put("version", BACKUP_VERSION)
            put("exportedAt", now.toString())
            put(
                "drinks",
                JSONArray().also { arr ->
                    drinks.forEach { d ->
                        arr.put(
                            JSONObject().apply {
                                put("id", d.id)
                                put("name", d.name)
                                put("volumeMl", d.volumeMl)
                                put("alcoholPercent", d.alcoholPercent)
                                put("isPreset", d.isPreset)
                                put("isFavorite", d.isFavorite)
                                put("category", d.category.name)
                            },
                        )
                    }
                },
            )
            put(
                "entries",
                JSONArray().also { arr ->
                    entries.forEach { e ->
                        arr.put(
                            JSONObject().apply {
                                put("id", e.id)
                                put("drinkId", e.drinkId)
                                put("drinkName", e.drinkName)
                                put("volumeMl", e.volumeMl)
                                put("alcoholPercent", e.alcoholPercent)
                                put("gramsAlcohol", e.gramsAlcohol)
                                put("timestampMillis", e.timestampMillis)
                                put("logicalDate", e.logicalDate)
                                put("note", e.note)
                            },
                        )
                    }
                },
            )
            put(
                "settings",
                // The user preferences live in a separate encrypted DataStore, so
                // they must be serialised explicitly here (format 3+). Field names
                // mirror [AppSettings]; enums are stored by their stable `name`.
                // These keys are read back in [parseSettings] with the same names.
                JSONObject().apply {
                    put("themeMode", settings.themeMode.name)
                    put("dayChangeHour", settings.dayChangeHour)
                    put("dayChangeMinute", settings.dayChangeMinute)
                    put("dailyLimitGrams", settings.dailyLimitGrams)
                    put("weeklyLimitGrams", settings.weeklyLimitGrams)
                    put("maxDrinkDaysPerWeek", settings.maxDrinkDaysPerWeek)
                    put("statsFromDate", settings.statsFromDate)
                    put("biometricEnabled", settings.biometricEnabled)
                    put("allowScreenshots", settings.allowScreenshots)
                    put("language", settings.language)
                    put("weightKg", settings.weightKg)
                },
            )
        }

        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues) ?: return null

        return try {
            // A null stream is a FAILURE, not a success with no content: silently
            // skipping the write used to leave an EMPTY .json in Downloads while
            // the UI reported a successful backup — a data-loss trap for a health
            // backup. Treat it exactly like an IOException: delete the orphaned
            // MediaStore entry and report failure.
            val stream = resolver.openOutputStream(uri) ?: run {
                resolver.delete(uri, null, null)
                return null
            }
            stream.use { it.write(root.toString(2).toByteArray(Charsets.UTF_8)) }
            ExportResult(fileName, uri, "application/json")
        } catch (e: IOException) {
            resolver.delete(uri, null, null)
            null
        }
    }

    // ── Import ────────────────────────────────────────────────────────────────

    /**
     * Typed failure cases for [importFromJson].
     *
     * Using a sealed class (instead of throwing exceptions or returning error
     * strings) keeps the error handling explicit and exhaustive: the ViewModel's
     * `when` expression must handle every subtype or the compiler will warn.
     *
     * KOTLIN "sealed class":
     *   A sealed class restricts which classes can extend it to those defined
     *   in the same file. This makes `when` exhaustive: the compiler knows all
     *   possible subtypes.
     */
    sealed class ImportError {
        /** The content resolver returned null or threw on openInputStream. */
        object CouldNotRead : ImportError()

        /** The file exists but contains only whitespace. */
        object FileEmpty : ImportError()

        /** The file content is not valid JSON. */
        object InvalidJson : ImportError()

        /**
         * The backup file exceeds [MAX_BACKUP_BYTES].
         * [foundBytes] is the reported file size; [maxBytes] is the limit.
         * Reported separately from [ReadError] so the UI can show a specific,
         * actionable message ("file too large") rather than a generic read error.
         */
        data class FileTooLarge(val foundBytes: Long, val maxBytes: Long) : ImportError()

        /**
         * The backup was created by a newer app version and may contain fields
         * this version cannot handle. [found] is the version in the file;
         * [max] is [BACKUP_VERSION].
         */
        data class VersionTooHigh(val found: Int, val max: Int) : ImportError()

        /** Parsing succeeded but a required field value was unexpected. [detail] carries the exception message. */
        data class ReadError(val detail: String?) : ImportError()
    }

    /**
     * Result of a JSON import attempt.
     *
     * On success: [error] is null, [drinks] and [entries] carry the parsed data.
     * The [drinks] IDs are the original backup IDs – the ViewModel remaps them
     * to local DB IDs before inserting entries (a drink name match is used to
     * detect whether a drink already exists locally).
     *
     * On failure: [error] is non-null; [drinks] and [entries] are empty.
     *
     * @param drinks         Parsed drink definitions with original backup IDs.
     * @param entries        Parsed consumption entries; drinkId values reference
     *                       backup drink IDs and must be remapped by the caller.
     * @param sourceVersion  "version" field from the backup JSON.
     * @param settings       Parsed user preferences, or `null` when the backup
     *                       carries no "settings" object (any pre-v3 file). A
     *                       `null` here MUST be treated as "do not touch the
     *                       local settings", never as "reset to defaults".
     * @param error          Non-null when parsing failed.
     */
    data class ImportResult(
        val drinks: List<DrinkDefinition> = emptyList(),
        val entries: List<ConsumptionEntry> = emptyList(),
        val sourceVersion: Int = 1,
        val settings: AppSettings? = null,
        val error: ImportError? = null,
    )

    /**
     * Parses a backup JSON file identified by [uri].
     *
     * All JSON reads use `optXxx(key, default)` for optional fields so that
     * version-1 backups (which lack "category") are handled gracefully.
     * Required fields use `getXxx(key)` which throws if the key is absent –
     * these exceptions are caught by the outer try/catch and returned as
     * [ImportError.ReadError].
     *
     * NOTE on drinkId remapping:
     * The returned [ImportResult.entries] still carry the original [drinkId]
     * values from the backup file. The caller (SettingsViewModel.importBackup)
     * must build an idMap and remap these before inserting into the local DB,
     * because the local auto-generated IDs will differ from the backup's IDs.
     *
     * @param context  Context for ContentResolver (to open the file URI).
     * @param uri      Content URI of the backup file (from the file picker).
     * @return [ImportResult] – always non-null; check [ImportResult.error].
     */
    @AndroidIoBound
    fun importFromJson(context: Context, uri: Uri): ImportResult {
        // ── Guard 1: file size ────────────────────────────────────────────────
        // Query the reported file size via ContentResolver before reading.
        // A size of -1 means "unknown" (some providers do not report sizes);
        // we allow those through and rely on the value guards in parseBackupJson.
        val fileSize = context.contentResolver
            .query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getLong(0) else -1L } ?: -1L
        if (fileSize > MAX_BACKUP_BYTES) {
            return ImportResult(error = ImportError.FileTooLarge(fileSize, MAX_BACKUP_BYTES))
        }

        val stream = context.contentResolver.openInputStream(uri)
            ?: return ImportResult(error = ImportError.CouldNotRead)

        // ── Guard 1b: bounded read (defence in depth) ─────────────────────────
        // Some content providers report SIZE as -1 ("unknown"), so the fast
        // pre-check above cannot catch an oversized file. readAllUpTo reads at
        // most MAX_BACKUP_BYTES and returns null on overflow, so a maliciously
        // large file can never be fully buffered into the JVM heap.
        val bytes = stream.use { readAllUpTo(it, MAX_BACKUP_BYTES) }
            ?: return ImportResult(error = ImportError.FileTooLarge(-1L, MAX_BACKUP_BYTES))

        return parseBackupJson(bytes.toString(Charsets.UTF_8))
    }

    /**
     * Reads up to [maxBytes] bytes from [input], or returns `null` if the stream
     * holds MORE than [maxBytes] bytes.
     *
     * WHY a bounded read (defence in depth)?
     *   [importFromJson] already performs a fast pre-check via
     *   [OpenableColumns.SIZE], but some providers report the size as -1
     *   ("unknown"). For those, the previous implementation fell back to an
     *   unbounded [java.io.BufferedReader.readText], so a maliciously large
     *   file could exhaust the JVM heap ([OutOfMemoryError]) before any JSON
     *   parsing started. By stopping as soon as the running total exceeds the
     *   cap, the whole oversized file is never buffered.
     *
     * `internal` + [VisibleForTesting] so the overflow logic can be unit-tested
     * with a plain [java.io.ByteArrayInputStream], without an Android Context.
     *
     * @param input    The stream to drain (the caller is responsible for closing it).
     * @param maxBytes The inclusive maximum number of bytes to accept.
     * @return The bytes read (size ≤ [maxBytes]), or `null` on overflow.
     */
    @VisibleForTesting(otherwise = VisibleForTesting.PRIVATE)
    internal fun readAllUpTo(input: InputStream, maxBytes: Long): ByteArray? {
        val buffer = ByteArrayOutputStream()
        val chunk = ByteArray(8 * 1024)
        var total = 0L
        while (true) {
            val read = input.read(chunk)
            if (read == -1) break
            total += read
            if (total > maxBytes) return null // exceeded the cap → reject
            buffer.write(chunk, 0, read)
        }
        return buffer.toByteArray()
    }

    /**
     * Parses a Potillus backup JSON string into an [ImportResult].
     *
     * All content validation (blank text, malformed JSON, version check, numeric
     * range guards) is performed here. The file-reading and size-check happen in
     * the public [importFromJson] wrapper so that this function can be called
     * directly in unit tests without an Android [Context] or [Uri].
     *
     * WHY `internal` and not `private`?
     *   `internal` is visible to the test source set of the same Gradle module,
     *   allowing [de.godisch.potillus.util.BackupManagerTest] to call it directly.
     *   `private` would force tests to go through the full [importFromJson] path,
     *   which requires an Android ContentResolver and a real file URI.
     */
    @VisibleForTesting(otherwise = VisibleForTesting.PRIVATE)
    internal fun parseBackupJson(text: String): ImportResult {
        if (text.isBlank()) return ImportResult(error = ImportError.FileEmpty)

        val root = try {
            JSONObject(text)
        } catch (e: Exception) {
            return ImportResult(error = ImportError.InvalidJson)
        }

        val version = root.optInt("version", 1)
        if (version > BACKUP_VERSION) {
            return ImportResult(error = ImportError.VersionTooHigh(version, BACKUP_VERSION))
        }

        return try {
            val drinks = mutableListOf<DrinkDefinition>()
            val drinksArr = root.optJSONArray("drinks") ?: JSONArray()
            for (i in 0 until drinksArr.length()) {
                val obj = drinksArr.getJSONObject(i)
                val catName = obj.optString("category", "OTHER")
                // ── Guard 2: drink value ranges ───────────────────────────────
                // Reject physically impossible values that could corrupt BAC
                // calculations (e.g. NaN / Infinity propagates through SUM()).
                val volumeMl = obj.getInt("volumeMl")
                    .also { require(it in 1..10_000) { "volumeMl out of range: $it" } }
                val alcoholPercent = obj.getDouble("alcoholPercent")
                    .also { require(it.isFinite() && it in 0.0..100.0) { "alcoholPercent invalid: $it" } }
                drinks.add(
                    DrinkDefinition(
                        id = obj.optLong("id", 0),
                        name = obj.getString("name"),
                        volumeMl = volumeMl,
                        alcoholPercent = alcoholPercent,
                        isPreset = obj.optBoolean("isPreset", false),
                        isFavorite = obj.optBoolean("isFavorite", false),
                        category = runCatching { DrinkCategory.valueOf(catName) }.getOrDefault(DrinkCategory.OTHER),
                    ),
                )
            }

            val entries = mutableListOf<ConsumptionEntry>()
            val entriesArr = root.optJSONArray("entries") ?: JSONArray()
            for (i in 0 until entriesArr.length()) {
                val obj = entriesArr.getJSONObject(i)
                // ── Guard 3: entry value ranges ───────────────────────────────
                // gramsAlcohol is the primary input to all BAC and statistics
                // calculations; a NaN or negative value would silently corrupt
                // every aggregate query that touches this entry.
                val entryVolumeMl = obj.getInt("volumeMl")
                    .also { require(it in 1..10_000) { "entry volumeMl out of range: $it" } }
                val entryAlcoholPercent = obj.getDouble("alcoholPercent")
                    .also { require(it.isFinite() && it in 0.0..100.0) { "entry alcoholPercent invalid: $it" } }
                val gramsAlcohol = obj.getDouble("gramsAlcohol")
                    .also { require(it.isFinite() && it >= 0.0) { "gramsAlcohol invalid: $it" } }
                val timestampMillis = obj.getLong("timestampMillis")
                    .also { require(it > 0) { "timestampMillis invalid: $it" } }
                // ── Guard 4: logicalDate – full calendar-semantic validation ─────
                // logicalDate is used in all SQL WHERE and ORDER BY clauses as a
                // plain String comparison (ISO-8601 lexicographic order = chronological
                // order). An arbitrary string injected here would silently corrupt
                // every date-scoped query.
                //
                // A shape-only regex \d{4}-\d{2}-\d{2} would accept
                // physically impossible values such as "9999-99-99" or "2024-02-31".
                // Note that DayResolver.parseDate() alone is NOT sufficient: it uses
                // the app-wide DateTimeFormatter, whose default ResolverStyle.SMART
                // silently CLAMPS an impossible day to the last valid one
                // ("2024-02-31" -> 2024-02-29) instead of throwing. We therefore both
                // (a) require it to parse, and (b) require a parse→format round-trip to
                // reproduce the input exactly, which rejects any clamped or
                // non-canonical date.
                val logicalDate = obj.getString("logicalDate").also { raw ->
                    val parsed = runCatching { DayResolver.parseDate(raw) }.getOrElse { ex ->
                        throw IllegalArgumentException(
                            "logicalDate is not a valid calendar date: $raw",
                            ex,
                        )
                    }
                    require(DayResolver.formatDate(parsed) == raw) {
                        "logicalDate is not a valid calendar date: $raw"
                    }
                }
                entries.add(
                    ConsumptionEntry(
                        id = obj.optLong("id", 0),
                        drinkId = obj.optLong("drinkId", 0),
                        drinkName = obj.getString("drinkName"),
                        volumeMl = entryVolumeMl,
                        alcoholPercent = entryAlcoholPercent,
                        gramsAlcohol = gramsAlcohol,
                        timestampMillis = timestampMillis,
                        logicalDate = logicalDate,
                        note = obj.optString("note", ""),
                    ),
                )
            }

            // ── Guard 5: referential integrity – every entry must point at a drink
            //    that is actually IN this backup. A dangling drinkId (hand-edited or
            //    truncated file) previously slipped through to the repository, where
            //    the REPLACE import's id-remap fallback kept the raw backup id: if
            //    that number happened to equal a local preset's id, the entry was
            //    silently attached to the WRONG drink (wrong category in every
            //    statistic); otherwise the entries→drinks FK (RESTRICT) aborted the
            //    whole transaction with only a generic error. Failing here instead
            //    yields a precise, actionable message — and lets the repository drop
            //    its fallback entirely (v0.79.0 QA fix).
            val drinkIds = drinks.mapTo(HashSet()) { it.id }
            entries.forEach { entry ->
                require(entry.drinkId in drinkIds) {
                    "entry references drinkId ${entry.drinkId}, which is not in the backup's drinks list"
                }
            }

            ImportResult(drinks, entries, sourceVersion = version, settings = parseSettings(root))
        } catch (e: Exception) {
            ImportResult(error = ImportError.ReadError(e.message))
        }
    }

    /**
     * Parses the optional top-level `"settings"` object (backup format 3+).
     *
     * Returns `null` when the key is absent (any pre-v3 backup, or a v3 file that
     * legitimately omits it) — the caller then leaves the local preferences
     * untouched. When present, every field is read DEFENSIVELY: unknown, missing,
     * non-finite or out-of-range values fall back to the [AppSettings] default or
     * are clamped to the same ranges the [de.godisch.potillus.data.prefs.AppPreferences]
     * setters enforce. This mirrors the tolerant reading already done in
     * `AppPreferences.settingsFlow` and, crucially, means a malformed settings
     * block can NEVER abort the surrounding import: the user's drink/entry history
     * is the primary payload and must always restore, even from a slightly corrupt
     * backup. Because of that contract this function never throws.
     *
     * Sentinels preserved on purpose:
     *  - `weightKg == 0.0` means "not set" (the setter would clamp a real value to
     *    ≥ 1 kg, so 0.0 must survive as-is rather than becoming a fake 1 kg body).
     *  - `language == ""` means "follow the system language".
     *  - `statsFromDate == ""` means "no explicit start date"; any non-empty value
     *    must be a canonical ISO-8601 calendar date or it degrades back to "".
     *
     * @param root The parsed backup JSON root object.
     * @return A validated [AppSettings], or `null` if no `"settings"` object exists.
     */
    private fun parseSettings(root: JSONObject): AppSettings? {
        val obj = root.optJSONObject("settings") ?: return null
        val def = AppSettings() // canonical defaults for any missing/invalid field

        val theme = runCatching { ThemeMode.valueOf(obj.optString("themeMode", def.themeMode.name)) }
            .getOrDefault(def.themeMode)

        val daily = obj.optDouble("dailyLimitGrams", def.dailyLimitGrams)
            .let { if (it.isFinite()) it.coerceIn(1.0, 500.0) else def.dailyLimitGrams }
        val weekly = obj.optDouble("weeklyLimitGrams", def.weeklyLimitGrams)
            .let { if (it.isFinite()) it.coerceIn(1.0, 3500.0) else def.weeklyLimitGrams }

        // weightKg: keep the 0.0 "unset" sentinel; clamp a real value to 1..500 kg.
        val rawWeight = obj.optDouble("weightKg", def.weightKg)
        val weight = when {
            !rawWeight.isFinite() -> def.weightKg // 0.0
            rawWeight <= 0.0 -> 0.0 // preserve the unset sentinel
            else -> rawWeight.coerceIn(1.0, 500.0)
        }

        // statsFromDate: "" stays "", otherwise require a canonical calendar date
        // (same parse→format round-trip the entry loop uses) or degrade to "".
        val statsFrom = obj.optString("statsFromDate", def.statsFromDate).let { raw ->
            if (raw.isBlank()) {
                ""
            } else {
                runCatching { DayResolver.formatDate(DayResolver.parseDate(raw)) == raw }
                    .getOrDefault(false)
                    .let { canonical -> if (canonical) raw else "" }
            }
        }

        // language: a BCP-47 tag is short; reject an implausibly long value so a
        // crafted backup cannot bloat the encrypted preferences file.
        val language = obj.optString("language", def.language).let { if (it.length <= 35) it else "" }

        return AppSettings(
            themeMode = theme,
            dayChangeHour = obj.optInt("dayChangeHour", def.dayChangeHour).coerceIn(0, 23),
            dayChangeMinute = obj.optInt("dayChangeMinute", def.dayChangeMinute).coerceIn(0, 59),
            dailyLimitGrams = daily,
            weeklyLimitGrams = weekly,
            maxDrinkDaysPerWeek = obj.optInt("maxDrinkDaysPerWeek", def.maxDrinkDaysPerWeek).coerceIn(1, 7),
            statsFromDate = statsFrom,
            biometricEnabled = obj.optBoolean("biometricEnabled", def.biometricEnabled),
            allowScreenshots = obj.optBoolean("allowScreenshots", def.allowScreenshots),
            language = language,
            weightKg = weight,
        )
    }
}
