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
// AlcoholCalculator.swift – Pharmacokinetic helper functions
// =============================================================================
//
// A faithful Swift port of the Android `domain/AlcoholCalculator.kt`. Every
// formula, constant, guard, and rounding rule matches the Kotlin original, and
// the shared golden vectors in `test-vectors/alcohol-calculator.json` are
// asserted against BOTH implementations so they cannot drift apart.
//
// WIDMARK FORMULA (Erik Widmark, 1932):
//   One dose raises the blood alcohol concentration by
//
//       ΔBAC [‰] = A / (P × r)
//
//   and elimination removes β ‰ per hour while alcohol is present.
//
//   A = grams of pure alcohol in the dose
//   P = body weight in kilograms
//   r = distribution coefficient (fixed at 0.6; see `widmarkR`)
//   β = elimination rate ≈ 0.15 ‰ per hour (population average)
//
// WHY DOSE BY DOSE AND NOT ONE LUMPED SUBTRACTION
//   The textbook shorthand sums every dose of a session and subtracts
//   β × (now − first dose). That form holds only while the concentration stays
//   above zero for the whole span. Across a dry afternoon between two rounds it
//   keeps subtracting from a level that is already zero and carries the deficit
//   into the evening: 40 g at noon and 40 g at ten, asked at eleven, came out at
//   0.25 ‰ where the second round alone stands at 0.80 ‰. The error pointed the
//   unsafe way and grew with the length of the gap.
//
//   `calculateBAC` therefore walks the doses in time order, eliminates over each
//   interval, clamps the level at zero before adding the next dose, and
//   eliminates once more up to the moment asked about. An unbroken session
//   yields exactly the lumped figure; a split one yields the higher, correct one.
//
// WHY A FIXED r = 0.6 (NOT PER-SEX)?
//   The app does not store the user's sex. To keep the readout honest as a
//   *worst-case* estimate, r is fixed at the smaller of the two classic Widmark
//   coefficients (0.6, historically used for women). A smaller r divides the
//   dose by a smaller distribution volume and therefore yields the HIGHER BAC —
//   the conservative choice for a safety-oriented display.
//
// LIMITATIONS:
//   The formula is a statistical model. Real BAC varies with food intake, liver
//   enzyme activity, age, and other individual factors. The app shows a
//   disclaimer and never implies the estimate is exact.
//
// SWIFT `enum` AS A NAMESPACE:
//   Kotlin's `object AlcoholCalculator` is a singleton. Swift has no direct
//   equivalent, so the idiomatic substitute is a caseless `enum`: it groups
//   static members, and — having no cases — it cannot be instantiated. This is
//   preferred over a `struct` with a private `init` because the compiler
//   enforces non-instantiability for free.
// =============================================================================

public enum AlcoholCalculator {

    // ── Physical and clinical constants ──────────────────────────────────────

    /// Density of ethanol in g/ml (CRC Handbook).
    public static let ethanolDensity = 0.789

    /// Binge-drinking threshold in grams of pure alcohol.
    ///
    /// 60 g is the figure the WHO uses for heavy episodic drinking. That
    /// indicator is sex-neutral — reported broken down by sex, not defined per
    /// sex — so it fits an app that does not store the user's sex. The NIAAA
    /// thresholds are a different measure: sex-specific and counted in US
    /// standard drinks of 14 g, which puts them near 56 g and 70 g rather than
    /// at 60 g.
    ///
    /// ONE LIMIT OF THE READING: the WHO counts per OCCASION, the report counts
    /// per logical day. A day is not an occasion, least of all with a
    /// user-chosen day-change time, so the figure is the count of days above the
    /// threshold rather than a count of WHO episodes.
    public static let bingeThreshold = 60.0

    /// Length of the gliding consumption window, in days (today plus the six
    /// preceding calendar days).
    public static let windowDays = 7

    /// Comparison tolerance for gram-vs-limit checks.
    ///
    /// All gram amounts enter the system rounded to 0.1 g (`calculateGrams`), but
    /// day and window totals are built by summing binary `Double`s — in the
    /// sliding window of `countLimitViolations` even incrementally (add on entry,
    /// subtract on eviction). Binary floating point cannot represent most
    /// multiples of 0.1 exactly, so a total that is EXACTLY at the limit can
    /// accumulate to, say, 190.60000000000002, and a strict `>` would flag an
    /// exceedance the user cannot see. That would break the app-wide principle
    /// that the displayed number IS the compared number.
    ///
    /// 1e-6 g is three orders of magnitude below the 0.1 g data grid, so the
    /// tolerance can never absorb a REAL exceedance (the smallest possible one is
    /// 0.1 g) while comfortably exceeding any drift a realistic history can
    /// accumulate.
    private static let limitEpsilon = 1e-6

    /// Whether `totalGrams` exceeds `limitGrams`, tolerating floating-point drift
    /// at the exact boundary (see `limitEpsilon`).
    ///
    /// This is the SINGLE definition of "over the limit", so a total that reads
    /// "100.0 g" against a 100 g limit is consistently AT the limit, never over
    /// it, on every surface. Reaching the limit exactly is allowed: the limit is
    /// what the user may consume.
    public static func isOverLimit(totalGrams: Double, limitGrams: Double) -> Bool {
        totalGrams > limitGrams + limitEpsilon
    }

    /// Whether a day whose entries sum to `totalGrams` counts as a drink day.
    ///
    /// This is the SINGLE definition of "drink day". A day is a drink day when
    /// alcohol was consumed on it — not when something was logged on it. A day
    /// holding nothing but alcohol-free entries (a 0.0 % beer sums to 0.0 g) is
    /// a dry day: it stays out of the drink-day counts, it does not end an
    /// abstinence streak, and it is not deducted from the abstinent days.
    ///
    /// **Why a named predicate.** The comparison used to be written out at some
    /// call sites and replaced by "a summary row exists for this date" at
    /// others, which is a different question — one the database answers with a
    /// row for every logged entry, alcohol-free ones included. The two answers
    /// disagreed on exactly the days that matter to someone abstaining.
    ///
    /// **No epsilon, unlike `isOverLimit`.** This compares against zero, not
    /// against a user-set limit, and `calculateGrams` rounds to the 0.1 g grid,
    /// so the smallest non-zero value it can produce is 0.1 g. There is no drift
    /// to absorb.
    ///
    /// The SQL twin lives in `EntryRepository.drinkDates()`; the two must stay
    /// in step. Pinned against Android by `test-vectors/alcohol-calculator.json`.
    public static func isDrinkDay(totalGrams: Double) -> Bool {
        totalGrams > 0.0
    }

    /// The dates of the drink days in `summaries`, ascending.
    ///
    /// The list shape the abstinence streaks expect (see
    /// `DayResolver.computeCurrentAbstinence`), and the list whose count is the
    /// drink-day figure. Days without alcohol are dropped by `isDrinkDay`, so
    /// both rest on one definition.
    public static func drinkDates(summaries: [DaySummary]) -> [String] {
        summaries.filter { isDrinkDay(totalGrams: $0.totalGrams) }.map(\.date).sorted()
    }

    // ── Widmark parameters ───────────────────────────────────────────────────

    /// Widmark distribution coefficient *r*, fixed at the conservative 0.6.
    private static let widmarkR = 0.6

    /// Standard ethanol elimination rate: 0.15 ‰ per hour. Individual values
    /// range from roughly 0.10 to 0.20 ‰/h depending on liver enzyme activity.
    private static let beta = 0.15

    /// Milliseconds per hour, as a `Double` so elapsed-time arithmetic reads
    /// naturally without casts at every call site.
    public static let millisPerHour = 3_600_000.0

    // ── Private rounding utilities ───────────────────────────────────────────
    //
    // ROUNDING SEMANTICS — the subtlest part of this port.
    //
    // Kotlin's `roundToLong()` rounds halves toward POSITIVE INFINITY
    // (`0.5 -> 1`, `-0.5 -> 0`). Swift's `rounded()` defaults to
    // `.toNearestOrAwayFromZero` (`0.5 -> 1`, `-0.5 -> -1`). The two disagree
    // only for negative halves.
    //
    // Both call sites here operate on values that are guaranteed non-negative
    // — `calculateGrams` takes a non-negative volume and ABV, and
    // `calculateBAC` clamps to `>= 0` *before* rounding — so the behaviours
    // coincide and `.rounded()` is safe. `.toNearestOrAwayFromZero` is spelled
    // out explicitly rather than relying on the default, to make the choice
    // visible to a future reader who might extend these to negative inputs.

    /// Rounds to one decimal place.
    ///
    /// Two callers, one precision. For alcohol GRAM values one decimal is what
    /// the UI displays ("20.0 g") and what every limit comparison uses, so the
    /// number a user sees is the number that is compared. For the BLOOD-ALCOHOL
    /// estimate it is the precision the model supports: β varies between roughly
    /// 0.10 and 0.20 ‰/h across people and r is a population average, so a
    /// second decimal would claim an accuracy Widmark does not have.
    private static func roundTo1Decimal(_ value: Double) -> Double {
        (value * 10.0).rounded(.toNearestOrAwayFromZero) / 10.0
    }

    // ── Public functions ─────────────────────────────────────────────────────

    /// Calculates the mass of pure (anhydrous) ethanol in a drink.
    ///
    /// Formula: `g = V [ml] × (p [%] ÷ 100) × 0.789 [g/ml]`
    ///
    /// The result is rounded to ONE decimal place. This is deliberate: the UI
    /// shows grams with one decimal ("20.0 g"), and the daily-limit and binge
    /// checks compare the stored grams against the limit. With two-decimal
    /// precision, 188 ml at 13.5 % stored 20.02 g, which displayed as "20.0 g"
    /// yet counted as over a 20 g limit — an exceedance the user could not see.
    /// Rounding at the source keeps display and comparison in agreement.
    ///
    /// - Parameters:
    ///   - volumeMl: Volume of the drink in millilitres.
    ///   - alcoholPercent: Alcohol by volume (ABV) as a percentage, e.g. 4.9.
    /// - Returns: Grams of pure alcohol, rounded to one decimal place.
    public static func calculateGrams(volumeMl: Int, alcoholPercent: Double) -> Double {
        let rawGrams = Double(volumeMl) * (alcoholPercent / 100.0) * ethanolDensity
        let grams = roundTo1Decimal(rawGrams)
        // Invariant: a real drink never has negative volume or ABV, so its pure-
        // alcohol mass is never negative. `assert` is compiled out of release
        // builds, so it costs shipped users nothing — the Swift equivalent of the
        // Kotlin `assert` enabled under -ea during the JVM test suite.
        assert(grams >= 0.0, "calculateGrams: negative grams \(grams)")
        return grams
    }

    /// Estimates the blood alcohol concentration at `nowMillis`.
    ///
    /// The doses are walked in time order. Between two of them the level falls
    /// by `beta` per hour and is clamped at zero, so a gap long enough to sober
    /// up cannot be subtracted a second time from the round that follows it; see
    /// the file header for what the lumped form got wrong. After the last dose
    /// the same elimination runs up to `nowMillis`.
    ///
    /// The coefficient *r* is fixed at the conservative 0.6, so the value is a
    /// worst-case rather than sex-specific estimate.
    ///
    /// NOT BOUND TO THE LOGICAL DAY. The caller passes the doses of a span of
    /// hours, not of a calendar or logical day. Someone who drank until three in
    /// the morning is not sober at four because the day-change time passed, and
    /// this function has no notion of a day that could make them look sober.
    ///
    /// Doses of zero grams are dropped: an alcohol-free drink neither raises the
    /// level nor anchors the elimination. Doses timestamped after `nowMillis` are
    /// dropped too — a drink entered for later in the evening has not been drunk.
    ///
    /// - Parameters:
    ///   - doses: The doses to consider, in any order.
    ///   - weightKg: Body weight in kilograms; must be positive.
    ///   - nowMillis: The instant the estimate is asked about, Unix epoch ms.
    /// - Returns: Estimated BAC in ‰, rounded to one decimal and never negative.
    ///   Zero when no weight is on record or no dose applies.
    public static func calculateBAC(
        doses: [AlcoholDose],
        weightKg: Double,
        nowMillis: Int64
    ) -> Double {
        guard weightKg > 0 else { return 0.0 }
        let relevant = doses
            .filter { $0.gramsAlcohol > 0.0 && $0.timestampMillis <= nowMillis }
            .sorted { $0.timestampMillis < $1.timestampMillis }
        guard let first = relevant.first else { return 0.0 }

        // `level` is the concentration reached just after the dose at `last`.
        var level = 0.0
        var last = first.timestampMillis
        for dose in relevant {
            level = eliminated(level, from: last, to: dose.timestampMillis)
            level += dose.gramsAlcohol / (weightKg * widmarkR)
            last = dose.timestampMillis
        }
        let bac = roundTo1Decimal(eliminated(level, from: last, to: nowMillis))
        // Postcondition: every step clamps at zero, so the estimate is never
        // reported as negative.
        assert(bac >= 0.0, "calculateBAC: negative BAC \(bac)")
        return bac
    }

    /// `level` after eliminating from `fromMillis` to `toMillis`, clamped at zero.
    ///
    /// The clamp is the whole point: elimination is a zero-order process that
    /// only runs while there is alcohol to eliminate. Letting the level go
    /// negative and carrying that deficit forward is exactly the error the
    /// lumped formula made.
    private static func eliminated(_ level: Double, from fromMillis: Int64, to toMillis: Int64) -> Double {
        let hours = max(Double(toMillis - fromMillis) / millisPerHour, 0.0)
        return max(level - beta * hours, 0.0)
    }

    /// Translates user settings into the active limit thresholds.
    ///
    /// This is the single place where `AppSettings` becomes `LimitInfo`, so
    /// every screen and the report exporter share one derivation.
    /// `maxDrinkDaysPerWeek` is clamped into 1...7 defensively.
    public static func getLimitInfo(_ settings: AppSettings) -> LimitInfo {
        LimitInfo(
            limitGrams: settings.dailyLimitGrams,
            weeklyLimitGrams: settings.weeklyLimitGrams,
            maxDrinkDaysPerWeek: min(max(settings.maxDrinkDaysPerWeek, 1), 7)
        )
    }

    /// The fraction of the daily limit that `totalGrams` represents.
    ///
    /// `1.0` means exactly at the limit; greater than `1.0` means over it. The
    /// result is clamped at zero from below so it can feed a progress bar
    /// directly. A non-positive `limitGrams` (limit not configured) yields `0`
    /// rather than a NaN or infinite fill.
    public static func limitPercent(totalGrams: Double, limitGrams: Double) -> Double {
        guard limitGrams > 0.0 else { return 0.0 }
        let fraction = max(totalGrams / limitGrams, 0.0)
        // Postcondition: the fill fraction is clamped to >= 0, so it is always a
        // valid progress-bar input, even for a negative (already-cleared) total.
        assert(fraction >= 0.0, "limitPercent: negative fraction \(fraction)")
        return fraction
    }

    /// Whether the weekly drink-day allowance is already spent, so that a drink
    /// logged *today* would exceed it.
    ///
    /// A drink day, once spent, stays spent for the rest of that day. What
    /// decides the question is therefore the number of drink days **strictly
    /// before today**:
    ///
    /// ```
    /// pastDrinkDays = drinkDaysThisWeek − (todayIsDrinkDay ? 1 : 0)
    /// ```
    ///
    /// - Today is already a drink day and completed the count (e.g. 5/5):
    ///   another drink today adds no further drink day, so the allowance is
    ///   *not* reached.
    /// - Today is still dry and the count is already full (also 5/5): the first
    ///   drink would spend a day the user does not have. The allowance *is*
    ///   reached.
    ///
    /// The two cases show the same "5 / 5" to the user, and differ in their
    /// answer. Extracted — mirroring Kotlin's `drinkDayLimitReached`, and pinned
    /// by the `drinkDayLimitReached` section of `alcohol-calculator.json` on
    /// both platforms — so that `trafficLight` and `LimitGauge`'s drink-day bar
    /// cannot disagree.
    ///
    /// - Parameters:
    ///   - drinkDaysThisWeek: Distinct drink days in the rolling window, today
    ///     included.
    ///   - maxDrinkDaysPerWeek: The configured allowance.
    ///   - todayIsDrinkDay: Whether today has already seen alcohol
    ///     (`todayGrams > 0`).
    public static func drinkDayLimitReached(
        drinkDaysThisWeek: Int,
        maxDrinkDaysPerWeek: Int,
        todayIsDrinkDay: Bool
    ) -> Bool {
        let pastDrinkDays = drinkDaysThisWeek - (todayIsDrinkDay ? 1 : 0)
        return pastDrinkDays >= maxDrinkDaysPerWeek
    }

    /// Whole servings of `gramsPerDrink` that fit into `remainingGrams`.
    ///
    /// A negative remaining budget counts as zero. Returns zero for a
    /// non-positive serving size, avoiding division by zero.
    private static func servingsFitting(remainingGrams: Double, gramsPerDrink: Double) -> Int {
        guard gramsPerDrink > 0.0 else { return 0 }
        // `Int(_:)` truncates toward zero, matching Kotlin's `toInt()`. The
        // argument is clamped to >= 0 first, so truncation is a plain floor.
        let count = Int(max(remainingGrams, 0.0) / gramsPerDrink)
        // Invariant: the remaining budget is floored at 0 before the division, so
        // the whole-serving count can never come out negative.
        assert(count >= 0, "servingsFitting: negative count \(count)")
        return count
    }

    /// Computes the traffic-light capacity status for one drink serving.
    ///
    /// Answers: "How many more of this drink can I log before exceeding ANY of
    /// my three limits?" — `.green` (two or more still fit), `.yellow` (exactly
    /// one fits), `.red` (none fits).
    ///
    /// All three limits are evaluated together:
    /// 1. **Daily gram limit** — servings that fit into today's remaining grams.
    /// 2. **Seven-day gram limit** — servings that fit into the remaining grams
    ///    of the trailing window (today plus the previous six days).
    /// 3. **Drink-day limit** — a *gate*, not a per-serving cap. Drinking more
    ///    on a day that already counts as a drink day consumes no additional
    ///    drink days, so this limit never reduces the serving count; it can only
    ///    force `.red` once the seven-day drink-day budget is spent.
    ///
    /// **The drink-day gate.** `pastDrinkDays` is the number of drink days
    /// *before today* inside the trailing window. The gate fires as soon as
    /// `pastDrinkDays >= maxDrinkDaysPerWeek`, covering both cases:
    /// - today is not yet a drink day and the window already holds `max` of
    ///   them, so logging would open a forbidden new drink day; and
    /// - today is already a drink day, but `max` drink days preceded it, so
    ///   today itself is over budget.
    ///
    /// Alcohol-free drinks (`gramsPerDrink == 0`) always return `.green`: they
    /// consume no gram budget and never turn a day into a drink day.
    public static func trafficLight(
        gramsPerDrink: Double,
        todayGrams: Double,
        dailyLimitGrams: Double,
        weeklyTotalGrams: Double,
        weeklyLimitGrams: Double,
        drinkDaysThisWeek: Int,
        maxDrinkDaysPerWeek: Int
    ) -> TrafficLight {
        guard gramsPerDrink > 0.0 else { return .green }

        // Drink-day gate: `drinkDayLimitReached` counts only the drink days
        // strictly before today (see its documentation for the two 5/5 cases).
        if drinkDayLimitReached(
            drinkDaysThisWeek: drinkDaysThisWeek,
            maxDrinkDaysPerWeek: maxDrinkDaysPerWeek,
            todayIsDrinkDay: todayGrams > 0.0
        ) {
            return .red
        }

        // Gram checks: whole servings fitting the remaining daily / weekly budget.
        let dailyCount = servingsFitting(
            remainingGrams: dailyLimitGrams - todayGrams,
            gramsPerDrink: gramsPerDrink
        )
        let weeklyCount = servingsFitting(
            remainingGrams: weeklyLimitGrams - weeklyTotalGrams,
            gramsPerDrink: gramsPerDrink
        )
        let count = min(dailyCount, weeklyCount)

        switch count {
        case ..<1: return .red
        case 1: return .yellow
        default: return .green
        }
    }

    /// Counts limit violations across per-day summaries, for the statistics
    /// screen and the report export.
    ///
    /// **Rolling seven-day window.** The weekly gram limit and the drink-day
    /// limit are *not* evaluated per fixed calendar week. Each consumption day
    /// is judged against the gliding `windowDays`-day window that *ends on that
    /// day* — the day itself plus the six calendar days before it. Such a window
    /// never resets on a weekday boundary, which makes the metric harder to game
    /// (heavy drinking split across a Sunday/Monday boundary no longer lands in
    /// two separate buckets) and reflects continuous health risk more honestly.
    ///
    /// The three counts answer:
    /// - `daysOverDailyLimit` — days whose own total exceeds `dailyLimitGrams`
    ///   (a per-day check, independent of any window).
    /// - `daysOverWeeklyLimit` — consumption days whose trailing seven-day gram
    ///   total exceeds `weeklyLimitGrams`.
    /// - `daysOverDrinkDayLimit` — consumption days for which the number of
    ///   distinct consumption days inside their trailing window exceeds
    ///   `maxDrinkDaysPerWeek`.
    ///
    /// Only days with more than 0 g count as consumption days for the weekly and
    /// drink-day checks; a day holding only alcohol-free entries is not a drink
    /// day and never enters the window.
    ///
    /// **Edge note (start of history / clipped periods).** The window is built
    /// only from the days actually present in `summaries`. Near the first
    /// recorded day, fewer than seven days of history exist, so the trailing
    /// window simply contains fewer days and is evaluated on what is visible.
    ///
    /// **Implementation (two-pointer sliding window).** The consumption days are
    /// sorted ascending once, then a single left pointer trails the current
    /// (right) day, dropping days that have fallen out of the window and
    /// maintaining the running gram sum incrementally. That is O(n) over the
    /// consumption days, rather than the O(n²) of re-scanning per day.
    ///
    /// - Parameter summaries: Per-day summaries in any order; `date` must be an
    ///   ISO-8601 `yyyy-MM-dd` string. Days that fail to parse are ignored.
    public static func countLimitViolations(
        summaries: [DaySummary],
        dailyLimitGrams: Double,
        weeklyLimitGrams: Double,
        maxDrinkDaysPerWeek: Int
    ) -> LimitViolations {
        let daysOverDaily = summaries.filter {
            isOverLimit(totalGrams: $0.totalGrams, limitGrams: dailyLimitGrams)
        }.count

        // Consumption days only (> 0 g), sorted ascending so the window can
        // advance in a single forward pass. Each ISO date is parsed once.
        let days: [(date: Date, grams: Double)] = summaries
            .filter { isDrinkDay(totalGrams: $0.totalGrams) }
            .compactMap { summary in
                guard let parsed = IsoDay.parse(summary.date) else { return nil }
                return (parsed, summary.totalGrams)
            }
            .sorted { $0.date < $1.date }

        var daysOverWeekly = 0
        var daysOverDrinkDay = 0

        // Two-pointer window: days[left...right] are exactly the consumption
        // days inside the trailing window ending at days[right]. `windowGrams`
        // is the running sum over precisely those days.
        var left = 0
        var windowGrams = 0.0
        for right in days.indices {
            windowGrams += days[right].grams
            let windowStart = IsoDay.addingDays(-(windowDays - 1), to: days[right].date)

            // Evict days now older than the window's first day.
            while days[left].date < windowStart {
                windowGrams -= days[left].grams
                left += 1
            }

            let windowDrinkDays = right - left + 1
            // Two-pointer invariant: days are sorted ascending and windowStart is
            // never after days[right], so left can never overtake right.
            assert(left <= right, "countLimitViolations: window invariant left > right")

            if isOverLimit(totalGrams: windowGrams, limitGrams: weeklyLimitGrams) { daysOverWeekly += 1 }
            if windowDrinkDays > maxDrinkDaysPerWeek { daysOverDrinkDay += 1 }
        }

        return LimitViolations(
            daysOverDailyLimit: daysOverDaily,
            daysOverWeeklyLimit: daysOverWeekly,
            daysOverDrinkDayLimit: daysOverDrinkDay
        )
    }
}

// =============================================================================
// IsoDay – calendar-day arithmetic for ISO-8601 date strings
// =============================================================================
//
// The Android code uses `java.time.LocalDate`, a date with no time and no zone.
// Foundation has no exact equivalent, and this is a classic correctness trap:
// using `Date` with the *current* time zone would make the seven-day window
// shift under DST transitions, and a backup exported on Android could then be
// evaluated differently on iOS.
//
// The fix is to pin every calculation to a UTC calendar and to noon rather than
// midnight. Noon is the standard trick: a DST shift of ±1 hour can never move a
// noon timestamp across a day boundary, whereas a midnight timestamp can.
// =============================================================================

enum IsoDay {

    /// A Gregorian calendar pinned to UTC, so day arithmetic is zone-independent.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// Parses a `yyyy-MM-dd` string into a `Date` at 12:00 UTC on that day.
    /// Returns `nil` for malformed input.
    static func parse(_ isoDate: String) -> Date? {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12  // noon: immune to DST shifts
        return calendar.date(from: components)
    }

    /// Returns the date `days` calendar days from `date` (negative to go back).
    static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}
