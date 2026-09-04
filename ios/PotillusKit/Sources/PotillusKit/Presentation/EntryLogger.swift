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
//   the reading — the timestamp and the frame it was taken in — and the user's
//   day-change hour. A view that COULD pass its own would eventually pass a wrong
//   one, and a drink logged at 02:00 would stop counting towards the evening it
//   belongs to. Only the facts the user actually chose cross this boundary: which
//   drink, how much, the reading, a note.
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
    /// THE DAY IS NOT A PARAMETER. It used to be, because the sheet offered hours
    /// and minutes and someone had to say which day a bare time belonged to. The
    /// sheet composes the whole reading now, and the repository derives the day
    /// from it, so the only day this can produce is the one the reading falls on.
    ///
    /// - Parameter utcOffsetSeconds: The frame the reading was taken in, as the
    ///   sheet determined it — which is not always the device's current one: an
    ///   edit that leaves the date alone keeps the frame it was recorded in.
    public static func makeEntry(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Int64,
        utcOffsetSeconds: Int,
        note: String,
        settings: AppSettings
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
            logicalDate: DayResolver.resolve(
                timestampMillis: timestampMillis,
                utcOffsetSeconds: utcOffsetSeconds,
                changeHour: settings.dayChangeHour,
                changeMinute: settings.dayChangeMinute
            ),
            note: note,
            utcOffsetSeconds: utcOffsetSeconds
        )
    }

    /// Stores a new entry.
    ///
    /// - Parameters:
    ///   - timestampMillis: The reading the sheet composed; `nil` defaults to now.
    ///   - utcOffsetSeconds: The frame it is read in; `nil` reads the device zone
    ///     for that instant, which is what a caller without a sheet means.
    @discardableResult
    public func log(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Int64? = nil,
        utcOffsetSeconds: Int? = nil,
        note: String = ""
    ) async throws -> ConsumptionEntry {
        let settings = await preferences.load()
        let instant = timestampMillis ?? nowMillis()
        let offset = utcOffsetSeconds ?? DayResolver.utcOffsetSeconds(
            timestampMillis: instant, timeZone: timeZone
        )
        let entry = Self.makeEntry(
            drink: drink,
            volumeMl: volumeMl,
            timestampMillis: instant,
            utcOffsetSeconds: offset,
            note: note,
            settings: settings
        )
        _ = try entries.add(entry, settings: settings)
        return entry
    }

    /// The logical day an entry logged now would belong to, with the day-change
    /// time that defines it — what the entry sheet needs to show the calendar
    /// date a typed time will land on.
    public func todayContext() async -> LoggingDay {
        let settings = await preferences.load()
        return LoggingDay(
            logical: DayResolver.today(
                now: nowMillis(),
                changeHour: settings.dayChangeHour, changeMinute: settings.dayChangeMinute,
                timeZone: timeZone
            ),
            changeHour: settings.dayChangeHour,
            changeMinute: settings.dayChangeMinute
        )
    }
}

/// A tiny observable wrapper, so a screen that only logs does not have to own a
/// whole `TodayModel`.
/// The day an entry logged now belongs to, and the day-change time that decides
/// it. A named value rather than a tuple: three members read badly at the call
/// site, and SwiftLint refuses them.
public struct LoggingDay: Sendable, Equatable {
    public let logical: String
    public let changeHour: Int
    public let changeMinute: Int
}

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

    /// The day the next entry belongs to and the day-change time; refreshed by
    /// `refreshDayContext()` so the sheet can show where a typed time lands.
    public private(set) var logicalDay: String = ""
    public private(set) var dayChangeHour: Int = AppSettings().dayChangeHour
    public private(set) var dayChangeMinute: Int = AppSettings().dayChangeMinute

    public func refreshDayContext() async {
        let day = await logger.todayContext()
        logicalDay = day.logical
        dayChangeHour = day.changeHour
        dayChangeMinute = day.changeMinute
    }

    /// Returns whether the entry was stored, so a sheet can stay open on failure.
    @discardableResult
    public func log(
        drink: DrinkDefinition,
        volumeMl: Int,
        timestampMillis: Int64? = nil,
        utcOffsetSeconds: Int? = nil,
        note: String = ""
    ) async -> Bool {
        failure = nil
        do {
            _ = try await logger.log(
                drink: drink,
                volumeMl: volumeMl,
                timestampMillis: timestampMillis,
                utcOffsetSeconds: utcOffsetSeconds,
                note: note
            )
            return true
        } catch {
            failure = String(describing: error)
            return false
        }
    }

    public func clearFailure() { failure = nil }
}
