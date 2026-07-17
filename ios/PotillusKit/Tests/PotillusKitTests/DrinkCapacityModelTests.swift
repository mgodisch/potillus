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
// DrinkCapacityModelTests.swift – the snapshot behind the traffic-light dots
// =============================================================================
//
// `DrinkCapacityTests` covers the VALUE (`DrinkCapacity.status(forServing:)`).
// This file covers the MODEL that produces it, and specifically the one thing a
// value test cannot see: that the snapshot follows the clock.
//
// WHY A SEPARATE FILE
//   The existing suite drives `DrinkCapacityModel` nowhere — the dots were only
//   ever tested through the value type they carry. That is precisely how the
//   missing ticker survived the round that added tickers to Today, Statistics
//   and Calendar (0.83.0 QA round): nothing here advanced a clock, so nothing
//   was red.
//
// A real in-memory database and a real preferences store, with only the CLOCK
// frozen — the shape TodayModelTests uses, for the same reason.
// =============================================================================

/// A clock the test can advance while the model's ticker observes it.
///
/// The same shape as TodayModelTests' `SteppingClock`, under its own name rather
/// than a second `SteppingClock`: both would be `private` and Swift would allow
/// it, but `check-swift-symbols` is textual and reads two same-named types as a
/// redeclaration — and a name that has to be explained is worse than a name that
/// does not. `@unchecked Sendable` for the same reason as there: the test drives
/// it serially on the main actor.
private final class AdvancingClock: Clock, @unchecked Sendable {
    var millis: Int64
    init(millis: Int64) { self.millis = millis }
    func now() -> Date { Date(timeIntervalSince1970: Double(millis) / 1000.0) }
}

@MainActor
final class DrinkCapacityModelTests: XCTestCase {

    private var environment: AppEnvironment!

    /// The drink every logged entry points at.
    ///
    /// `entries.drinkId` is a FOREIGN KEY, and `makeEphemeral()` opens an EMPTY
    /// in-memory database — `AppDatabase.openOrCreate` seeds the presets, but
    /// nothing here goes through it. So the row has to exist before an entry can
    /// reference it; there is no id 1 to assume.
    private var drink: DrinkDefinition!

    /// 2026-01-02, 20:14:00 UTC — an evening, well inside the logical day that
    /// began at 04:00 on the 2nd.
    private let evening: Int64 = 1_767_384_840_000

    override func setUpWithError() throws {
        try super.setUpWithError()
        environment = try AppEnvironment.makeEphemeral()
        drink = try addDrink("Beer")
    }

    @discardableResult
    private func addDrink(_ name: String) throws -> DrinkDefinition {
        let id = try environment.drinks.add(
            DrinkDefinition(name: name, volumeMl: 500, alcoholPercent: 5.0)
        )
        return try XCTUnwrap(try environment.drinks.allOnce().first { $0.id == id })
    }

    private func makeModel(clock: any Clock, tickInterval: Duration) -> DrinkCapacityModel {
        DrinkCapacityModel(
            entries: environment.entries,
            preferences: environment.preferences,
            clock: clock,
            timeZone: TimeZone(identifier: "UTC")!,
            tickInterval: tickInterval
        )
    }

    /// Writes one entry on a chosen logical day. The logical date is explicit, so
    /// the timestamp only needs to be plausible. The new row's id is discarded
    /// explicitly: `add` returns it and is not `@discardableResult`, and no test
    /// here needs it.
    private func logDay(_ date: String, grams: Double) throws {
        let noon = try XCTUnwrap(DayResolver.parseDate(date)).addingTimeInterval(12 * 3_600)
        _ = try environment.entries.add(
            ConsumptionEntry(
                drinkId: drink.id,
                drinkName: drink.name,
                volumeMl: drink.volumeMl,
                alcoholPercent: drink.alcoholPercent,
                gramsAlcohol: grams,
                timestampMillis: Int64(noon.timeIntervalSince1970 * 1000),
                logicalDate: date
            )
        )
    }

    // ── The ticker ───────────────────────────────────────────────────────────

    /// The dot answers "how much fits before a limit is crossed", and every
    /// figure behind it is scoped to TODAY. Nothing in the database changes at
    /// the day-change boundary, so without a ticker the Drinks tab kept colouring
    /// its dots against yesterday's grams — and it corrected itself only when the
    /// user logged something, which is after the decision the dot exists to
    /// inform. This pins the fix: ONLY time passes, and the snapshot moves on.
    func testTheTickerRollsTheLogicalDayOverWithoutADatabaseEvent() async throws {
        // 30 g drunk on the 2nd; nothing on the 3rd.
        try logDay("2026-01-02", grams: 30.0)

        let clock = AdvancingClock(millis: evening)
        let model = makeModel(clock: clock, tickInterval: .milliseconds(10))
        model.start()
        defer { model.stop() }

        // While it is still the 2nd, the snapshot carries the 2nd's grams.
        try await waitUntil { model.capacity.todayGrams == 30.0 }

        // Cross the boundary by advancing the clock ALONE: no entry is written,
        // no setting is touched. 2026-01-03, 05:00 UTC is past the 04:00
        // default change hour, so the logical day is now the 3rd — a dry day.
        clock.millis = 1_767_416_400_000
        try await waitUntil { model.capacity.todayGrams == 0.0 }
    }

    /// The weekly window is a function of "now" too, and it is the SECOND figure
    /// the dot depends on. Rolling into the 3rd keeps the 2nd inside the trailing
    /// seven days, so the weekly total must NOT drop with the daily one — the
    /// same tick that clears `todayGrams` must leave `weeklyTotalGrams` alone.
    func testTheWeeklyWindowSurvivesTheRollover() async throws {
        try logDay("2026-01-02", grams: 30.0)

        let clock = AdvancingClock(millis: evening)
        let model = makeModel(clock: clock, tickInterval: .milliseconds(10))
        model.start()
        defer { model.stop() }
        try await waitUntil { model.capacity.todayGrams == 30.0 }

        clock.millis = 1_767_416_400_000  // 2026-01-03, 05:00 UTC
        try await waitUntil { model.capacity.todayGrams == 0.0 }

        let weekly = model.capacity.weeklyTotalGrams
        XCTAssertEqual(weekly, 30.0, accuracy: 1e-9)
        XCTAssertEqual(model.capacity.drinkDaysThisWeek, 1)
    }

    /// The ticker is DAY-KEYED: a tick within the same logical day must not
    /// reload. Asserting "it did not requery" without a spy is not possible here,
    /// so this asserts the observable consequence instead — the snapshot is
    /// stable across many ticks, which is what a reload loop would break by
    /// flickering, and what a wrongly-keyed comparison would turn into a
    /// once-a-minute requery forever.
    func testATickWithinTheSameDayLeavesTheSnapshotAlone() async throws {
        try logDay("2026-01-02", grams: 30.0)

        let clock = AdvancingClock(millis: evening)
        let model = makeModel(clock: clock, tickInterval: .milliseconds(5))
        model.start()
        defer { model.stop() }
        try await waitUntil { model.capacity.todayGrams == 30.0 }

        // Several tick intervals of wall time, and one minute of model time —
        // still the 2nd.
        clock.millis = evening + 60_000
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(model.capacity.todayGrams, 30.0, accuracy: 1e-9)
    }

    /// `stop()` must silence the ticker: a model whose view has gone still holds
    /// a `Task` that would otherwise wake every minute for a screen nobody is
    /// looking at, and — worse — write state after teardown.
    func testStopSilencesTheTicker() async throws {
        try logDay("2026-01-02", grams: 30.0)

        let clock = AdvancingClock(millis: evening)
        let model = makeModel(clock: clock, tickInterval: .milliseconds(5))
        model.start()
        try await waitUntil { model.capacity.todayGrams == 30.0 }
        model.stop()

        // A day boundary crossed AFTER stop() must not move the snapshot.
        clock.millis = 1_767_416_400_000
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(model.capacity.todayGrams, 30.0, accuracy: 1e-9)
    }

    /// Polls until `condition` holds. The ticker runs on wall time, so the test
    /// waits for it rather than guessing an interval; the timeout is what turns a
    /// broken ticker into a named failure instead of a hang.
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
