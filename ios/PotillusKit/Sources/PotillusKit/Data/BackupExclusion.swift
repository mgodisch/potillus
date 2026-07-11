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
// BackupExclusion – keeps the consumption log out of the device backup.
//
// "Device backup" deliberately, not "iCloud backup". The one attribute this sets,
// `isExcludedFromBackup`, is defined by Apple as excluding a file from ALL backups
// of app data — both the automatic iCloud backup and the local, encrypted
// Finder/iTunes backup made over a cable. Naming it after iCloud alone would
// understate what it does and mislead a user about the cable path.
//
// Android sets android:allowBackup="false" in its manifest, removing the whole app
// from Google's automatic backup. iOS has no blanket switch: everything in the app
// container is backed up by default, and the counterpart is this per-file value.
//
// WHAT IS PROTECTED, AND WHY ONLY THIS FILE
//   The database `potillus.sqlite` holds the consumption entries — the sensitive,
//   health-adjacent data — alongside the drinks list. Excluding it keeps the log
//   out of every backup. The settings live in a separate `prefs.bin`, encrypted
//   with a `ThisDeviceOnly` key a restored backup cannot decrypt anyway, so they do
//   not need excluding; the drinks list travelling with the database is not a
//   privacy concern. The supported way to move data to a new device stays the JSON
//   backup (Settings → Backup → Export / Import).
//
// WHY THE MARKER, AND WHY RE-APPLY EVERY LAUNCH
//   Apple warns that some file operations reset `isExcludedFromBackup` back to
//   false, and advises re-setting it whenever the file is saved. The database is
//   written constantly, so a once-only set would silently decay. Instead:
//     • `applyPreference` runs at every launch and re-asserts the exclusion, unless
//       the user has opted IN to the backup.
//     • the user's choice lives in a UserDefaults marker, not in the file attribute
//       — a plain "does the user want the log in the backup" boolean, not health
//       data, so UserDefaults is appropriate. This decouples "has the user chosen"
//       from the attribute, which can be reset out from under us.
//
//   SQLite runs in the default rollback-journal mode here (GRDB's DatabaseQueue,
//   not a WAL pool), so there is no persistent `-wal`/`-shm` sidecar — only a
//   transient `-journal` during a write, excluded defensively too.
// =============================================================================

/// Reads and writes the device-backup exclusion on the database file(s), backed by
/// a UserDefaults preference so the choice survives the attribute being reset.
public enum BackupExclusion {

    /// The UserDefaults key holding the user's preference: `true` means "include the
    /// log in the device backup" (opted in). Absent or `false` means excluded, the
    /// privacy-preserving default that matches Android's allowBackup="false".
    static let includeKey = "backup.includeDatabaseInDeviceBackup"

    /// The database file and any transient sidecar that could hold row data.
    private static func files(for databasePath: String) -> [URL] {
        let base = URL(fileURLWithPath: databasePath)
        return [
            base,
            base.deletingPathExtension().appendingPathExtension("sqlite-journal"),
        ]
    }

    /// Whether the user has opted to INCLUDE the log in the device backup. The switch
    /// in Settings reads this; default is `false` (excluded).
    public static func includesInBackup(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: includeKey)
    }

    /// Records the user's choice and applies it to the file immediately. `include:
    /// true` opts into the backup (clears the exclusion); `false` excludes.
    public static func setIncludesInBackup(
        _ include: Bool, databasePath: String, defaults: UserDefaults = .standard
    ) throws {
        defaults.set(include, forKey: includeKey)
        try setExcluded(!include, databasePath: databasePath)
    }

    /// Re-asserts the stored preference on the file. Call at every launch: file
    /// writes can reset `isExcludedFromBackup`, so the exclusion must be renewed, and
    /// the UserDefaults marker is the durable record of what the user wants.
    public static func applyPreference(
        databasePath: String, defaults: UserDefaults = .standard
    ) throws {
        try setExcluded(!includesInBackup(defaults: defaults), databasePath: databasePath)
    }

    /// The raw attribute read, for tests and diagnostics: whether the file itself is
    /// currently marked excluded. The user-facing truth is `includesInBackup`.
    public static func isExcluded(databasePath: String) -> Bool {
        let url = URL(fileURLWithPath: databasePath)
        let values = try? url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values?.isExcludedFromBackup ?? false
    }

    /// Sets the exclusion on the database and its transient journal, if present.
    /// A missing sidecar is not an error — it simply does not exist yet.
    public static func setExcluded(_ excluded: Bool, databasePath: String) throws {
        for url in files(for: databasePath) where FileManager.default.fileExists(atPath: url.path) {
            var mutable = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = excluded
            try mutable.setResourceValues(values)
        }
    }
}
