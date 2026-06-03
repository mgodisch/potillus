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
package de.godisch.potillus.util

import android.content.ContentValues
import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.VisibleForTesting
import de.godisch.potillus.R
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import java.io.IOException
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// =============================================================================
// CsvExporter.kt – Export consumption history as a CSV file
// =============================================================================
//
// CSV FORMAT CHOICES:
//
//   RFC 4180 compliance:
//     - Lines are separated by CRLF (\r\n), not just LF (\n).
//       Many Windows applications (including older Excel versions) expect CRLF.
//     - Fields that contain commas, double-quotes, or newlines are enclosed in
//       double-quotes. Internal double-quotes are escaped by doubling them ("").
//
//   UTF-8 BOM:
//     The file starts with the byte sequence EF BB BF (UTF-8 Byte Order Mark).
//     Microsoft Excel does not detect UTF-8 encoding automatically; the BOM
//     signals the encoding so that characters like ä, ö, ü are displayed
//     correctly without a manual import wizard.
//     Other applications (LibreOffice Calc, Python csv module, etc.) handle
//     the BOM transparently.
//
//   Locale-aware column headers:
//     Column names are read from string resources so they match the app's
//     active language. This makes the export more readable for non-English users.
// =============================================================================

/** Exports consumption history as a UTF-8 CSV file to the Downloads folder. */
object CsvExporter {

    /** Timestamp format for the file name ("yyyyMMdd_HHmm"). */
    private val FILE_FMT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm").withZone(ZoneId.systemDefault())

    /**
     * Exports all [entries] as a CSV file and saves it to the system Downloads folder
     * via MediaStore (Android 10+ approach; does not require WRITE_EXTERNAL_STORAGE).
     *
     * Column order: date, time, drink name, category, volume (ml),
     * alcohol (%), grams, note.
     *
     * @param context  Context for string resources and ContentResolver access.
     * @param entries  All consumption entries in chronological order.
     * @param drinks   Full drink catalogue (used to look up the category name
     *                 for each entry's [ConsumptionEntry.drinkId]).
     * @return         [ExportResult] with filename and MediaStore URI on success,
     *                 `null` on any I/O error (the incomplete MediaStore entry is
     *                 deleted so no corrupt file remains in Downloads).
     */
    fun export(
        context: Context,
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>
    ): ExportResult? {
        val fileName = "potillus_export_${FILE_FMT.format(Instant.now())}.csv"

        // Build a map from drink ID → definition for O(1) category lookups.
        // A plain Map lookup is faster than searching the list for every entry.
        val drinkMap = drinks.associateBy { it.id }

        // Column headers from string resources (locale-aware)
        val header = listOf(
            context.getString(R.string.csv_col_date),
            context.getString(R.string.csv_col_time),
            context.getString(R.string.csv_col_drink),
            context.getString(R.string.csv_col_category),
            context.getString(R.string.csv_col_volume_ml),
            context.getString(R.string.csv_col_alcohol_pct),
            context.getString(R.string.csv_col_grams),
            context.getString(R.string.csv_col_note)
        ).joinToString(",")

        val timeFmt = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.systemDefault())

        val rows = entries.map { e ->
            val instant  = Instant.ofEpochMilli(e.timestampMillis)
            // Category falls back to "OTHER" for entries whose drink was edited
            // or if a future backup format includes an unknown category.
            val category = drinkMap[e.drinkId]?.category?.name ?: "OTHER"
            listOf(
                e.logicalDate,
                timeFmt.format(instant),
                escapeField(e.drinkName),
                category,
                e.volumeMl.toString(),
                e.alcoholPercent.toString(),
                "%.2f".format(e.gramsAlcohol),
                escapeField(e.note)
            ).joinToString(",")
        }

        // RFC 4180: lines are separated by CRLF; every record including the last
        // one MUST be terminated by CRLF (postfix = "\r\n")
        val csv = (listOf(header) + rows).joinToString("\r\n", postfix = "\r\n")

        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            ?: return null   // MediaStore declined to create the entry

        return try {
            resolver.openOutputStream(uri)?.use { stream ->
                // Prepend UTF-8 BOM so Excel detects the encoding automatically
                stream.write(byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()))
                stream.write(csv.toByteArray(Charsets.UTF_8))
            }
            ExportResult(fileName, uri, "text/csv")
        } catch (e: IOException) {
            // Clean up the orphaned MediaStore entry so Downloads is not polluted
            resolver.delete(uri, null, null)
            null
        }
    }

    /**
     * Escapes a free-text field for safe inclusion in a CSV file.
     *
     * This performs TWO independent jobs, in order:
     *
     * 1. **Formula-injection neutralisation (OWASP "CSV Injection").**
     *    Spreadsheet applications (Microsoft Excel, LibreOffice Calc, Google
     *    Sheets, Apple Numbers) treat a cell whose first character is one of
     *    `= + - @` — or a leading TAB (0x09) / CR (0x0D) — as a *formula* rather
     *    than literal text. Because drink names and notes are free text typed by
     *    the user, a value such as `=HYPERLINK("http://evil","click")` or
     *    `=1+CMD|...` would execute when the exported file is opened. Since this
     *    file is explicitly produced to be *shared* (see SettingsScreen share
     *    intent), the recipient's spreadsheet would be the victim.
     *
     *    The OWASP-recommended mitigation is to prefix any field that begins
     *    with a dangerous character with a single quote (`'`). The leading quote
     *    forces the spreadsheet to interpret the whole cell as text; most tools
     *    do not render the quote itself. This is a deliberate, visible trade-off:
     *    a legitimate note like `-5 today` is exported as `'-5 today`.
     *
     * 2. **RFC 4180 quoting.** If the (already formula-guarded) value contains a
     *    comma, double-quote, or newline, the whole field is wrapped in double
     *    quotes and any embedded double-quote is doubled (`"` → `""`).
     *
     * The two steps compose correctly: the guard is applied to the raw value
     * first, then RFC 4180 quoting wraps the guarded value if structurally
     * required. Fields that need neither step are returned unchanged, keeping
     * the output compact for typical drink names.
     *
     * `internal` (not `private`) so [de.godisch.potillus.util.CsvExporterTest]
     * can verify the sanitisation directly without an Android [Context].
     *
     * @param raw  The unsanitised field value (e.g. a drink name or note).
     * @return     A CSV-safe representation of [raw].
     */
    @VisibleForTesting(otherwise = VisibleForTesting.PRIVATE)
    internal fun escapeField(raw: String): String = rfc4180Quote(neutralizeFormula(raw))

    /**
     * Characters that trigger formula evaluation when they appear as the first
     * character of a spreadsheet cell. TAB (0x09) and CR (0x0D) are included
     * because some importers strip a leading TAB/CR and then re-evaluate the
     * next character, so a value like "\t=1+1" can still become a formula.
     */
    private val FORMULA_TRIGGERS = charArrayOf('=', '+', '-', '@', '\t', '\r')

    /**
     * Prepends a single quote to [raw] iff its first character could trigger
     * formula evaluation. Empty strings are returned unchanged (no first char).
     */
    private fun neutralizeFormula(raw: String): String =
        if (raw.isNotEmpty() && raw[0] in FORMULA_TRIGGERS) "'$raw" else raw

    /**
     * Applies RFC 4180 quoting to [value] if it contains a comma, double-quote,
     * or newline; otherwise returns it unchanged.
     */
    private fun rfc4180Quote(value: String): String =
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
            "\"${value.replace("\"", "\"\"")}\""
        } else value
}
