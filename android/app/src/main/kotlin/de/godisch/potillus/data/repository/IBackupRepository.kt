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
package de.godisch.potillus.data.repository

// =============================================================================
// IBackupRepository.kt – Contract for transactional backup import operations
// =============================================================================
//
// WHY A DEDICATED REPOSITORY?
//   Backup import requires a database transaction that spans both
//   the `entries` and `drinks` tables. Previously this transaction lived in
//   SettingsViewModel, giving the ViewModel direct AppDatabase access – a
//   layer violation. Moving it here:
//     - Keeps ViewModels free of AppDatabase references.
//     - Makes the import logic independently testable via FakeBackupRepository.
//     - Separates the "how to import" concern from the "when to import" concern.
// =============================================================================

import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkDefinition

/**
 * Counts of rows affected by a single backup import operation.
 *
 * @param imported  Number of entries successfully written to the database.
 * @param skipped   Number of entries skipped because an identical row already
 *                  existed (MERGE mode only; always 0 in REPLACE mode).
 */
data class ImportStats(val imported: Int, val skipped: Int)

/** Contract for transactional backup import operations. */
interface IBackupRepository {

    /**
     * Deletes all user data and replaces it with the backup content.
     *
     * Runs in a single database transaction: either every backup row is
     * inserted, or none are (the database is unchanged on failure).
     *
     * Preset drinks are preserved; their IDs are reused when a backup drink
     * shares the same name as a preset.
     *
     * @param backupDrinks   Drink definitions from the parsed backup.
     * @param backupEntries  Consumption entries from the parsed backup.
     * @return               [ImportStats] with [ImportStats.imported] = total entries inserted.
     */
    suspend fun importReplace(
        backupDrinks:  List<DrinkDefinition>,
        backupEntries: List<ConsumptionEntry>
    ): ImportStats

    /**
     * Merges backup content into the existing database, skipping duplicates.
     *
     * A duplicate is detected by (timestampMillis, drinkId) pair. Drink
     * definitions in the backup are matched to existing local drinks by name;
     * if a match is found the existing ID is used, otherwise a new drink is
     * inserted.
     *
     * @param backupDrinks   Drink definitions from the parsed backup.
     * @param backupEntries  Consumption entries from the parsed backup.
     * @return               [ImportStats] with both [ImportStats.imported] and
     *                       [ImportStats.skipped] populated.
     */
    suspend fun importMerge(
        backupDrinks:  List<DrinkDefinition>,
        backupEntries: List<ConsumptionEntry>
    ): ImportStats
}
