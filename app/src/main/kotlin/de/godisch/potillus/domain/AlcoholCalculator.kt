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
//   r  = distribution coefficient (0.7 male / 0.6 female)
//        reflects the different ratio of body water to total mass
//   β  = elimination rate ≈ 0.15 ‰ per hour (average value)
//   t  = hours elapsed since the FIRST drink of the episode
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
import de.godisch.potillus.domain.model.Gender
import de.godisch.potillus.domain.model.LimitInfo
import de.godisch.potillus.domain.model.LimitMode
import de.godisch.potillus.domain.model.TrafficLight
import kotlin.math.roundToLong

object AlcoholCalculator {

    // ── Physical and clinical constants ───────────────────────────────────────

    /** Density of ethanol in g/ml (exact value, CRC Handbook). */
    const val ETHANOL_DENSITY = 0.789

    /** WHO daily limit for males: ≤ 20 g pure alcohol. */
    const val WHO_LIMIT_MALE    = 20.0
    /** WHO daily limit for females: ≤ 10 g pure alcohol. */
    const val WHO_LIMIT_FEMALE  = 10.0
    /** DHS (Deutsche Hauptstelle für Suchtfragen – German Centre for Addiction Issues)
     *  daily limit for males: ≤ 24 g pure alcohol. */
    const val DHS_LIMIT_MALE    = 24.0
    /** DHS daily limit for females: ≤ 12 g pure alcohol. */
    const val DHS_LIMIT_FEMALE  = 12.0

    /**
     * WHO/NIAAA binge-drinking threshold for males: > 60 g per occasion.
     * Used in the PDF export's binge section.
     */
    const val BINGE_THRESHOLD_MALE   = 60.0
    /**
     * WHO/NIAAA binge-drinking threshold for females: > 48 g per occasion.
     */
    const val BINGE_THRESHOLD_FEMALE = 48.0

    // ── Widmark parameters ────────────────────────────────────────────────────

    /**
     * Widmark distribution coefficient r for males.
     * Reflects the higher proportion of body water in males (≈ 70 % of body mass).
     */
    private const val R_MALE   = 0.7

    /**
     * Widmark distribution coefficient r for females.
     * Females have a lower average water-to-mass ratio (≈ 60 % of body mass),
     * leading to a higher BAC for the same dose.
     */
    private const val R_FEMALE = 0.6

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
     * Important: only entries with [alcoholPercent] > 0 should be included in
     * [totalGrams], and their earliest timestamp should be used for [hoursElapsed].
     * Including alcohol-free entries would falsely push the start time earlier,
     * underestimating the BAC.
     *
     * @param totalGrams    Total grams of pure alcohol in the current episode.
     * @param weightKg      Body weight in kilograms (must be > 0).
     * @param gender        Determines the Widmark r coefficient.
     * @param hoursElapsed  Hours since the first alcoholic drink of the episode.
     *                      Negative values are treated as 0 (coerced).
     * @return              Estimated BAC in ‰, always ≥ 0.0.
     *                      Returns 0.0 for invalid inputs (weight ≤ 0 or no alcohol).
     */
    fun calculateBAC(
        totalGrams: Double,
        weightKg: Double,
        gender: Gender,
        hoursElapsed: Double
    ): Double {
        if (weightKg <= 0 || totalGrams <= 0) return 0.0
        val r   = if (gender == Gender.FEMALE) R_FEMALE else R_MALE
        val raw = (totalGrams / (weightKg * r)) - (BETA * hoursElapsed.coerceAtLeast(0.0))
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
     * Returns the [LimitInfo] appropriate for the given [settings].
     *
     * This is the single place where [AppSettings] is translated into a
     * concrete gram threshold. Keeping the derivation here (in the domain
     * layer) means ViewModels and the PDF exporter both use the same logic.
     *
     * WHO and DHS mandate at least 2 abstinent days per week, which equals
     * a maximum of 5 drink days. Custom mode uses [AppSettings.customMaxDrinkDays].
     *
     * Note: [LimitInfo] carries no UI label. Use the `@Composable` extension
     * `LimitMode.localizedLabel` for a localised string in the UI.
     *
     * @param settings  Current user preferences.
     * @return          [LimitInfo] with the resolved mode and gram threshold.
     */
    fun getLimitInfo(settings: AppSettings): LimitInfo {
        return when (settings.limitMode) {
            LimitMode.WHO -> LimitInfo(
                mode                 = LimitMode.WHO,
                limitGrams           = if (settings.gender == Gender.FEMALE) WHO_LIMIT_FEMALE else WHO_LIMIT_MALE,
                maxDrinkDaysPerWeek  = 5
            )
            LimitMode.DHS -> LimitInfo(
                mode                 = LimitMode.DHS,
                limitGrams           = if (settings.gender == Gender.FEMALE) DHS_LIMIT_FEMALE else DHS_LIMIT_MALE,
                maxDrinkDaysPerWeek  = 5
            )
            LimitMode.CUSTOM -> LimitInfo(
                mode                 = LimitMode.CUSTOM,
                limitGrams           = settings.customLimitGrams,
                maxDrinkDaysPerWeek  = settings.customMaxDrinkDays.coerceIn(1, 7)
            )
        }
    }

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

    /**
     * Returns the binge-drinking threshold in grams for the given [gender].
     *
     * @param gender  Biological sex.
     * @return        Grams of alcohol per occasion above which the WHO/NIAAA
     *                considers an event to be a binge-drinking episode.
     */
    fun bingeThreshold(gender: Gender): Double =
        if (gender == Gender.FEMALE) BINGE_THRESHOLD_FEMALE else BINGE_THRESHOLD_MALE

    /**
     * Computes the traffic-light capacity status for one drink serving.
     *
     * Answers: "How many more of this drink can I log before exceeding my limits?"
     * The result is [TrafficLight.GREEN] (≥2 servings remain), [TrafficLight.YELLOW]
     * (exactly 1 remains), or [TrafficLight.RED] (0 remain).
     *
     * Logic:
     *   - Compute how many whole servings fit into the remaining daily headroom.
     *   - If the weekly limit is enabled, do the same for the weekly headroom
     *     and take the MINIMUM of the two counts (the stricter limit wins).
     *   - Alcohol-free drinks (alcoholPercent = 0 → gramsPerDrink = 0) always
     *     return [TrafficLight.GREEN] since they don't consume any limit budget.
     *
     * @param gramsPerDrink    Grams for one serving at the current volume.
     * @param consumedGrams    Grams already consumed against the active budget.
     *                         In daily mode  → today's grams.
     *                         In weekly mode → this week's total grams.
     * @param gramBudget       Active gram budget.
     *                         In daily mode  → daily limit.
     *                         In weekly mode → [maxDrinkDaysPerWeek] × daily limit.
     * @param rawTodayGrams    Today's actual grams, used ONLY to determine whether
     *                         today already counts as a drink day.
     *                         Always pass [DrinkCapacity.todayGrams], never the
     *                         effective value – a Monday drink must not make Tuesday
     *                         appear as a drink day in the weekly-mode check.
     * @param drinkDaysThisWeek  Distinct days this week with ≥1 entry.
     * @param maxDrinkDaysPerWeek  Max allowed drink days/week.
     * @return                 [TrafficLight] status.
     */
    fun trafficLight(
        gramsPerDrink: Double,
        consumedGrams: Double,
        gramBudget: Double,
        rawTodayGrams: Double,
        drinkDaysThisWeek: Int,
        maxDrinkDaysPerWeek: Int
    ): TrafficLight {
        if (gramsPerDrink <= 0.0) return TrafficLight.GREEN

        // Drink-day check: uses rawTodayGrams so the check is always about *today*.
        val todayIsAlreadyDrinkDay = rawTodayGrams > 0.0
        if (!todayIsAlreadyDrinkDay && drinkDaysThisWeek >= maxDrinkDaysPerWeek) {
            return TrafficLight.RED
        }

        // Gram check: how many whole servings fit into the remaining budget?
        val remaining = (gramBudget - consumedGrams).coerceAtLeast(0.0)
        val count     = (remaining / gramsPerDrink).toInt()

        return when {
            count == 0 -> TrafficLight.RED
            count == 1 -> TrafficLight.YELLOW
            else       -> TrafficLight.GREEN
        }
    }
}
