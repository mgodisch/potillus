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
// StatsWindowVectorTest.kt – cross-platform parity suite
// =============================================================================
//
// Asserts the JVM implementation against `test-vectors/stats-window.json`, the
// same file the iOS Swift suite loads. Until the 0.84.0 review this arithmetic
// existed twice with no shared pin: iOS had thirteen boundary tests around an
// extracted `StatsWindow.swift`, this side had the derivation inline in
// `StatsViewModel` and one clipping test in `StatsViewModelTest`. The two agreed;
// nothing held them to it.
//
// `StatsViewModelTest` keeps its own clipping test. That one asserts that the
// ViewModel USES the floor — it goes through the database and the flow — while
// this file asserts what the floor DOES. Both are needed: a correct window that
// the ViewModel forgets to apply is still a bug.
// =============================================================================

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StatsWindowVectorTest {

    private companion object {
        /** Loaded once; a failure here fails the whole class, by design. */
        val VECTORS: JSONObject = SharedTestVectors.load("stats-window")

        /** Iterates a JSON array of objects as a Kotlin sequence. */
        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }
    }

    /**
     * Asserts one window against the four dates and the baseline flag a case
     * carries. The case description goes into every message, so a red test names
     * the boundary rather than only the value.
     */
    private fun assertMatches(case: JSONObject, actual: StatsWindow?) {
        val what = case.getString("description")
        val window = requireNotNull(actual) { "$what: expected a window, got null" }
        assertEquals("$what: from", case.getString("from"), window.from)
        assertEquals("$what: to", case.getString("to"), window.to)
        assertEquals("$what: previousFrom", case.getString("previousFrom"), window.previousFrom)
        assertEquals("$what: previousTo", case.getString("previousTo"), window.previousTo)
        assertEquals("$what: hasBaseline", case.getBoolean("hasBaseline"), window.hasBaseline)
    }

    private fun period(case: JSONObject) = StatsPeriod.valueOf(case.getString("period"))

    // ── The three periods and their boundaries ───────────────────────────────

    @Test
    fun `window matches the shared vectors`() {
        VECTORS.getJSONArray("window").objects().forEach { case ->
            assertMatches(case, StatsWindows.window(period(case), case.getString("today")))
        }
    }

    /**
     * The offset cases, where a period other than the current one is asked for.
     *
     * The boundary these pin is where the window ENDS: the current period stops at
     * today, a past one at its own last day. Getting that wrong divides an average
     * by days that have not happened.
     */
    @Test
    fun `window with an offset matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("windowOffset")
        assertTrue("the shared vectors carry offset cases", cases.length() > 0)
        cases.objects().forEach { case ->
            assertMatches(
                case,
                StatsWindows.window(period(case), case.getString("today"), case.getInt("offset")),
            )
        }
    }

    /**
     * How far back the arrows may go.
     *
     * `offsetOf` answers how many steps of a period lie between a day and today,
     * and the statistics screen turns that answer into `canGoEarlier`. A wrong
     * ceiling does not misdraw anything — it disables a button, which looks like
     * a broken control rather than like a boundary. It reached 0.85.0 without
     * shared coverage; these cases give both platforms the same ceiling.
     */
    @Test
    fun `offsetOf matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("earliestOffset")
        assertTrue("the shared vectors carry earliest-offset cases", cases.length() > 0)
        cases.objects().forEach { case ->
            assertEquals(
                case.getString("description"),
                case.getInt("offset"),
                StatsWindows.offsetOf(
                    period(case),
                    case.getString("today"),
                    case.getString("day"),
                ),
            )
        }
    }

    // ── The floor ────────────────────────────────────────────────────────────

    @Test
    fun `applyingFloor matches the shared vectors`() {
        VECTORS.getJSONArray("applyingFloor").objects().forEach { case ->
            val base = requireNotNull(
                StatsWindows.window(period(case), case.getString("today")),
            ) { "${case.getString("description")}: the unclipped window must exist" }
            assertMatches(case, StatsWindows.applyingFloor(base, case.getString("floor")))
        }
    }

    // ── The invariant, over every period and day the vector lists ────────────

    @Test
    fun `the previous window always ends the day before the current begins`() {
        val spec = VECTORS.getJSONObject("adjacency")
        val periods = spec.getJSONArray("periods")
        val todays = spec.getJSONArray("todays")
        for (p in 0 until periods.length()) {
            for (t in 0 until todays.length()) {
                val name = periods.getString(p)
                val today = todays.getString(t)
                val window = requireNotNull(StatsWindows.window(StatsPeriod.valueOf(name), today)) {
                    "$name on $today: expected a window"
                }
                assertEquals(
                    "$name on $today: previousTo must be the day before from",
                    window.previousTo,
                    DayResolver.formatDate(DayResolver.parseDate(window.from).minusDays(1)),
                )
            }
        }
    }

    // ── Unparseable input ────────────────────────────────────────────────────
    //
    // Swift returns nil where java.time would throw, so this case is the one most
    // likely to diverge: it is pinned rather than left to each platform's taste.

    @Test
    fun `an unparseable today yields no window`() {
        VECTORS.getJSONArray("invalidToday").objects().forEach { case ->
            assertNull(
                case.getString("description"),
                StatsWindows.window(period(case), case.getString("today")),
            )
        }
    }
}
