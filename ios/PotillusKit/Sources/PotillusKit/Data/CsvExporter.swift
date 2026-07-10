// vim: set et ts=4:
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
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import Foundation

// =============================================================================
// CsvExporter.swift – consumption history as RFC 4180 CSV
// =============================================================================
//
// A faithful Swift port of Android's `util/CsvExporter.kt` (its Android-free
// core, `buildCsv`). The two produce byte-identical documents for the same
// input; `test-vectors/csv-export.json` pins that.
//
// FORMAT CHOICES, carried over verbatim
//
//   RFC 4180. Records are separated by CRLF, and — per §2 — the LAST record is
//   terminated by CRLF as well. Fields containing a comma, a double quote, or a
//   line break are wrapped in double quotes, with embedded quotes doubled.
//
//   UTF-8 BOM. The exported FILE begins with EF BB BF so Excel detects the
//   encoding without an import wizard. That belongs to the file writer, not to
//   `buildCsv`, exactly as on Android — the BOM is a property of the artefact,
//   not of the document.
//
//   Locale-independent decimals. The grams column is formatted with an explicit
//   "%.2f" and no locale. On a comma-decimal locale a naive formatter would emit
//   "19,60"; that comma sits unquoted inside a comma-separated row and would
//   split the value across two columns, silently corrupting the export.
//
//   Escaped headers. Column captions are translator-supplied free text, so they
//   run through `escapeField` like any data cell: a comma inside a localised
//   header would otherwise add a spurious column and misalign every row.
//
// WHAT IS *NOT* ESCAPED, and why that is deliberate
//   Only free text is escaped: the headers, the drink name and the note. The
//   generated cells — logical date, clock time, category name, the three numbers
//   — cannot contain a comma, a quote or a newline by construction. Android
//   makes exactly this distinction, and mirroring the asymmetry rather than
//   "escaping everything for safety" is what keeps the two outputs identical.
//
// TIME ZONE
//   Android reads `ZoneId.systemDefault()` inside `buildCsv`. Here the zone is
//   an explicit parameter defaulting to `.current`: the behaviour is the same in
//   the app, and a test can pin it, which is what lets the shared vectors assert
//   a clock time at all. The column shows WALL-CLOCK time in that zone, while
//   `logicalDate` is the stored logical day — the two can disagree around the
//   day-change hour, and that is correct.
// =============================================================================

public enum CsvExporter {

    /// Characters that make a spreadsheet treat a cell as a FORMULA rather than
    /// as text.
    ///
    /// TAB (0x09) and CR (0x0D) are included because some importers strip a
    /// leading TAB or CR and then re-evaluate the next character, so "\t=1+1"
    /// can still become a formula.
    private static let formulaTriggers: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

    /// Assembles the full CSV document: one header row, then one row per entry.
    ///
    /// - Parameters:
    ///   - headerCells: The localised column captions, in column order.
    ///   - entries: The consumption entries to serialise, one row each.
    ///   - drinks: The drink catalogue, used to resolve each entry's category.
    ///   - timeZone: The zone the `HH:mm` column is rendered in.
    /// - Returns: The complete CSV text, CRLF-terminated per RFC 4180.
    public static func buildCsv(
        headerCells: [String],
        entries: [ConsumptionEntry],
        drinks: [DrinkDefinition],
        timeZone: TimeZone = .current
    ) -> String {
        // O(1) category lookups.
        var categoryById: [Int64: DrinkCategory] = [:]
        for drink in drinks { categoryById[drink.id] = drink.category }

        let timeFormatter = Self.timeFormatter(for: timeZone)

        // Headers are escaped too — see the note above.
        let header = headerCells.map(escapeField).joined(separator: ",")

        let rows = entries.map { entry -> String in
            let instant = Date(timeIntervalSince1970: Double(entry.timestampMillis) / 1000.0)
            // Falls back to OTHER for an entry whose drink was deleted, or whose
            // category a future format introduced.
            let category = categoryById[entry.drinkId] ?? .other

            return [
                entry.logicalDate,
                timeFormatter.string(from: instant),
                escapeField(entry.drinkName),
                category.rawValue,
                String(entry.volumeMl),
                // Swift's default `String(describing:)` for Double is
                // locale-independent and matches Kotlin's `Double.toString()`
                // for the values an ABV can take: 4.9 -> "4.9", 40.0 -> "40.0".
                String(entry.alcoholPercent),
                // `String(format:)` with no locale argument uses the POSIX
                // conventions, i.e. always a '.' separator.
                String(format: "%.2f", entry.gramsAlcohol),
                escapeField(entry.note),
            ].joined(separator: ",")
        }

        // RFC 4180: every record, including the last, is terminated by CRLF.
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }

    /// Makes a field safe to place in a CSV row.
    ///
    /// Two independent jobs, in this order:
    ///
    /// 1. **Formula-injection neutralisation (OWASP "CSV Injection").** A cell
    ///    starting with `=`, `+`, `-`, `@`, TAB or CR is evaluated as a formula by
    ///    Excel, LibreOffice, Google Sheets and Numbers. Drink names and notes are
    ///    free text, so `=HYPERLINK("http://evil","click")` would execute when the
    ///    exported file is opened — and this file exists precisely to be SHARED,
    ///    making the recipient's spreadsheet the victim. The OWASP mitigation is a
    ///    leading single quote, which forces a text interpretation. It is a
    ///    visible trade-off: a legitimate note `-5 today` exports as `'-5 today`.
    ///
    /// 2. **RFC 4180 quoting.** If the guarded value contains a comma, a double
    ///    quote, or a line break, the field is wrapped in double quotes and any
    ///    embedded quote is doubled.
    ///
    /// The steps compose: the guard sees the raw value, then quoting wraps the
    /// guarded one. A field needing neither is returned unchanged, which keeps
    /// the output compact for ordinary drink names.
    static func escapeField(_ raw: String) -> String {
        rfc4180Quote(neutralizeFormula(raw))
    }

    /// Prepends a single quote when the first character could trigger formula
    /// evaluation. An empty string has no first character and is returned as is.
    private static func neutralizeFormula(_ raw: String) -> String {
        guard let first = raw.first, formulaTriggers.contains(first) else { return raw }
        return "'" + raw
    }

    /// Wraps `value` in double quotes when it embeds a comma, a quote, or a line
    /// break, doubling any embedded quote.
    ///
    /// CR and LF are tested independently rather than only LF, so a lone CR — an
    /// old-Mac line ending pasted into a note, which never carries an
    /// accompanying LF — cannot slip through unquoted and split the record.
    private static func rfc4180Quote(_ value: String) -> String {
        let needsQuoting = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// `HH:mm` in the given zone.
    ///
    /// Pinned to `en_US_POSIX` and the Gregorian calendar for the same reason as
    /// in `DayResolver`: a device locale must never substitute an alternate
    /// calendar or a 12-hour clock into a machine-readable export.
    private static func timeFormatter(for timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    /// The UTF-8 byte-order mark prepended when WRITING the file.
    ///
    /// Excel does not detect UTF-8 automatically; the BOM signals it so that ä,
    /// ö, ü survive without a manual import wizard. Other tools (LibreOffice,
    /// Python's csv module) handle it transparently.
    /// The file name Android writes: `potillus_export_yyyyMMdd_HHmm.csv`.
    ///
    /// Local wall-clock time, as there too. The user finds this file among their
    /// documents and thinks in the time their watch shows.
    public static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return "potillus_export_\(formatter.string(from: now)).csv"
    }

    /// The column captions Android's English resources carry, in column order.
    ///
    /// Android localises these; iOS cannot yet, having no string catalogue. The
    /// English set is therefore the CURRENT truth, not a placeholder to be quietly
    /// forgotten: a German user gets German drink names in an English-headed file
    /// until localisation lands. `buildCsv` still takes the captions as a
    /// parameter, so that change will not touch the exporter.
    ///
    /// The underscores are Android's, kept so a spreadsheet built against one
    /// platform's export opens against the other's.
    public static let englishHeaderCells = [
        "Date", "Time", "Drink", "Category",
        "Amount_ml", "Alcohol_Percent", "Grams_Alcohol", "Note",
    ]

    public static let utf8BOM = Data([0xEF, 0xBB, 0xBF])

    /// The bytes of a complete `.csv` file: BOM followed by UTF-8 text.
    public static func fileData(csv: String) -> Data {
        utf8BOM + Data(csv.utf8)
    }
}
