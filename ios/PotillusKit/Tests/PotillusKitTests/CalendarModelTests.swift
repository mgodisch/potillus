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

import XCTest
@testable import PotillusKit

// =============================================================================
// CalendarModelTests.swift – the grid, and what it must not shift
// =============================================================================
//
// Calendars fail quietly. A leading-blank count that is off by one puts every
// date under the wrong weekday, and nothing crashes. The grid is therefore tested
// against months chosen for their first weekday, in both a Monday-first and a
// Sunday-first locale.
// =============================================================================

@MainActor
final class CalendarModelTests: XCTestCase {

    private var environment: AppEnvironment!

    /// A real drink, because `entries.drinkId` references `drinks.id`. Inserting
    /// an entry against an id that does not exist is refused by the foreign key —
    /// which is the constraint working, not a test-harness inconvenience.
    private var drinkId: Int64 = 0

    /// 2026-01-15, 12:00 UTC — mid-month, so navigation cannot rely on an edge.
    private let midJanuary: Int64 = 1_768_478_400_000

    private let utc = TimeZone(identifier: "UTC")!

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
        drinkId = try environment.drinks.add(
            DrinkDefinition(name: "Pils", volumeMl: 500, alcoholPercent: 4.9, category: .beer)
        )
    }

    // ── Logging onto the selected day ────────────────────────────────────────
    //
    // The point of these: a calendar entry's TIMESTAMP and its LOGICAL DATE are
    // different facts. The user is typing now; the day they are recording is the
    // one they tapped. `EntryLogger` derived the date from the instant
    // unconditionally until 0.83.0, so an entry booked onto the 12th would have
    // landed on today -- silently, and only noticed once the month was reopened.

    func testAnEntryIsBookedOntoTheSelectedDayNotToday() async throws {
        let model = makeModel(at: midJanuary)
        await model.load()
        await model.select("2026-01-12")

        let drink = try XCTUnwrap(environment.drinks.allOnce().first)
        await model.addEntry(drink: drink, volumeMl: 500, timestampMillis: midJanuary)

        let stored = try environment.entries.all()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].logicalDate, "2026-01-12", "the day the user picked")
        XCTAssertEqual(
            stored[0].timestampMillis, midJanuary,
            "the instant the user typed -- deliberately not the selected day"
        )
    }

    /// The selected day is honoured whatever the day-change boundary says: a
    /// calendar square is not subject to a 4 a.m. rollover.
    func testTheDayChangeBoundaryDoesNotMoveACalendarEntry() async throws {
        try await environment.preferences.update { $0.dayChangeHour = 4 }
        let model = makeModel(at: midJanuary)
        await model.load()
        await model.select("2026-01-12")

        // 02:00 on the 15th: before the boundary, so the derivation this replaces
        // would have said "the 14th" -- neither today nor the day chosen.
        let earlyHours = midJanuary - 10 * 3_600_000
        let drink = try XCTUnwrap(environment.drinks.allOnce().first)
        await model.addEntry(drink: drink, volumeMl: 500, timestampMillis: earlyHours)

        let stored = try environment.entries.all()
        XCTAssertEqual(stored[0].logicalDate, "2026-01-12")
    }

    func testAddingWithNoSelectionDoesNothing() async throws {
        let model = makeModel(at: midJanuary)
        await model.load()
        await model.select(nil)

        let drink = try XCTUnwrap(environment.drinks.allOnce().first)
        await model.addEntry(drink: drink, volumeMl: 500, timestampMillis: midJanuary)

        XCTAssertTrue(try environment.entries.all().isEmpty)
    }

    func testTheSelectedDayReflectsTheNewEntryWithoutAReload() async throws {
        let model = makeModel(at: midJanuary)
        await model.load()
        await model.select("2026-01-12")

        let drink = try XCTUnwrap(environment.drinks.allOnce().first)
        await model.addEntry(drink: drink, volumeMl: 500, timestampMillis: midJanuary)

        XCTAssertEqual(model.state.selectedEntries.count, 1)
        XCTAssertGreaterThan(model.state.totalGramsSelected, 0)
    }

    /// The "+" sheet chooses from this, so `load()` has to fill it.
    func testTheCatalogueIsAvailableForTheSheet() async {
        let model = makeModel(at: midJanuary)
        await model.load()
        XCTAssertEqual(model.state.drinks.map(\.name), ["Pils"])
    }

    // ── MonthGrid, the pure part ─────────────────────────────────────────────

    /// 1 January 2026 is a Thursday.
    func testLeadingBlanksInAMondayFirstLocale() {
        let grid = MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: 1)
        XCTAssertEqual(grid.leadingBlanks, 3, "Mon Tue Wed are blank before Thursday")
        XCTAssertEqual(grid.days.count, 31)
        XCTAssertEqual(grid.days.first, "2026-01-01")
        XCTAssertEqual(grid.days.last, "2026-01-31")
    }

    /// The same month, a Sunday-first locale: one more blank.
    func testLeadingBlanksInASundayFirstLocale() {
        let grid = MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: 7)
        XCTAssertEqual(grid.leadingBlanks, 4)
        XCTAssertEqual(grid.weekdayOrder, [7, 1, 2, 3, 4, 5, 6], "Sunday leads")
    }

    /// A month starting on Sunday is where the +7 in the modulo earns its keep:
    /// without it the count would be -6.
    func testAMonthBeginningOnSundayInAMondayFirstLocale() {
        // 1 February 2026 is a Sunday.
        let grid = MonthGrid(year: 2026, month: 2, firstDayOfWeekIso: 1)
        XCTAssertEqual(grid.leadingBlanks, 6)
        XCTAssertEqual(grid.days.count, 28)
    }

    /// The same month with Sunday first: no blanks at all.
    func testAMonthBeginningOnTheWeeksFirstDayHasNoBlanks() {
        let grid = MonthGrid(year: 2026, month: 2, firstDayOfWeekIso: 7)
        XCTAssertEqual(grid.leadingBlanks, 0)
    }

    func testLeapYearFebruaryHasTwentyNineDays() {
        let grid = MonthGrid(year: 2024, month: 2, firstDayOfWeekIso: 1)
        XCTAssertEqual(grid.days.count, 29)
        XCTAssertEqual(grid.days.last, "2024-02-29")
    }

    func testTheGridRoundsUpToWholeWeeks() {
        let grid = MonthGrid(year: 2026, month: 2, firstDayOfWeekIso: 1)
        XCTAssertEqual(grid.cellCount, 35, "6 blanks + 28 days = 34, rounded to 35")
        XCTAssertEqual(grid.cellCount % 7, 0)
    }

    func testWeekdayOrderStartsAtTheLocalesFirstDay() {
        XCTAssertEqual(
            MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: 1).weekdayOrder,
            [1, 2, 3, 4, 5, 6, 7]
        )
        XCTAssertEqual(
            MonthGrid(year: 2026, month: 1, firstDayOfWeekIso: 3).weekdayOrder,
            [3, 4, 5, 6, 7, 1, 2], "Wednesday-first, wrapping past Sunday"
        )
    }

    // ── The model ────────────────────────────────────────────────────────────

    func testTheModelOpensOnTheMonthContainingToday() async {
        let model = makeModel(at: midJanuary)
        await model.load()

        XCTAssertEqual(model.state.year, 2026)
        XCTAssertEqual(model.state.month, 1)
        XCTAssertEqual(model.state.today, "2026-01-15")
    }

    /// A day with no entries is absent from the map, not present with zero. The
    /// view can then distinguish "nothing logged" from "logged nothing".
    func testOnlyDaysWithEntriesHaveSummaries() async throws {
        try addEntry(on: "2026-01-10", grams: 19.3, at: midJanuary)

        let model = makeModel(at: midJanuary)
        await model.load()

        XCTAssertEqual(model.state.summaries.count, 1)
        XCTAssertEqual(model.state.summaries["2026-01-10"]?.totalGrams ?? 0, 19.3, accuracy: 1e-9)
        XCTAssertNil(model.state.summaries["2026-01-11"])
    }

    /// Summaries stop at the month's edge, or January would colour December's days.
    func testSummariesAreConfinedToTheVisibleMonth() async throws {
        try addEntry(on: "2025-12-31", grams: 40.0, at: midJanuary)
        try addEntry(on: "2026-01-01", grams: 10.0, at: midJanuary)
        try addEntry(on: "2026-02-01", grams: 50.0, at: midJanuary)

        let model = makeModel(at: midJanuary)
        await model.load()

        XCTAssertEqual(Set(model.state.summaries.keys), ["2026-01-01"])
    }

    // ── Navigation: integers, not dates ──────────────────────────────────────

    func testSteppingBackFromJanuaryLandsInTheDecemberBefore() async {
        let model = makeModel(at: midJanuary)
        await model.load()
        await model.previousMonth()

        XCTAssertEqual(model.state.year, 2025)
        XCTAssertEqual(model.state.month, 12)
        XCTAssertEqual(model.state.grid.days.count, 31)
    }

    func testSteppingForwardFromDecemberLandsInTheJanuaryAfter() async {
        let model = makeModel(at: midJanuary)
        await model.load()
        for _ in 0..<11 { await model.nextMonth() }   // to December 2026
        XCTAssertEqual(model.state.month, 12)

        await model.nextMonth()
        XCTAssertEqual(model.state.year, 2027)
        XCTAssertEqual(model.state.month, 1)
    }

    /// A selection belongs to the month it was made in.
    func testNavigatingAwayClearsTheSelection() async throws {
        try addEntry(on: "2026-01-10", grams: 19.3, at: midJanuary)
        let model = makeModel(at: midJanuary)
        await model.load()

        await model.select("2026-01-10")
        XCTAssertEqual(model.state.selectedEntries.count, 1)

        await model.nextMonth()
        XCTAssertNil(model.state.selectedDate)
        XCTAssertTrue(model.state.selectedEntries.isEmpty)
    }

    // ── Selection ────────────────────────────────────────────────────────────

    func testSelectingADayLoadsItsEntriesAndTotal() async throws {
        try addEntry(on: "2026-01-10", grams: 19.3, at: midJanuary)
        try addEntry(on: "2026-01-10", grams: 20.5, at: midJanuary + 1)
        try addEntry(on: "2026-01-11", grams: 99.0, at: midJanuary + 2)

        let model = makeModel(at: midJanuary)
        await model.load()
        await model.select("2026-01-10")

        XCTAssertEqual(model.state.selectedEntries.count, 2)
        XCTAssertEqual(model.state.totalGramsSelected, 39.8, accuracy: 1e-9)
    }

    func testSelectingTheSameDayTwiceKeepsItSelected() async throws {
        try addEntry(on: "2026-01-10", grams: 19.3, at: midJanuary)
        let model = makeModel(at: midJanuary)
        await model.load()

        await model.select("2026-01-10")
        await model.select("2026-01-10")

        // Non-toggling, like Android: a second tap does not deselect. The entries
        // stay visible instead of flickering away.
        XCTAssertEqual(model.state.selectedDate, "2026-01-10")
        XCTAssertFalse(model.state.selectedEntries.isEmpty)
        XCTAssertEqual(model.state.totalGramsSelected, 19.3, accuracy: 1e-9)
    }

    // ── Over-limit marking ───────────────────────────────────────────────────

    func testADayOverTheDailyLimitIsMarked() async throws {
        try await environment.preferences.update { $0.dailyLimitGrams = 20.0 }
        try addEntry(on: "2026-01-10", grams: 25.0, at: midJanuary)
        try addEntry(on: "2026-01-11", grams: 10.0, at: midJanuary + 1)

        let model = makeModel(at: midJanuary)
        await model.load()

        XCTAssertTrue(model.isOverLimit("2026-01-10"))
        XCTAssertFalse(model.isOverLimit("2026-01-11"))
        XCTAssertFalse(model.isOverLimit("2026-01-12"), "a day with no entries is not over")
    }

    /// Deleting the last entry of a day must remove its summary, not leave a
    /// coloured cell behind.
    func testDeletingTheLastEntryOfADayRemovesItsSummary() async throws {
        try addEntry(on: "2026-01-10", grams: 19.3, at: midJanuary)
        let model = makeModel(at: midJanuary)
        await model.load()
        await model.select("2026-01-10")

        let entry = try XCTUnwrap(model.state.selectedEntries.first)
        await model.deleteEntry(entry)

        XCTAssertNil(model.state.summaries["2026-01-10"])
        XCTAssertNil(model.failure)
    }

    // ── The month is live ────────────────────────────────────────────────────
    //
    // The calendar used to load on `.task` and never again. A backup imported while
    // it sat in another tab left the month showing its old dots. It observes now,
    // reloading the CURRENT month whatever the change was.

    /// `start()` loads the visible month without a separate `load()`.
    func testStartLoadsTheMonth() async throws {
        try addEntry(on: "2026-01-10", grams: 12.0, at: midJanuary)

        let model = makeModel(at: midJanuary)
        await model.start()
        defer { model.stop() }

        try await waitUntil { model.state.summaries["2026-01-10"] != nil }
    }

    /// An entry added after `start()` reaches the visible month.
    func testAnEntryAppearsInTheVisibleMonth() async throws {
        let model = makeModel(at: midJanuary)
        await model.start()
        defer { model.stop() }

        try await waitUntil { model.state.summaries.isEmpty }

        try addEntry(on: "2026-01-20", grams: 8.0, at: midJanuary)
        try await waitUntil { model.state.summaries["2026-01-20"] != nil }
    }

    /// The case that decides the design: a second entry on a day that already has
    /// one leaves `SELECT DISTINCT logicalDate` unchanged, and the dot must still
    /// update. GRDB fires on the write regardless.
    func testASecondEntryOnAnExistingDayUpdatesTheDot() async throws {
        try addEntry(on: "2026-01-10", grams: 12.0, at: midJanuary)

        let model = makeModel(at: midJanuary)
        await model.start()
        defer { model.stop() }

        try await waitUntil {
            (model.state.summaries["2026-01-10"]?.totalGrams ?? 0) == 12.0
        }

        try addEntry(on: "2026-01-10", grams: 8.0, at: midJanuary)
        try await waitUntil {
            (model.state.summaries["2026-01-10"]?.totalGrams ?? 0) == 20.0
        }
    }

    /// After paging to another month, the observation reloads THAT month, not the
    /// one that was showing when `start()` ran.
    func testObservationFollowsThePagedMonth() async throws {
        let model = makeModel(at: midJanuary)
        await model.start()
        defer { model.stop() }

        try await waitUntil { model.state.month == 1 }
        await model.nextMonth()
        try await waitUntil { model.state.month == 2 }

        try addEntry(on: "2026-02-14", grams: 30.0, at: midJanuary)
        try await waitUntil { model.state.summaries["2026-02-14"] != nil }
    }

    /// A stopped model observes nothing.
    func testStopEndsTheSubscription() async throws {
        let model = makeModel(at: midJanuary)
        await model.start()
        try await waitUntil { model.state.summaries.isEmpty }
        model.stop()

        try addEntry(on: "2026-01-15", grams: 42.0, at: midJanuary)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(model.state.summaries["2026-01-15"], "a stopped observation still fired")
    }
}

// Fixtures live in an extension, as in TodayModelTests: SwiftLint's
// `type_body_length` counts only the class body, and a test class should earn
// its length from tests, not fixtures.
extension CalendarModelTests {

    private func makeModel(at millis: Int64, firstDayOfWeekIso: Int = 1) -> CalendarModel {
        CalendarModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences,
            clock: FixedClock(millis: millis),
            timeZone: utc,
            firstDayOfWeekIso: firstDayOfWeekIso
        )
    }

    @discardableResult
    private func addEntry(on date: String, grams: Double, at millis: Int64) throws -> Int64 {
        try environment.entries.add(
            ConsumptionEntry(
                drinkId: drinkId, drinkName: "Pils", volumeMl: 500, alcoholPercent: 4.9,
                gramsAlcohol: grams, timestampMillis: millis, logicalDate: date
            )
        )
    }

    /// Polls the main actor until `condition` holds. The observation is a stream, so
    /// there is no completion to await; a fixed sleep would be flaky.
    private func waitUntil(
        timeout: TimeInterval = 2.0, _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("condition not met within \(timeout) s")
    }
}
