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

import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Branch test for [CsvExporter.buildCsv]: the category is taken from a matching
 * drink definition (the "drink found" side of the lookup), complementing the
 * unknown-id fallback covered elsewhere.
 */
class CsvExporterCategoryTest {

    @Test fun `buildCsv uses the category of a matching drink definition`() {
        val drink = DrinkDefinition(
            id = 7,
            name = "Lager",
            volumeMl = 500,
            alcoholPercent = 5.0,
            category = DrinkCategory.BEER,
        )
        val entry = ConsumptionEntry(
            drinkId = 7,
            drinkName = "Lager",
            volumeMl = 500,
            alcoholPercent = 5.0,
            gramsAlcohol = 20.0,
            timestampMillis = 1_700_000_000_000L,
            logicalDate = "2026-01-01",
        )
        val csv = CsvExporter.buildCsv(
            listOf("d", "t", "drink", "cat", "v", "a", "g", "n"),
            listOf(entry),
            listOf(drink),
        )
        assertTrue("matching drink category BEER must appear", csv.contains("BEER"))
    }
}
