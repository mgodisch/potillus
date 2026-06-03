/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
 * =============================================================================
 */
package de.godisch.potillus.domain

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

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
     * @return                 Logical date as "YYYY-MM-DD".
     */
    fun resolve(
        timestampMillis: Long,
        changeHour: Int,
        changeMinute: Int,
        zoneId: ZoneId = ZoneId.systemDefault()
    ): String {
        val localDateTime = LocalDateTime.ofInstant(
            Instant.ofEpochMilli(timestampMillis),
            zoneId
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

    /** Returns today's logical date from the current system clock. */
    fun today(changeHour: Int, changeMinute: Int): String =
        resolve(System.currentTimeMillis(), changeHour, changeMinute)

    /** Parses a "YYYY-MM-DD" string into a [LocalDate]. */
    fun parseDate(dateStr: String): LocalDate =
        LocalDate.parse(dateStr, DATE_FORMATTER)

    /** Formats a [LocalDate] as "YYYY-MM-DD". */
    fun formatDate(date: LocalDate): String =
        date.format(DATE_FORMATTER)

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
     * [statsFrom] semantics: if the user has never logged a drink, the streak
     * starts at [statsFrom] (the "recording start" date). This represents the
     * implicit assumption that all days from [statsFrom] to today were abstinent.
     *
     * @param sortedDates  Ascending list of distinct logical dates with ≥1 drink.
     * @param today        Logical today from [DayResolver.today].
     * @param statsFrom    Optional statistics start date ("YYYY-MM-DD"). When set,
     *                     used as the streak origin when [sortedDates] is empty.
     * @return             Current abstinence streak in days (≥ 0).
     */
    fun computeCurrentAbstinence(
        sortedDates: List<String>,
        today: String,
        statsFrom: String = ""
    ): Int {
        if (sortedDates.isEmpty()) {
            // No drink history: streak runs from statsFrom to today (exclusive)
            if (statsFrom.isEmpty() || statsFrom >= today) return 0
            return parseDate(statsFrom).datesUntil(parseDate(today)).count().toInt()
        }
        // Drank today (or somehow in the future): streak is 0
        if (sortedDates.last() >= today) return 0
        // Days strictly BETWEEN the last drink day and today, i.e. the completed,
        // alcohol-free days. Both endpoints are non-abstinent and must be excluded:
        //   • `today` is excluded automatically (datesUntil's end is exclusive) —
        //     the current day is still in progress and is not yet a finished day.
        //   • the last drink day is the *start* of the range and is itself a drink
        //     day, so the `- 1` drops it.
        // The guard above guarantees last < today, so the raw count is >= 1 and the
        // result is >= 0 (coerceAtLeast is defensive).
        return (parseDate(sortedDates.last()).datesUntil(parseDate(today)).count().toInt() - 1)
            .coerceAtLeast(0)
    }

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
     * @param today        Logical today. When provided, the tail gap is included.
     *                     Defaults to "" (tail gap ignored; the conservative behaviour
     *                     for backward-compatible callers).
     * @param statsFrom    Optional statistics start date. Enables the initial gap.
     * @return             Longest abstinence run in days (≥ 0).
     */
    fun computeLongestAbstinence(
        sortedDates: List<String>,
        today: String = "",
        statsFrom: String = ""
    ): Int {
        // No drink history at all: longest = same as current streak
        if (sortedDates.isEmpty()) {
            if (today.isEmpty() || statsFrom.isEmpty() || statsFrom >= today) return 0
            return parseDate(statsFrom).datesUntil(parseDate(today)).count().toInt()
        }

        var max = 0

        // 1. Initial gap: statsFrom → first drink
        if (statsFrom.isNotEmpty() && statsFrom < sortedDates.first()) {
            val gap = parseDate(statsFrom).datesUntil(parseDate(sortedDates.first())).count().toInt()
            max = maxOf(max, gap)
        }

        // 2. Inter-drink gaps
        for (i in 1 until sortedDates.size) {
            val gap = (parseDate(sortedDates[i - 1]).datesUntil(parseDate(sortedDates[i])).count() - 1).toInt()
            max = maxOf(max, gap)
        }

        // 3. Tail gap: last drink → today (same semantics as computeCurrentAbstinence:
        //    both endpoints are non-abstinent, so exclude today via the exclusive end
        //    and the last drink day via `- 1`).
        if (today.isNotEmpty() && sortedDates.last() < today) {
            val gap = (parseDate(sortedDates.last()).datesUntil(parseDate(today)).count().toInt() - 1)
                .coerceAtLeast(0)
            max = maxOf(max, gap)
        }

        return max
    }
}
