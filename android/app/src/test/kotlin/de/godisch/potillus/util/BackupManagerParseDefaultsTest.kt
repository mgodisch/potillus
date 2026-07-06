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
 * =============================================================================
 */
package de.godisch.potillus.util

import de.godisch.potillus.domain.model.DrinkCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Branch tests for [BackupManager.parseBackupJson] covering the "absent optional
 * key" paths: a backup with no drinks/entries arrays, and a drink that omits its
 * optional fields (id, isPreset, isFavorite, category), which must fall back to
 * their defaults.
 */
class BackupManagerParseDefaultsTest {

    @Test fun `backup without drinks or entries arrays parses to an empty result`() {
        val result = BackupManager.parseBackupJson("""{"version":1}""")
        assertNull(result.error)
        assertTrue(result.drinks.isEmpty())
        assertTrue(result.entries.isEmpty())
    }

    @Test fun `a drink with only required fields uses defaults`() {
        val json = """{"version":1,"drinks":[{"name":"Beer","volumeMl":500,"alcoholPercent":5.0}]}"""
        val result = BackupManager.parseBackupJson(json)
        assertNull(result.error)
        assertEquals(1, result.drinks.size)
        val drink = result.drinks.first()
        assertEquals(0L, drink.id) // id absent -> 0
        assertFalse(drink.isPreset) // isPreset absent -> false
        assertFalse(drink.isFavorite) // isFavorite absent -> false
        assertEquals(DrinkCategory.OTHER, drink.category) // category absent -> OTHER
    }
}
