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
package de.godisch.potillus.domain

// =============================================================================
// AppLockVectorTest.kt – cross-platform parity suite for the re-auth threshold
// =============================================================================
//
// Asserts the JVM implementation against `test-vectors/app-lock.json`, the same
// file the iOS Swift suite loads (`AppLockVectorTest.swift`). Until the 0.83.0
// QA round this vector was one-sided: only iOS asserted it, so Android's strict
// `>` at the 30-second boundary diverged unnoticed from the `>=` the vectors
// pin. Loading the file here is what makes the "loaded by BOTH platforms"
// promise of test-vectors/README.md true for the lock.
//
// The vector times are in SECONDS (as doubles); the Kotlin implementation works
// in milliseconds, so each reading is scaled on the way in — the same conversion
// direction the file's own `_comment` describes.
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Test

class AppLockVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("app-lock")

        /** Seconds (vector unit) to the milliseconds the implementation takes. */
        fun seconds(value: Double): Long = (value * 1000.0).toLong()
    }

    /**
     * The vector file repeats the threshold so it is self-contained; a change to
     * the constant on one platform must show up as a mismatch here.
     */
    @Test
    fun `the vector threshold matches the implementation constant`() {
        assertEquals(
            AppLock.REAUTH_THRESHOLD_MS,
            seconds(VECTORS.getDouble("thresholdSeconds")),
        )
    }

    @Test
    fun `requiresReauth matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("requiresReauth")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val backgroundedAt =
                if (case.isNull("backgroundedAt")) null else seconds(case.getDouble("backgroundedAt"))
            val actual = AppLock.requiresReauth(
                backgroundedAtMillis = backgroundedAt,
                nowMillis = seconds(case.getDouble("now")),
            )
            assertEquals(
                "requiresReauth: ${case.getString("description")}",
                case.getBoolean("expected"),
                actual,
            )
        }
    }
}
