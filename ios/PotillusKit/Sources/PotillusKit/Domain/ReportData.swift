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
    /// This month's calendar days INSIDE the period — the divisor behind
    /// `avgPerCalendarDay`. Carried rather than recomputed because `MonthRollup`
    /// needs it: a summary row's average is the summed grams over the summed days,
    /// and averaging the averages of a 31-day and a 3-day month is not that.
    public let effectiveDays: Int
    /// For a summary row, the FIRST month it stands for; `nil` for a single month.
    ///
    /// The report prints the row as a span, `"Jan 2025 – Jun 2025"`, from this and
    /// `monthKey`. No new label: both ends go through the month formatter the
    /// report already carries.
    public let rollupFromKey: String?

    public init(
        monthKey: String,
        drinkDays: Int,
        totalGrams: Double,
        avgPerCalendarDay: Double,
        daysOverDailyLimit: Int,
        effectiveDays: Int,
        rollupFromKey: String? = nil
    ) {
        self.monthKey = monthKey
        self.drinkDays = drinkDays
        self.totalGrams = totalGrams
        self.avgPerCalendarDay = avgPerCalendarDay
        self.daysOverDailyLimit = daysOverDailyLimit
        self.effectiveDays = effectiveDays
        self.rollupFromKey = rollupFromKey
    }
}

/// Caps the monthly table, so a report over a long period still fits its sheet.
///
/// WHY A CAP AT ALL
///   Sheet one holds the header, the key figures, the trend chart and this table,
///   and the table was the only part with no upper bound: one row per calendar
///   month, for however long the period ran. Sheet one has room for roughly eight
///   more rows than the six a half-year report shows, so a two-year report ran off
///   the page — and a report that outgrew its sheets lost the last one entirely,
///   which is what `ReportPdfPrinter`'s completeness check now refuses to ship.
///
/// WHAT IT DOES
///   Keeps the most recent `keeping` months in full and folds everything older
///   into one summary row at the top. Nothing is dropped: the summary carries the
///   summed drink days, grams and over-limit days, and an average weighted by the
///   days each month contributed.
///
/// WHY NOT WHEN IT WOULD SAVE NOTHING
///   Folding a single month into a summary row costs a row and buys none, and it
///   turns a real month into a span of one. With `keeping` + 1 months or fewer the
///   table is returned unchanged.
public enum MonthRollup {

    /// Months shown in full. Six is a half year, which is what a reader scans.
    public static let keep = 6

    /// Returns `months` with everything older than the last `keeping` folded into
    /// a single leading summary row.
    ///
    /// - Parameters:
    ///   - months: Ascending by month, as `ReportData.make` produces them.
    ///   - keeping: How many months stay in full. Returned unchanged when there are
    ///     `keeping` + 1 or fewer, where a summary would fold one month into a span
    ///     of one and cost a row to do it.
    /// - Returns: At most `keeping` + 1 rows, still ascending, the summary first.
    public static func capped(_ months: [MonthStat], keeping: Int = keep) -> [MonthStat] {
        guard months.count > keeping + 1 else { return months }
        let rolled = months.dropLast(keeping)
        let grams = rolled.reduce(0.0) { $0 + $1.totalGrams }
        let days = rolled.reduce(0) { $0 + $1.effectiveDays }
        guard let first = rolled.first, let last = rolled.last else { return months }
        let summary = MonthStat(
            monthKey: last.monthKey,
            drinkDays: rolled.reduce(0) { $0 + $1.drinkDays },
            totalGrams: grams,
            avgPerCalendarDay: days > 0 ? grams / Double(days) : 0,
            daysOverDailyLimit: rolled.reduce(0) { $0 + $1.daysOverDailyLimit },
            effectiveDays: days,
            rollupFromKey: first.monthKey
        )
        return [summary] + months.suffix(keeping)
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
    /// Inclusive first day of the reported period, and the one the header prints.
    ///
    /// The window the caller asked for when it passed both bounds to `make`;
    /// otherwise the first day carrying an entry. Not necessarily a day with
    /// entries — a period may open on dry days, and they belong in it.
    public let firstDate: String
    /// Inclusive last day of the reported period. Set like `firstDate`, except
    /// that a window ending on the running day ends on the day before it until
    /// that day has seen alcohol — see the reporting-window block in `make`.
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
    /// Pairs index-for-index with `weekdayOrder`. Every occurrence of the
    /// weekday in the period is averaged, dry ones included; `nil` means the
    /// weekday does not occur in the period at all.
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
    ///   - periodStart: The user-chosen INCLUSIVE start of the export range, or
    ///     `nil`. With `periodEnd` it bounds the reporting window; see below.
    ///   - periodEnd: The user-chosen INCLUSIVE end of the export range, or `nil`.
    ///     It anchors the abstinence streaks and bounds the window; see below.
    ///   - today: The current logical day. Passed in rather than read from a clock,
    ///     so the figures are reproducible in a test and in a screenshot.
    ///   - timeZone: The zone whose wall clock decides the hour-of-day bucket.
    ///   - locale: Decides which weekday a week starts on. Callers pass the
    ///     REPORT locale — the one `ReportRenderer.Context` gets for labels and
    ///     numbers (`Loc.locale(for: settings.language)`) — so the column order
    ///     of the weekday profile matches the column names printed over it:
    ///     Monday-first under German or Greek headings, Sunday-first under
    ///     US-English ones. The app has no configurable week start. Android's
    ///     `PdfReportData.from` takes the same locale for the same reason (a
    ///     0.84.0 fix: Sunday-first columns under Greek headings in the store
    ///     assets). Until the v0.86.0 review this side left the parameter at the
    ///     DEVICE locale, and the two doc comments each claimed the other port
    ///     did the same as itself. The SCREENS keep the device locale on both
    ///     platforms; only the printed report follows its own language. The
    ///     default exists for tests and stays `.current`; production call
    ///     sites pass the report locale explicitly.
    /// - Returns: `nil` if `entries` is empty.
    public static func make(
        entries: [ConsumptionEntry],
        drinks: [DrinkDefinition],
        settings: AppSettings,
        periodStart: String? = nil,
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

        // The period every denominator below rests on. Its own function: see
        // `reportingWindow` for what the two dates mean and why they are not
        // simply the span of the entries.
        let (firstDate, lastDate) = reportingWindow(
            entries: entries, byDate: byDate,
            periodStart: periodStart, periodEnd: periodEnd, today: today
        )
        let limitInfo = AlcoholCalculator.getLimitInfo(settings)

        let allDays = DayResolver.inclusiveDates(from: firstDate, to: lastDate)
        let totalDays = allDays.count

        // One summary per recorded day, in the shape the shared calculators
        // expect. Built before every figure that rests on it.
        let daySummaries = byDate
            .map { date, dayEntries in
                DaySummary(
                    date: date,
                    totalGrams: dayEntries.reduce(0.0) { $0 + $1.gramsAlcohol },
                    entryCount: dayEntries.count
                )
            }
            .sorted { $0.date < $1.date }

        // The days that saw alcohol. A day of alcohol-free drinks has a summary
        // row and belongs to the reporting period, but it is not a drink day: it
        // counts as abstinent, it stays out of the drink-day divisor, and it does
        // not interrupt a streak (`AlcoholCalculator.isDrinkDay`).
        let drinkDates = AlcoholCalculator.drinkDates(summaries: daySummaries)

        let drinkDays = drinkDates.count
        let abstinentDays = max(totalDays - drinkDays, 0)
        let totalGrams = entries.reduce(0.0) { $0 + $1.gramsAlcohol }
        let avgPerDay = totalDays > 0 ? totalGrams / Double(totalDays) : 0.0
        let avgPerDrinkDay = drinkDays > 0 ? totalGrams / Double(drinkDays) : 0.0

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

        let months = MonthRollup.capped(
            monthStats(
                daySummaries: daySummaries,
                firstDate: firstDate,
                lastDate: lastDate,
                dailyLimitGrams: limitInfo.limitGrams
            )
        )

        // The two per-day series the medians and the rolling peak rest on; see
        // `perDayTotals` and `perDrinkDayTotals` for why they differ.
        let perDayTotals = perDayTotals(daySummaries: daySummaries, allDays: allDays)
        let perDrinkDayTotals = perDrinkDayTotals(daySummaries: daySummaries)

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
                summaries: daySummaries, from: firstDate, to: lastDate,
                firstDayOfWeekIso: firstWeekday
            ),
            longestAbstinence: DayResolver.computeLongestAbstinence(
                sortedDates: drinkDates,
                today: streakAnchor(periodEnd: periodEnd, today: today)
            ),
            currentAbstinence: DayResolver.computeCurrentAbstinence(
                sortedDates: drinkDates,
                today: streakAnchor(periodEnd: periodEnd, today: today)
            )
        )
    }
}

// =============================================================================
// The pieces the computation is assembled from
// =============================================================================
//
// An extension rather than more of the struct body: SwiftLint caps a type body
// at 250 lines and does not count extensions, and these are helpers of the
// computation above rather than part of the value it returns. Several are
// internal rather than private so the test suite can reach them directly.

extension ReportData {

    /// The inclusive period the report covers, as `(first, last)`.
    ///
    /// WHAT THESE TWO DATES DECIDE
    ///   Every denominator rests on them: `totalDays` and the abstinent days, the
    ///   per-day series behind the medians and the rolling peak, the clipped first
    ///   and last month, the chart's axis, and the period the header prints.
    ///
    /// WHY NOT THE SPAN OF THE ENTRIES
    ///   Derived from the entries, they answered a question nobody asked: a July
    ///   export by someone who drank from the 10th to the 20th became a report
    ///   over 11 days, while the Statistics screen divided the same July by 31.
    ///   The export dialog knew the window; it never reached the arithmetic.
    ///
    ///   The window applies when the caller passes BOTH bounds. With neither, or
    ///   with `periodEnd` alone — the shape the historical streak anchor arrived
    ///   in — the entry span stands, so no legacy call changed its figures.
    ///
    /// THE LAST DAY
    ///   A window ending today ends on an unfinished day. Dividing by it deflates
    ///   the average and books it as abstinent before it can become anything, so
    ///   it waits until alcohol is logged on it. That is the rule
    ///   `DayResolver.windowDays` applies for the Statistics screen, expressed
    ///   here as a date because the aggregates need a bound, not a length; the two
    ///   are pinned against each other in ReportDataTests.
    ///
    /// - Parameters:
    ///   - entries: The report's entries, non-empty. Read only for the fallback.
    ///   - byDate: Those entries grouped by logical date, for the drink-day test.
    ///   - periodStart: Inclusive window start, or `nil`.
    ///   - periodEnd: Inclusive window end, or `nil`.
    ///   - today: The current logical day.
    static func reportingWindow(
        entries: [ConsumptionEntry],
        byDate: [String: [ConsumptionEntry]],
        periodStart: String?,
        periodEnd: String?,
        today: String
    ) -> (first: String, last: String) {
        guard let periodStart, let periodEnd else {
            return (entries.map(\.logicalDate).min()!, entries.map(\.logicalDate).max()!)
        }

        let todayGrams = byDate[periodEnd]?.reduce(0.0) { $0 + $1.gramsAlcohol } ?? 0.0
        var windowEnd = periodEnd
        if periodEnd == today,
           !AlcoholCalculator.isDrinkDay(totalGrams: todayGrams),
           let end = DayResolver.parseDate(periodEnd) {
            windowEnd = DayResolver.formatDate(DayResolver.addingDays(-1, to: end))
        }
        // Dropping the unfinished day can empty a window the user did pick —
        // "today only", exported before the first drink of the day. A report over
        // zero days states nothing, so the raw window stands in that one case.
        return (periodStart, windowEnd < periodStart ? periodEnd : windowEnd)
    }

    /// Grams per calendar day over the whole period, dry days as zeros.
    ///
    /// The median and the rolling seven-day peak both need the dry days. Taken
    /// from the summaries alone, the median would describe only the drinking,
    /// which is a different and much less flattering number.
    static func perDayTotals(daySummaries: [DaySummary], allDays: [String]) -> [Double] {
        var totalByDate: [String: Double] = [:]
        for summary in daySummaries { totalByDate[summary.date] = summary.totalGrams }
        return allDays.map { totalByDate[$0] ?? 0.0 }
    }

    /// Grams per DRINK day, dry days left out.
    ///
    /// A 0.0 g day in this list would pull the median of the drinking down to a
    /// figure no drinking day produced.
    static func perDrinkDayTotals(daySummaries: [DaySummary]) -> [Double] {
        daySummaries
            .filter { AlcoholCalculator.isDrinkDay(totalGrams: $0.totalGrams) }
            .map(\.totalGrams)
    }

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

        // The hour a drink was logged at, in the frame it was logged in. Reading
        // every entry in the CURRENT frame moved every bar of a travelled or
        // daylight-saving-crossed history by an hour. `timeZone` is the fallback
        // for entries that recorded no frame.
        var hours = [Double](repeating: 0.0, count: 24)
        for entry in entries {
            calendar.timeZone = DayResolver.displayTimeZone(
                utcOffsetSeconds: entry.utcOffsetSeconds, fallback: timeZone
            )
            let date = Date(timeIntervalSince1970: Double(entry.timestampMillis) / 1000.0)
            let hour = calendar.component(.hour, from: date)
            hours[hour] += entry.gramsAlcohol
        }
        return hours
    }

    /// One row per calendar month the period touches, ascending.
    ///
    /// EVERY such month is listed, the dry ones included. Listing only the months
    /// with entries left a table whose rows did not add up to the period printed
    /// above it: a reader of a January-to-June report that skips April cannot tell
    /// an abstinent month from a missing one, while the abstinent days in the KPIs
    /// counted April all along. In a report meant for a conversation the dry month
    /// is often the row that matters.
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

        return monthKeys(from: firstDate, to: lastDate).compactMap { monthKey -> MonthStat? in
            guard
                let monthStart = DayResolver.parseDate("\(monthKey)-01"),
                let periodStart = DayResolver.parseDate(firstDate),
                let periodEnd = DayResolver.parseDate(lastDate)
            else { return nil }
            let days = byMonth[monthKey] ?? []

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
                drinkDays: AlcoholCalculator.drinkDates(summaries: days).count,
                totalGrams: grams,
                avgPerCalendarDay: grams / Double(effectiveDays),
                daysOverDailyLimit: over,
                effectiveDays: effectiveDays
            )
        }
    }

    /// The `"YYYY-MM"` keys of every calendar month the inclusive period touches,
    /// ascending. A period inside one month yields that one key.
    /// Counted on the year and month numbers rather than on `Date`, so no calendar
    /// or time zone can shift a boundary: the keys are the strings the day
    /// summaries are already grouped by.
    static func monthKeys(from: String, to: String) -> [String] {
        guard let start = DayResolver.parseDate(from), let end = DayResolver.parseDate(to),
              start <= end
        else { return [] }

        let startKey = String(from.prefix(7))
        let endKey = String(to.prefix(7))
        guard
            let startYear = Int(startKey.prefix(4)), let startMonth = Int(startKey.suffix(2)),
            Int(endKey.prefix(4)) != nil, Int(endKey.suffix(2)) != nil
        else { return [] }

        var keys: [String] = []
        var year = startYear
        var month = startMonth
        while true {
            let key = String(format: "%04d-%02d", year, month)
            keys.append(key)
            if key >= endKey { break }
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        }
        return keys
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
