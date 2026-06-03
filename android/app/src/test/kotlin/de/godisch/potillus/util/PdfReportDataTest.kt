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
package de.godisch.potillus.util

import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for [PdfReportData.from], the report's pure (Context-free) data layer.
 *
 * These verify the structural figures that feed the PDF. Time-of-day hour averages
 * are intentionally NOT asserted to exact values because they depend on the test
 * runner's time zone; only their invariant (the two percentages sum to 100) is checked.
 */
class PdfReportDataTest {

    private val beer = DrinkDefinition(id = 1, name = "Beer", volumeMl = 500,
        alcoholPercent = 5.0, category = DrinkCategory.BEER)
    private val wine = DrinkDefinition(id = 2, name = "Wine", volumeMl = 200,
        alcoholPercent = 13.0, category = DrinkCategory.WINE)

    private fun entry(date: String, drinkId: Long, grams: Double) = ConsumptionEntry(
        id = 0, drinkId = drinkId, drinkName = "x", volumeMl = 0, alcoholPercent = 0.0,
        gramsAlcohol = grams, timestampMillis = 0L, logicalDate = date
    )

    /** Two months of data: one over-limit day (25 g > 20 g) in January, one quiet day in February. */
    private val entries = listOf(
        entry("2026-01-10", 1, 19.3),
        entry("2026-01-20", 2, 25.0),   // over the 20 g daily limit
        entry("2026-02-05", 1, 10.0)
    )
    private val drinks = listOf(beer, wine)
    private val settings = AppSettings()   // dailyLimit 20 g, weekStart Mon, weight 0

    private fun build() = PdfReportData.from(entries, drinks, settings)

    @Test fun `counts drink days and total grams`() {
        val d = build()
        assertEquals(3, d.drinkDays)
        assertEquals(54.3, d.totalGrams, 0.001)
        assertEquals("2026-01-10", d.firstDate)
        assertEquals("2026-02-05", d.lastDate)
        assertEquals(d.totalDays - d.drinkDays, d.abstinentDays)
    }

    @Test fun `monthly aggregation marks the over-limit month`() {
        val months = build().months
        assertEquals(2, months.size)
        assertEquals("2026-01", months[0].monthKey)
        assertEquals(2, months[0].drinkDays)
        assertEquals(1, months[0].daysOverDailyLimit)   // the 25 g day
        assertEquals("2026-02", months[1].monthKey)
        assertEquals(0, months[1].daysOverDailyLimit)
    }

    @Test fun `categories are sorted by grams with whole-percent shares summing to 100`() {
        val cats = build().categories
        assertEquals("BEER", cats[0].categoryName)          // 29.3 g > 25.0 g
        assertEquals(29.3, cats[0].grams, 0.001)
        assertEquals("WINE", cats[1].categoryName)
        assertEquals(54, cats[0].percent)
        assertEquals(46, cats[1].percent)
        assertEquals(100, cats.sumOf { it.percent })
    }

    @Test fun `daily limit violation is counted once`() {
        assertEquals(1, build().violations.daysOverDailyLimit)
    }

    @Test fun `no binge days below the 48 g threshold`() {
        assertEquals(0, build().bingeDays)
        assertEquals(48.0, PdfReportData.bingeThreshold, 0.0)
    }

    @Test fun `weekday order starts on the configured first weekday`() {
        val d = build()
        assertEquals(1, d.weekdayOrder.first())             // Monday (ISO 1)
        assertEquals(7, d.weekdayOrder.size)
        assertEquals(7, d.weekdayAverages.size)
    }

    @Test fun `time-of-day percentages are complementary`() {
        val d = build()
        assertEquals(100, d.percentBefore17 + d.percentAfter17)
    }
}
