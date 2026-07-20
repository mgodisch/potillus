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
import Observation

// =============================================================================
// EntryLogger.swift – the one way an entry comes into existence
// =============================================================================
//
// Two screens log a drink: the Today screen's "+", and a tap on a row of the
// Drinks screen. Both must produce the same entry, and neither may supply the
// derived fields itself.
//
// WHAT IS DERIVED, AND WHY THE CALLER MUST NOT PASS IT
//   `gramsAlcohol` follows from volume and strength; `logicalDate` follows from
//   the timestamp and the user's day-change hour. A view that COULD pass its own
//   would eventually pass a wrong one — and a drink logged at 02:00 would stop
//   counting towards the evening it belongs to. Only the facts the user actually
//   chose (which drink, how much, when, a note) cross this boundary.
// =============================================================================

/// Builds and stores consumption entries.
public struct EntryLogger: Sendable {

    private let entries: any EntryRepositoryProtocol
    private let preferences: any PreferencesStoring
    private let clock: any Clock
    private let timeZone: TimeZone

    public init(
        entries: any EntryRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current
    ) {
        self.entries = entries
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
    }

    /// The current instant in the milliseconds the database stores.
    public func nowMillis() -> Int64 {
        Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
    }

    /// Assembles an entry from what the user chose plus what follows from it.
    ///
    /// Pure: no I/O, so the derivation can be tested without a database.
    ///
    /// - Parameter logicalDate: The day the entry BELONGS TO, `yyyy-MM-dd`. Nil —
    ///   the default, and what the Today screen passes — derives it from
    ///   `timestampMillis` through the user's day-change boundary, which is right
    ///   when the entry is being logged as it happens.
    ///
    ///   The Calendar screen passes a date, because there the two genuinely differ:
    ///   the user picks a day in the past and records a drink they had then, so the
    ///   TIMESTAMP is the moment of typing while the DAY is the one they chose. The
    ///   fields exist separately on `ConsumptionEntry` for exactly this, and Android
    ///   has always used them so — `CalendarViewModel.addEntry` hands the selected
    ///   date to `entryRepo.addFromDrinkWithDate`, and its `updateEntry` documents
    ///   that calendar entries "are deliberately assigned to a specific date that
    ///   may differ from the wall-clock date of the timestamp". iOS could not say
    ///   that until now: the derivation was unconditional, so an entry booked for
    ///   the 12th would have landed on today.
    public static func makeEntry(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Int64,
        note: String,
        settings: AppSettings,
        timeZone: TimeZone,
        logicalDate: String? = nil
    ) -> ConsumptionEntry {
        ConsumptionEntry(
            drinkId: drink.id,
            drinkName: drink.name,
            volumeMl: volumeMl,
            alcoholPercent: drink.alcoholPercent,
            gramsAlcohol: AlcoholCalculator.calculateGrams(
                volumeMl: volumeMl, alcoholPercent: drink.alcoholPercent
            ),
            timestampMillis: timestampMillis,
            logicalDate: logicalDate ?? DayResolver.resolve(
                timestampMillis: timestampMillis,
                changeHour: settings.dayChangeHour,
                changeMinute: settings.dayChangeMinute,
                timeZone: timeZone
            ),
            note: note
        )
    }

    /// Stores a new entry, defaulting the instant to now.
    ///
    /// - Parameter logicalDate: See `makeEntry`. Nil derives the day from the
    ///   instant; the Calendar screen passes the day the user selected.
    @discardableResult
    public func log(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Int64? = nil,
        note: String = "",
        logicalDate: String? = nil
    ) async throws -> ConsumptionEntry {
        let settings = await preferences.load()
        let entry = Self.makeEntry(
            drink: drink,
            volumeMl: volumeMl,
            timestampMillis: timestampMillis ?? nowMillis(),
            note: note,
            settings: settings,
            timeZone: timeZone,
            logicalDate: logicalDate
        )
        _ = try entries.add(entry)
        return entry
    }
}

/// A tiny observable wrapper, so a screen that only logs does not have to own a
/// whole `TodayModel`.
@MainActor
@Observable
public final class EntryLogModel {

    /// Set when the last write failed. Never swallowed; deliberately technical
    /// body — see the content policy on `TodayModel.failure`.
    public private(set) var failure: String?

    private let logger: EntryLogger

    public init(logger: EntryLogger) {
        self.logger = logger
    }

    public convenience init(environment: AppEnvironment, clock: any Clock = SystemClock()) {
        self.init(logger: EntryLogger(
            entries: environment.entries, preferences: environment.preferences, clock: clock
        ))
    }

    /// The instant the sheet should offer as its default.
    public func now() -> Date { Date(timeIntervalSince1970: Double(logger.nowMillis()) / 1000.0) }

    /// Returns whether the entry was stored, so a sheet can stay open on failure.
    @discardableResult
    public func log(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Int64? = nil,
        note: String = "",
        logicalDate: String? = nil
    ) async -> Bool {
        failure = nil
        do {
            _ = try await logger.log(
                drink: drink,
                volumeMl: volumeMl,
                timestampMillis: timestampMillis,
                note: note,
                logicalDate: logicalDate
            )
            return true
        } catch {
            failure = String(describing: error)
            return false
        }
    }

    public func clearFailure() { failure = nil }
}
