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
import java.time.DayOfWeek
import java.time.temporal.TemporalAdjusters
import kotlin.math.roundToLong

object AlcoholCalculator {

    // ── Physical and clinical constants ───────────────────────────────────────

    /** Density of ethanol in g/ml (exact value, CRC Handbook). */
    const val ETHANOL_DENSITY = 0.789

    /**
     * Binge-drinking threshold in grams of pure alcohol per occasion.
     *
     * Fixed at 48 g, the WHO/NIAAA threshold historically used for women. As the
     * app no longer stores the user's sex, the lower (stricter) of the two
     * thresholds is used so the PDF report flags binge days conservatively.
     */
    const val BINGE_THRESHOLD = 48.0

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
     * Rounding to 2 decimal places is applied to alcohol gram values so that
     * aggregate `SUM()` queries in SQLite are numerically stable (floating-point
     * drift is bounded at the storage step rather than accumulating over many rows).
     */
    private fun Double.roundTo2Decimals(): Double = (this * 100.0).roundToLong() / 100.0

    // ── Public functions ──────────────────────────────────────────────────────

    /**
     * Calculates the mass of pure (anhydrous) ethanol in a drink.
     *
     * Formula: g = V [ml] × (p [%] ÷ 100) × 0.789 [g/ml]
     *
     * The result is rounded to two decimal places and stored in the database
     * so that aggregate SUM() queries are numerically stable.
     *
     * @param volumeMl       Volume of the drink in millilitres.
     * @param alcoholPercent Alcohol by volume (ABV) as a percentage, e.g. 4.9.
     * @return               Grams of pure alcohol, rounded to 2 decimal places.
     */
    fun calculateGrams(volumeMl: Int, alcoholPercent: Double): Double {
        val rawGrams = volumeMl.toDouble() * (alcoholPercent / 100.0) * ETHANOL_DENSITY
        return rawGrams.roundTo2Decimals()
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
     * @return              Estimated BAC in ‰, always ≥ 0.0.
     *                      Returns 0.0 for invalid inputs (weight ≤ 0 or no alcohol).
     */
    fun calculateBAC(
        totalGrams: Double,
        weightKg: Double,
        hoursElapsed: Double
    ): Double {
        if (weightKg <= 0 || totalGrams <= 0) return 0.0
        val raw = (totalGrams / (weightKg * R_CONSERVATIVE)) - (BETA * hoursElapsed.coerceAtLeast(0.0))
        return raw.coerceAtLeast(0.0).roundTo2Decimals()
    }

    /**
     * Returns the estimated epoch-millisecond timestamp at which BAC reaches zero.
     *
     * Derived from the Widmark formula solved for t:
     *   t_sober = BAC / β
     *
     * @param bacPermille  Current BAC in ‰ (should be ≥ 0).
     * @param nowMillis    Current time as Unix milliseconds (typically
     *                     [System.currentTimeMillis]).
     * @return             Epoch-ms when BAC is expected to reach 0.0.
     *                     Returns [nowMillis] immediately if [bacPermille] ≤ 0.
     */
    fun soberByMillis(bacPermille: Double, nowMillis: Long): Long {
        if (bacPermille <= 0.0) return nowMillis
        val hoursUntilSober = bacPermille / BETA
        return nowMillis + (hoursUntilSober * MILLIS_PER_HOUR).toLong()
    }

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
     * @return          [LimitInfo] with the daily, weekly and drink-day thresholds.
     */
    fun getLimitInfo(settings: AppSettings): LimitInfo = LimitInfo(
        limitGrams          = settings.dailyLimitGrams,
        weeklyLimitGrams    = settings.weeklyLimitGrams,
        maxDrinkDaysPerWeek = settings.maxDrinkDaysPerWeek.coerceIn(1, 7)
    )

    /**
     * Returns the fraction of the daily limit that [totalGrams] represents.
     *
     * A value of 1.0 means exactly at the limit; > 1.0 means over limit.
     * The result is clamped to a minimum of 0f so it can be passed directly
     * to a [androidx.compose.material3.LinearProgressIndicator].
     *
     * @param totalGrams  Grams of alcohol consumed today.
     * @param limitGrams  Active daily limit in grams (must be > 0).
     * @return            Fraction in range [0f, ∞), clamped to 0f from below.
     */
    fun limitPercent(totalGrams: Double, limitGrams: Double): Float {
        if (limitGrams <= 0.0) return 0f
        return (totalGrams / limitGrams).toFloat().coerceAtLeast(0f)
    }

    // bingeThreshold(gender) has been removed: the binge threshold is now the
    // sex-independent constant [BINGE_THRESHOLD] (48 g). Callers reference the
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
     *   2. WEEKLY gram limit – how many servings fit into this week's remaining grams.
     *   3. DRINK-DAY limit   – a *gate*, not a per-serving cap. Drinking more on a
     *      day that already counts as a drink day does not consume additional drink
     *      days, so this limit never reduces the green/yellow serving count; it can
     *      only force [TrafficLight.RED] once the weekly drink-day budget is used up.
     *
     * DRINK-DAY GATE:
     *   `pastDrinkDays = drinkDaysThisWeek − (todayIsDrinkDay ? 1 : 0)` is the number
     *   of drink days *before today*. The gate fires (RED) as soon as
     *   `pastDrinkDays ≥ maxDrinkDaysPerWeek`, which covers both cases the product
     *   spec calls out:
     *     - today is not yet a drink day and the week already has `max` drink days
     *       → logging would open a forbidden new drink day; and
     *     - today is already a drink day but there were already `max` drink days in
     *       the past → today itself is over budget.
     *
     * Alcohol-free drinks ([gramsPerDrink] = 0) always return [TrafficLight.GREEN]:
     * they consume no gram budget and, being 0 g, never turn a day into a drink day.
     *
     * @param gramsPerDrink       Grams for one serving at the current volume.
     * @param todayGrams          Grams already consumed today.
     * @param dailyLimitGrams     Daily gram limit.
     * @param weeklyTotalGrams    Grams consumed this week so far (including today).
     * @param weeklyLimitGrams    Weekly gram limit.
     * @param drinkDaysThisWeek   Distinct drink days this week (today included when
     *                            today already has alcohol).
     * @param maxDrinkDaysPerWeek Maximum allowed drink days per week.
     * @return                    [TrafficLight] status.
     */
    fun trafficLight(
        gramsPerDrink: Double,
        todayGrams: Double,
        dailyLimitGrams: Double,
        weeklyTotalGrams: Double,
        weeklyLimitGrams: Double,
        drinkDaysThisWeek: Int,
        maxDrinkDaysPerWeek: Int
    ): TrafficLight {
        if (gramsPerDrink <= 0.0) return TrafficLight.GREEN

        // Drink-day gate: count drink days strictly before today.
        val todayIsDrinkDay = todayGrams > 0.0
        val pastDrinkDays   = drinkDaysThisWeek - (if (todayIsDrinkDay) 1 else 0)
        if (pastDrinkDays >= maxDrinkDaysPerWeek) return TrafficLight.RED

        // Gram checks: whole servings that fit into the remaining daily / weekly budget.
        val dailyCount  = servingsFitting(dailyLimitGrams  - todayGrams,        gramsPerDrink)
        val weeklyCount = servingsFitting(weeklyLimitGrams - weeklyTotalGrams,  gramsPerDrink)
        val count       = minOf(dailyCount, weeklyCount)

        return when {
            count <= 0 -> TrafficLight.RED
            count == 1 -> TrafficLight.YELLOW
            else       -> TrafficLight.GREEN
        }
    }

    /**
     * Whole servings of [gramsPerDrink] that fit into [remainingGrams].
     * Negative remaining budget is treated as zero. Returns 0 when
     * [gramsPerDrink] ≤ 0 to avoid division by zero.
     */
    private fun servingsFitting(remainingGrams: Double, gramsPerDrink: Double): Int {
        if (gramsPerDrink <= 0.0) return 0
        return (remainingGrams.coerceAtLeast(0.0) / gramsPerDrink).toInt()
    }

    /**
     * Counts limit violations across a list of per-day summaries, used by the
     * Statistics screen and the PDF export.
     *
     * The three counts answer:
     *   - [LimitViolations.daysOverDailyLimit]   – days whose own total grams exceed
     *     [dailyLimitGrams].
     *   - [LimitViolations.daysOverWeeklyLimit]  – consumption days on which the
     *     running weekly total (cumulative from the week's start up to and including
     *     that day) exceeds [weeklyLimitGrams]. The day that pushes the week over the
     *     limit counts, as do all later consumption days in the same week.
     *   - [LimitViolations.daysOverDrinkDayLimit] – consumption days whose 1-based
     *     index within their week is greater than [maxDrinkDaysPerWeek] (e.g. the
     *     6th and 7th drink day of a week when the limit is 5).
     *
     * Only days with > 0 g count as consumption days for the weekly and drink-day
     * checks (a day with only alcohol-free entries is not a drink day). Weeks are
     * delimited by [weekStartDay] (ISO 1 = Monday … 7 = Sunday).
     *
     * EDGE NOTE: when the surrounding period (e.g. a calendar month) starts or ends
     * mid-week, only the days present in [summaries] contribute to that week's
     * running total, so a week clipped at a period boundary is evaluated on its
     * visible days only. This matches how the rest of the statistics screen scopes
     * its figures to the selected period.
     *
     * @param summaries           Per-day summaries in any order; only days present
     *                            are considered.
     * @param dailyLimitGrams     Daily gram limit.
     * @param weeklyLimitGrams    Weekly gram limit.
     * @param maxDrinkDaysPerWeek Maximum allowed drink days per week.
     * @param weekStartDay        First day of the week (ISO 1 = Monday … 7 = Sunday).
     * @return                    The three violation counts.
     */
    fun countLimitViolations(
        summaries: List<DaySummary>,
        dailyLimitGrams: Double,
        weeklyLimitGrams: Double,
        maxDrinkDaysPerWeek: Int,
        weekStartDay: Int
    ): LimitViolations {
        val daysOverDaily = summaries.count { it.totalGrams > dailyLimitGrams }

        val weekStart = DayOfWeek.of(weekStartDay.coerceIn(1, 7))
        var daysOverWeekly   = 0
        var daysOverDrinkDay = 0

        // Group consumption days (> 0 g) by the date their week starts on, then walk
        // each week chronologically to accumulate the running gram total and the
        // 1-based drink-day index.
        summaries
            .filter { it.totalGrams > 0.0 }
            .groupBy { java.time.LocalDate.parse(it.date).with(TemporalAdjusters.previousOrSame(weekStart)) }
            .forEach { (_, weekDays) ->
                var runningGrams = 0.0
                var drinkDayIndex = 0
                weekDays.sortedBy { it.date }.forEach { day ->
                    runningGrams += day.totalGrams
                    drinkDayIndex += 1
                    if (runningGrams > weeklyLimitGrams) daysOverWeekly++
                    if (drinkDayIndex > maxDrinkDaysPerWeek) daysOverDrinkDay++
                }
            }

        return LimitViolations(daysOverDaily, daysOverWeekly, daysOverDrinkDay)
    }
}
