// vim: set et ts=4 sw=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
// =============================================================================

package de.godisch.potillus.util

/**
 * The project's GPLv3 notice, in the two shapes the exporters need.
 *
 * Single source of truth so the wording stays identical across export formats
 * and matches the header carried by every source file. The text is kept in
 * English on purpose: it is a legal notice, not UI chrome, so it is NOT a
 * translatable string resource (and therefore does not affect the per-locale
 * `strings.xml` parity checked by `LocaleSyncTest`).
 *
 * WHERE EACH SHAPE IS USED
 *   - [HEADER_LINES] is embedded as a JSON `_comment` array by
 *     [BackupManager.exportToJson]. JSON has no comment syntax, so a dedicated,
 *     parser-ignored field is the faithful equivalent of a non-evaluated
 *     comment: the importer reads only the known keys and skips `_comment`.
 *   - [PDF_FOOTER] is rendered as a small footer line on every page of the PDF
 *     report by [PdfReportBuilder]. A two-page clinical layout has no room for the
 *     full header, so this is the notice condensed to a single line.
 *
 *   The CSV export intentionally carries no notice: CSV has no portable comment
 *   convention, and a leading `#`/comment line would surface as a spurious data
 *   row in spreadsheet importers, defeating the machine-readable purpose of the
 *   format.
 */
object GplNotice {

    /**
     * The license header as individual lines (no comment markers), ready to be
     * stored as a JSON array. Blank entries reproduce the paragraph breaks of
     * the canonical header.
     */
    val HEADER_LINES: List<String> = listOf(
        "Libellus Potionis - Privacy-Friendly Alcohol Tracker",
        "Copyright (c) 2026 Martin A. Godisch <android@godisch.de>",
        "",
        "This program is free software: you can redistribute it and/or modify it",
        "under the terms of the GNU General Public License as published by the",
        "Free Software Foundation, either version 3 of the License, or (at your",
        "option) any later version.",
        "",
        "This program is distributed in the hope that it will be useful, but",
        "WITHOUT ANY WARRANTY; without even the implied warranty of",
        "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General",
        "Public License for more details.",
        "",
        "You should have received a copy of the GNU General Public License along",
        "with this program. If not, see <https://www.gnu.org/licenses/>."
    )

    /** One-line condensed notice for the PDF report footer. */
    const val PDF_FOOTER: String =
        "Libellus Potionis \u00A9 2026 Martin A. Godisch \u00B7 free software under the " +
        "GNU GPL v3, WITHOUT ANY WARRANTY \u00B7 https://www.gnu.org/licenses/"
}
