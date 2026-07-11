// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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

import PotillusKit
import SwiftUI
import UniformTypeIdentifiers

// =============================================================================
// BackupDocument.swift – handing files to iOS
// =============================================================================
//
// `.fileExporter` and `.fileImporter` present the system's own document browser,
// which is the whole point: the app never sees the file system, asks for no
// permissions, and the user chooses where their data goes. iCloud Drive, a USB
// stick, or nowhere at all.
//
// The bytes are produced by `BackupExporter` in the kit. This wrapper exists only
// because `fileExporter` wants a `FileDocument`.
// =============================================================================

/// A JSON backup, ready to be written wherever the user points.
struct BackupDocument: FileDocument {

    /// `.json`, not a custom UTI. A backup a user cannot open in a text editor is
    /// a backup they cannot verify, and this file is meant to be readable.
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    /// Required by `FileDocument`, and unused: this app only ever WRITES through
    /// the exporter. Reading happens via `.fileImporter`, which hands over a URL
    /// and lets `BackupImporter` parse it.
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// =============================================================================
// CsvDocument
// =============================================================================
//
// The CSV a spreadsheet opens. Separate from `BackupDocument` because it is a
// different content type and a different promise: a backup round-trips, a CSV is
// a one-way report.
// =============================================================================

/// A UTF-8 CSV export, byte-identical to what `CsvExporter.fileData` produced.
struct CsvDocument: FileDocument {

    /// `.commaSeparatedText`, so the system offers Numbers and Excel rather than a
    /// text editor.
    static let readableContentTypes: [UTType] = [.commaSeparatedText]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    /// Never read back by this app; required by the protocol.
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // The bytes already carry the BOM that `CsvExporter.fileData` prepends;
        // adding one here would write it twice and Excel would show it as text.
        FileWrapper(regularFileWithContents: data)
    }
}

// =============================================================================
// PdfDocument
// =============================================================================

/// The finished report, on its way to `fileExporter`.
struct PdfDocument: FileDocument {

    /// `.pdf`, so the system offers Files, Books and Mail rather than a text editor.
    static let readableContentTypes: [UTType] = [.pdf]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    /// Never read back by this app; required by the protocol.
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
