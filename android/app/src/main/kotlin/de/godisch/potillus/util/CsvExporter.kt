/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
import java.util.Locale

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

        // Resolve the localised column headers from string resources here (the
        // only step that needs a Context), then delegate the Android-free CSV
        // assembly to buildCsv so it can be unit-tested under any locale without a
        // Context (see CsvExporterBuildTest).
        val headerCells = listOf(
            context.getString(R.string.csv_col_date),
            context.getString(R.string.csv_col_time),
            context.getString(R.string.csv_col_drink),
            context.getString(R.string.csv_col_category),
            context.getString(R.string.csv_col_volume_ml),
            context.getString(R.string.csv_col_alcohol_pct),
            context.getString(R.string.csv_col_grams),
            context.getString(R.string.csv_col_note)
        )

        val csv = buildCsv(headerCells, entries, drinks)

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
     * Assembles the full CSV document (header row + one row per entry) from
     * already-resolved [headerCells].
     *
     * This is the Android-free core of [export]: it takes the localised column
     * headers as plain strings instead of reading them from a [Context], so the
     * entire row-assembly and number-formatting logic can be unit-tested on the
     * JVM under any [Locale] (see `CsvExporterBuildTest`). [export] resolves the
     * headers from string resources and then calls this.
     *
     * Two correctness details are enforced here:
     *
     * 1. **Locale-independent decimals.** The grams field is formatted with
     *    [Locale.ROOT] (`String.format(Locale.ROOT, "%.2f", …)`). `"%.2f".format`
     *    would otherwise honour [Locale.getDefault], so on a comma-decimal locale
     *    (de, fr, es, it, …) `19.6` becomes `"19,60"`; that comma is unquoted
     *    inside a comma-separated row and would split the value across two columns,
     *    silently corrupting the export. CSV is a machine-readable interchange
     *    format, so a `.` decimal separator is the correct, portable choice.
     *
     * 2. **Escaped headers.** The column captions are translator-supplied free
     *    text and are therefore passed through [escapeField] just like the data
     *    cells: a comma inside a localised header would otherwise add a spurious
     *    column and misalign every row.
     *
     * `internal` + [VisibleForTesting] so the test source set can call it directly.
     *
     * @param headerCells The localised column captions, in column order.
     * @param entries     The consumption entries to serialise (one row each).
     * @param drinks      The drink catalogue, used to resolve each entry's category.
     * @return            The complete CSV text, CRLF-terminated per RFC 4180.
     */
    @VisibleForTesting(otherwise = VisibleForTesting.PRIVATE)
    internal fun buildCsv(
        headerCells: List<String>,
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>
    ): String {
        // Build a map from drink ID → definition for O(1) category lookups.
        val drinkMap = drinks.associateBy { it.id }
        val timeFmt  = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.systemDefault())

        // Headers are escaped too (see step 2 in the KDoc above).
        val header = headerCells.joinToString(",") { escapeField(it) }

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
                // Double.toString() is already locale-independent (always '.'),
                // so the ABV column needs no special handling.
                e.alcoholPercent.toString(),
                // Locale.ROOT forces a '.' decimal separator (see step 1 above).
                String.format(Locale.ROOT, "%.2f", e.gramsAlcohol),
                escapeField(e.note)
            ).joinToString(",")
        }

        // RFC 4180: lines are separated by CRLF; every record including the last
        // one MUST be terminated by CRLF (postfix = "\r\n").
        return (listOf(header) + rows).joinToString("\r\n", postfix = "\r\n")
    }

    /**
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
