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
// CalendarModel.swift – a month of logical days
// =============================================================================
//
// The counterpart of Android's `CalendarViewModel`, month view only. The YEAR
// view is deliberately absent: it is a second layout over the same summaries, and
// it arrives with the Statistics screen, which already owns per-month aggregation.
//
// THE MONTH IS NOT AN INSTANT
//   A cell is a logical day — the string "2026-01-02" — because that is what the
//   entries carry. Navigating months therefore moves integers, never dates, and
//   no time zone or DST transition can shift the grid relative to its contents.
//   Only "today" is read from the clock, once.
// =============================================================================

/// What the calendar screen shows.
public struct CalendarState: Sendable, Equatable {

    public var year: Int = 0
    public var month: Int = 0

    /// The grid: days, leading blanks, weekday headers.
    public var grid = MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: 1)

    /// Summaries for the visible month, keyed by logical date. A day with no
    /// entries is absent, not zero.
    public var summaries: [String: DaySummary] = [:]

    /// Today's logical date, for the "today" ring.
    public var today: String = ""

    /// The day the user tapped, if any.
    public var selectedDate: String?

    /// Entries of the selected day, oldest first.
    public var selectedEntries: [ConsumptionEntry] = []

    /// Their grams, summed.
    public var totalGramsSelected: Double = 0.0

    /// The drink catalogue, for the "+" sheet. Held here rather than fetched when
    /// the sheet opens, so it is already warm and stays live with the catalogue —
    /// the same arrangement TodayState has.
    public var drinks: [DrinkDefinition] = []

    public var limitInfo: LimitInfo = AlcoholCalculator.getLimitInfo(AppSettings())

    public init() {}
}

@MainActor
@Observable
public final class CalendarModel {

    public private(set) var state = CalendarState()
    public private(set) var failure: String?

    private let entries: any EntryRepositoryProtocol
    private let drinks: any DrinkRepositoryProtocol
    private let preferences: any PreferencesStoring
    private let clock: any Clock
    private let timeZone: TimeZone
    private let firstDayOfWeekIso: Int

    /// How long the ticker in `start()` sleeps between day checks. 60 seconds,
    /// Android's `TICK_INTERVAL_MS`; see `TodayModel.tickInterval` for the full
    /// rationale. Injectable so a test can tick in milliseconds.
    private let tickInterval: Duration

    /// The live subscriptions, torn down by `stop()`.
    private var observations: [Task<Void, Never>] = []

    public init(
        entries: any EntryRepositoryProtocol,
        drinks: any DrinkRepositoryProtocol,
        preferences: any PreferencesStoring,
        clock: any Clock = SystemClock(),
        timeZone: TimeZone = .current,
        firstDayOfWeekIso: Int = DayResolver.firstDayOfWeekIso(),
        tickInterval: Duration = .seconds(60)
    ) {
        self.entries = entries
        self.drinks = drinks
        self.preferences = preferences
        self.clock = clock
        self.timeZone = timeZone
        self.firstDayOfWeekIso = firstDayOfWeekIso
        self.tickInterval = tickInterval
    }

    // ── Loading ──────────────────────────────────────────────────────────────

    /// Loads the month containing today, unless a month is already shown.
    public func load() async {
        let settings = await preferences.load()
        let nowMillis = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        let today = DayResolver.resolve(
            timestampMillis: nowMillis,
            changeHour: settings.dayChangeHour,
            changeMinute: settings.dayChangeMinute,
            timeZone: timeZone
        )

        state.today = today
        state.limitInfo = AlcoholCalculator.getLimitInfo(settings)
        state.drinks = (try? drinks.allOnce()) ?? []

        if state.year == 0 {
            // "2026-01-02" — parsed as integers, not as a date.
            let parts = today.split(separator: "-").compactMap { Int($0) }
            state.year = parts.count == 3 ? parts[0] : 2026
            state.month = parts.count == 3 ? parts[1] : 1
        }
        await reloadMonth()
    }

    /// Fetches the visible month's summaries and re-reads the selection.
    private func reloadMonth() async {
        state.grid = MonthGrid(
            year: state.year, month: state.month, firstDayOfWeekIso: firstDayOfWeekIso
        )
        guard let range = state.grid.range else { return }

        do {
            let summaries = try entries.dailySummaries(from: range.from, to: range.to)
            state.summaries = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })
            try reloadSelection()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    private func reloadSelection() throws {
        guard let date = state.selectedDate else {
            state.selectedEntries = []
            state.totalGramsSelected = 0.0
            return
        }
        let dayEntries = try entries.inRange(from: date, to: date)
        state.selectedEntries = dayEntries
        state.totalGramsSelected = dayEntries.reduce(0.0) { $0 + $1.gramsAlcohol }
    }

    // ── Observation ──────────────────────────────────────────────────────────
    //
    // The calendar observes the SAME triggers as the statistics screen — the set of
    // logged dates and the settings — but reloads the CURRENT month rather than a
    // fixed window. The month changes underfoot when the user pages, so the stream
    // must not carry a range: it carries the fact that something changed, and
    // `reloadMonth()` reads whichever month is on screen when it fires.
    //
    // `observeDailySummaries(from:to:)` would tie the stream to one month and would
    // have to be resubscribed on every page turn. `observeAllDates()` is month-blind
    // and fires on every entry write — including a second entry on a day that
    // already has one, where the DISTINCT date list is unchanged but GRDB notifies
    // anyway (it does not remove duplicates unless asked). One subscription, correct
    // across paging.
    //
    // Without this, a backup imported while the calendar sat in another tab left the
    // month showing the dots it had before the import, with nothing to say so.

    /// Loads once, then subscribes. Safe to call again; the previous subscriptions
    /// are cancelled first.
    ///
    /// Unlike `StatsModel`, this calls `load()` up front rather than leaning on the
    /// first emission: `load()` resolves today and seeds `state.year`/`state.month`,
    /// which `reloadMonth()` needs before it can pick a month. The entry stream then
    /// drives `reloadMonth()` — the grid, not the whole model — and the settings
    /// stream drives `load()`, because a changed day-boundary moves what today is.
    public func start() async {
        stop()
        await load()

        observations = [
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await _ in self.entries.observeAllDates() {
                        // The stream may deliver one more element between stop()
                        // cancelling this task and the underlying observation
                        // tearing down (they cancel asynchronously). Without this
                        // check that late element would still write state — the
                        // "a stopped observation still fired" the tests guard.
                        if Task.isCancelled { break }
                        await self.reloadMonth()
                    }
                } catch {
                    self.failure = String(describing: error)
                }
            },
            Task { [weak self] in
                guard let self else { return }
                for await _ in await self.preferences.observe() {
                    if Task.isCancelled { break }
                    await self.load()
                }
            },
            // The catalogue: the "+" sheet chooses from it, so a drink added or
            // renamed on the Drinks screen must be there the next time the sheet
            // opens, without the calendar being left and re-entered. Same
            // late-element guard as above.
            Task { [weak self] in
                guard let self else { return }
                do {
                    for try await catalogue in self.drinks.observeDrinks() {
                        if Task.isCancelled { break }
                        self.state.drinks = catalogue
                    }
                } catch {
                    self.failure = String(describing: error)
                }
            },
            // The ticker. Day-keyed like StatsModel's (see there): the grid's
            // "today" highlight — and, while the user has not paged away, the
            // shown month — must follow the logical day across the day-change
            // time even when no entry is written. `load()` is safe to call
            // from here: it re-derives today and touches `state.year/month`
            // only while they are unset, so a user browsing another month is
            // not yanked back (its own doc: "unless a month is already shown").
            Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: self.tickInterval)
                    if Task.isCancelled { break }
                    let settings = await self.preferences.load()
                    let nowMillis = Int64((self.clock.now().timeIntervalSince1970 * 1000).rounded())
                    let today = DayResolver.resolve(
                        timestampMillis: nowMillis,
                        changeHour: settings.dayChangeHour,
                        changeMinute: settings.dayChangeMinute,
                        timeZone: self.timeZone
                    )
                    if today != self.state.today { await self.load() }
                }
            }
        ]
    }

    public func stop() {
        observations.forEach { $0.cancel() }
        observations = []
    }

    // ── Navigation ───────────────────────────────────────────────────────────

    /// Integer arithmetic, so December → January cannot go wrong.
    public func previousMonth() async {
        if state.month == 1 {
            state.month = 12
            state.year -= 1
        } else {
            state.month -= 1
        }
        clearSelection()
        await reloadMonth()
    }

    public func nextMonth() async {
        if state.month == 12 {
            state.month = 1
            state.year += 1
        } else {
            state.month += 1
        }
        clearSelection()
        await reloadMonth()
    }

    /// A selection belongs to the month it was made in; carrying it across would
    /// show January's entries under a February heading.
    private func clearSelection() {
        state.selectedDate = nil
        state.selectedEntries = []
        state.totalGramsSelected = 0.0
    }

    // ── Selection ────────────────────────────────────────────────────────────

    /// Selects `date` (or clears the selection when passed `nil`).
    ///
    /// Non-toggling, matching Android's `selectDate`: tapping the already
    /// selected day KEEPS it selected. iOS used to toggle here — a second tap
    /// deselected and hid the day's entries — which a platform switcher reads
    /// as the entries flickering away (0.83.0 UI-parity pass). To clear the
    /// selection, pass `nil` (the month-change paths already do).
    public func select(_ date: String?) async {
        state.selectedDate = date
        do {
            try reloadSelection()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    /// Logs a drink on the SELECTED day, timestamped now.
    ///
    /// The two are deliberately different facts. The instant is when the user
    /// typed; the logical date is the day they picked and are recording for. The
    /// Today screen never needs the distinction — there the day follows from the
    /// instant — but a calendar exists to book a day that is not today, so it
    /// hands `EntryLogger` an explicit `logicalDate` rather than letting it derive
    /// one and land the entry on the wrong day. Android has always drawn this line:
    /// its `CalendarViewModel.addEntry` passes the selected date to
    /// `addFromDrinkWithDate`, and its `updateEntry` documents that calendar
    /// entries "are deliberately assigned to a specific date that may differ from
    /// the wall-clock date of the timestamp".
    ///
    /// The day-change boundary is therefore NOT applied: the user chose a calendar
    /// square, and a square is not subject to a 4 a.m. rollover.
    ///
    /// Does nothing when no day is selected. The "+" only appears once one is, so
    /// this is a guard against a future caller, not a state the UI can reach.
    ///
    /// - Parameters:
    ///   - drink:           The catalogue drink consumed.
    ///   - volumeMl:        Serving volume in millilitres.
    ///   - timestampMillis: The instant, as the sheet returned it — it defaults to
    ///     the moment of typing and the user may adjust it. Taken from the caller
    ///     rather than read off `clock` here, exactly as Android's
    ///     `CalendarViewModel.addEntry` takes it from its dialog.
    ///   - note:            Optional free text.
    public func addEntry(
        drink: DrinkDefinition, volumeMl: Int, timestampMillis: Int64, note: String = ""
    ) async {
        guard let date = state.selectedDate else { return }
        // Loaded, not read off `state`: CalendarState carries no settings, unlike
        // TodayState. They are needed only to satisfy `makeEntry`'s signature here
        // — the day-change fields it would read are bypassed by `logicalDate`.
        let settings = await preferences.load()
        let entry = EntryLogger.makeEntry(
            drink: drink,
            volumeMl: volumeMl,
            timestampMillis: timestampMillis,
            note: note,
            settings: settings,
            timeZone: timeZone,
            logicalDate: date
        )
        do {
            _ = try entries.add(entry)
        } catch {
            failure = String(describing: error)
            return
        }
        await reloadMonth()
    }

    public func deleteEntry(_ entry: ConsumptionEntry) async {
        do {
            try entries.delete(entry)
        } catch {
            failure = String(describing: error)
            return
        }
        await reloadMonth()
    }

    /// Applies an edited entry, then reloads the month so both the grid summary
    /// and the selected-day list reflect the change. The entry keeps its `id`
    /// and `logicalDate`, so editing volume/percent/time/note updates the row
    /// in place — the same contract as Android's `updateEntry`, which the
    /// repository's `update` preserves.
    public func updateEntry(_ entry: ConsumptionEntry) async {
        do {
            try entries.update(entry)
        } catch {
            failure = String(describing: error)
            return
        }
        await reloadMonth()
    }

    /// Whether a day exceeded the daily limit. Absent days are not over.
    public func isOverLimit(_ date: String) -> Bool {
        guard let summary = state.summaries[date] else { return false }
        return AlcoholCalculator.isOverLimit(
            totalGrams: summary.totalGrams, limitGrams: state.limitInfo.limitGrams
        )
    }
}
