/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
package de.godisch.potillus.fake

import de.godisch.potillus.data.repository.IBackupRepository
import de.godisch.potillus.data.repository.ImportStats
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition

// See FakeEntryRepository.kt for the general rationale behind Fake vs Mock.

class FakeBackupRepository : IBackupRepository {

    // Recorded call arguments – useful for verifying which mode was used.
    var lastReplaceCall: Pair<List<DrinkDefinition>, List<ConsumptionEntry>>? = null
    var lastMergeCall:   Pair<List<DrinkDefinition>, List<ConsumptionEntry>>? = null

    // Configurable return values for tests.
    var replaceResult: ImportStats = ImportStats(imported = 0, skipped = 0)
    var mergeResult:   ImportStats = ImportStats(imported = 0, skipped = 0)

    // Set to non-null to simulate a failure (throws this exception).
    var throwOnImport: Exception? = null

    override suspend fun importReplace(
        backupDrinks:  List<DrinkDefinition>,
        backupEntries: List<ConsumptionEntry>
    ): ImportStats {
        throwOnImport?.let { throw it }
        lastReplaceCall = backupDrinks to backupEntries
        return replaceResult
    }

    override suspend fun importMerge(
        backupDrinks:  List<DrinkDefinition>,
        backupEntries: List<ConsumptionEntry>
    ): ImportStats {
        throwOnImport?.let { throw it }
        lastMergeCall = backupDrinks to backupEntries
        return mergeResult
    }
}
