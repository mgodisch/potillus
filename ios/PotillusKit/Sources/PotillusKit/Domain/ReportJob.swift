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
// ReportJob – what the exported file is called
// =============================================================================
//
// Android names its print job `potillus_report_20260603_1430.pdf`, and the print
// dialog offers that name verbatim as the default file name. The suffix is spelled
// out for the same reason there: without it the dialog showed a bare stem that
// looked unfinished and hid the file type.
//
// The whole of this file is one function, and it lives in the kit rather than
// beside the printer because it is the only part of exporting a PDF that can be
// tested without a screen.
// =============================================================================

public enum ReportJob {

    /// `potillus_report_yyyyMMdd_HHmm.pdf`, in `timeZone`'s wall clock.
    ///
    /// The formatter is pinned to `en_US_POSIX`. A locale-aware one would honour a
    /// Japanese calendar and name the file `potillus_report_00080603_1430.pdf`, and
    /// an Arabic one would write the digits in Eastern Arabic numerals — neither of
    /// which sorts, and one of which is not even the same year.
    public static func fileName(date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return "potillus_report_\(formatter.string(from: date)).pdf"
    }

    /// Whether `data` is structurally a PDF: it begins `%PDF-` and ends `%%EOF`.
    ///
    /// This is not a validator. It answers one question, and the question is not
    /// academic: `UIGraphicsEndPDFContext` writes the cross-reference table and the
    /// `%%EOF` marker, so a buffer read BEFORE the context was closed carries a
    /// perfectly good header, real page objects, and no ending. Every reader calls
    /// such a file corrupt, and it is the exact shape of the bug that shipped in
    /// patch -59.
    ///
    /// It lives here, in the kit, because it is the last thing about exporting a PDF
    /// that can be tested without a screen.
    public static func isWellFormed(_ data: Data) -> Bool {
        guard data.count > 8, data.starts(with: Array("%PDF-".utf8)) else { return false }

        // The trailer may be followed by a newline or two, so look near the end
        // rather than demanding the very last byte.
        return data.suffix(32).range(of: Data("%%EOF".utf8)) != nil
    }
}
