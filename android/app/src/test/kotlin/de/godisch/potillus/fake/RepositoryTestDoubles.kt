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
package de.godisch.potillus.fake

import de.godisch.potillus.data.db.dao.LogicalDayKeyDao
import de.godisch.potillus.data.db.entity.LogicalDayKeyEntity
import de.godisch.potillus.data.repository.Transactor

// =============================================================================
// RepositoryTestDoubles.kt – the two seams EntryRepository needs beside its DAO
// =============================================================================
//
// `EntryRepository` takes a `Transactor` and a `LogicalDayKeyDao` alongside the
// entry DAO. Both are here as plain in-memory stand-ins, so the repository's own
// tests keep running on the JVM: the alternative was giving the repository an
// `AppDatabase`, which would have moved them onto a device.
// =============================================================================

/**
 * A [Transactor] that simply runs the block.
 *
 * WHAT IS AND IS NOT BEING TESTED WITH THIS. The realignment's DECISIONS — when
 * it rewrites, what it rewrites to, which rows it repairs first, what it leaves
 * in the key — are arithmetic over values, and this double exercises all of
 * them. Its ATOMICITY is not: a list in memory cannot be left half-written, so
 * there is nothing here for a rollback to undo. That property belongs to Room
 * and is asserted where a real database is available.
 */
class DirectTransactor : Transactor {
    override suspend fun <T> inTransaction(block: suspend () -> T): T = block()
}

/**
 * The one-row key table, in memory.
 *
 * Starts empty, which is what a fresh `MIGRATION_3_4` leaves behind: the row
 * exists on disk but holds NULLs, and every reader treats a missing row and a
 * NULL-filled one alike (see [LogicalDayKeyDao.get]).
 */
class FakeLogicalDayKeyDao(private var key: LogicalDayKeyEntity? = null) : LogicalDayKeyDao {

    override suspend fun get(): LogicalDayKeyEntity? = key

    override suspend fun put(key: LogicalDayKeyEntity) {
        this.key = key
    }

    override suspend fun invalidate() {
        key = LogicalDayKeyEntity()
    }
}
