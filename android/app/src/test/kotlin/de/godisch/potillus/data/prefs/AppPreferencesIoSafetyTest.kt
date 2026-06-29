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
package de.godisch.potillus.data.prefs

import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.mutablePreferencesOf
import java.io.IOException
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import org.junit.Test

// =============================================================================
// AppPreferencesIoSafetyTest – unit tests for recoverIoAsEmpty(...)
// =============================================================================
//
// WHAT IS UNDER TEST
//   recoverIoAsEmpty(source) is the small, Android-free guard that the encrypted
//   DataStore settingsFlow (AppPreferences.settingsFlow) is routed through. It
//   must turn a *transient* read IOException into a single
//   emptyPreferences() emission (so the downstream map falls back to defaults
//   instead of crashing every collector), while letting any non-IO exception —
//   a genuine bug — propagate unchanged.
//
// WHY THIS RUNS ON THE PLAIN JVM (no device, no Context)
//   recoverIoAsEmpty only transforms a Flow<Preferences>; it touches neither the
//   Android Keystore nor the filesystem. Constructing real Preferences values
//   for the inputs is done with the public datastore-preferences builders
//   (mutablePreferencesOf / intPreferencesKey), which are pure data structures.
//   The test therefore needs none of the Robolectric / instrumentation machinery.
// =============================================================================

/** Verifies the IOException-to-defaults recovery contract of [recoverIoAsEmpty]. */
class AppPreferencesIoSafetyTest {

    /** A transient [IOException] is swallowed and replaced by one empty snapshot. */
    @Test
    fun ioExceptionIsRecoveredToEmptyPreferences() = runTest {
        val emissions = recoverIoAsEmpty(flow<Preferences> { throw IOException("transient read") }).toList()

        assertEquals(1, emissions.size, "exactly one fallback value should be emitted")
        assertTrue(emissions.single().asMap().isEmpty(), "fallback must be empty preferences")
    }

    /**
     * Values that arrive before a transient [IOException] are passed through, and
     * the error is then recovered to an empty snapshot appended at the end.
     */
    @Test
    fun valuesBeforeAnIoExceptionArePreservedThenRecovered() = runTest {
        val key = intPreferencesKey("k")
        val good = mutablePreferencesOf(key to 7)

        val emissions = recoverIoAsEmpty(
            flow {
                emit(good)
                throw IOException("read fault after first value")
            }
        ).toList()

        assertEquals(2, emissions.size)
        assertEquals(7, emissions[0][key], "the pre-error value must be forwarded unchanged")
        assertTrue(emissions[1].asMap().isEmpty(), "the IOException must be recovered to empty")
    }

    /** A non-IO exception is a real bug and must NOT be swallowed. */
    @Test
    fun nonIoExceptionIsRethrown() = runTest {
        assertFailsWith<IllegalStateException> {
            recoverIoAsEmpty(flow<Preferences> { throw IllegalStateException("boom") }).toList()
        }
    }

    /** A healthy stream is forwarded verbatim, with no extra emissions. */
    @Test
    fun healthyStreamPassesThroughUnchanged() = runTest {
        val key = intPreferencesKey("k")
        val prefs = mutablePreferencesOf(key to 42)

        val emissions = recoverIoAsEmpty(flowOf<Preferences>(prefs)).toList()

        assertEquals(1, emissions.size)
        assertEquals(42, emissions.single()[key])
    }
}
