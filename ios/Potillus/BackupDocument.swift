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

import PotillusKit
import SwiftUI
import UniformTypeIdentifiers

// =============================================================================
// BackupDocument.swift – handing the file to iOS
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
