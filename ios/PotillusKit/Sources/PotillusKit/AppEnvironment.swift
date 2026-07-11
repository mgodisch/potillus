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

import Foundation

// =============================================================================
// AppEnvironment.swift – the composition root
// =============================================================================
//
// One place where the concrete implementations are chosen and wired together.
// Everything downstream — every view model, every screen — receives protocols,
// never constructs a database or a keychain of its own.
//
// WHY THIS LIVES IN THE KIT AND NOT IN THE APP TARGET
//   The app target is not covered by `swift test`. Putting the wiring here means
//   the composition itself can be tested, and an in-memory variant can be handed
//   to a preview or a screenshot run without touching the file system.
//
// This mirrors the role of Android's manual dependency graph: the app assembles
// its dependencies once at launch and passes them down, with no service locator
// and no global singletons that a test would have to fight.
// =============================================================================

/// Everything the UI needs, assembled once at launch.
public struct AppEnvironment: Sendable {

    public let database: AppDatabase
    public let drinks: any DrinkRepositoryProtocol
    public let entries: any EntryRepositoryProtocol
    public let preferences: any PreferencesStoring
    /// "Now", injected. Production uses `SystemClock`; a screenshot run pins it to
    /// a fixed instant so every capture shows the same dated data.
    public let clock: any Clock
    public let importer: BackupImporter

    public init(
        database: AppDatabase,
        drinks: any DrinkRepositoryProtocol,
        entries: any EntryRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock()
    ) {
        self.database = database
        self.drinks = drinks
        self.entries = entries
        self.preferences = preferences
        self.clock = clock
        self.importer = BackupImporter(database: database, preferences: preferences)
    }

    /// The real environment: an on-disk database and a Keychain-backed store.
    public static func makeLive() throws -> AppEnvironment {
        let database = try AppDatabase.makeDefault()
        return AppEnvironment(
            database: database,
            drinks: DrinkRepository(database: database),
            entries: EntryRepository(database: database),
            preferences: try PreferencesStore.makeDefault()
        )
    }

    /// An environment that leaves no trace: an in-memory database and a
    /// preferences file in a temporary directory with an ephemeral key.
    ///
    /// For previews, screenshot runs and tests. The crypto and the SQL are the
    /// real ones; only their storage is disposable.
    public static func makeEphemeral(clock: any Clock = SystemClock()) throws -> AppEnvironment {
        let database = try AppDatabase(inMemory: true)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return AppEnvironment(
            database: database,
            drinks: DrinkRepository(database: database),
            entries: EntryRepository(database: database),
            preferences: PreferencesStore(
                fileURL: directory.appendingPathComponent("prefs.bin"),
                keyProvider: InMemoryKeyProvider()
            ),
            clock: clock
        )
    }
}
