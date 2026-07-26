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

// =============================================================================
// StatsWindow.kt – which days a statistics period covers
// =============================================================================
//
// Three periods, each with a comparison period immediately before it, and a user
// setting that can cut both short. Pure, because every one of those interactions
// is a place to be off by a day.
//
// THE COMPARISON PERIOD IS ADJACENT AND EQUAL-LENGTH
//   Week: the seven days ending today, against the seven before them.
//   Month: this month so far, against the whole previous calendar month.
//   Year: this year so far, against the whole previous year.
//
//   Note the asymmetry in month and year: a partial current period is compared
//   against a complete previous one. The trend is a comparison of grams PER DAY,
//   which is what makes it fair — twelve days into January, the daily average is
//   compared, not the total.
//
// THE FLOOR
//   `statsFromDate` is the user saying "my history before this date is not mine
//   to be judged by" — imported data, a fresh start. It raises the beginning of
//   BOTH windows. Three cases follow, and only the third is surprising:
//
//     - floor before both: nothing changes.
//     - floor inside the current period: the current window shrinks, the previous
//       window vanishes (its `from` exceeds its `to`), and there is no baseline.
//     - floor inside the PREVIOUS period: the previous window shrinks, and a
//       shorter baseline is compared against a longer current one. This is fair
//       BECAUSE the comparison is per-day, and unfair if anyone ever compares the
//       totals. `DayResolver.effectivePeriodDays` divides by the days that remain.
//
// WHY THIS IS ITS OWN FILE
//   Until the 0.84.0 review this derivation sat inline in `StatsViewModel`, inside
//   a `flatMapLatest` block that needs a database and a coroutine to reach. iOS
//   had it extracted as `StatsWindow.swift` with thirteen boundary tests; this
//   side had one. The two agreed, but nothing held them to it. Extracted, the
//   arithmetic is reachable from a plain JVM test, and both platforms now assert
//   it against `test-vectors/stats-window.json`.
// =============================================================================

/**
 * The three spans the statistics screen can show.
 *
 * Declared here rather than beside the ViewModel because the window arithmetic
 * is what gives the values meaning, and `StatsWindows` may not depend on the UI
 * layer. The raw names are the strings the shared vectors use, and they match
 * the Swift `StatsPeriod` case raw values one for one.
 */
enum class StatsPeriod { WEEK, MONTH, YEAR }

/**
 * A period and the period it is compared against, as logical dates.
 *
 * All four values are `yyyy-MM-dd` logical dates, never instants: the whole
 * screen works in logical days, and a date that carried a time would reopen the
 * day-change question this type exists to keep out.
 *
 * @property from First day of the current period, inclusive.
 * @property to Last day of the current period, inclusive — always `today`.
 * @property previousFrom First day of the comparison period, inclusive.
 * @property previousTo Last day of the comparison period, inclusive.
 */
data class StatsWindow(
    val from: String,
    val to: String,
    val previousFrom: String,
    val previousTo: String,
) {
    /**
     * Whether the previous window contains any days at all.
     *
     * An inverted range — which the floor can produce — means there is no
     * baseline, not zero grams. Callers must branch on this rather than on a
     * summed total, or an excluded history reads as a period of abstinence.
     */
    val hasBaseline: Boolean get() = previousFrom <= previousTo
}

/**
 * Derives statistics windows. Pure: no clock, no database, no Android.
 *
 * The Swift counterpart is `StatsWindows` in
 * `ios/PotillusKit/Sources/PotillusKit/Domain/StatsWindow.swift`; the two are
 * pinned against each other by `test-vectors/stats-window.json`.
 */
object StatsWindows {

    /**
     * The window for [period], ending on [today].
     *
     * @param period Which span the user selected.
     * @param today The current logical date, `yyyy-MM-dd`.
     * @return The window, or `null` if [today] is not a parseable logical date.
     *         Swift returns `nil` for the same input; the shared vectors pin
     *         that case, so the two must agree on it and not merely on the
     *         happy path.
     */
    fun window(period: StatsPeriod, today: String): StatsWindow? {
        val todayDate = runCatching { DayResolver.parseDate(today) }.getOrNull() ?: return null

        val from = when (period) {
            // Today plus the six days before it.
            StatsPeriod.WEEK -> todayDate.minusDays(6)
            StatsPeriod.MONTH -> todayDate.withDayOfMonth(1)
            StatsPeriod.YEAR -> todayDate.withDayOfYear(1)
        }
        val previousFrom = when (period) {
            // The seven days before the current seven.
            StatsPeriod.WEEK -> from.minusDays(7)
            // Calendar arithmetic, not a fixed day count: this is what puts the
            // leap day inside the previous February and keeps a 31-day month
            // from swallowing a day of the one before it.
            StatsPeriod.MONTH -> from.minusMonths(1)
            StatsPeriod.YEAR -> from.minusYears(1)
        }

        return StatsWindow(
            from = DayResolver.formatDate(from),
            to = today,
            previousFrom = DayResolver.formatDate(previousFrom),
            // The previous window always ends the day before the current one
            // begins: no gap, no overlap, whatever the period.
            previousTo = DayResolver.formatDate(from.minusDays(1)),
        )
    }

    /**
     * Raises both windows' start to [floor], if the user set one.
     *
     * String comparison, not date arithmetic: `yyyy-MM-dd` sorts
     * chronologically, which is the entire reason the schema stores it that way.
     * Swift's `applyingFloor` compares the same way, so a malformed floor
     * degrades identically on both platforms instead of throwing on one.
     *
     * @param window The unclipped window.
     * @param floor The user's statistics start date, or the empty string when
     *        none is set.
     */
    fun applyingFloor(window: StatsWindow, floor: String): StatsWindow {
        if (floor.isEmpty()) return window
        return window.copy(
            from = maxOf(window.from, floor),
            previousFrom = maxOf(window.previousFrom, floor),
        )
    }
}
