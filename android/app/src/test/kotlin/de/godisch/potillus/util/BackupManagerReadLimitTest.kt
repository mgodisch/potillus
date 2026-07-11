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
 * UNIT TEST — BackupManager.readAllUpTo (bounded-read hardening)
 *
 * Validates the defence-in-depth byte cap that protects the JSON import path
 * from an oversized file when the content provider reports an unknown size.
 * The logic is pure (just an InputStream + a limit), so a ByteArrayInputStream
 * lets us test it on the plain JVM without an Android Context.
 */
package de.godisch.potillus.util

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.ByteArrayInputStream

/**
 * Verifies the overflow behaviour of [BackupManager.readAllUpTo].
 */
class BackupManagerReadLimitTest {

    /** A stream smaller than the cap is read in full. */
    @Test
    fun underLimit_returnsAllBytes() {
        val data = ByteArray(100) { it.toByte() }
        val result = BackupManager.readAllUpTo(ByteArrayInputStream(data), maxBytes = 1_000)
        assertArrayEquals(data, result)
    }

    /** A stream of exactly the cap size is accepted (the bound is inclusive). */
    @Test
    fun exactlyAtLimit_returnsAllBytes() {
        val data = ByteArray(256) { (it % 7).toByte() }
        val result = BackupManager.readAllUpTo(ByteArrayInputStream(data), maxBytes = 256)
        assertArrayEquals(data, result)
    }

    /** A stream one byte larger than the cap is rejected with null. */
    @Test
    fun overLimit_returnsNull() {
        val data = ByteArray(257)
        val result = BackupManager.readAllUpTo(ByteArrayInputStream(data), maxBytes = 256)
        assertNull(result)
    }

    /** An empty stream yields an empty (non-null) byte array. */
    @Test
    fun emptyStream_returnsEmptyArray() {
        val result = BackupManager.readAllUpTo(ByteArrayInputStream(ByteArray(0)), maxBytes = 256)
        assertArrayEquals(ByteArray(0), result)
    }
}
