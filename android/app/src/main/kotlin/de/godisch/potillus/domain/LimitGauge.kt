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
// LimitGauge.kt – what a progress bar should show, without knowing about UI
// =============================================================================
//
// The Kotlin twin of PotillusKit's `LimitGauge`. The rules `LimitBar` and
// `DrinkDaysBar` in ui/component/Components.kt encode — how full the bar is,
// and whether it reads calm, warning or danger — used to sit inline in the two
// composables, where Kover does not measure and no JVM test reaches. Now they
// are here, and pinned to the iOS port by `test-vectors/limit-gauge.json`
// (`LimitGaugeVectorTest` on each side). The composables map [Emphasis] onto
// colours and nothing else.
//
// TWO FRACTIONS, NOT ONE
//   The bar's FILL is clamped to 0..1, or a 130 % day would draw past the
//   track. The EMPHASIS is decided from the UNCLAMPED value, so the overflow
//   still shows. Conflating them would either break the layout or hide the
//   violation.
//
// A DELIBERATE ASYMMETRY BETWEEN THE TWO BARS
//   GRAMS. Danger only when the limit is EXCEEDED, decided by the domain's ONE
//   definition of "over the limit" (`AlcoholCalculator.isOverLimit`) — the
//   epsilon-guarded check the calendar dots, the chart and the report use.
//   Reaching the limit exactly is allowed, so a full bar stays amber.
//
//   DRINK DAYS. A full bar does NOT mean stop, because a drink day, once spent,
//   stays spent for the whole day. What matters is whether the allowance was
//   already exhausted BEFORE today, which is exactly what the traffic-light
//   gate `AlcoholCalculator.drinkDayLimitReached` answers: at the cap with
//   today already a drink day → warning (today is free); at the cap with today
//   still dry → danger (the first drink would spend a day the user does not
//   have).
// =============================================================================

/** How a bar reads. The composables map this onto colours. */
enum class Emphasis { CALM, WARNING, DANGER }

object LimitGauge {

    /** Above this fraction of the allowance a bar turns amber. */
    const val WARNING_THRESHOLD = 0.75f

    /** The gram bar's fill, clamped to 0..1. An unconfigured limit draws empty. */
    fun fillFraction(totalGrams: Double, limitGrams: Double): Float =
        AlcoholCalculator.limitPercent(totalGrams, limitGrams).coerceIn(0f, 1f)

    /** The gram bar's emphasis, from the UNCLAMPED fraction. */
    fun emphasis(totalGrams: Double, limitGrams: Double): Emphasis = when {
        limitGrams <= 0.0 -> Emphasis.CALM
        AlcoholCalculator.isOverLimit(totalGrams, limitGrams) -> Emphasis.DANGER
        AlcoholCalculator.limitPercent(totalGrams, limitGrams) >= WARNING_THRESHOLD -> Emphasis.WARNING
        else -> Emphasis.CALM
    }

    /** The drink-day bar's fill, clamped to 0..1; a cap below 1 counts as 1. */
    fun drinkDaysFillFraction(drinkDays: Int, maxDrinkDays: Int): Float =
        (drinkDays.toFloat() / maxDrinkDays.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)

    /** The drink-day bar's emphasis; see the header for the asymmetry. */
    fun drinkDaysEmphasis(drinkDays: Int, maxDrinkDays: Int, todayIsDrinkDay: Boolean): Emphasis {
        if (AlcoholCalculator.drinkDayLimitReached(drinkDays, maxDrinkDays, todayIsDrinkDay)) {
            return Emphasis.DANGER
        }
        val fraction = (drinkDays.toFloat() / maxDrinkDays.toFloat().coerceAtLeast(1f)).coerceAtLeast(0f)
        return if (fraction < WARNING_THRESHOLD) Emphasis.CALM else Emphasis.WARNING
    }
}
