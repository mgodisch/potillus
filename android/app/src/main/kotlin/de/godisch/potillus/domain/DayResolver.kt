/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.domain

import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.temporal.WeekFields
import java.util.Locale

/**
 * Calculates logical dates by applying a configurable day-change time.
 *
 * All methods are pure functions: same input always produces the same output,
 * with no observable side effects. This makes them straightforward to unit-test
 * (see `DayResolverTest`).
 */
object DayResolver {

    /**
     * Canonical date format "YYYY-MM-DD" (ISO 8601).
     *
     * Lexicographic ordering equals chronological ordering – SQL ORDER BY
     * and String comparison (e.g. `date >= statsFrom`) work correctly.
     */
    val DATE_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    /**
     * Determines the logical date of a Unix timestamp.
     *
     * Timestamps BEFORE the configured day-change time are attributed to the
     * previous calendar day (e.g. 02:30 AM with a 04:00 boundary → yesterday).
     *
     * @param timestampMillis  Unix timestamp in milliseconds (UTC).
     * @param changeHour       Hour of the day-change boundary (0–23).
     * @param changeMinute     Minute of the day-change boundary (0–59).
     * @param zoneId           Timezone for conversion. Defaults to system timezone.
     * @return Logical date as "YYYY-MM-DD".
     */
    fun resolve(
        timestampMillis: Long,
        changeHour: Int,
        changeMinute: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): String {
        val localDateTime = LocalDateTime.ofInstant(
            Instant.ofEpochMilli(timestampMillis),
            zoneId,
        )
        val isBeforeChangeTime =
            localDateTime.hour < changeHour ||
                (localDateTime.hour == changeHour && localDateTime.minute < changeMinute)

        val logicalDate: LocalDate = if (isBeforeChangeTime) {
            localDateTime.toLocalDate().minusDays(1)
        } else {
            localDateTime.toLocalDate()
        }
        return logicalDate.format(DATE_FORMATTER)
    }

    /**
     * The inverse of [resolve]: the instant a wall-clock time on a logical date
     * falls on.
     *
     * A logical day runs from the day-change time to the next one, so a time
     * BEFORE the boundary belongs to the following calendar day: with a 04:00
     * boundary, 01:00 on the logical 30th is 01:00 on the calendar 31st. Reading
     * the calendar day off the logical date alone is what put an entry logged for
     * a past evening on today's clock.
     *
     * @param logicalDate  The logical day as "YYYY-MM-DD".
     * @param hour         Wall-clock hour on that logical day (0–23).
     * @param minute       Wall-clock minute (0–59).
     * @param changeHour   Hour of the day-change boundary (0–23).
     * @param changeMinute Minute of the day-change boundary (0–59).
     * @param zoneId       Timezone the wall clock is read in.
     * @return The instant in milliseconds, or null when [logicalDate] is not a
     *   canonical date. A wall-clock time that does not exist in the zone (the
     *   spring-forward gap) resolves to the instant the zone offers instead,
     *   which is what `ZonedDateTime` does with a gap.
     */
    fun instantOnLogicalDate(
        logicalDate: String,
        hour: Int,
        minute: Int,
        changeHour: Int,
        changeMinute: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Long? {
        val day = try {
            LocalDate.parse(logicalDate, DATE_FORMATTER)
        } catch (_: DateTimeParseException) {
            return null
        }

        val isBeforeChangeTime = hour < changeHour || (hour == changeHour && minute < changeMinute)
        val calendarDay = if (isBeforeChangeTime) day.plusDays(1) else day

        return calendarDay.atTime(hour, minute).atZone(zoneId).toInstant().toEpochMilli()
    }

    /**
     * The same, taking the wall-clock time from an existing instant.
     *
     * The entry dialog offers hours and minutes only, so the instant it returns
     * carries the date of the day it was opened on. The calendar needs the time
     * off it and the day from elsewhere.
     */
    fun instantOnLogicalDate(
        logicalDate: String,
        timestampMillis: Long,
        changeHour: Int,
        changeMinute: Int,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Long? {
        val clockTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(timestampMillis), zoneId)
        return instantOnLogicalDate(
            logicalDate = logicalDate,
            hour = clockTime.hour,
            minute = clockTime.minute,
            changeHour = changeHour,
            changeMinute = changeMinute,
            zoneId = zoneId,
        )
    }

    /**
     * The CALENDAR date an instant falls on, "YYYY-MM-DD", read in [zoneId].
     *
     * Not the logical date — [resolve] answers that. The entry dialog shows this
     * beside the time it is about to store when the two dates differ: a
     * drink typed as "02:00" on the logical 10th is placed on the calendar 11th
     * by [instantOnLogicalDate], and the dialog says so, so what the user sees
     * is what the row will read. Pinned with iOS by `day-resolver.json`
     * (`calendarDate`).
     */
    fun calendarDate(timestampMillis: Long, zoneId: ZoneId = ZoneId.systemDefault()): String =
        formatDate(LocalDateTime.ofInstant(Instant.ofEpochMilli(timestampMillis), zoneId).toLocalDate())

    /**
     * Test-only override for the wall clock that [today] reads.
     *
     * PRODUCTION (the default, `null`): [today] reads the real device clock, so
     * behaviour is identical to a direct `System.currentTimeMillis()` call — this
     * seam changes nothing for shipped builds.
     *
     * INSTRUMENTATION / SCREENSHOTS ONLY: a test may pin a fixed [Clock] here so
     * that every date-relative surface renders from one reproducible logical day.
     * Because Today, Calendar, Statistics and the PDF report all derive "today"
     * exclusively through [today], pinning this single field pins the perspective
     * of the whole app at once. That is what lets `make screenshots-android` capture from
     * a fixed date on ANY device — including a locked production phone, where the
     * Makefile's `adb shell date` pin is silently rejected and the device keeps
     * its real date. The capture suite sets it in its `@Before` and clears it in
     * its `@After` (see `ScreenshotClock`, `ScreenshotTest`, `ReportExportTest`).
     *
     * Marked `@Volatile` because it is written from the instrumentation thread and
     * read from the UI / flow-collector threads that evaluate [today].
     */
    @Volatile
    var clockOverride: Clock? = null

    /**
     * The effective wall clock: the pinned test clock when [clockOverride] is set,
     * otherwise the real system clock ([Clock.systemDefaultZone]).
     *
     * Prefer this over calling `LocalDate.now()`, `YearMonth.now()` or
     * `System.currentTimeMillis()` directly for anything that determines
     * date-relative UI: passing this clock (e.g. `YearMonth.now(DayResolver.clock())`)
     * makes that surface honour the screenshot pin too, instead of silently reading
     * the real device clock. In production (override `null`) it is exactly the
     * system clock, so behaviour is unchanged.
     */
    fun clock(): Clock = clockOverride ?: Clock.systemDefaultZone()

    /**
     * Returns today's logical date.
     *
     * The wall-clock reading comes from [clock] (the pinned test clock when set,
     * otherwise the real device clock); the resulting instant is then run through
     * [resolve] so the configured day-change boundary is honoured either way.
     */
    fun today(changeHour: Int, changeMinute: Int): String = resolve(clock().millis(), changeHour, changeMinute)

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

    /**
     * The UTC offset in seconds that [zoneId] was at [timestampMillis].
     *
     * Read once, when an entry is written, and stored with it. The zone's
     * historical rules are consulted for the instant in question, so an entry
     * logged in winter records the winter offset even if it is written from a
     * summer clock.
     *
     * @param timestampMillis Unix timestamp in milliseconds (UTC).
     * @param zoneId          Timezone to read the offset from. Defaults to the
     *                        device zone, which is what a live log wants.
     */
    fun utcOffsetSeconds(timestampMillis: Long, zoneId: ZoneId = ZoneId.systemDefault()): Int =
        zoneId.rules.getOffset(Instant.ofEpochMilli(timestampMillis)).totalSeconds

    /**
     * The local wall-clock time of [timestampMillis] in the frame [utcOffsetSeconds].
     *
     * NULL MEANS "NOT RECORDED", NOT "UTC". Entries written before the offset
     * existed, and entries read from a backup that predates it, carry no frame.
     * They fall back to what the app did for all of them until now: the device
     * zone's rules for that instant. For anyone who has not changed zones that
     * reproduces the previous display exactly, and it gets past daylight-saving
     * switches right, because the rules are historical rather than current.
     *
     * @param timestampMillis  Unix timestamp in milliseconds (UTC).
     * @param utcOffsetSeconds The recorded offset, or `null` when the entry
     *                         predates the column.
     * @param zoneId           Zone used for the fallback only.
     */
    fun localDateTime(
        timestampMillis: Long,
        utcOffsetSeconds: Int?,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): LocalDateTime {
        val instant = Instant.ofEpochMilli(timestampMillis)
        val offset = utcOffsetSeconds?.let(ZoneOffset::ofTotalSeconds)
            ?: zoneId.rules.getOffset(instant)
        return LocalDateTime.ofInstant(instant, offset)
    }

    /**
     * Parses a canonical `"YYYY-MM-DD"` date.
     *
     * STRICT BY ROUND TRIP, NOT BY RESOLVER STYLE
     *   [DATE_FORMATTER] resolves SMART, which CLAMPS a day the month does not
     *   have instead of refusing it: `"2026-02-30"` comes back as 28 February and
     *   `"2026-04-31"` as 30 April, silently. Only structurally wrong input —
     *   `"2026-1-1"`, `"2026-13-01"` — throws.
     *
     *   Switching the formatter to STRICT is not the fix: STRICT reads `yyyy` as a
     *   year-of-era and then wants an era to go with it. Formatting the result back
     *   and demanding the original string is the fix, and it is what
     *   [BackupManager] already did at its own gate before this was here.
     *
     * @throws DateTimeParseException When [dateStr] is not a date, or not the
     *         canonical spelling of a day that exists. iOS `DayResolver.parseDate`
     *         returns nil on the same inputs.
     */
    fun parseDate(dateStr: String): LocalDate {
        val parsed = LocalDate.parse(dateStr, DATE_FORMATTER)
        if (formatDate(parsed) != dateStr) {
            throw DateTimeParseException("Not a canonical calendar date: $dateStr", dateStr, 0)
        }
        return parsed
    }

    /** Formats a [LocalDate] as "YYYY-MM-DD". */
    fun formatDate(date: LocalDate): String = date.format(DATE_FORMATTER)

    /**
     * Number of *effective* days in the inclusive range [[from], [today]] for the
     * app's per-day averages, applying the "today counts only once it is a drink
     * day" rule.
     *
     * The in-progress current day is in superposition: until a drink is logged it
     * may still become either a drink day or an abstinent day, so it is kept out
     * of the denominator; logging a drink resolves it to a drink day and it joins
     * the period immediately. Hence:
     *
     *     effectivePeriodDays = completedDays(from … the day before today)
     *                           + (todayIsDrinkDay ? 1 : 0)
     *
     * `datesUntil`'s end is exclusive, so `from.datesUntil(today)` is exactly the
     * completed days. Returns 0 when [from] is after [today] (empty/invalid range);
     * callers guard against dividing by zero.
     *
     * This is the single definition shared by the Statistics summary, the Today
     * card's monthly average and the chart's current bucket, so all three agree.
     *
     * @param from            Inclusive period start ("yyyy-MM-dd").
     * @param today           The in-progress current logical day ("yyyy-MM-dd").
     * @param todayIsDrinkDay Whether a drink has already been logged today.
     */
    fun effectivePeriodDays(from: String, today: String, todayIsDrinkDay: Boolean): Int {
        val f = parseDate(from)
        val t = parseDate(today)
        if (f.isAfter(t)) return 0
        val completedDays = f.datesUntil(t).count().toInt() // [from, today) — excludes today
        val days = completedDays + if (todayIsDrinkDay) 1 else 0
        // Postcondition: the range is non-empty here (f ≤ t), so the effective day
        // count is never negative; callers divide averages by it. Checked under -ea.
        assert(days >= 0) { "effectivePeriodDays: negative count $days (from=$from, today=$today)" }
        return days
    }

    /**
     * Days in the inclusive window [[from], [to]] that a per-day average may be
     * divided by, and that an abstinent-day count may be subtracted from.
     *
     * WHICH OF TWO RULES APPLIES DEPENDS ON WHERE THE WINDOW ENDS, and that is the
     * whole point of this function:
     *
     *  - The window ends TODAY (the statistics screen at offset 0, the Today
     *    card's month): the last day is still running, so
     *    [effectivePeriodDays] applies and keeps it out until it resolves.
     *  - The window ends in the PAST (any offset > 0): every day in it is
     *    finished, including the last one, so all of them count.
     *
     * Passing the window's end as if it were today conflated the two and cost the
     * last day of every past period: July was 30 days long, its average divided by
     * 30, its abstinent-day count one short, and its final bar drew no abstinence
     * tick because the bucket believed the day might still become a drink day
     * (0.85.0 QA round). Callers therefore hand in BOTH the window end and the
     * real logical day and let this function decide.
     *
     * @param from            Inclusive window start ("yyyy-MM-dd").
     * @param to              Inclusive window end ("yyyy-MM-dd").
     * @param today           The real current logical day ("yyyy-MM-dd").
     * @param todayIsDrinkDay Whether a drink has already been logged today. Read
     *                        only when the window ends today.
     */
    fun windowDays(from: String, to: String, today: String, todayIsDrinkDay: Boolean): Int {
        if (to == today) return effectivePeriodDays(from, to, todayIsDrinkDay)
        val f = parseDate(from)
        val t = parseDate(to)
        if (f.isAfter(t)) return 0
        return f.datesUntil(t.plusDays(1)).count().toInt() // [from, to] — inclusive
    }

    /**
     * The first weekday of the calendar week for the given [locale], as an ISO-8601
     * weekday number (1 = Monday … 7 = Sunday).
     *
     * WHY THIS EXISTS
     *   As of the rolling-window refactor (v0.62.0) the app no longer has a
     *   user-configurable "week starts on" setting, and all consumption metrics use
     *   a gliding 7-day window instead of a fixed calendar week. Two purely *visual*
     *   features still need a fixed first weekday, though:
     *     - the calendar month grid (which weekday heads column 0), and
     *     - the PDF "weekday profile" histogram (the order of its seven bars).
     *   For those, the natural, locale-aware choice is the convention the user's
     *   region already uses (Monday in most of Europe, Sunday in the US, Saturday in
     *   much of the Middle East). [WeekFields.firstDayOfWeek] encodes exactly that.
     *
     * WHY A DEFAULT-LOCALE PARAMETER
     *   Production callers pass nothing and get the device locale. Unit tests can
     *   inject a fixed [Locale] to make the expected column order deterministic
     *   regardless of the machine the tests run on.
     *
     * @param locale Locale whose week definition is used. Defaults to the JVM /
     *               device default locale.
     * @return ISO-8601 weekday number of the locale's first weekday (1..7).
     */
    fun firstDayOfWeekIso(locale: Locale = Locale.getDefault()): Int {
        val iso = WeekFields.of(locale).firstDayOfWeek.value
        // Invariant: an ISO-8601 weekday number is always in 1..7 (Mon..Sun).
        assert(iso in 1..7) { "firstDayOfWeekIso: out-of-range ISO weekday $iso" }
        return iso
    }

    /**
     * Number of completed, alcohol-free days since the most recent drink (or since
     * [statsFrom] if there are no drink entries yet).
     *
     * Returns 0 if:
     * - [sortedDates] is empty AND [statsFrom] is empty or ≥ [today]
     * - [sortedDates] is non-empty AND the last entry equals or exceeds [today]
     *   (the user drank today, so no streak has started yet)
     *
     * A day counts only once it has finished alcohol-free. Therefore BOTH the last
     * drink day (a drink day, never abstinent) and the current day (still in
     * progress, not yet finished) are excluded — only the fully completed dry days
     * in between are counted. Consequently the day immediately after a drink day is
     * still 0; the count becomes 1 only on the following day.
     *
     * [statsFrom] semantics: the floor. Drink days BEFORE it are dropped here,
     * inside the function, so a caller cannot forget to; the streak then runs
     * from the floor as if the history began there. If nothing remains, the
     * streak starts at [statsFrom] (the "recording start" date) — the implicit
     * assumption that all days from [statsFrom] to today were abstinent. (Until
     * the v0.86.0 review the floor was applied by both callers and the vector
     * pinned "with entries, statsFrom is ignored"; a third caller without the
     * filter would have counted a streak across the floor.)
     *
     * @param sortedDates  Ascending list of distinct logical dates with ≥1 drink.
     *                     May include dates before [statsFrom]; they are ignored.
     * @param today        Logical today from [DayResolver.today].
     * @param statsFrom    Optional statistics start date ("YYYY-MM-DD"). When set,
     *                     the floor: earlier drink days are dropped, and it is
     *                     the streak origin when no drink day remains.
     * @return Current abstinence streak in days (≥ 0).
     */
    fun computeCurrentAbstinence(
        sortedDates: List<String>,
        today: String,
        statsFrom: String = "",
    ): Int {
        val dates = applyingFloor(sortedDates, statsFrom)
        if (dates.isEmpty()) {
            // No drink history: streak runs from statsFrom to today (exclusive)
            if (statsFrom.isEmpty() || statsFrom >= today) return 0
            return parseDate(statsFrom).datesUntil(parseDate(today)).count().toInt()
        }
        // Drank today (or somehow in the future): streak is 0
        if (dates.last() >= today) return 0
        // Days strictly BETWEEN the last drink day and today, i.e. the completed,
        // alcohol-free days. Both endpoints are non-abstinent and must be excluded:
        //   • `today` is excluded automatically (datesUntil's end is exclusive) —
        //     the current day is still in progress and is not yet a finished day.
        //   • the last drink day is the *start* of the range and is itself a drink
        //     day, so the `- 1` drops it.
        // The guard above guarantees last < today, so the raw count is >= 1 and the
        // result is >= 0 (coerceAtLeast is defensive).
        val streak = (parseDate(dates.last()).datesUntil(parseDate(today)).count().toInt() - 1)
            .coerceAtLeast(0)
        // Postcondition (see @return): an abstinence streak is never negative; the
        // coerceAtLeast is the guard and this verifies it under -ea.
        assert(streak >= 0) { "computeCurrentAbstinence: negative streak $streak" }
        return streak
    }

    /** The dates on or after [statsFrom]; all of them when the floor is empty. */
    private fun applyingFloor(sortedDates: List<String>, statsFrom: String): List<String> =
        if (statsFrom.isEmpty()) sortedDates else sortedDates.filter { it >= statsFrom }

    /**
     * Longest recorded abstinence run in days.
     *
     * Considers three types of gap:
     *
     * 1. **Initial gap** ([statsFrom] → first drink):
     *    The days from [statsFrom] up to (but not including) the first drink day.
     *    [statsFrom] itself is an abstinent day, so no −1 adjustment is needed.
     *    `gap = datesUntil(firstDrink).count()` from statsFrom.
     *
     * 2. **Inter-drink gaps** (between consecutive drink days):
     *    Neither endpoint is abstinent (both are drink days), so subtract 1.
     *    `gap = datesUntil(nextDrink).count() − 1` from prevDrink.
     *
     * 3. **Tail gap** (last drink → [today]):
     *    Equivalent to the current streak – uses the same formula as
     *    [computeCurrentAbstinence] for consistency. Both endpoints are
     *    non-abstinent (last drink day; in-progress today), so subtract 1.
     *    `gap = datesUntil(today).count() − 1` from lastDrink.
     *
     * @param sortedDates  Ascending list of distinct drinking dates ("YYYY-MM-DD").
     *                     Dates before [statsFrom] are dropped here, as in
     *                     [computeCurrentAbstinence]: a gap must not span the floor.
     * @param today        Logical today. When provided, the tail gap is included.
     *                     Defaults to "" (tail gap ignored; the conservative behaviour
     *                     for backward-compatible callers).
     * @param statsFrom    Optional statistics start date. Enables the initial gap
     *                     and floors the dates.
     * @return Longest abstinence run in days (≥ 0).
     */
    fun computeLongestAbstinence(
        sortedDates: List<String>,
        today: String = "",
        statsFrom: String = "",
    ): Int {
        val dates = applyingFloor(sortedDates, statsFrom)
        // No drink history at all: longest = same as current streak
        if (dates.isEmpty()) {
            if (today.isEmpty() || statsFrom.isEmpty() || statsFrom >= today) return 0
            return parseDate(statsFrom).datesUntil(parseDate(today)).count().toInt()
        }

        var max = 0

        // 1. Initial gap: statsFrom → first drink
        if (statsFrom.isNotEmpty() && statsFrom < dates.first()) {
            val gap = parseDate(statsFrom).datesUntil(parseDate(dates.first())).count().toInt()
            max = maxOf(max, gap)
        }

        // 2. Inter-drink gaps
        for (i in 1 until dates.size) {
            val gap = (parseDate(dates[i - 1]).datesUntil(parseDate(dates[i])).count() - 1).toInt()
            max = maxOf(max, gap)
        }

        // 3. Tail gap: last drink → today (same semantics as computeCurrentAbstinence:
        //    both endpoints are non-abstinent, so exclude today via the exclusive end
        //    and the last drink day via `- 1`).
        if (today.isNotEmpty() && dates.last() < today) {
            val gap = (parseDate(dates.last()).datesUntil(parseDate(today)).count().toInt() - 1)
                .coerceAtLeast(0)
            max = maxOf(max, gap)
        }

        return max
    }
}
