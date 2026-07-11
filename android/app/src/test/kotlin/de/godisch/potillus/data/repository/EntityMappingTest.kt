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
 *
 * UNIT TEST — EntityMapping (shared entity ↔ domain conversions)
 *
 * These tests pin down the repository layer's conversion helpers
 * ([DrinkEntity.toDomain]/[DrinkDefinition.toEntity] and the matching
 * [EntryEntity]/[ConsumptionEntry] pair). The conversions are the single piece
 * of non-trivial logic in the otherwise pass-through repositories, and the one
 * defensive branch — an unknown category string decoding to
 * [DrinkCategory.OTHER] — is the kind of thing a future schema change could
 * silently break. The functions are pure (plain data classes, no Room, no
 * Android), so the whole suite runs on the JVM without a device.
 */
package de.godisch.potillus.data.repository

import de.godisch.potillus.data.db.entity.DrinkEntity
import de.godisch.potillus.data.db.entity.EntryEntity
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import org.junit.Assert.assertEquals
import org.junit.Test

/** Verifies the entity ↔ domain mappings used by every repository. */
class EntityMappingTest {

    // ── Drink conversions ─────────────────────────────────────────────────────

    /**
     * A drink survives a full domain → entity → domain round trip unchanged,
     * including a non-default [DrinkCategory], so no field is dropped or reordered.
     */
    @Test fun `drink round-trips domain to entity to domain`() {
        val original = DrinkDefinition(
            id = 7,
            name = "Lager (Pint)",
            volumeMl = 568,
            alcoholPercent = 4.5,
            isPreset = true,
            isFavorite = true,
            category = DrinkCategory.BEER,
        )
        assertEquals(original, original.toEntity().toDomain())
    }

    /** [DrinkDefinition.toEntity] stores the category as its [Enum.name] string. */
    @Test fun `drink toEntity stores category as enum name`() {
        val entity = DrinkDefinition(
            id = 1,
            name = "Red Wine",
            volumeMl = 150,
            alcoholPercent = 13.5,
            category = DrinkCategory.WINE,
        ).toEntity()
        assertEquals("WINE", entity.category)
    }

    /** A known category string decodes back to the matching enum constant. */
    @Test fun `drink toDomain decodes a known category string`() {
        val domain = DrinkEntity(
            id = 1,
            name = "Vodka Shot",
            volumeMl = 40,
            alcoholPercent = 40.0,
            category = "SPIRITS",
        ).toDomain()
        assertEquals(DrinkCategory.SPIRITS, domain.category)
    }

    /**
     * An unknown / misspelled category string (e.g. from a corrupted or
     * future-format backup) defaults to [DrinkCategory.OTHER] rather than
     * throwing, matching the defensive `runCatching { … }.getOrDefault(OTHER)`.
     */
    @Test fun `drink toDomain falls back to OTHER for an unknown category`() {
        val domain = DrinkEntity(
            id = 1,
            name = "Mystery",
            volumeMl = 100,
            alcoholPercent = 5.0,
            category = "NOT_A_REAL_CATEGORY",
        ).toDomain()
        assertEquals(DrinkCategory.OTHER, domain.category)
    }

    // ── Entry conversions ─────────────────────────────────────────────────────

    /**
     * An entry survives a full domain → entity → domain round trip unchanged.
     * Entry fields are mapped 1-to-1, so this guards against a field being
     * forgotten if the schema grows.
     */
    @Test fun `entry round-trips domain to entity to domain`() {
        val original = ConsumptionEntry(
            id = 42,
            drinkId = 7,
            drinkName = "Lager (Pint)",
            volumeMl = 568,
            alcoholPercent = 4.5,
            gramsAlcohol = 20.2,
            timestampMillis = 1_700_000_000_000L,
            logicalDate = "2025-05-26",
            note = "after work",
        )
        assertEquals(original, original.toEntity().toDomain())
    }

    /** The reverse direction (entity → domain → entity) is equally lossless. */
    @Test fun `entry round-trips entity to domain to entity`() {
        val entity = EntryEntity(
            id = 3,
            drinkId = 1,
            drinkName = "Red Wine",
            volumeMl = 150,
            alcoholPercent = 13.5,
            gramsAlcohol = 16.0,
            timestampMillis = 1_700_000_500_000L,
            logicalDate = "2025-05-27",
            note = "",
        )
        assertEquals(entity, entity.toDomain().toEntity())
    }
}
