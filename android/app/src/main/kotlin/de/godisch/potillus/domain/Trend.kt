/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
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

/**
 * Direction of a per-day-average trend versus a previous period. Shared by the
 * Statistics screen and the Today card so both render the same arrow for the
 * same situation.
 *
 * The comparison is always made on grams of alcohol PER CALENDAR DAY, never on
 * totals: the current (possibly in-progress) period is divided by its effective
 * days and the previous (complete) period by its full day count, so a partial
 * month compares fairly against a full previous month. Both averages are rounded
 * to 0.1 g — the precision shown to the user — before comparing, so a difference
 * below that reads as "no change".
 *
 * - [UP]   current average is higher than the previous one (more alcohol, the
 *          "worse" direction): rendered as a red ↑.
 * - [DOWN] current average is lower (less alcohol, the "better" direction):
 *          rendered as a green ↓.
 * - [FLAT] equal at 0.1 g precision, OR no comparable previous value exists
 *          (previous average ≤ 0): no arrow is shown.
 */
enum class Trend {
    UP,
    DOWN,
    FLAT,
    ;

    companion object {
        /**
         * Rounds grams to 0.1 g, commercially (HALF_UP). The inputs are
         * non-negative, so `Math.round` (ties toward positive infinity) is
         * equivalent to "round half away from zero" here, matching the rounding
         * used for the on-screen value labels.
         */
        private fun round1(grams: Double): Double = Math.round(grams * 10.0) / 10.0

        /**
         * Classifies [currentAvg] grams/day against [prevAvg] grams/day. Returns
         * [FLAT] when there is no usable previous value ([prevAvg] ≤ 0) or the two
         * are equal once rounded to 0.1 g.
         */
        fun of(currentAvg: Double, prevAvg: Double): Trend {
            if (prevAvg <= 0.0) return FLAT
            val c = round1(currentAvg)
            val p = round1(prevAvg)
            return when {
                c > p -> UP
                c < p -> DOWN
                else -> FLAT
            }
        }
    }
}
