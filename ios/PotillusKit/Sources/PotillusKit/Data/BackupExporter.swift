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
// BackupExporter.swift – the whole of the user's data, as one file
// =============================================================================
//
// The JSON backup is the ONLY route between Android and iOS. Room writes a
// `room_master_table`, GRDB a `grdb_migrations`; a copied `.db` would be refused
// by the other platform. So this file must be byte-for-byte acceptable to the
// Android reader, and `BackupWriter.makeJSON` — already tested against the real Android
// demo backup — decides how it is written. This type only decides WHAT goes in.
//
// EVERYTHING, INCLUDING THE PRESETS
//   The export carries every drink, presets included. It would be tempting to
//   omit them, since the importer recreates them anyway — but a preset the user
//   renamed or re-categorised is no longer the preset the other app ships, and
//   dropping it would silently discard that edit.
//
// SETTINGS ARE OPTIONAL, AND ASKED FOR
//   A backup shared with someone else should not carry a body weight. The caller
//   decides; the default is to include them, because the common case is the user
//   moving their own data to their own new phone.
// =============================================================================

/// Assembles a `BackupFile` from the live stores.
public struct BackupExporter: Sendable {

    private let drinks: any DrinkRepositoryProtocol
    private let entries: any EntryRepositoryProtocol
    private let preferences: any PreferencesStoring

    public init(
        drinks: any DrinkRepositoryProtocol,
        entries: any EntryRepositoryProtocol,
        preferences: any PreferencesStoring
    ) {
        self.drinks = drinks
        self.entries = entries
        self.preferences = preferences
    }

    /// Reads everything and returns the file's bytes.
    ///
    /// - Parameter includeSettings: When false, the `settings` key is omitted
    ///   entirely rather than emitted with defaults. An absent key means "the
    ///   importer should leave my settings alone"; a defaulted one would overwrite
    ///   them with someone else's.
    public func makeBackup(includeSettings: Bool = true) async throws -> Data {
        let allDrinks = try drinks.allOnce()
        let allEntries = try entries.all()

        let settings: BackupSettings? = includeSettings
            ? Self.backupSettings(from: await preferences.load())
            : nil

        return try BackupWriter.makeJSON(
            BackupFile(
                exportedAt: Self.timestamp(),
                drinks: allDrinks,
                entries: allEntries,
                settings: settings
            )
        )
    }

    /// The instant of export, as Kotlin's `Instant.toString()` writes it: UTC,
    /// RFC 3339, with a trailing `Z`.
    ///
    /// The reader treats this as an opaque string and never parses it, so the
    /// exact precision does not matter — but a human opening the file should read
    /// the same shape on both platforms.
    static func timestamp(now: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: now)
    }

    /// The file name Android writes: `potillus_backup_yyyyMMdd_HHmm.json`.
    ///
    /// Copied exactly, underscores and all, so a user with both phones sees one
    /// convention and their backups sort together in the Files app.
    ///
    /// The stamp is LOCAL wall-clock time, unlike `exportedAt` inside the file.
    /// That is Android's choice and it is the right one: the file lands among the
    /// user's documents, and they will look for "the backup from Friday evening",
    /// not for a UTC instant.
    public static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return "potillus_backup_\(formatter.string(from: now)).json"
    }

    /// `AppSettings` as the file format spells it.
    ///
    /// A plain field-by-field copy, save for `themeMode`, which the app holds as an
    /// enum and the file as a string. It lives here rather than on `AppSettings`
    /// because the domain should not know the backup format exists.
    static func backupSettings(from settings: AppSettings) -> BackupSettings {
        BackupSettings(
            themeMode: settings.themeMode.rawValue,
            dayChangeHour: settings.dayChangeHour,
            dayChangeMinute: settings.dayChangeMinute,
            dailyLimitGrams: settings.dailyLimitGrams,
            weeklyLimitGrams: settings.weeklyLimitGrams,
            maxDrinkDaysPerWeek: settings.maxDrinkDaysPerWeek,
            statsFromDate: settings.statsFromDate,
            biometricEnabled: settings.biometricEnabled,
            allowScreenshots: settings.allowScreenshots,
            alternativeStatusSymbols: settings.alternativeStatusSymbols,
            language: settings.language,
            weightKg: settings.weightKg
        )
    }
}
