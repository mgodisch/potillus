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
// ChartBucketing.swift – turning sparse day totals into chart bars
// =============================================================================
//
// A faithful Swift port of the Android `domain/ChartBucketing.kt`.
//
// The database stores only days that HAVE entries. A chart, however, needs a
// continuous axis: an abstinent Tuesday must appear as a zero-height bar, not as
// a missing one. Bucketing expands the sparse data into a gap-free series, and —
// for longer spans — aggregates days into weeks or months so the bar count stays
// readable.
//
// All calendar arithmetic runs on a UTC-pinned calendar, for the same reason as
// in `DayResolver`: bucket boundaries must be pure calendar-day computations, so
// a device time zone or a DST transition can never shift a bar.
// =============================================================================

/// Bucket width for a chart.
public enum ChartGranularity: String, Sendable, Equatable, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
}

/// One bar of a chart.
public struct ChartBucket: Sendable, Equatable {

    /// The bucket's first calendar day, `yyyy-MM-dd`; used as the axis label.
    public let labelDate: String

    /// Mean grams of alcohol per day over the days this bucket actually covers.
    public let avgPerDay: Double

    /// True when the bucket was recorded fully alcohol-free AND is a completed
    /// period. A bucket still containing the in-progress day never qualifies.
    public let isAbstinent: Bool

    public init(labelDate: String, avgPerDay: Double, isAbstinent: Bool) {
        self.labelDate = labelDate
        self.avgPerDay = avgPerDay
        self.isAbstinent = isAbstinent
    }
}

public enum ChartBucketing {

    /// A Gregorian calendar pinned to UTC, so bucket boundaries are
    /// zone-independent. See `DayResolver` for why days are anchored at noon.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// Picks a sensible granularity for an ARBITRARY span (used by the PDF
    /// export, whose date range is whatever the user chose, not week/month/year):
    /// up to 35 days one bar per day, up to 366 days one bar per week (at most
    /// ~53 bars), otherwise one bar per month.
    ///
    /// - Parameter days: Number of calendar days in the inclusive span.
    public static func granularityForSpan(days: Int) -> ChartGranularity {
        if days <= 35 { return .daily }
        if days <= 366 { return .weekly }
        return .monthly
    }

    /// Expands sparse `summaries` (days WITH entries only) into a continuous,
    /// gap-free list of buckets covering the inclusive range `from...to`.
    ///
    /// Missing days contribute 0 g, so abstinent days appear as zero-value
    /// buckets. Buckets are clamped to the period end, so the last week or month
    /// may be shorter than a full one, and its average is taken over the days that
    /// actually fall inside the period.
    ///
    /// **The in-progress day ("today in superposition").** When `inProgressDay` is
    /// given — the current logical day, which on screen equals `to` — the bucket
    /// containing it applies the app's per-day rule in two distinct ways:
    ///
    /// 1. **Average.** While the day is not yet a drink day it is dropped from the
    ///    divisor, so the average is taken over completed days only. The bucket's
    ///    sum already excludes the empty day, so only the divisor changes. This
    ///    mirrors `DayResolver.effectivePeriodDays`, keeping the chart in step
    ///    with the Statistics summary and the Today card.
    ///
    /// 2. **Abstinence.** A bucket that still holds the open day is not a
    ///    *completed* period, so it must never be flagged abstinent. The green
    ///    tick promises "this whole period was recorded alcohol-free", and that
    ///    claim cannot be settled while today is still running: the day could yet
    ///    become a drink day before the day-change time.
    ///
    /// The PDF export passes `nil`, so historical reports count every calendar day
    /// and every zero bucket is a finished, abstinent one.
    ///
    /// - Parameters:
    ///   - summaries: Daily totals for days that have entries.
    ///   - from: Inclusive period start, `yyyy-MM-dd`.
    ///   - to: Inclusive period end, `yyyy-MM-dd`.
    ///   - granularity: Bucket width; see `granularityForSpan(days:)`.
    ///   - inProgressDay: Optional current logical day.
    /// - Returns: Buckets in chronological order, or empty when `from > to` or a
    ///   date fails to parse.
    public static func bucketize(
        summaries: [DaySummary],
        from: String,
        to: String,
        granularity: ChartGranularity,
        inProgressDay: String? = nil
    ) -> [ChartBucket] {
        guard let start = DayResolver.parseDate(from),
              let end = DayResolver.parseDate(to),
              start <= end
        else { return [] }

        // O(1) lookup of a day's total; days absent here are abstinent (0 g).
        var gramsByDate: [String: Double] = [:]
        for summary in summaries { gramsByDate[summary.date] = summary.totalGrams }

        // One day past the period end; the exclusive upper bound when summing.
        let endExclusive = addingDays(1, to: end)

        var buckets: [ChartBucket] = []
        var bucketStart = start

        while bucketStart <= end {
            // Natural (un-clamped) end of this bucket, exclusive.
            let naturalEndExclusive: Date
            switch granularity {
            case .daily:
                naturalEndExclusive = addingDays(1, to: bucketStart)
            case .weekly:
                naturalEndExclusive = addingDays(7, to: bucketStart)
            case .monthly:
                // Month buckets snap to the 1st of the next month, so successive
                // buckets align to calendar months even when the first one starts
                // mid-month.
                naturalEndExclusive = firstOfNextMonth(after: bucketStart)
            }

            // Never let a bucket run past the period.
            let cappedEndExclusive = min(naturalEndExclusive, endExclusive)

            var sum = 0.0
            var dayCount = 0
            var day = bucketStart
            while day < cappedEndExclusive {
                sum += gramsByDate[DayResolver.formatDate(day)] ?? 0.0
                dayCount += 1
                day = addingDays(1, to: day)
            }

            // See the two consequences documented above.
            var bucketHoldsInProgressDay = false
            if let inProgressDay, let inProgress = DayResolver.parseDate(inProgressDay) {
                let isInBucket = inProgress >= bucketStart && inProgress < cappedEndExclusive
                let isDrinkDay = (gramsByDate[inProgressDay] ?? 0.0) > 0.0
                bucketHoldsInProgressDay = isInBucket
                if isInBucket && !isDrinkDay && dayCount > 0 { dayCount -= 1 }
            }

            buckets.append(
                ChartBucket(
                    labelDate: DayResolver.formatDate(bucketStart),
                    avgPerDay: dayCount > 0 ? sum / Double(dayCount) : 0.0,
                    // Abstinent = recorded fully alcohol-free AND a completed
                    // period. The guard is consequence (2): the current
                    // day/week/month never earns a tick until it closes.
                    isAbstinent: sum == 0.0 && !bucketHoldsInProgressDay
                )
            )

            // Advancing to the capped end (not the natural one) is what makes the
            // loop terminate on the final, possibly short, bucket.
            bucketStart = cappedEndExclusive
        }

        // Invariant: the loop always advances, so a non-empty range yields at
        // least one bucket.
        assert(!buckets.isEmpty, "bucketize: non-empty range produced no buckets")
        return buckets
    }

    // ── Calendar helpers ─────────────────────────────────────────────────────

    private static func addingDays(_ days: Int, to date: Date) -> Date {
        utcCalendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// The first day of the month following `date`'s month, at the same noon
    /// anchor. Equivalent to Kotlin's `withDayOfMonth(1).plusMonths(1)`.
    private static func firstOfNextMonth(after date: Date) -> Date {
        var parts = utcCalendar.dateComponents([.year, .month], from: date)
        parts.day = 1
        parts.hour = 12
        guard let firstOfThisMonth = utcCalendar.date(from: parts),
              let next = utcCalendar.date(byAdding: .month, value: 1, to: firstOfThisMonth)
        else { return addingDays(1, to: date) }
        return next
    }
}
