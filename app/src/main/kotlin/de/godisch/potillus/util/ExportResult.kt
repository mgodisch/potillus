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

import android.net.Uri

// =============================================================================
// ExportResult.kt – Return type shared by all export functions
// =============================================================================
//
// WHY A SHARED RETURN TYPE?
//   CsvExporter and BackupManager both write a file to the MediaStore Downloads
//   folder and then offer it for sharing via an Intent. By returning the same
//   [ExportResult] type, their callers can handle both cases with identical code
//   (no if/when on the type).
//
//   NOTE (v0.61.0): the PDF report no longer flows through [ExportResult]. It is
//   rendered to HTML (PdfReportBuilder) and handed to the system print dialog
//   (WebViewPdfPrinter), which owns saving and sharing the PDF itself.
//
// MediaStore vs FileProvider:
//   On Android 10+, apps should write shared files to MediaStore (via
//   ContentResolver.insert + openOutputStream) rather than directly to
//   file paths. MediaStore returns a content:// URI that can be safely
//   shared with other apps via FLAG_GRANT_READ_URI_PERMISSION.
//   The [uri] field carries this content:// URI.
// =============================================================================

/**
 * Returned by every export function on success.
 *
 * On failure the exporters return `null`, and the ViewModel shows an error
 * message from string resources.
 *
 * @param fileName  Human-readable name of the created file
 *                  (e.g. "potillus_export_20250526_1430.csv"). Shown in the
 *                  share-sheet title and in the success banner.
 * @param uri       MediaStore `content://` URI of the created file.
 *                  Used to build the share [android.content.Intent] with
 *                  [android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION].
 * @param mimeType  MIME type string for the share intent
 *                  (e.g. "text/csv", "application/pdf", "application/json").
 */
data class ExportResult(
    val fileName: String,
    val uri: Uri,
    val mimeType: String
)
