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
// ReportData – everything the PDF report states, computed once
// =============================================================================
//
// The Swift counterpart of Android's `PdfReportData.from`. It computes; it does
// not format. No locale, no number formatting, no HTML: those belong to the
// renderer, and keeping them out is what makes every figure here testable.
//
// WHERE THE NUMBERS COME FROM
//   Wherever the Statistics screen already answers a question, the report asks
//   the same code — `AlcoholCalculator.countLimitViolations`,
//   `ChartBucketing.bucketize`, `StatsAggregator.weekdayAverages`,
//   `DayResolver.computeLongestAbstinence`. A report that disagreed with the
//   screen would be worse than no report: the user would not know which to trust.
//
// WHAT IS COMPUTED HERE, AND ONLY HERE
//   Medians, binge days, the monthly table, the 24-hour profile and the rolling
//   seven-day peak. The screen shows none of them.
// =============================================================================

/// One calendar month of the reporting period.
public struct MonthStat: Sendable, Equatable {
    /// `"YYYY-MM"`.
    public let monthKey: String
    /// Days in this month on which anything was logged.
    public let drinkDays: Int
    public let totalGrams: Double
    /// Grams divided by the month's days INSIDE the period — see `make`.
    public let avgPerCalendarDay: Double
    public let daysOverDailyLimit: Int

    public init(
        monthKey: String,
        drinkDays: Int,
        totalGrams: Double,
        avgPerCalendarDay: Double,
        daysOverDailyLimit: Int
    ) {
        self.monthKey = monthKey
        self.drinkDays = drinkDays
        self.totalGrams = totalGrams
        self.avgPerCalendarDay = avgPerCalendarDay
        self.daysOverDailyLimit = daysOverDailyLimit
    }
}

/// One drink category's share of the period.
public struct CategoryStat: Sendable, Equatable {
    /// The stored spelling, `"BEER"` … `"OTHER"`. The renderer localises it.
    public let categoryName: String
    public let grams: Double
    /// Rounded to a whole percent; the slices need not sum to exactly 100.
    public let percent: Int

    public init(categoryName: String, grams: Double, percent: Int) {
        self.categoryName = categoryName
        self.grams = grams
        self.percent = percent
    }
}

public struct ReportData: Sendable, Equatable {

    // ── The period ───────────────────────────────────────────────────────────
    public let firstDate: String
    public let lastDate: String
    /// Calendar days in `[firstDate, lastDate]`, inclusive. Abstinent days count.
    public let totalDays: Int
    public let limitInfo: LimitInfo
    public let weightKg: Double

    // ── Totals and averages ──────────────────────────────────────────────────
    public let totalGrams: Double
    /// Over every calendar day, abstinent days included.
    public let avgPerDay: Double
    /// Over drink days only. The two answer different questions.
    public let avgPerDrinkDay: Double
    public let drinkDays: Int
    public let abstinentDays: Int
    public let violations: LimitViolations
    /// Days above `AlcoholCalculator.bingeThreshold`.
    public let bingeDays: Int

    // ── Medians and peaks ────────────────────────────────────────────────────
    public let medianPerDay: Double
    public let medianPerDrinkDay: Double
    public let avgDrinkDaysPerMonth: Double
    public let medianDrinkDaysPerMonth: Double
    public let maxPerDay: Double
    /// The worst rolling window of seven consecutive calendar days.
    public let maxPer7Days: Double

    // ── Breakdowns ───────────────────────────────────────────────────────────
    /// Ascending by `monthKey`.
    public let months: [MonthStat]
    public let chartBuckets: [ChartBucket]
    public let chartGranularity: ChartGranularity
    /// Descending by grams.
    public let categories: [CategoryStat]
    /// Exactly 24 entries, one per clock hour. Hours with nothing logged are 0.
    public let hourlyGrams: [Double]
    /// ISO weekdays in display order, rotated to the locale's first day.
    public let weekdayOrder: [Int]
    /// Pairs index-for-index with `weekdayOrder`. `nil` = the weekday never
    /// occurred as a drink day.
    public let weekdayAverages: [Double?]

    // ── Streaks ──────────────────────────────────────────────────────────────
    public let longestAbstinence: Int
    public let currentAbstinence: Int

    // =========================================================================
    // Computation
    // =========================================================================

    /// Computes the whole dataset for a non-empty set of entries.
    ///
    /// - Parameters:
    ///   - entries: Entries of the range. MUST be non-empty; the caller checks,
    ///     because an empty report is refused rather than rendered blank.
    ///   - drinks: The catalogue, for mapping each entry to a category.
    ///   - settings: Limits, weight, and the day-change hour.
    ///   - periodEnd: The user-chosen INCLUSIVE end of the export range, or `nil`.
    ///     It anchors the abstinence streaks; see below.
    ///   - today: The current logical day. Passed in rather than read from a clock,
    ///     so the figures are reproducible in a test and in a screenshot.
    ///   - timeZone: The zone whose wall clock decides the hour-of-day bucket.
    ///   - locale: Decides which weekday a week starts on.
    /// - Returns: `nil` if `entries` is empty.
    public static func make(
        entries: [ConsumptionEntry],
        drinks: [DrinkDefinition],
        settings: AppSettings,
        periodEnd: String? = nil,
        today: String,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> ReportData? {
        guard !entries.isEmpty else { return nil }

        let categoryById = Dictionary(
            drinks.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first }
        )

        // Grouped once; every per-day and per-month figure below reuses it.
        var byDate: [String: [ConsumptionEntry]] = [:]
        for entry in entries { byDate[entry.logicalDate, default: []].append(entry) }

        let firstDate = entries.map(\.logicalDate).min()!
        let lastDate = entries.map(\.logicalDate).max()!
        let limitInfo = AlcoholCalculator.getLimitInfo(settings)

        let allDays = DayResolver.inclusiveDates(from: firstDate, to: lastDate)
        let totalDays = allDays.count

        let drinkDays = byDate.count
        let abstinentDays = max(totalDays - drinkDays, 0)
        let totalGrams = entries.reduce(0.0) { $0 + $1.gramsAlcohol }
        let avgPerDay = totalDays > 0 ? totalGrams / Double(totalDays) : 0.0
        let avgPerDrinkDay = drinkDays > 0 ? totalGrams / Double(drinkDays) : 0.0

        // One summary per drink day, in the shape the shared calculators expect.
        let daySummaries = byDate
            .map { date, dayEntries in
                DaySummary(
                    date: date,
                    totalGrams: dayEntries.reduce(0.0) { $0 + $1.gramsAlcohol },
                    entryCount: dayEntries.count
                )
            }
            .sorted { $0.date < $1.date }

        let violations = AlcoholCalculator.countLimitViolations(
            summaries: daySummaries,
            dailyLimitGrams: limitInfo.limitGrams,
            weeklyLimitGrams: limitInfo.weeklyLimitGrams,
            maxDrinkDaysPerWeek: limitInfo.maxDrinkDaysPerWeek
        )
        let bingeDays = daySummaries.filter {
            AlcoholCalculator.isOverLimit(
                totalGrams: $0.totalGrams, limitGrams: AlcoholCalculator.bingeThreshold
            )
        }.count

        let months = monthStats(
            daySummaries: daySummaries,
            firstDate: firstDate,
            lastDate: lastDate,
            dailyLimitGrams: limitInfo.limitGrams
        )

        // ── Per-day totals over EVERY calendar day, abstinent days as zeros ──
        //
        // The median and the rolling window both need the dry days. Taking them
        // from `byDate` alone would median only the drinking, which is a different
        // and much less flattering number.
        var totalByDate: [String: Double] = [:]
        for summary in daySummaries { totalByDate[summary.date] = summary.totalGrams }
        let perDayTotals = allDays.map { totalByDate[$0] ?? 0.0 }
        let perDrinkDayTotals = daySummaries.map(\.totalGrams)

        let drinkDaysPerMonth = months.map { Double($0.drinkDays) }
        let avgDrinkDaysPerMonth = drinkDaysPerMonth.isEmpty
            ? 0.0
            : drinkDaysPerMonth.reduce(0.0, +) / Double(drinkDaysPerMonth.count)

        let firstWeekday = DayResolver.firstDayOfWeekIso(locale: locale)
        let granularity = ChartBucketing.granularityForSpan(days: totalDays)

        return ReportData(
            firstDate: firstDate,
            lastDate: lastDate,
            totalDays: totalDays,
            limitInfo: limitInfo,
            weightKg: settings.weightKg,
            totalGrams: totalGrams,
            avgPerDay: avgPerDay,
            avgPerDrinkDay: avgPerDrinkDay,
            drinkDays: drinkDays,
            abstinentDays: abstinentDays,
            violations: violations,
            bingeDays: bingeDays,
            medianPerDay: median(perDayTotals),
            medianPerDrinkDay: median(perDrinkDayTotals),
            avgDrinkDaysPerMonth: avgDrinkDaysPerMonth,
            medianDrinkDaysPerMonth: median(drinkDaysPerMonth),
            maxPerDay: perDayTotals.max() ?? 0.0,
            maxPer7Days: maxRollingSevenDays(perDayTotals),
            months: months,
            chartBuckets: ChartBucketing.bucketize(
                summaries: daySummaries, from: firstDate, to: lastDate, granularity: granularity
            ),
            chartGranularity: granularity,
            categories: categoryStats(
                entries: entries, categoryById: categoryById, totalGrams: totalGrams
            ),
            hourlyGrams: hourlyGrams(entries: entries, timeZone: timeZone),
            weekdayOrder: StatsAggregator.weekdayOrder(firstDayOfWeekIso: firstWeekday),
            weekdayAverages: StatsAggregator.weekdayAverages(
                summaries: daySummaries, firstDayOfWeekIso: firstWeekday
            ),
            longestAbstinence: DayResolver.computeLongestAbstinence(
                sortedDates: daySummaries.map(\.date),
                today: streakAnchor(periodEnd: periodEnd, today: today)
            ),
            currentAbstinence: DayResolver.computeCurrentAbstinence(
                sortedDates: daySummaries.map(\.date),
                today: streakAnchor(periodEnd: periodEnd, today: today)
            )
        )
    }

    // ── Pieces ───────────────────────────────────────────────────────────────

    /// Where the abstinence streaks are measured from.
    ///
    /// A report over a HISTORICAL range must not anchor at the real today: every
    /// day between the last in-range drink and now would count as abstinent —
    /// including days outside the report on which the user did drink. The anchor is
    /// therefore clamped to the day after the period ends, which makes
    /// `computeCurrentAbstinence` count the dry days up to and including the last
    /// report day. A range ending today keeps the real anchor, so that the report
    /// and the Statistics screen agree about an in-progress day.
    ///
    /// Android learned this the hard way (v0.81.0); its comment is worth reading.
    static func streakAnchor(periodEnd: String?, today: String) -> String {
        guard let periodEnd, periodEnd < today, let end = DayResolver.parseDate(periodEnd) else {
            return today
        }
        return DayResolver.formatDate(DayResolver.addingDays(1, to: end))
    }

    /// Grams per clock hour, 24 entries.
    ///
    /// Bucketed by the WALL CLOCK, not by the logical day: a drink at 01:00 belongs
    /// in hour 1, however the day-change hour assigns it. The hour-of-day chart is
    /// about when a person drinks, not which day the app books it to.
    static func hourlyGrams(entries: [ConsumptionEntry], timeZone: TimeZone) -> [Double] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var hours = [Double](repeating: 0.0, count: 24)
        for entry in entries {
            let date = Date(timeIntervalSince1970: Double(entry.timestampMillis) / 1000.0)
            let hour = calendar.component(.hour, from: date)
            hours[hour] += entry.gramsAlcohol
        }
        return hours
    }

    /// One row per calendar month that saw a drink, ascending.
    ///
    /// `avgPerCalendarDay` divides by the month's days INSIDE the period, not by the
    /// month's full length. For a partial first or last month the untouched tail
    /// would otherwise be counted as abstinent, deflating the figure — a month
    /// begun yesterday would look like a very sober one.
    static func monthStats(
        daySummaries: [DaySummary],
        firstDate: String,
        lastDate: String,
        dailyLimitGrams: Double
    ) -> [MonthStat] {
        var byMonth: [String: [DaySummary]] = [:]
        for summary in daySummaries {
            byMonth[String(summary.date.prefix(7)), default: []].append(summary)
        }

        return byMonth.keys.sorted().compactMap { monthKey -> MonthStat? in
            guard
                let days = byMonth[monthKey],
                let monthStart = DayResolver.parseDate("\(monthKey)-01"),
                let periodStart = DayResolver.parseDate(firstDate),
                let periodEnd = DayResolver.parseDate(lastDate)
            else { return nil }

            let effectiveStart = max(monthStart, periodStart)
            let effectiveEnd = min(lastDayOfMonth(monthStart), periodEnd)
            let effectiveDays = max(
                DayResolver.inclusiveDates(
                    from: DayResolver.formatDate(effectiveStart),
                    to: DayResolver.formatDate(effectiveEnd)
                ).count,
                1
            )

            let grams = days.reduce(0.0) { $0 + $1.totalGrams }
            let over = days.filter {
                AlcoholCalculator.isOverLimit(totalGrams: $0.totalGrams, limitGrams: dailyLimitGrams)
            }.count

            return MonthStat(
                monthKey: monthKey,
                drinkDays: days.count,
                totalGrams: grams,
                avgPerCalendarDay: grams / Double(effectiveDays),
                daysOverDailyLimit: over
            )
        }
    }

    /// The last day of the month containing `monthStart`.
    private static func lastDayOfMonth(_ monthStart: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return DayResolver.addingDays(-1, to: nextMonth)
    }

    /// Category totals, descending by grams.
    ///
    /// An entry whose drink has since been deleted falls to `OTHER`, as on the
    /// Statistics screen: the log keeps the drink's name, not its category.
    ///
    /// TIES ARE BROKEN BY FIRST APPEARANCE, and that is not a detail. Kotlin
    /// accumulates into a `linkedMapOf` — insertion-ordered — and `sortedByDescending`
    /// is stable, so two categories with equal grams keep the order in which the log
    /// first mentioned them. Swift's `Dictionary` has no order and `sorted(by:)` is
    /// not stable, so two equal categories would come out in whichever order the
    /// hash seed chose that morning. The index is carried explicitly.
    static func categoryStats(
        entries: [ConsumptionEntry],
        categoryById: [Int64: DrinkCategory],
        totalGrams: Double
    ) -> [CategoryStat] {
        var grams: [String: Double] = [:]
        var firstSeen: [String: Int] = [:]

        for entry in entries {
            let name = (categoryById[entry.drinkId] ?? .other).rawValue
            grams[name, default: 0.0] += entry.gramsAlcohol
            if firstSeen[name] == nil { firstSeen[name] = firstSeen.count }
        }

        // Guards the division when a period somehow totals zero grams.
        let denominator = max(totalGrams, 0.01)

        // Spelled out in steps, with every intermediate type written down. Chained
        // as `map` -> tuple -> `sorted` -> `map(\.stat)` this defeated Swift's type
        // checker outright: "unable to type-check this expression in reasonable
        // time". The inference cost of an unannotated tuple inside a closure inside
        // a sort predicate is not linear.
        struct Ranked {
            let stat: CategoryStat
            let firstAppearance: Int
        }

        var ranked: [Ranked] = []
        for (name, value) in grams {
            let percent = Int((value / denominator * 100).rounded())
            ranked.append(Ranked(
                stat: CategoryStat(categoryName: name, grams: value, percent: percent),
                firstAppearance: firstSeen[name] ?? 0
            ))
        }

        ranked.sort { left, right in
            if left.stat.grams == right.stat.grams {
                return left.firstAppearance < right.firstAppearance
            }
            return left.stat.grams > right.stat.grams
        }

        return ranked.map { $0.stat }
    }

    /// The worst sum over seven consecutive calendar days.
    ///
    /// A period shorter than a full window has no seven-day total to speak of, so
    /// the whole period is used. Android does the same, and the report says
    /// "highest in 7 days" either way.
    static func maxRollingSevenDays(_ perDayTotals: [Double]) -> Double {
        guard perDayTotals.count > 7 else { return perDayTotals.reduce(0.0, +) }

        var best = 0.0
        for start in 0...(perDayTotals.count - 7) {
            let window = perDayTotals[start..<(start + 7)].reduce(0.0, +)
            best = max(best, window)
        }
        return best
    }

    /// The 50th percentile; `0.0` for nothing. An even count averages the middle
    /// pair. The input is copied, never sorted in place.
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1
            ? sorted[middle]
            : (sorted[middle - 1] + sorted[middle]) / 2.0
    }
}
