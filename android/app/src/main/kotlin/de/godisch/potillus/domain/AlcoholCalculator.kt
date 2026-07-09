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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.domain

// =============================================================================
// AlcoholCalculator.kt – Pharmacokinetic helper functions
// =============================================================================
//
// WIDMARK FORMULA (Erik Widmark, 1932):
//   BAC [‰] = A / (P × r) − β × t
//
//   A  = grams of pure alcohol consumed
//   P  = body weight in kilograms
//   r  = distribution coefficient (fixed at 0.6 here; see R_CONSERVATIVE)
//   β  = elimination rate ≈ 0.15 ‰ per hour (average value)
//   t  = hours elapsed since the FIRST drink of the episode
//
// WHY A FIXED r = 0.6 (NOT PER-SEX)?
//   The app no longer stores the user's sex. To keep the BAC display honest as
//   a *worst-case* estimate, r is fixed at the smaller of the two classic
//   Widmark coefficients (0.6, the value historically used for women). A smaller
//   r divides the dose by a smaller distribution volume, so it yields the
//   HIGHER BAC of the two sexes — the conservative choice for a safety-oriented
//   readout.
//
// LIMITATIONS:
//   The formula is a statistical model; actual BAC varies with food intake,
//   liver enzyme activity, age, and other individual factors. The app
//   displays a disclaimer and never implies the estimate is exact.
//
// KOTLIN "object":
//   Declares a singleton – a class with exactly one instance, created lazily
//   on first access. No "AlcoholCalculator()" constructor call needed;
//   call AlcoholCalculator.calculateGrams(…) directly.
// =============================================================================

import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.DaySummary
import de.godisch.potillus.domain.model.LimitInfo
import de.godisch.potillus.domain.model.LimitViolations
import de.godisch.potillus.domain.model.TrafficLight
import java.time.LocalDate
import kotlin.math.roundToLong

object AlcoholCalculator {

    // ── Physical and clinical constants ───────────────────────────────────────

    /** Density of ethanol in g/ml (exact value, CRC Handbook). */
    const val ETHANOL_DENSITY = 0.789

    /**
     * Binge-drinking threshold in grams of pure alcohol per occasion.
     *
     * Fixed at 60 g, the WHO/NIAAA threshold historically used for women. As the
     * app no longer stores the user's sex, the lower (stricter) of the two
     * thresholds is used so the PDF report flags binge days conservatively.
     */
    const val BINGE_THRESHOLD = 60.0

    // ── Widmark parameters ────────────────────────────────────────────────────

    /**
     * Widmark distribution coefficient r, fixed at the conservative value 0.6.
     *
     * See the file header for the rationale: 0.6 is the smaller of the two
     * classic coefficients and therefore yields the higher (worst-case) BAC,
     * which is the safe choice now that the user's sex is no longer recorded.
     */
    private const val R_CONSERVATIVE = 0.6

    /**
     * Standard ethanol elimination rate: 0.15 ‰ per hour.
     * This is the average across the population; individual values range from
     * roughly 0.10 to 0.20 ‰/h depending on liver enzyme activity.
     */
    private const val BETA = 0.15

    /**
     * Milliseconds per hour (3 600 000 ms) as a [Double].
     *
     * WHY Double (not Long)?
     *   Every call-site divides a Long delta (ms) by this value to obtain a
     *   Double (hours), or multiplies a Double (hours) by it to obtain ms.
     *   Declaring it as Double avoids a [toLong] / [toDouble] cast at every
     *   use-site and makes the arithmetic expression read naturally.
     *
     * WHY here (not a generic TimeConstants file)?
     *   Every caller that uses this constant does so as part of an alcohol-related
     *   elapsed-time calculation (BAC decay, sober-by estimate). Keeping it in
     *   [AlcoholCalculator] makes the dependency explicit and keeps the constant
     *   close to the formulas it serves.
     */
    const val MILLIS_PER_HOUR = 3_600_000.0

    // ── Private utility ───────────────────────────────────────────────────────

    /**
     * Rounds a [Double] to two decimal places using Kotlin's [roundToLong].
     *
     * WHY a private extension instead of [Math.round]?
     *   `Math.round` is Java-style and requires explicit casting:
     *     `Math.round(x * 100.0) / 100.0`
     *   Kotlin's [roundToLong] (from `kotlin.math`) is idiomatic and type-safe.
     *   A named extension function documents the intent ("2 decimal places") at
     *   the call site, avoids the magic literal `100.0`, and can be reused
     *   by any future calculation that needs the same rounding precision.
     *
     * The sole caller is [calculateBAC]: the estimated blood-alcohol value in ‰
     * is rounded to two decimal places, the precision the Today screen displays
     * ("0.42 ‰"). Alcohol GRAM values are NOT rounded here — they use
     * [roundTo1Decimal] (0.1 g) so the displayed and limit-compared gram figures
     * agree; see [calculateGrams] and [roundTo1Decimal].
     */
    private fun Double.roundTo2Decimals(): Double = (this * 100.0).roundToLong() / 100.0

    /**
     * Rounds a [Double] to one decimal place (0.1 g).
     *
     * Used for alcohol gram values. One decimal is the precision the UI displays
     * ("20.0 g") AND the precision every daily-limit / binge comparison uses, so
     * the number a user sees is exactly the number that is compared against the
     * limit. See [calculateGrams] for why this matters.
     */
    private fun Double.roundTo1Decimal(): Double = (this * 10.0).roundToLong() / 10.0

    // ── Public functions ──────────────────────────────────────────────────────

    /**
     * Calculates the mass of pure (anhydrous) ethanol in a drink.
     *
     * Formula: g = V [ml] × (p [%] ÷ 100) × 0.789 [g/ml]
     *
     * The result is rounded to ONE decimal place (0.1 g). This is deliberate and
     * fixes a visible inconsistency: the UI shows grams with one decimal (e.g.
     * "20.0 g"), but the daily-limit and binge checks compare the stored grams
     * against the limit. With the previous two-decimal precision, 188 ml at 13.5 %
     * stored 20.02 g, which displayed as "20.0 g" yet counted as over a 20 g limit
     * — an exceedance the user could not see. Rounding to 0.1 g at the source means
     * the displayed value and every comparison use exactly the same number.
     *
     * @param volumeMl       Volume of the drink in millilitres.
     * @param alcoholPercent Alcohol by volume (ABV) as a percentage, e.g. 4.9.
     * @return Grams of pure alcohol, rounded to one decimal place (0.1 g).
     */
    fun calculateGrams(volumeMl: Int, alcoholPercent: Double): Double {
        val rawGrams = volumeMl.toDouble() * (alcoholPercent / 100.0) * ETHANOL_DENSITY
        val grams = rawGrams.roundTo1Decimal()
        // Invariant: a real drink never has negative volume or ABV, so its pure-
        // alcohol mass is never negative. Enabled under -ea during the test suite
        // (see the ROADMAP dynamic-analysis item); a hit here would mean a negative
        // volume/percent slipped past input validation. assert() is a no-op in
        // release builds, so it costs shipped users nothing.
        assert(grams >= 0.0) { "calculateGrams: negative grams $grams (volumeMl=$volumeMl, abv=$alcoholPercent)" }
        return grams
    }

    /**
     * Estimates the blood alcohol concentration (BAC) using the Widmark formula.
     *
     * BAC [‰] = A / (P × r) − β × t
     *
     * The distribution coefficient r is fixed at the conservative value
     * [R_CONSERVATIVE] (0.6), so the returned value is a worst-case (maximum)
     * estimate rather than a sex-specific one.
     *
     * Important: only entries with [alcoholPercent] > 0 should be included in
     * [totalGrams], and their earliest timestamp should be used for [hoursElapsed].
     * Including alcohol-free entries would falsely push the start time earlier,
     * underestimating the BAC.
     *
     * @param totalGrams    Total grams of pure alcohol in the current episode.
     * @param weightKg      Body weight in kilograms (must be > 0).
     * @param hoursElapsed  Hours since the first alcoholic drink of the episode.
     *                      Negative values are treated as 0 (coerced).
     * @return Estimated BAC in ‰, always ≥ 0.0.
     *                      Returns 0.0 for invalid inputs (weight ≤ 0 or no alcohol).
     */
    fun calculateBAC(
        totalGrams: Double,
        weightKg: Double,
        hoursElapsed: Double,
    ): Double {
        if (weightKg <= 0 || totalGrams <= 0) return 0.0
        val raw = (totalGrams / (weightKg * R_CONSERVATIVE)) - (BETA * hoursElapsed.coerceAtLeast(0.0))
        val bac = raw.coerceAtLeast(0.0).roundTo2Decimals()
        // Postcondition (see @return): the estimate is clamped to ≥ 0, so a BAC is
        // never reported as negative. Verifies the coerceAtLeast above still holds.
        assert(bac >= 0.0) { "calculateBAC: negative BAC $bac" }
        return bac
    }

    // soberByMillis(bacPermille, nowMillis) has been removed: it was never
    // wired into any screen (dead production code found in the v0.78.0 QA
    // review). Should a "sober by" estimate ever ship, re-derive it from the
    // Widmark decay used in [calculateBAC]: t_sober = BAC / β.

    /**
     * Returns the [LimitInfo] for the given [settings].
     *
     * This is the single place where [AppSettings] is translated into the active
     * limit thresholds. Keeping the derivation here (in the domain layer) means
     * ViewModels and the PDF exporter all use the same logic.
     *
     * All three limits are always active; [maxDrinkDaysPerWeek] is clamped to the
     * valid 1–7 range defensively (the preference layer already clamps on write).
     *
     * @param settings  Current user preferences.
     * @return [LimitInfo] with the daily, weekly and drink-day thresholds.
     */
    fun getLimitInfo(settings: AppSettings): LimitInfo = LimitInfo(
        limitGrams = settings.dailyLimitGrams,
        weeklyLimitGrams = settings.weeklyLimitGrams,
        maxDrinkDaysPerWeek = settings.maxDrinkDaysPerWeek.coerceIn(1, 7),
    )

    /**
     * Returns the fraction of the daily limit that [totalGrams] represents.
     *
     * A value of 1.0 means exactly at the limit; > 1.0 means over limit.
     * The result is clamped to a minimum of 0f so it can be passed directly
     * to a [androidx.compose.material3.LinearProgressIndicator].
     *
     * This is the SINGLE source of the fill-fraction logic: the LimitBar
     * composable (ui/component/Components.kt) calls it instead of duplicating
     * the division inline, so the zero-limit guard below cannot drift from the
     * one the UI shows.
     *
     * @param totalGrams  Grams of alcohol consumed today.
     * @param limitGrams  Active daily limit in grams. A non-positive value
     *                    (limit not configured) yields 0f — an empty bar —
     *                    instead of a NaN/Infinity fill.
     * @return Fraction in range [0f, ∞), clamped to 0f from below.
     */
    fun limitPercent(totalGrams: Double, limitGrams: Double): Float {
        if (limitGrams <= 0.0) return 0f
        val fraction = (totalGrams / limitGrams).toFloat().coerceAtLeast(0f)
        // Postcondition (see @return): the fill fraction is clamped to ≥ 0f, so it
        // is always a valid LinearProgressIndicator input — even for a negative
        // (already-cleared) gram total, as the limitPercent tests exercise.
        assert(fraction >= 0f) { "limitPercent: negative fraction $fraction" }
        return fraction
    }

    // bingeThreshold(gender) has been removed: the binge threshold is now the
    // sex-independent constant [BINGE_THRESHOLD] (60 g). Callers reference the
    // constant directly.

    /**
     * Computes the traffic-light capacity status for one drink serving.
     *
     * Answers: "How many more of this drink can I log before exceeding ANY of my
     * three limits?" The result is [TrafficLight.GREEN] (≥ 2 servings still fit),
     * [TrafficLight.YELLOW] (exactly 1 fits), or [TrafficLight.RED] (0 fit).
     *
     * All three limits are evaluated together:
     *   1. DAILY gram limit  – how many servings fit into today's remaining grams.
     *   2. 7-DAY gram limit  – how many servings fit into the remaining grams of the
     *      trailing 7-day window (today plus the previous six days).
     *   3. DRINK-DAY limit   – a *gate*, not a per-serving cap. Drinking more on a
     *      day that already counts as a drink day does not consume additional drink
     *      days, so this limit never reduces the green/yellow serving count; it can
     *      only force [TrafficLight.RED] once the 7-day drink-day budget is used up.
     *
     * DRINK-DAY GATE:
     *   `pastDrinkDays = drinkDaysThisWeek − (todayIsDrinkDay ? 1 : 0)` is the number
     *   of drink days *before today* inside the trailing 7-day window. The gate fires
     *   (RED) as soon as `pastDrinkDays ≥ maxDrinkDaysPerWeek`, which covers both
     *   cases the product spec calls out:
     *     - today is not yet a drink day and the window already has `max` drink days
     *       → logging would open a forbidden new drink day; and
     *     - today is already a drink day but there were already `max` drink days in
     *       the window before today → today itself is over budget.
     *
     * Alcohol-free drinks ([gramsPerDrink] = 0) always return [TrafficLight.GREEN]:
     * they consume no gram budget and, being 0 g, never turn a day into a drink day.
     *
     * @param gramsPerDrink       Grams for one serving at the current volume.
     * @param todayGrams          Grams already consumed today.
     * @param dailyLimitGrams     Daily gram limit.
     * @param weeklyTotalGrams    Grams consumed in the trailing 7-day window so far
     *                            (including today).
     * @param weeklyLimitGrams    Gram limit for the trailing 7-day window.
     * @param drinkDaysThisWeek   Distinct drink days in the trailing 7-day window
     *                            (today included when today already has alcohol).
     * @param maxDrinkDaysPerWeek Maximum allowed drink days within the 7-day window.
     * @return [TrafficLight] status.
     */
    fun trafficLight(
        gramsPerDrink: Double,
        todayGrams: Double,
        dailyLimitGrams: Double,
        weeklyTotalGrams: Double,
        weeklyLimitGrams: Double,
        drinkDaysThisWeek: Int,
        maxDrinkDaysPerWeek: Int,
    ): TrafficLight {
        if (gramsPerDrink <= 0.0) return TrafficLight.GREEN

        // Drink-day gate: count drink days strictly before today.
        val todayIsDrinkDay = todayGrams > 0.0
        val pastDrinkDays = drinkDaysThisWeek - (if (todayIsDrinkDay) 1 else 0)
        if (pastDrinkDays >= maxDrinkDaysPerWeek) return TrafficLight.RED

        // Gram checks: whole servings that fit into the remaining daily / weekly budget.
        val dailyCount = servingsFitting(dailyLimitGrams - todayGrams, gramsPerDrink)
        val weeklyCount = servingsFitting(weeklyLimitGrams - weeklyTotalGrams, gramsPerDrink)
        val count = minOf(dailyCount, weeklyCount)

        return when {
            count <= 0 -> TrafficLight.RED
            count == 1 -> TrafficLight.YELLOW
            else -> TrafficLight.GREEN
        }
    }

    /**
     * Whole servings of [gramsPerDrink] that fit into [remainingGrams].
     * Negative remaining budget is treated as zero. Returns 0 when
     * [gramsPerDrink] ≤ 0 to avoid division by zero.
     */
    private fun servingsFitting(remainingGrams: Double, gramsPerDrink: Double): Int {
        if (gramsPerDrink <= 0.0) return 0
        val count = (remainingGrams.coerceAtLeast(0.0) / gramsPerDrink).toInt()
        // Invariant: the remaining budget is floored at 0 before the division, so
        // the whole-serving count can never come out negative.
        assert(count >= 0) { "servingsFitting: negative count $count" }
        return count
    }

    /** Length of the gliding consumption window, in days (today + the previous 6). */
    const val WINDOW_DAYS = 7

    /**
     * Comparison tolerance for gram-vs-limit checks.
     *
     * All gram amounts enter the system rounded to 0.1 g ([calculateGrams]), but
     * day/window totals are built by summing binary [Double]s — in the sliding
     * window of [countLimitViolations] even incrementally (add on entry, subtract
     * on eviction). Binary floating point cannot represent most multiples of 0.1
     * exactly, so a total that is EXACTLY at the limit (e.g. two 50.0 g days
     * against a 100 g window limit) can accumulate to 100.000000000000014… and a
     * strict `>` would flag it as an exceedance the user cannot see. That breaks
     * the app-wide principle that the displayed number IS the compared number
     * (see [calculateGrams]). Verified empirically in the v0.79.0 QA review:
     * randomly generated 0.1-g-grid histories with an exactly-at-limit window
     * flip the strict comparison in a substantial share of runs.
     *
     * 1e-6 g is three orders of magnitude below the 0.1 g data grid, so the
     * tolerance can never absorb a REAL exceedance (the smallest possible one is
     * 0.1 g) while comfortably exceeding any drift a realistic history (decades
     * of entries, |sum| < 10⁶) can accumulate.
     */
    private const val LIMIT_EPSILON = 1e-6

    /**
     * Whether [totalGrams] exceeds [limitGrams], tolerating floating-point drift
     * at the exact boundary (see [LIMIT_EPSILON]).
     *
     * This is the SINGLE definition of "over the limit" — used by
     * [countLimitViolations], the report data/builder (over-limit months, binge
     * days, peak-KPI warn flags, over-limit chart bars) and the on-screen
     * over-limit markers (LimitBar, calendar day cells, chart bars) — so a total
     * that reads "100.0 g" against a 100 g limit is consistently AT the limit,
     * never over it, on every surface. Reaching the limit exactly is allowed:
     * the limit is what the user may consume.
     */
    fun isOverLimit(totalGrams: Double, limitGrams: Double): Boolean = totalGrams > limitGrams + LIMIT_EPSILON

    /**
     * Counts limit violations across a list of per-day summaries, used by the
     * Statistics screen and the PDF export.
     *
     * ROLLING 7-DAY WINDOW (changed in v0.62.0)
     *   The weekly gram limit and the drink-day limit are no longer evaluated per
     *   fixed calendar week (which reset on a configured weekday). Instead each
     *   consumption day is judged against the gliding [WINDOW_DAYS]-day window that
     *   *ends on that day* — i.e. the day itself plus the six calendar days before
     *   it. This window never "resets" on a weekday boundary, which makes the metric
     *   harder to game (heavy drinking split across a Sun/Mon boundary no longer
     *   lands in two separate buckets) and reflects continuous health risk more
     *   honestly. See CHANGELOG v0.62.0 for the rationale.
     *
     * The three counts answer:
     *   - [LimitViolations.daysOverDailyLimit]   – days whose own total grams exceed
     *     [dailyLimitGrams]. (Unchanged: a per-day check, independent of any window.)
     *   - [LimitViolations.daysOverWeeklyLimit]  – consumption days whose trailing
     *     7-day gram total (this day plus the previous six calendar days) exceeds
     *     [weeklyLimitGrams].
     *   - [LimitViolations.daysOverDrinkDayLimit] – consumption days for which the
     *     number of distinct consumption days inside their trailing 7-day window
     *     exceeds [maxDrinkDaysPerWeek] (e.g. the day is the 6th drink day within the
     *     last 7 days when the limit is 5).
     *
     * Only days with > 0 g count as consumption days for the weekly and drink-day
     * checks (a day with only alcohol-free entries is not a drink day and does not
     * enter the window at all).
     *
     * EDGE NOTE (start of history / clipped periods): the window is built only from
     * the days actually present in [summaries]. Near the first recorded day — or at
     * the lower edge of a period clipped by the statistics-start date — fewer than
     * seven days of history exist, so the trailing window simply contains fewer days
     * and is evaluated on what is visible. This preserves the previous "visible days
     * only" behaviour and matches how the rest of the statistics screen scopes its
     * figures to the selected period.
     *
     * IMPLEMENTATION (two-pointer sliding window): the consumption days are sorted
     * ascending once, then a single left pointer trails the current (right) day,
     * dropping any day that has fallen out of the 7-day window and maintaining the
     * running gram sum incrementally. This is O(n) over the consumption days rather
     * than the O(n²) a naïve "re-scan the window for every day" would cost.
     *
     * @param summaries           Per-day summaries in any order; only days present
     *                            are considered.
     * @param dailyLimitGrams     Daily gram limit.
     * @param weeklyLimitGrams    Gram limit for the trailing 7-day window.
     * @param maxDrinkDaysPerWeek Maximum allowed drink days within any 7-day window.
     * @return The three violation counts.
     */
    fun countLimitViolations(
        summaries: List<DaySummary>,
        dailyLimitGrams: Double,
        weeklyLimitGrams: Double,
        maxDrinkDaysPerWeek: Int,
    ): LimitViolations {
        val daysOverDaily = summaries.count { isOverLimit(it.totalGrams, dailyLimitGrams) }

        // Consumption days only (> 0 g), sorted ascending by date so the window can
        // advance with a single forward pass. We parse the ISO date once per day.
        val days = summaries
            .filter { it.totalGrams > 0.0 }
            .map { LocalDate.parse(it.date) to it.totalGrams }
            .sortedBy { it.first }

        var daysOverWeekly = 0
        var daysOverDrinkDay = 0

        // Two-pointer window: [left, right] holds every consumption day whose date is
        // within the 7-day span ending at the current right-hand day. `windowGrams`
        // is the running gram sum of exactly those days.
        var left = 0
        var windowGrams = 0.0
        for (right in days.indices) {
            windowGrams += days[right].second
            val windowStart = days[right].first.minusDays((WINDOW_DAYS - 1).toLong())

            // Evict days that are now older than the window's first day. After this
            // loop, days[left..right] are exactly the days inside the trailing window.
            while (days[left].first < windowStart) {
                windowGrams -= days[left].second
                left++
            }
            // Two-pointer invariant: days are sorted ascending and windowStart is
            // never after days[right], so the left pointer can never overtake right.
            // A hit here would mean the sliding-window bookkeeping is broken.
            assert(left <= right) { "countLimitViolations: window invariant left=$left > right=$right" }

            val windowDrinkDays = right - left + 1
            if (isOverLimit(windowGrams, weeklyLimitGrams)) daysOverWeekly++
            if (windowDrinkDays > maxDrinkDaysPerWeek) daysOverDrinkDay++
        }

        return LimitViolations(daysOverDaily, daysOverWeekly, daysOverDrinkDay)
    }
}
