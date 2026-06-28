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
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.json.JSONArray
import org.json.JSONObject
import androidx.annotation.VisibleForTesting
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
//   BACKUP_VERSION = 2 (current).
//   Format 1: same structure but without the "category" field on
//   drinks – optString("category", "OTHER") handles this transparently.
//   The importer rejects files with version > BACKUP_VERSION (written by a
//   newer app) to avoid silently truncating unknown fields.
//
// IMPORT MODES (handled in SettingsViewModel, not here):
//   REPLACE – delete all local data, then import everything from the backup.
//   MERGE   – keep local data, add backup entries that are not duplicates.
//             Duplicates are detected by (timestampMillis, drinkId) pairs.
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
     */
    private const val BACKUP_VERSION = 2

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
    private const val MAX_BACKUP_BYTES = 10L * 1_024 * 1_024   // 10 MB

    /** Timestamp format for the backup file name. */
    private val FILE_FMT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm").withZone(ZoneId.systemDefault())

    // ── Export ────────────────────────────────────────────────────────────────

    /**
     * Serialises [drinks] and [entries] to a JSON file in the Downloads folder.
     *
     * The produced JSON structure:
     * ```json
     * {
     *   "version": 2,
     *   "exportedAt": "2025-05-26T14:30:00Z",
     *   "drinks": [ { "id": 1, "name": "Pils 0,5 l", … }, … ],
     *   "entries": [ { "id": 1, "drinkId": 1, "gramsAlcohol": 19.6, … }, … ]
     * }
     * ```
     *
     * The file is written via MediaStore so no file-system permissions are
     * required on Android 10+.
     *
     * @param context  Context for ContentResolver access.
     * @param drinks   Current drink catalogue (including presets).
     * @param entries  All consumption entries.
     * @return         [ExportResult] on success; `null` on I/O error.
     */
    fun exportToJson(
        context: Context,
        drinks: List<DrinkDefinition>,
        entries: List<ConsumptionEntry>
    ): ExportResult? {
        // Capture Instant.now() once so the file name and the
        // "exportedAt" field in the JSON root are guaranteed to match exactly,
        // even on devices where the clock is adjusted between two calls.
        val now      = Instant.now()
        val fileName = "potillus_backup_${FILE_FMT.format(now)}.json"

        val root = JSONObject().apply {
            // Non-evaluated GPLv3 notice. JSON has no comment syntax, so the
            // header is carried as a dedicated "_comment" array; importers
            // (including ours) read only the known keys and ignore it. See
            // GplNotice for the rationale.
            put("_comment", JSONArray(GplNotice.HEADER_LINES))
            put("version", BACKUP_VERSION)
            put("exportedAt", now.toString())
            put("drinks", JSONArray().also { arr ->
                drinks.forEach { d ->
                    arr.put(JSONObject().apply {
                        put("id", d.id)
                        put("name", d.name)
                        put("volumeMl", d.volumeMl)
                        put("alcoholPercent", d.alcoholPercent)
                        put("isPreset", d.isPreset)
                        put("isFavorite", d.isFavorite)
                        put("category", d.category.name)
                    })
                }
            })
            put("entries", JSONArray().also { arr ->
                entries.forEach { e ->
                    arr.put(JSONObject().apply {
                        put("id", e.id)
                        put("drinkId", e.drinkId)
                        put("drinkName", e.drinkName)
                        put("volumeMl", e.volumeMl)
                        put("alcoholPercent", e.alcoholPercent)
                        put("gramsAlcohol", e.gramsAlcohol)
                        put("timestampMillis", e.timestampMillis)
                        put("logicalDate", e.logicalDate)
                        put("note", e.note)
                    })
                }
            })
        }

        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues) ?: return null

        return try {
            resolver.openOutputStream(uri)?.use { it.write(root.toString(2).toByteArray(Charsets.UTF_8)) }
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
        object FileEmpty    : ImportError()
        /** The file content is not valid JSON. */
        object InvalidJson  : ImportError()
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
     * @param error          Non-null when parsing failed.
     */
    data class ImportResult(
        val drinks: List<DrinkDefinition> = emptyList(),
        val entries: List<ConsumptionEntry> = emptyList(),
        val sourceVersion: Int = 1,
        val error: ImportError? = null
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
     * @return         [ImportResult] – always non-null; check [ImportResult.error].
     */
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
     * @return         The bytes read (size ≤ [maxBytes]), or `null` on overflow.
     */
    @VisibleForTesting(otherwise = VisibleForTesting.PRIVATE)
    internal fun readAllUpTo(input: InputStream, maxBytes: Long): ByteArray? {
        val buffer = ByteArrayOutputStream()
        val chunk  = ByteArray(8 * 1024)
        var total  = 0L
        while (true) {
            val read = input.read(chunk)
            if (read == -1) break
            total += read
            if (total > maxBytes) return null   // exceeded the cap → reject
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

        val root = try { JSONObject(text) }
        catch (e: Exception) { return ImportResult(error = ImportError.InvalidJson) }

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
                val volumeMl       = obj.getInt("volumeMl")
                    .also { require(it in 1..10_000) { "volumeMl out of range: $it" } }
                val alcoholPercent = obj.getDouble("alcoholPercent")
                    .also { require(it.isFinite() && it in 0.0..100.0) { "alcoholPercent invalid: $it" } }
                drinks.add(DrinkDefinition(
                    id             = obj.optLong("id", 0),
                    name           = obj.getString("name"),
                    volumeMl       = volumeMl,
                    alcoholPercent = alcoholPercent,
                    isPreset       = obj.optBoolean("isPreset", false),
                    isFavorite     = obj.optBoolean("isFavorite", false),
                    category       = runCatching { DrinkCategory.valueOf(catName) }.getOrDefault(DrinkCategory.OTHER)
                ))
            }

            val entries = mutableListOf<ConsumptionEntry>()
            val entriesArr = root.optJSONArray("entries") ?: JSONArray()
            for (i in 0 until entriesArr.length()) {
                val obj = entriesArr.getJSONObject(i)
                // ── Guard 3: entry value ranges ───────────────────────────────
                // gramsAlcohol is the primary input to all BAC and statistics
                // calculations; a NaN or negative value would silently corrupt
                // every aggregate query that touches this entry.
                val entryVolumeMl       = obj.getInt("volumeMl")
                    .also { require(it in 1..10_000) { "entry volumeMl out of range: $it" } }
                val entryAlcoholPercent = obj.getDouble("alcoholPercent")
                    .also { require(it.isFinite() && it in 0.0..100.0) { "entry alcoholPercent invalid: $it" } }
                val gramsAlcohol        = obj.getDouble("gramsAlcohol")
                    .also { require(it.isFinite() && it >= 0.0) { "gramsAlcohol invalid: $it" } }
                val timestampMillis     = obj.getLong("timestampMillis")
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
                            "logicalDate is not a valid calendar date: $raw", ex
                        )
                    }
                    require(DayResolver.formatDate(parsed) == raw) {
                        "logicalDate is not a valid calendar date: $raw"
                    }
                }
                entries.add(ConsumptionEntry(
                    id              = obj.optLong("id", 0),
                    drinkId         = obj.optLong("drinkId", 0),
                    drinkName       = obj.getString("drinkName"),
                    volumeMl        = entryVolumeMl,
                    alcoholPercent  = entryAlcoholPercent,
                    gramsAlcohol    = gramsAlcohol,
                    timestampMillis = timestampMillis,
                    logicalDate     = logicalDate,
                    note            = obj.optString("note", "")
                ))
            }

            ImportResult(drinks, entries, sourceVersion = version)
        } catch (e: Exception) {
            ImportResult(error = ImportError.ReadError(e.message))
        }
    }
}
