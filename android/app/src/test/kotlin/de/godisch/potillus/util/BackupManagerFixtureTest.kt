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

// =============================================================================
// BackupManagerFixtureTest.kt – a backup an earlier version really wrote
// =============================================================================
//
// CONTRIBUTING.md §8 promises that every version reads a backup written by
// v0.77.4 or newer. The other BackupManager tests build their JSON by hand, so
// none of them can catch a validation rule that quietly outgrew an older
// file — the gram plausibility check above all, which compares against the
// CURRENT `calculateGrams`. This test reads `fastlane/demo-backup.json`, a
// genuine version-2 file with 15 drinks and 85 entries that the screenshot
// suite seeds from, and the iOS kit reads in
// `BackupImporterTests.testTheRealAndroidDemoBackupImportsCompletely`.
// =============================================================================

import de.godisch.potillus.domain.SharedTestVectors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupManagerFixtureTest {

    @Test
    fun `the real demo backup parses completely`() {
        val result = BackupManager.parseBackupJson(SharedTestVectors.repositoryFile("fastlane/demo-backup.json"))

        assertNull("a shipped backup must import: ${result.error}", result.error)
        assertEquals(2, result.sourceVersion)
        assertEquals(15, result.drinks.size)
        assertEquals(85, result.entries.size)
        assertNull("a version-2 file carries no settings block", result.settings)

        val ids = result.drinks.mapTo(HashSet()) { it.id }
        result.entries.forEach { entry ->
            assertTrue("entry ${entry.id} references drink ${entry.drinkId}", entry.drinkId in ids)
        }
    }
}
