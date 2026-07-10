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
package de.godisch.potillus.util

import de.godisch.potillus.domain.SharedTestVectors
import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// =============================================================================
// ReportDataVectorTest – PdfReportData against the shared golden vectors
// =============================================================================
//
// The same file drives Swift's ReportDataTests. Both compute the figures the PDF
// states, and a difference between them is a difference between two PDFs of the
// same drinking.
//
// SCOPE: the vectors pin only what does not depend on the device time zone, the
// device locale or the real clock — `PdfReportData.from` reads all three itself.
// The hour-of-day profile, the weekday columns and the abstinence streaks are
// therefore checked on the Swift side, where they can be injected, and by this
// module's own PdfReportDataTest.
// =============================================================================

class ReportDataVectorTest {

    companion object {
        val VECTORS: JSONObject = SharedTestVectors.load("report-data")
        const val EPS = 1e-6

        fun JSONArray.objects(): Sequence<JSONObject> =
            (0 until length()).asSequence().map { getJSONObject(it) }
    }

    private fun settings(case: JSONObject): AppSettings = AppSettings(
        dailyLimitGrams = case.getDouble("dailyLimitGrams"),
        weeklyLimitGrams = case.getDouble("weeklyLimitGrams"),
        maxDrinkDaysPerWeek = case.getInt("maxDrinkDaysPerWeek"),
        weightKg = 80.0,
    )

    private fun drinks(case: JSONObject): List<DrinkDefinition> =
        case.getJSONArray("drinks").objects().map { drink ->
            DrinkDefinition(
                id = drink.getLong("id"),
                name = "d${drink.getLong("id")}",
                volumeMl = 500,
                alcoholPercent = 5.0,
                category = DrinkCategory.valueOf(drink.getString("category")),
            )
        }.toList()

    private fun entries(case: JSONObject): List<ConsumptionEntry> =
        case.getJSONArray("entries").objects().map { entry ->
            ConsumptionEntry(
                id = entry.getLong("id"),
                drinkId = entry.getLong("drinkId"),
                drinkName = "x",
                volumeMl = 500,
                alcoholPercent = 5.0,
                gramsAlcohol = entry.getDouble("gramsAlcohol"),
                timestampMillis = 0L,
                logicalDate = entry.getString("logicalDate"),
            )
        }.toList()

    @Test
    fun `the computed figures match the shared vectors`() {
        VECTORS.getJSONArray("cases").objects().forEach { case ->
            val label = case.getString("description")
            val data = PdfReportData.from(
                entries = entries(case),
                drinks = drinks(case),
                settings = settings(case),
            )
            val expected = case.getJSONObject("expected")

            assertEquals(label, expected.getString("firstDate"), data.firstDate)
            assertEquals(label, expected.getString("lastDate"), data.lastDate)
            assertEquals(label, expected.getInt("totalDays"), data.totalDays)
            assertEquals(label, expected.getInt("drinkDays"), data.drinkDays)
            assertEquals(label, expected.getInt("abstinentDays"), data.abstinentDays)
            assertEquals(label, expected.getInt("bingeDays"), data.bingeDays)
            assertEquals(
                label,
                expected.getInt("daysOverDailyLimit"),
                data.violations.daysOverDailyLimit,
            )
            assertEquals(label, expected.getDouble("totalGrams"), data.totalGrams, EPS)
            assertEquals(label, expected.getDouble("avgPerDay"), data.avgPerDay, EPS)
            assertEquals(label, expected.getDouble("avgPerDrinkDay"), data.avgPerDrinkDay, EPS)
            assertEquals(label, expected.getDouble("medianPerDay"), data.medianPerDay, EPS)
            assertEquals(
                label,
                expected.getDouble("medianPerDrinkDay"),
                data.medianPerDrinkDay,
                EPS,
            )
            assertEquals(
                label,
                expected.getDouble("avgDrinkDaysPerMonth"),
                data.avgDrinkDaysPerMonth,
                EPS,
            )
            assertEquals(
                label,
                expected.getDouble("medianDrinkDaysPerMonth"),
                data.medianDrinkDaysPerMonth,
                EPS,
            )
            assertEquals(label, expected.getDouble("maxPerDay"), data.maxPerDay, EPS)
            assertEquals(label, expected.getDouble("maxPer7Days"), data.maxPer7Days, EPS)

            val months = expected.getJSONArray("months")
            assertEquals(label, months.length(), data.months.size)
            months.objects().forEachIndexed { index, month ->
                val actual = data.months[index]
                assertEquals(label, month.getString("monthKey"), actual.monthKey)
                assertEquals(label, month.getInt("drinkDays"), actual.drinkDays)
                assertEquals(
                    label,
                    month.getInt("daysOverDailyLimit"),
                    actual.daysOverDailyLimit,
                )
                assertEquals(label, month.getDouble("totalGrams"), actual.totalGrams, EPS)
                assertEquals(
                    label,
                    month.getDouble("avgPerCalendarDay"),
                    actual.avgPerCalendarDay,
                    EPS,
                )
            }

            val categories = expected.getJSONArray("categories")
            assertEquals(label, categories.length(), data.categories.size)
            categories.objects().forEachIndexed { index, category ->
                val actual = data.categories[index]
                assertEquals(label, category.getString("categoryName"), actual.categoryName)
                assertEquals(label, category.getInt("percent"), actual.percent)
                assertEquals(label, category.getDouble("grams"), actual.grams, EPS)
            }
        }
    }

    @Test
    fun `the vector file is not empty`() {
        assertTrue(VECTORS.getJSONArray("cases").length() >= 5)
    }
}
