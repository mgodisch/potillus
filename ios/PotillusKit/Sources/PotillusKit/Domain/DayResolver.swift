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
// DayResolver.swift – logical-day arithmetic
// =============================================================================
//
// A faithful Swift port of the Android `domain/DayResolver.kt`. All functions
// are pure: the same input always yields the same output, with no side effects.
//
// WHY THIS FILE IS THE RISKIEST PORT IN THE PROJECT
//   The "logical day" boundary decides which calendar day an entry belongs to.
//   A drink at 02:30 with a 04:00 boundary counts toward the *previous* evening.
//   Every downstream figure — daily totals, the rolling seven-day window, the
//   violation counts, the streaks — is built on that assignment. If Android and
//   iOS disagreed by one day, a backup exported on one platform would produce
//   different statistics on the other, silently.
//
//   Two traps make that easy to get wrong:
//
//   1. TIME ZONES. `resolve` takes an *absolute* instant (epoch milliseconds)
//      plus the zone it should be interpreted in. The same instant is a
//      different logical day in different zones — 23:00 in New York is already
//      05:00 the next day in Berlin. The zone is therefore an explicit
//      parameter, never an implicit global.
//
//   2. DAYLIGHT SAVING TIME. On the spring-forward day the local wall clock
//      jumps 02:00 -> 03:00, so 02:30 does not exist; on the fall-back day
//      01:30 occurs twice. Deriving the wall-clock hour from the instant *via
//      the zone* (as both platforms do) handles this correctly, whereas naive
//      millisecond arithmetic would not. The shared vectors cover both edges.
//
// PLATFORM SEAMS NOT PORTED
//   The Android object also carries `clockOverride` / `clock()` / `today()` and
//   `firstDayOfWeekIso()`. The first three are a test seam for pinning the wall
//   clock during screenshot capture; the last is a locale-driven *visual* detail
//   (which weekday heads the calendar grid). Both are platform concerns and are
//   reintroduced on the iOS side when the corresponding UI is built, not here.
// =============================================================================

public enum DayResolver {

    // ── Calendar plumbing ────────────────────────────────────────────────────
    //
    // Kotlin's `java.time.LocalDate` is a date with no time and no zone.
    // Foundation has no such type, so calendar-day arithmetic is done on a
    // `Calendar` pinned to UTC, with each day anchored at 12:00 rather than
    // midnight. Noon is the standard defence: a DST shift of ±1 hour can never
    // move a noon timestamp across a day boundary, while a midnight one can.
    //
    // This is *only* for date-string arithmetic. `resolve` deliberately uses the
    // caller's zone, because there the wall-clock reading is the whole point.

    /// A Gregorian calendar pinned to UTC, for zone-independent day arithmetic.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// Canonical date format, ISO-8601 `yyyy-MM-dd`.
    ///
    /// Lexicographic ordering equals chronological ordering, so SQL `ORDER BY`
    /// and plain string comparison (`date >= statsFrom`) both work.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        // A fixed POSIX locale, so the formatter never adopts a device locale's
        // alternate calendar or numerals. Without this, the same code prints
        // Buddhist-era years on a Thai device.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // ── Core resolution ──────────────────────────────────────────────────────

    /// Determines the logical date of a Unix timestamp.
    ///
    /// Timestamps *before* the configured day-change time are attributed to the
    /// previous calendar day (02:30 with a 04:00 boundary becomes yesterday).
    ///
    /// - Parameters:
    ///   - timestampMillis: Unix timestamp in milliseconds since the epoch (UTC).
    ///   - changeHour: Hour of the day-change boundary, 0...23.
    ///   - changeMinute: Minute of the day-change boundary, 0...59.
    ///   - timeZone: Zone the instant is interpreted in. Defaults to the device
    ///     zone, mirroring the Kotlin default of `ZoneId.systemDefault()`.
    /// - Returns: The logical date as `yyyy-MM-dd`.
    public static func resolve(
        timestampMillis: Int64,
        changeHour: Int,
        changeMinute: Int,
        timeZone: TimeZone = .current
    ) -> String {
        let instant = Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)

        // Read the wall clock *in the given zone*. This is what makes DST work:
        // Foundation resolves the instant against the zone's offset rules, so a
        // spring-forward gap or a fall-back repetition is handled for us.
        var zoned = Calendar(identifier: .gregorian)
        zoned.timeZone = timeZone
        let parts = zoned.dateComponents([.year, .month, .day, .hour, .minute], from: instant)

        guard let hour = parts.hour, let minute = parts.minute else {
            // Unreachable for the requested components, but Foundation's API is
            // optional-typed; fall back to the raw calendar day.
            return format(instant, in: timeZone)
        }

        let isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)

        // Build the calendar day as a zone-free value, then step back one day if
        // the instant falls before the boundary.
        var day = DateComponents()
        day.year = parts.year
        day.month = parts.month
        day.day = parts.day
        day.hour = 12  // noon: DST-proof anchor for the subsequent day arithmetic

        guard let anchored = utcCalendar.date(from: day) else {
            return format(instant, in: timeZone)
        }
        let logical = isBeforeChangeTime ? addingDays(-1, to: anchored) : anchored
        return formatDate(logical)
    }

    /// Formats an instant as `yyyy-MM-dd` in the given zone. Fallback path only.
    private static func format(_ instant: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: instant)
    }

    // ── Date-string helpers ──────────────────────────────────────────────────

    /// Parses a `yyyy-MM-dd` string into a UTC-noon `Date`. Returns `nil` if the
    /// string is malformed.
    ///
    /// Unlike Kotlin's `LocalDate.parse`, which throws, this returns an optional:
    /// the Swift idiom for a recoverable parse failure.
    /// The locale's first day of the week, as an ISO-8601 weekday number
    /// (1 = Monday … 7 = Sunday).
    ///
    /// Two numbering schemes meet here, and confusing them shifts the whole
    /// calendar grid by a day:
    ///   - `Calendar.firstWeekday` counts 1 = SUNDAY … 7 = Saturday.
    ///   - ISO-8601, which Kotlin's `WeekFields.of(locale).firstDayOfWeek.value`
    ///     returns, counts 1 = MONDAY … 7 = Sunday.
    ///
    /// So Sunday is 1 in one scheme and 7 in the other, and every other day is off
    /// by one. The conversion below is the whole reason this function exists
    /// rather than a bare `Calendar.current.firstWeekday` at the call site.
    public static func firstDayOfWeekIso(locale: Locale = .current) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let sundayBased = calendar.firstWeekday          // 1 = Sunday … 7 = Saturday
        return sundayBased == 1 ? 7 : sundayBased - 1    // 1 = Monday … 7 = Sunday
    }

    public static func parseDate(_ dateString: String) -> Date? {
        guard let parsed = dateFormatter.date(from: dateString) else { return nil }
        // The formatter yields midnight UTC; re-anchor at noon so later day
        // arithmetic cannot be nudged across a boundary.
        return utcCalendar.date(byAdding: .hour, value: 12, to: parsed)
    }

    /// Formats a `Date` as `yyyy-MM-dd` in UTC.
    public static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// Returns the date `days` calendar days from `date` (negative to go back).
    private static func addingDays(_ days: Int, to date: Date) -> Date {
        utcCalendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Whole calendar days in the half-open range `[from, to)`, never negative.
    ///
    /// This is the analogue of Kotlin's `from.datesUntil(to).count()`: the end is
    /// *exclusive*, which is exactly what the abstinence and period-length rules
    /// below rely on.
    private static func daysUntil(_ from: Date, _ to: Date) -> Int {
        let components = utcCalendar.dateComponents([.day], from: from, to: to)
        return max(components.day ?? 0, 0)
    }

    // ── Day arithmetic ───────────────────────────────────────────────────────

    /// The date `count` days after `date`.
    ///
    /// Goes through `utcCalendar`, so it inherits the noon anchoring that keeps a
    /// day from slipping across a daylight-saving boundary. Adding 86400 seconds
    /// would not: some days are 23 or 25 hours long.
    public static func addingDays(_ count: Int, to date: Date) -> Date {
        utcCalendar.date(byAdding: .day, value: count, to: date) ?? date
    }

    /// Every date from `from` to `to`, INCLUSIVE, ascending. Empty if `to < from`
    /// or either string is malformed.
    ///
    /// The report uses this to give abstinent days a row of their own: a day with
    /// no entries has no key in the log, yet it must still contribute a zero to the
    /// median and to the rolling seven-day window.
    public static func inclusiveDates(from: String, to: String) -> [String] {
        guard let start = parseDate(from), let end = parseDate(to), start <= end else {
            return []
        }
        var dates: [String] = []
        var day = start
        while day <= end {
            dates.append(formatDate(day))
            day = addingDays(1, to: day)
        }
        return dates
    }

    // ── Period length ────────────────────────────────────────────────────────

    /// Number of *effective* days in the inclusive range `[from, today]` for the
    /// app's per-day averages, applying the "today counts only once it is a drink
    /// day" rule.
    ///
    /// The in-progress current day is in superposition: until a drink is logged
    /// it may still become either a drink day or an abstinent day, so it is kept
    /// out of the denominator; logging a drink resolves it and it joins the
    /// period immediately:
    ///
    ///     effectivePeriodDays = completedDays(from … the day before today)
    ///                           + (todayIsDrinkDay ? 1 : 0)
    ///
    /// Returns `0` when `from` is after `today` (an empty or inverted range);
    /// callers guard against dividing by zero.
    public static func effectivePeriodDays(from: String, today: String, todayIsDrinkDay: Bool) -> Int {
        guard let start = parseDate(from), let end = parseDate(today), start <= end else { return 0 }
        let completedDays = daysUntil(start, end)  // [from, today) — excludes today
        let days = completedDays + (todayIsDrinkDay ? 1 : 0)
        // Postcondition: the range is non-empty here (start <= end), so the count
        // is never negative; callers divide averages by it. `assert` is compiled
        // out of release builds, mirroring the Kotlin `assert` under -ea.
        assert(days >= 0, "effectivePeriodDays: negative count \(days)")
        return days
    }

    // ── Abstinence streaks ───────────────────────────────────────────────────

    /// Completed, alcohol-free days since the most recent drink — or since
    /// `statsFrom` when there is no drink history yet.
    ///
    /// A day counts only once it has *finished* alcohol-free. Both endpoints are
    /// therefore excluded: the last drink day (never abstinent) and the current
    /// day (still in progress). So the day right after a drink day still yields
    /// `0`; the count becomes `1` only on the day after that.
    ///
    /// - Parameters:
    ///   - sortedDates: Ascending, distinct logical dates that have ≥ 1 drink.
    ///   - today: Logical today.
    ///   - statsFrom: Optional recording-start date, used as the streak origin
    ///     when there is no drink history. It represents the assumption that
    ///     every day from `statsFrom` to today was abstinent.
    /// - Returns: The current abstinence streak in days, never negative.
    public static func computeCurrentAbstinence(
        sortedDates: [String],
        today: String,
        statsFrom: String = ""
    ) -> Int {
        guard let lastDrink = sortedDates.last else {
            // No drink history: the streak runs from statsFrom to today (exclusive).
            guard !statsFrom.isEmpty, statsFrom < today,
                  let start = parseDate(statsFrom), let end = parseDate(today)
            else { return 0 }
            return daysUntil(start, end)
        }

        // Drank today (or, defensively, in the future): no streak has started.
        guard lastDrink < today,
              let start = parseDate(lastDrink), let end = parseDate(today)
        else { return 0 }

        // Days strictly between the last drink day and today. `daysUntil` already
        // excludes today; the `- 1` drops the last drink day itself.
        let streak = max(daysUntil(start, end) - 1, 0)
        // Postcondition: an abstinence streak is never negative; `max` is the
        // guard and this verifies it in debug builds.
        assert(streak >= 0, "computeCurrentAbstinence: negative streak \(streak)")
        return streak
    }

    /// The longest recorded abstinence run, in days.
    ///
    /// Three kinds of gap are considered:
    ///
    /// 1. **Initial gap** (`statsFrom` → first drink). `statsFrom` is itself an
    ///    abstinent day, so no adjustment is needed.
    /// 2. **Inter-drink gaps** (between consecutive drink days). Neither endpoint
    ///    is abstinent, so subtract one.
    /// 3. **Tail gap** (last drink → `today`). Same semantics as
    ///    `computeCurrentAbstinence`: both endpoints are non-abstinent.
    ///
    /// - Parameters:
    ///   - sortedDates: Ascending, distinct drinking dates.
    ///   - today: Logical today. When empty, the tail gap is ignored — the
    ///     conservative behaviour for backward-compatible callers.
    ///   - statsFrom: Optional recording start; enables the initial gap.
    public static func computeLongestAbstinence(
        sortedDates: [String],
        today: String = "",
        statsFrom: String = ""
    ) -> Int {
        guard let firstDrink = sortedDates.first, let lastDrink = sortedDates.last else {
            // No drink history: the longest run equals the current streak.
            guard !today.isEmpty, !statsFrom.isEmpty, statsFrom < today,
                  let start = parseDate(statsFrom), let end = parseDate(today)
            else { return 0 }
            return daysUntil(start, end)
        }

        var longest = 0

        // 1. Initial gap: statsFrom → first drink.
        if !statsFrom.isEmpty, statsFrom < firstDrink,
           let start = parseDate(statsFrom), let end = parseDate(firstDrink) {
            longest = max(longest, daysUntil(start, end))
        }

        // 2. Inter-drink gaps. A single-element list yields the empty range 1..<1.
        for index in 1..<sortedDates.count {
            guard let previous = parseDate(sortedDates[index - 1]),
                  let current = parseDate(sortedDates[index])
            else { continue }
            longest = max(longest, daysUntil(previous, current) - 1)
        }

        // 3. Tail gap: last drink → today.
        if !today.isEmpty, lastDrink < today,
           let start = parseDate(lastDrink), let end = parseDate(today) {
            longest = max(longest, max(daysUntil(start, end) - 1, 0))
        }

        return longest
    }
}
