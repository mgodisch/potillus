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
//   Two traps used to make that easy to get wrong. `resolve` now takes the
//   offset the reading was recorded in, so neither reaches it any more; both
//   still apply to `today`, which asks the device zone where the user is now:
//
//   1. TIME ZONES. The same instant is a different logical day in different
//      frames — 23:00 at -04:00 is already 05:00 the next day at +02:00. For a
//      stored entry the frame is the one it recorded, which is why `resolve`
//      takes an offset and looks nothing up. `today` reads the device zone,
//      and that is the whole of the jump described at the Today screen's call
//      site: its "today" moves with the traveller, the entries do not.
//
//   2. DAYLIGHT SAVING TIME. On the spring-forward day the local wall clock
//      jumps 02:00 -> 03:00, so 02:30 does not exist; on the fall-back day
//      01:30 occurs twice. A zone lookup handles both, and `today` gets one.
//      A fixed offset cannot: it knows no switch. That is not a gap in
//      `resolve` but its point — the reading was taken on one side of the
//      switch and keeps that side. The shared vectors read each instant around
//      a switch in both offsets to pin it.
//
// PLATFORM SEAMS NOT PORTED
//   The Android object also carries `clockOverride` / `clock()` and
//   `firstDayOfWeekIso()`. The first two are a test seam for pinning the wall
//   clock during screenshot capture — `today` here takes the instant as a
//   parameter instead, because the callers already hold an injected clock; the
//   last is a locale-driven *visual* detail (which weekday heads the calendar
//   grid) and is reintroduced when the corresponding UI is built, not here.
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

    /// Determines the logical date of a Unix timestamp read in a recorded frame.
    ///
    /// Timestamps *before* the configured day-change time are attributed to the
    /// previous calendar day (02:30 with a 04:00 boundary becomes yesterday).
    ///
    /// THE FRAME IS THE ENTRY'S, NOT THE DEVICE'S. `utcOffsetSeconds` is the
    /// offset recorded when the drink was logged, so the wall-clock reading this
    /// works from is the one the user made. A later flight or a daylight-saving
    /// switch moves the device zone, not the reading, and the entry keeps the day
    /// it was drunk on. Nothing here is looked up in a zone: the offset is all
    /// the frame there is, which is why two readings of the same instant can land
    /// on two different logical days.
    ///
    /// For "which logical day is it right now", where the device zone IS the
    /// answer, use `today(now:changeHour:changeMinute:timeZone:)`.
    ///
    /// - Parameters:
    ///   - timestampMillis: Unix timestamp in milliseconds since the epoch (UTC).
    ///   - utcOffsetSeconds: The offset the reading was taken in, in seconds.
    ///   - changeHour: Hour of the day-change boundary, 0...23.
    ///   - changeMinute: Minute of the day-change boundary, 0...59.
    /// - Returns: The logical date as `yyyy-MM-dd`.
    public static func resolve(
        timestampMillis: Int64,
        utcOffsetSeconds: Int,
        changeHour: Int,
        changeMinute: Int
    ) -> String {
        // The reading is the instant shifted into its own frame. With a fixed
        // offset that is arithmetic, not a lookup, and the components read off it
        // in UTC afterwards ARE the wall clock the user saw. Kotlin does the same
        // through `ZoneOffset.ofTotalSeconds`.
        let reading = Date(
            timeIntervalSince1970: Double(timestampMillis) / 1000.0 + Double(utcOffsetSeconds)
        )
        let parts = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: reading)

        guard let hour = parts.hour, let minute = parts.minute else {
            // Unreachable for the requested components, but Foundation's API is
            // optional-typed; fall back to the raw calendar day.
            return formatDate(reading)
        }

        let isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)

        // Build the calendar day as a zone-free value, then step back one day if
        // the reading falls before the boundary.
        var day = DateComponents()
        day.year = parts.year
        day.month = parts.month
        day.day = parts.day
        day.hour = 12  // noon: keeps the day arithmetic clear of any boundary

        guard let anchored = utcCalendar.date(from: day) else {
            return formatDate(reading)
        }
        let logical = isBeforeChangeTime ? addingDays(-1, to: anchored) : anchored
        return formatDate(logical)
    }

    /// The logical day that is running right now, in the device zone.
    ///
    /// THE ONE PLACE THE DEVICE ZONE STILL DECIDES. `resolve` reads an entry in
    /// the frame the entry recorded; this asks where the user is now, so the
    /// frame comes from `timeZone` for the current instant. Mixing the two is
    /// deliberate and its consequence is known: after a flight, entries can drop
    /// out of the Today screen or appear on it.
    ///
    /// THE INSTANT IS A PARAMETER, not a reading of the system clock, because
    /// every caller already has a clock of its own — the models take one by
    /// injection and the tests pin it. A `today` that read the wall clock itself
    /// would quietly bypass that and tie those tests to the hour the suite runs
    /// at. The Kotlin twin owns its clock seam instead (`DayResolver.clock`),
    /// which is the same decision on a platform where the seam already exists.
    ///
    /// - Parameters:
    ///   - timestampMillis: The current instant, from the caller's clock.
    ///   - changeHour: Hour of the day-change boundary, 0...23.
    ///   - changeMinute: Minute of the day-change boundary, 0...59.
    ///   - timeZone: The device zone. Defaults to `.current`.
    public static func today(
        now timestampMillis: Int64,
        changeHour: Int,
        changeMinute: Int,
        timeZone: TimeZone = .current
    ) -> String {
        resolve(
            timestampMillis: timestampMillis,
            utcOffsetSeconds: utcOffsetSeconds(timestampMillis: timestampMillis, timeZone: timeZone),
            changeHour: changeHour,
            changeMinute: changeMinute
        )
    }

    /// Whether a reading counts toward a logical day other than `logicalDay`.
    ///
    /// The entry sheet is opened on one logical day — today's on the Today
    /// screen, the tapped cell's in the calendar — and the date and time in it
    /// can be moved anywhere. When the two part company, the entry is still
    /// correct, it just belongs elsewhere, and the sheet says which day it is
    /// going to. When they agree there is nothing to say.
    ///
    /// ONE CONDITION, NO SPECIAL CASES. Adding, editing, typing a time, picking a
    /// date, arriving from the calendar: all of them end in a reading and a day
    /// the sheet was opened on, and this compares the two. The sheet decides
    /// nothing itself, which is what keeps the note from appearing on one screen
    /// and not on the other for the same entry.
    ///
    /// - Parameters:
    ///   - timestampMillis: The composed instant of date and time.
    ///   - utcOffsetSeconds: The frame that instant is read in.
    ///   - changeHour: Hour of the day-change boundary, 0...23.
    ///   - changeMinute: Minute of the day-change boundary, 0...59.
    ///   - logicalDay: The logical day the sheet was opened on.
    public static func logicalDayDiffers(
        timestampMillis: Int64,
        utcOffsetSeconds: Int,
        changeHour: Int,
        changeMinute: Int,
        logicalDay: String
    ) -> Bool {
        resolve(
            timestampMillis: timestampMillis,
            utcOffsetSeconds: utcOffsetSeconds,
            changeHour: changeHour,
            changeMinute: changeMinute
        ) != logicalDay
    }

    // ── Date-string helpers ──────────────────────────────────────────────────

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

    /// A `yyyy-MM-dd` logical date, or `nil` when the string is not one.
    ///
    /// Where Kotlin's `LocalDate.parse` throws, this returns an optional: the
    /// Swift idiom for a recoverable parse failure. Callers that must not proceed
    /// on a malformed date say so at their own call site.
    ///
    /// STRICT BY ROUND TRIP, NOT BY LENIENCY
    ///   What `DateFormatter` does with a day its calendar does not have —
    ///   `"2026-02-30"` — is a framework detail: it may refuse it, clamp it to the
    ///   month's last day, or carry it into the next month. This file should not
    ///   rest on which. Kotlin does not settle it either: `DateTimeFormatter`
    ///   resolves SMART and CLAMPS such a day — `"2026-02-30"` comes back as 28
    ///   February — so both sides needed this, and both sides now do it. A
    ///   hand-edited backup would otherwise mean one logical date here and a
    ///   different one there, with neither complaining.
    ///
    ///   Formatting the result back and demanding the original string settles it
    ///   here: a date survives only if it is the canonical spelling of a day that
    ///   exists. `SettingsSanitizer` already applies the same round trip to
    ///   `statsFromDate`; this puts it where every caller gets it.
    ///
    ///   The same rule rejects `"2026-1-1"`, which `DateTimeFormatter` with
    ///   `"yyyy-MM-dd"` also rejects — two digits mean two digits on both sides.
    public static func parseDate(_ dateString: String) -> Date? {
        guard let parsed = dateFormatter.date(from: dateString) else { return nil }
        guard dateFormatter.string(from: parsed) == dateString else { return nil }
        // The formatter yields midnight UTC; re-anchor at noon so later day
        // arithmetic cannot be nudged across a boundary.
        return utcCalendar.date(byAdding: .hour, value: 12, to: parsed)
    }

    /// Formats a `Date` as `yyyy-MM-dd` in UTC.
    public static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // ── The recorded local frame ─────────────────────────────────────────────
    //
    // WHY AN ENTRY CARRIES ITS OWN UTC OFFSET
    //   `logicalDate` is frozen at write time; the clock time was not. It used to
    //   be recomputed from `timestampMillis` and whatever zone the device was in
    //   at READ time, so date and time came from two different frames as soon as
    //   the frame moved. Fly from Berlin to New York and a 23:30 drink still sat
    //   under the 1st but read 17:30. Twice a year the same thing happened
    //   without travelling: after a daylight-saving switch every historical time
    //   shifted by an hour, and with a 04:00 day boundary an entry could end up
    //   displaying a time on the far side of the boundary its own logicalDate
    //   says it is on.
    //
    //   Storing the offset the drink was logged at makes the local frame part of
    //   the record, next to the date that already was. `timestampMillis` stays
    //   the single instant: it is what elapsed-time arithmetic, ordering and
    //   duplicate detection use, and the offset never enters them.
    //
    //   The Kotlin twins are `DayResolver.utcOffsetSeconds` and
    //   `DayResolver.localDateTime`; the shared vectors pin both sides.

    /// The UTC offset in seconds that `timeZone` was at `timestampMillis`.
    ///
    /// Read once, when an entry is written, and stored with it. The zone's
    /// historical rules are consulted for the instant in question, so an entry
    /// logged in winter records the winter offset even if it is written from a
    /// summer clock.
    ///
    /// AN OFFSET, NOT A ZONE NAME, AND THAT IS A PRIVACY DECISION. A name like
    /// `Europe/Berlin` is an address at country level; `+01:00` covers a strip
    /// from the North Cape to Lagos. For an app that calls itself
    /// privacy-friendly, that difference decides it.
    ///
    /// WHAT FOLLOWS FROM IT. An offset says how the clock ran at the moment of
    /// the reading; only a name would say how it ran on another day. So a date
    /// moved across a daylight-saving boundary cannot be kept in its own frame,
    /// and the app reads the DEVICE zone for the new instant — on the assumption
    /// that the phone is where its owner is, the same assumption logging an entry
    /// makes. Move a Berlin entry's date while standing in Tokyo and you get the
    /// Tokyo offset, with the instant jumping eight hours. That is accepted.
    public static func utcOffsetSeconds(
        timestampMillis: Int64, timeZone: TimeZone = .current
    ) -> Int {
        timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0))
    }

    /// The `TimeZone` an entry's clock time should be read in.
    ///
    /// NO FALLBACK, AND NO DEVICE ZONE. Until schema 4 the offset could be nil —
    /// "written before the column existed" — and this derived a replacement from
    /// the device zone on every read. The v4 migration wrote that same
    /// replacement into the rows once and made the column NOT NULL, so the second
    /// code path had nothing left to answer for and is gone. What remains is the
    /// reading the entry recorded, read back as it was taken.
    ///
    /// Returned as a `TimeZone` rather than a `Date`, because every caller on
    /// this side hands the zone to a `DateFormatter` or a `Calendar` instead of
    /// building a wall-clock value itself — the shape Foundation wants, holding
    /// the same fact Kotlin's `localDateTime` returns.
    ///
    /// The `??` is not a fallback in disguise: `TimeZone(secondsFromGMT:)` is
    /// failable and rejects an offset outside ±18 hours, which the backup gate
    /// and the database both refuse long before a value gets here. UTC is what an
    /// impossible number resolves to; nothing in the app can produce one.
    public static func displayTimeZone(utcOffsetSeconds: Int) -> TimeZone {
        TimeZone(secondsFromGMT: utcOffsetSeconds) ?? TimeZone(secondsFromGMT: 0)!
    }

    /// Returns the date `days` calendar days from `date` (negative to go back).
    ///
    /// Goes through `utcCalendar`, so it inherits the noon anchoring that keeps a
    /// day from slipping across a daylight-saving boundary. Adding 86400 seconds
    /// would not: some days are 23 or 25 hours long.
    ///
    /// Public because the report walks months and clips them to a period. It was
    /// private until then, which is why a second copy of it briefly existed here.
    public static func addingDays(_ days: Int, to date: Date) -> Date {
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
        // A malformed date is a bug on this side of the sanitizer (CONTRIBUTING §3):
        // Android throws here, a debug build asserts, a release degrades to 0.
        guard let start = parseDate(from), let end = parseDate(today) else {
            assertionFailure("effectivePeriodDays: non-canonical date \(from) / \(today)")
            return 0
        }
        guard start <= end else { return 0 }
        let completedDays = daysUntil(start, end)  // [from, today) — excludes today
        let days = completedDays + (todayIsDrinkDay ? 1 : 0)
        // Postcondition: the range is non-empty here (start <= end), so the count
        // is never negative; callers divide averages by it. `assert` is compiled
        // out of release builds, mirroring the Kotlin `assert` under -ea.
        assert(days >= 0, "effectivePeriodDays: negative count \(days)")
        return days
    }

    /// Days in the inclusive window `from ... to` that a per-day average may be
    /// divided by, and that an abstinent-day count may be subtracted from.
    ///
    /// WHICH OF TWO RULES APPLIES DEPENDS ON WHERE THE WINDOW ENDS, and that is
    /// the whole point of this function:
    ///
    /// - The window ends TODAY (the statistics screen at offset 0, the Today
    ///   card's month): the last day is still running, so `effectivePeriodDays`
    ///   applies and keeps it out until it resolves.
    /// - The window ends in the PAST (any offset > 0): every day in it is
    ///   finished, the last one included, so all of them count.
    ///
    /// Passing the window's end as if it were today conflated the two and cost the
    /// last day of every past period: July was 30 days long, its average divided
    /// by 30, its abstinent-day count one short, and its final bar drew no
    /// abstinence tick because the bucket believed the day might still become a
    /// drink day (0.85.0 QA round). Callers therefore hand in BOTH the window end
    /// and the real logical day and let this function decide.
    ///
    /// - Parameters:
    ///   - from: Inclusive window start ("yyyy-MM-dd").
    ///   - to: Inclusive window end ("yyyy-MM-dd").
    ///   - today: The real current logical day ("yyyy-MM-dd").
    ///   - todayIsDrinkDay: Whether a drink has already been logged today. Read
    ///     only when the window ends today.
    public static func windowDays(
        from: String, to: String, today: String, todayIsDrinkDay: Bool
    ) -> Int {
        if to == today {
            return effectivePeriodDays(from: from, today: to, todayIsDrinkDay: todayIsDrinkDay)
        }
        guard let start = parseDate(from), let end = parseDate(to) else {
            assertionFailure("windowDays: non-canonical date \(from) / \(to)")
            return 0
        }
        guard start <= end else { return 0 }
        return daysUntil(start, end) + 1  // [from, to] — inclusive
    }
}

// =============================================================================
// Abstinence streaks
// =============================================================================
//
// IN AN EXTENSION, NOT IN THE TYPE BODY. Two reasons, and the second is the
// one that would keep it here anyway: `check-swift-length` holds the type body
// to what SwiftLint's `type_body_length` allows, and an extension is not
// counted; and these three are day COUNTING rather than day RESOLUTION — they
// take logical dates that the rest of this file produced and measure gaps
// between them. Nothing above calls them. The Kotlin twin keeps them in the
// object, which has no such limit, under the same section heading.

extension DayResolver {
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
    ///     May include dates before `statsFrom`; they are dropped HERE, so a
    ///     caller cannot forget to, and a streak never runs across the floor.
    ///     (Until the v0.86.0 review both callers filtered and the vector pinned
    ///     "with entries, statsFrom is ignored".)
    ///   - today: Logical today.
    ///   - statsFrom: Optional recording-start date: the floor for the dates,
    ///     and the streak origin when no drink day remains. It represents the
    ///     assumption that every day from `statsFrom` to today was abstinent.
    /// - Returns: The current abstinence streak in days, never negative.
    public static func computeCurrentAbstinence(
        sortedDates: [String],
        today: String,
        statsFrom: String = ""
    ) -> Int {
        let dates = applyingFloor(sortedDates, statsFrom)
        guard let lastDrink = dates.last else {
            // No drink history: the streak runs from statsFrom to today (exclusive).
            guard !statsFrom.isEmpty, statsFrom < today else { return 0 }
            // A malformed date is a bug on this side of the sanitizer (CONTRIBUTING
            // §3): Android throws here, a debug build asserts, a release degrades.
            guard let start = parseDate(statsFrom), let end = parseDate(today) else {
                assertionFailure("computeCurrentAbstinence: non-canonical date \(statsFrom) / \(today)")
                return 0
            }
            return daysUntil(start, end)
        }

        // Drank today (or, defensively, in the future): no streak has started.
        guard lastDrink < today else { return 0 }
        guard let start = parseDate(lastDrink), let end = parseDate(today) else {
            assertionFailure("computeCurrentAbstinence: non-canonical date \(lastDrink) / \(today)")
            return 0
        }

        // Days strictly between the last drink day and today. `daysUntil` already
        // excludes today; the `- 1` drops the last drink day itself.
        let streak = max(daysUntil(start, end) - 1, 0)
        // Postcondition: an abstinence streak is never negative; `max` is the
        // guard and this verifies it in debug builds.
        assert(streak >= 0, "computeCurrentAbstinence: negative streak \(streak)")
        return streak
    }

    /// The dates on or after `statsFrom`; all of them when the floor is empty.
    private static func applyingFloor(_ sortedDates: [String], _ statsFrom: String) -> [String] {
        statsFrom.isEmpty ? sortedDates : sortedDates.filter { $0 >= statsFrom }
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
    ///   - sortedDates: Ascending, distinct drinking dates. Dates before
    ///     `statsFrom` are dropped here, as in `computeCurrentAbstinence`: a gap
    ///     must not span the floor.
    ///   - today: Logical today. When empty, the tail gap is ignored — the
    ///     conservative behaviour for backward-compatible callers.
    ///   - statsFrom: Optional recording start; enables the initial gap and
    ///     floors the dates.
    public static func computeLongestAbstinence(
        sortedDates: [String],
        today: String = "",
        statsFrom: String = ""
    ) -> Int {
        let dates = applyingFloor(sortedDates, statsFrom)
        guard let firstDrink = dates.first, let lastDrink = dates.last else {
            // No drink history: the longest run equals the current streak.
            guard !today.isEmpty, !statsFrom.isEmpty, statsFrom < today else { return 0 }
            guard let start = parseDate(statsFrom), let end = parseDate(today) else {
                assertionFailure("computeLongestAbstinence: non-canonical date \(statsFrom) / \(today)")
                return 0
            }
            return daysUntil(start, end)
        }

        var longest = 0

        // Every parse below is of a date the database or the sanitizer wrote; a
        // failure is a bug (CONTRIBUTING §3), so a debug build asserts and a
        // release build skips the gap, where Android's throw would stop.

        // 1. Initial gap: statsFrom → first drink.
        if !statsFrom.isEmpty, statsFrom < firstDrink {
            if let start = parseDate(statsFrom), let end = parseDate(firstDrink) {
                longest = max(longest, daysUntil(start, end))
            } else {
                assertionFailure("computeLongestAbstinence: non-canonical date \(statsFrom) / \(firstDrink)")
            }
        }

        // 2. Inter-drink gaps. A single-element list yields the empty range 1..<1.
        for index in 1..<dates.count {
            guard let previous = parseDate(dates[index - 1]),
                  let current = parseDate(dates[index])
            else {
                assertionFailure("computeLongestAbstinence: non-canonical date \(dates[index - 1]) / \(dates[index])")
                continue
            }
            longest = max(longest, daysUntil(previous, current) - 1)
        }

        // 3. Tail gap: last drink → today.
        if !today.isEmpty, lastDrink < today {
            if let start = parseDate(lastDrink), let end = parseDate(today) {
                longest = max(longest, max(daysUntil(start, end) - 1, 0))
            } else {
                assertionFailure("computeLongestAbstinence: non-canonical date \(lastDrink) / \(today)")
            }
        }

        return longest
    }
}
