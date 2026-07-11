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
//   BAC [‰] = A / (P × r) − β × t
//
//   A = grams of pure alcohol consumed
//   P = body weight in kilograms
//   r = distribution coefficient (fixed at 0.6; see `widmarkR`)
//   β = elimination rate ≈ 0.15 ‰ per hour (population average)
//   t = hours elapsed since the FIRST drink of the episode
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

    /// Binge-drinking threshold in grams of pure alcohol per occasion.
    ///
    /// Fixed at 60 g, the WHO/NIAAA threshold historically used for women. As
    /// the app does not store the user's sex, the stricter of the two
    /// thresholds is used so the report flags binge days conservatively.
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

    /// Rounds to two decimal places, matching the Kotlin original's precision
    /// for the BAC readout (e.g. "0.42 ‰").
    private static func roundTo2Decimals(_ value: Double) -> Double {
        (value * 100.0).rounded(.toNearestOrAwayFromZero) / 100.0
    }

    /// Rounds to one decimal place (0.1 g), the precision used for every gram
    /// value the UI displays *and* every limit comparison, so the number a user
    /// sees is exactly the number that is compared against the limit.
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

    /// Estimates the blood alcohol concentration using the Widmark formula.
    ///
    /// `BAC [‰] = A / (P × r) − β × t`
    ///
    /// The coefficient *r* is fixed at the conservative 0.6, so the value is a
    /// worst-case rather than sex-specific estimate.
    ///
    /// Only entries with a positive ABV should contribute to `totalGrams`, and
    /// their earliest timestamp should drive `hoursElapsed`. Including
    /// alcohol-free entries would push the start time earlier and underestimate
    /// the BAC.
    ///
    /// - Parameters:
    ///   - totalGrams: Total grams of pure alcohol in the current episode.
    ///   - weightKg: Body weight in kilograms; must be positive.
    ///   - hoursElapsed: Hours since the first alcoholic drink. Negative values
    ///     are treated as zero.
    /// - Returns: Estimated BAC in ‰, never negative. Returns 0 for invalid
    ///   input (non-positive weight, or no alcohol).
    public static func calculateBAC(
        totalGrams: Double,
        weightKg: Double,
        hoursElapsed: Double
    ) -> Double {
        guard weightKg > 0, totalGrams > 0 else { return 0.0 }
        let elapsed = max(hoursElapsed, 0.0)
        let raw = (totalGrams / (weightKg * widmarkR)) - (beta * elapsed)
        let bac = roundTo2Decimals(max(raw, 0.0))
        // Postcondition: the estimate is clamped to >= 0, so a BAC is never
        // reported as negative.
        assert(bac >= 0.0, "calculateBAC: negative BAC \(bac)")
        return bac
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

        // Drink-day gate: count only the drink days strictly before today.
        let todayIsDrinkDay = todayGrams > 0.0
        let pastDrinkDays = drinkDaysThisWeek - (todayIsDrinkDay ? 1 : 0)
        if pastDrinkDays >= maxDrinkDaysPerWeek { return .red }

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
            .filter { $0.totalGrams > 0.0 }
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
