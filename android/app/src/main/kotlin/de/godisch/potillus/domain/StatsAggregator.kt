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

import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition

// =============================================================================
// StatsAggregator.kt – the three aggregations the Statistics screen and the
// report share, in one place
// =============================================================================
//
// The Kotlin twin of PotillusKit's `StatsAggregator`. Until the v0.86.0 review
// the 24-hour histogram was written twice on this side — once in
// `StatsViewModel`, once in `PdfReportData` — and the category breakdown and
// the 3-hour buckets lived in the view model, where nothing tested them. Now
// all three are pure functions here, pinned to the iOS port by
// `test-vectors/stats-aggregator.json` (`StatsAggregatorVectorTest` on each
// side). `WeekdayProfile` next door is the fourth aggregation, kept in its own
// file because it has a history of its own.
//
// THE HOUR IS THE HOUR IT WAS LOGGED AT
//   `hourlyGrams` reads each entry's clock hour in the frame it was logged in
//   (`utcOffsetSeconds`), not in the device's current zone: read in the current
//   frame, a travelled or daylight-saving-crossed history moves every bar by an
//   hour. Entries without a stored offset (schema versions before 3) fall back
//   to the device zone, as `DayResolver.localDateTime` does.
// =============================================================================

object StatsAggregator {

    /**
     * Grams of pure alcohol per drink category, for the categories that saw
     * any. An entry whose drink is gone from the catalogue counts as
     * [DrinkCategory.OTHER]. Categories at 0 g are absent, not zero: the donut
     * and the legend draw only what there is.
     */
    fun categoryBreakdown(
        entries: List<ConsumptionEntry>,
        drinks: List<DrinkDefinition>,
    ): Map<DrinkCategory, Double> {
        val categoryOf = drinks.associate { it.id to it.category }
        return entries
            .groupBy { categoryOf[it.drinkId] ?: DrinkCategory.OTHER }
            .mapValues { (_, es) -> es.sumOf { it.gramsAlcohol } }
            .filter { it.value > 0.0 }
    }

    /** Grams of pure alcohol per clock hour of the day, index 0..23. */
    fun hourlyGrams(entries: List<ConsumptionEntry>): List<Double> {
        val hours = DoubleArray(24)
        entries.forEach { e ->
            val hour = DayResolver.localDateTime(e.timestampMillis, e.utcOffsetSeconds).hour
            hours[hour] += e.gramsAlcohol
        }
        return hours.toList()
    }

    /**
     * The 24 clock hours collapsed into eight 3-hour buckets (0–3, 3–6 … 21–24),
     * each as the AVERAGE grams per day of the period — the bucket's sum divided
     * by [effectivePeriodDays] — so the eight bars sum to the period's average
     * grams per day. A divisor below 1 is raised to 1, for the empty period.
     */
    fun hourBucketAverages(entries: List<ConsumptionEntry>, effectivePeriodDays: Int): List<Double> {
        val hours = hourlyGrams(entries)
        val divisor = effectivePeriodDays.coerceAtLeast(1).toDouble()
        return (0 until 8).map { bucket ->
            var sum = 0.0
            for (hour in bucket * 3 until bucket * 3 + 3) sum += hours[hour]
            sum / divisor
        }
    }
}
