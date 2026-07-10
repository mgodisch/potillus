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
// StatsAggregator.swift – the arithmetic behind the Statistics screen
// =============================================================================
//
// On Android these four aggregations live inside `StatsViewModel`, where nothing
// tests them. Ported here as pure functions instead, for the same reason the
// drink-day gate was extracted: an unnamed calculation buried in a view model is
// a calculation nobody can check and everybody will copy.
//
// TWO CLOCKS, ON PURPOSE
//   A drink at 01:00 belongs to the previous LOGICAL day — that is how the totals
//   are grouped. But it happened at one in the morning, and the time-of-day
//   histogram must say so. So the histogram buckets by WALL-CLOCK hour while the
//   day totals follow the logical date. The question the histogram answers is
//   "when do I drink", not "on which day does it count".
// =============================================================================

/// Pure aggregations over a period's entries and daily summaries.
public enum StatsAggregator {

    // ── Category breakdown ───────────────────────────────────────────────────

    /// Grams of alcohol per drink category.
    ///
    /// The category comes from the CURRENT catalogue, looked up by `drinkId`, so
    /// re-categorising a drink re-colours its history. Entries whose drink no
    /// longer exists fall to `.other` rather than vanishing — the alcohol was
    /// still drunk.
    ///
    /// Categories totalling zero are omitted: a slice of nothing is not a slice.
    public static func categoryBreakdown(
        entries: [ConsumptionEntry], drinks: [DrinkDefinition]
    ) -> [DrinkCategory: Double] {
        let categoryOf = Dictionary(
            drinks.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first }
        )

        var totals: [DrinkCategory: Double] = [:]
        for entry in entries {
            let category = categoryOf[entry.drinkId] ?? .other
            totals[category, default: 0.0] += entry.gramsAlcohol
        }
        return totals.filter { $0.value > 0.0 }
    }

    // ── Time of day ──────────────────────────────────────────────────────────

    /// Grams per clock hour, 0…23, in the given zone.
    public static func hourlyGrams(
        entries: [ConsumptionEntry], timeZone: TimeZone
    ) -> [Double] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var hours = [Double](repeating: 0.0, count: 24)
        for entry in entries {
            let instant = Date(timeIntervalSince1970: Double(entry.timestampMillis) / 1000.0)
            let hour = calendar.component(.hour, from: instant)
            hours[hour] += entry.gramsAlcohol
        }
        return hours
    }

    /// The 24 hours collapsed into eight three-hour buckets (0–3, 3–6 … 21–24),
    /// each expressed as AVERAGE grams per day of the period.
    ///
    /// Averaging by the period's length — not by the number of days that fall in
    /// the bucket — is what makes the eight bars sum to the overall average grams
    /// per day. A bucket that is empty on most days should look small.
    ///
    /// - Parameter effectivePeriodDays: Days the period actually covers, from
    ///   `DayResolver.effectivePeriodDays`. Clamped to at least 1, so an empty
    ///   period yields zeros rather than a division by zero.
    public static func hourBucketAverages(
        entries: [ConsumptionEntry], effectivePeriodDays: Int, timeZone: TimeZone
    ) -> [Double] {
        let hours = hourlyGrams(entries: entries, timeZone: timeZone)
        let divisor = Double(max(effectivePeriodDays, 1))

        return (0..<8).map { bucket in
            let sum = (bucket * 3..<bucket * 3 + 3).reduce(0.0) { $0 + hours[$1] }
            return sum / divisor
        }
    }

    // ── Weekday profile ──────────────────────────────────────────────────────

    /// The seven ISO weekday numbers, starting at the locale's first day.
    ///
    /// The same rotation `MonthGrid` performs for its headers, stated once more
    /// here because the weekday profile is indexed by it and the two must agree.
    public static func weekdayOrder(firstDayOfWeekIso: Int) -> [Int] {
        (0..<7).map { (firstDayOfWeekIso - 1 + $0) % 7 + 1 }
    }

    /// Average grams for each weekday column, in `weekdayOrder`.
    ///
    /// Computed from the DAILY SUMMARIES — one total per day — not from individual
    /// entries, so a day with six beers counts once, as a day. Android's PDF does
    /// the same, and screen and report must not disagree.
    ///
    /// A column with no days at all is `nil`, not `0.0`: an average of nothing is
    /// not zero, and a bar chart must be able to draw the difference between "no
    /// Tuesdays in this period" and "Tuesdays were dry".
    public static func weekdayAverages(
        summaries: [DaySummary], firstDayOfWeekIso: Int
    ) -> [Double?] {
        var columns = [[Double]](repeating: [], count: 7)

        for summary in summaries {
            guard let date = DayResolver.parseDate(summary.date) else { continue }
            let column = (isoWeekday(of: date) - firstDayOfWeekIso + 7) % 7
            columns[column].append(summary.totalGrams)
        }

        return columns.map { totals in
            totals.isEmpty ? nil : totals.reduce(0.0, +) / Double(totals.count)
        }
    }

    /// The ISO weekday (1 = Monday … 7 = Sunday) of a date, read in UTC because
    /// `DayResolver` anchors its logical days there.
    private static func isoWeekday(of date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let sundayBased = calendar.component(.weekday, from: date)
        return sundayBased == 1 ? 7 : sundayBased - 1
    }

    // ── Averages and trend ───────────────────────────────────────────────────

    /// Grams per day across the period, or zero when it has no days.
    public static func averagePerDay(totalGrams: Double, effectivePeriodDays: Int) -> Double {
        effectivePeriodDays > 0 ? totalGrams / Double(effectivePeriodDays) : 0.0
    }

    /// Grams per DRINK day — days on which anything was drunk.
    ///
    /// A different question from `averagePerDay`, and usually a larger number:
    /// "how much when I drink" rather than "how much per calendar day".
    public static func averagePerDrinkDay(totalGrams: Double, drinkDays: Int) -> Double {
        drinkDays > 0 ? totalGrams / Double(drinkDays) : 0.0
    }

    /// The change against the previous period, in percent.
    ///
    /// Zero when the previous period had no drinking: a rise from nothing has no
    /// meaningful percentage, and dividing by it would produce an infinity.
    ///
    /// NOTE — this uses the RAW averages, while `Trend.of` rounds both to one
    /// decimal before comparing. The two can therefore disagree at the margin: a
    /// rise from 10.00 to 10.04 g/day reports +0.4 % beside a FLAT arrow. Android
    /// behaves identically, and the vectors pin it; the arrow is deliberately
    /// less twitchy than the number.
    public static func trendPercent(
        currentAveragePerDay: Double, previousAveragePerDay: Double
    ) -> Double {
        guard previousAveragePerDay > 0 else { return 0.0 }
        return ((currentAveragePerDay - previousAveragePerDay) / previousAveragePerDay) * 100.0
    }
}
