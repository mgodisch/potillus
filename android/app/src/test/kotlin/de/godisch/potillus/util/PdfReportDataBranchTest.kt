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
package de.godisch.potillus.util

import de.godisch.potillus.domain.model.AppSettings
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/**
 * Complementary branch tests for [PdfReportData.from]. The existing
 * PdfReportDataTest covers the main happy path; these cases target the remaining
 * conditional branches: a binge day *above* the threshold, the category
 * fall-back for an unknown drink id, and the short-span (<= 7 days) path of the
 * 7-day peak window.
 */
class PdfReportDataBranchTest {

    private val beer = DrinkDefinition(id = 1, name = "Beer", volumeMl = 500, alcoholPercent = 5.0)
    private val settings = AppSettings()

    private fun entry(date: String, drinkId: Long, grams: Double, hour: Int = 12) = ConsumptionEntry(
        drinkId = drinkId,
        drinkName = "X",
        volumeMl = 500,
        alcoholPercent = 5.0,
        gramsAlcohol = grams,
        timestampMillis = LocalDate.parse(date).atTime(hour, 0)
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
        logicalDate = date,
    )

    @Test fun `binge day above threshold and unknown category fall back are handled`() {
        val entries = listOf(
            entry("2026-03-01", 1, 70.0), // > 60 g binge threshold and over the daily limit
            entry("2026-03-02", 99, 5.0), // unknown drink id -> category OTHER
        )
        val data = PdfReportData.from(entries, listOf(beer), settings)
        assertEquals("one binge day expected", 1, data.bingeDays)
        assertTrue(
            "unknown drink id must fall back to OTHER",
            data.categories.any { it.categoryName == "OTHER" },
        )
    }

    @Test fun `short span of at most seven days sums the whole window for the 7-day peak`() {
        val entries = listOf(
            entry("2026-04-01", 1, 10.0),
            entry("2026-04-03", 1, 20.0),
        )
        val data = PdfReportData.from(entries, listOf(beer), settings)
        // The period spans three days (<= 7), so maxPer7Days is the sum of all
        // daily totals rather than a sliding-window maximum.
        assertEquals(30.0, data.maxPer7Days, 0.001)
    }
}
