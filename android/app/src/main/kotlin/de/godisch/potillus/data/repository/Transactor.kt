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
package de.godisch.potillus.data.repository

import androidx.room.withTransaction
import de.godisch.potillus.data.db.AppDatabase

// =============================================================================
// Transactor.kt – "run this as one unit", without handing out the database
// =============================================================================
//
// WHY THIS EXISTS
//   `EntryRepository.realignDays` rewrites a column across the whole `entries`
//   table and then records what it rewrote it to, in `logical_day_key`. The two
//   writes must land together or not at all — a key that describes rows which
//   were never written is worse than no key. That means a transaction, and a
//   transaction means `RoomDatabase.withTransaction`. `add` and `update` need
//   the same thing in miniature: they read the key to learn which boundary to
//   derive under and must write before that answer can change.
//
//   Giving the repository an `AppDatabase` would have been the shortest route
//   and the wrong one: the repository would then depend on Room's runtime, and
//   `EntryRepositoryTest` — which today drives it with an in-memory fake DAO on
//   the plain JVM — would need an instrumented device or Robolectric to run at
//   all. One method's worth of interface keeps that test where it is.
//
// WHY NOT `@Transaction` ON A DAO INSTEAD
//   Room can wrap a DAO method in a transaction, and that would need no seam.
//   But the body of the realignment is the day DERIVATION, and the derivation
//   belongs to the domain, not to the data-access object. Pushing it down to
//   make the plumbing easier would put `DayResolver` in the DAO layer, where the
//   next reader would not look for it.
//
// WHAT IMPLEMENTERS MUST GUARANTEE
//   That the block runs to completion or leaves no trace, and that DAO calls
//   made inside it join the same transaction. `RoomTransactor` gets both from
//   Room. A test double that simply invokes the block gets neither, which is
//   correct for a test whose fake DAO holds a map in memory and cannot be left
//   half-written anyway.
// =============================================================================

/**
 * Runs a block of database work as a single atomic unit.
 *
 * A plain interface rather than a `fun interface`: the single method carries its
 * own type parameter, and Kotlin does not convert a lambda to a generic member.
 */
interface Transactor {

    /**
     * Executes [block] inside one transaction and returns its result.
     *
     * An exception thrown out of [block] rolls the transaction back and
     * propagates, which is the behaviour the realignment relies on: an
     * interrupted rewrite leaves the previous key in place, and the next
     * comparison starts the whole thing again.
     */
    suspend fun <T> inTransaction(block: suspend () -> T): T
}

/**
 * The production [Transactor]: Room's own transaction, on Room's own dispatcher.
 *
 * `withTransaction` confines the block to the single-threaded transaction
 * executor, so suspending DAO calls inside it are part of the transaction rather
 * than racing it from another connection.
 */
class RoomTransactor(private val db: AppDatabase) : Transactor {
    override suspend fun <T> inTransaction(block: suspend () -> T): T = db.withTransaction { block() }
}
