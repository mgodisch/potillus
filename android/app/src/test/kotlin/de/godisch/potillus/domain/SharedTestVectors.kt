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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.domain

// =============================================================================
// SharedTestVectors.kt – loader for the cross-platform golden vectors
// =============================================================================
//
// The vectors live at the repository root in `test-vectors/`, OUTSIDE this
// Gradle module, because the iOS (Swift) test suite loads the very same files.
// Neither platform can change a health-relevant formula without either updating
// the shared vectors — a visible, reviewable change — or turning its own suite
// red. See docs/IOS_MIGRATION.md, "Correctness parity".
//
// FILE-PATH STRATEGY
//   Gradle runs unit tests with the module root (…/android/app/) as the working
//   directory, so the repository root is two levels up. The same
//   `potillus.project.dir` override the other file-reading tests honour is
//   supported here, for the case where the tests are launched from elsewhere.
//
// WHY org.json AND NOT kotlinx.serialization?
//   `org.json:json` is already on the unit-test classpath (the SDK ships only
//   throwing stubs, so a real implementation is added for the BackupManager
//   tests). Reusing it keeps this change dependency-free: no new library, no
//   SBOM entry, no change to the reproducible release build.
// =============================================================================

import org.json.JSONObject
import java.io.File

/** Access to the shared golden vectors under `test-vectors/`. */
object SharedTestVectors {

    /** The app module directory (…/android/app), per the project's test convention. */
    private val MODULE_DIR: File = run {
        val override = System.getProperty("potillus.project.dir")
        if (override != null) File(override) else File(".")
    }

    /** The repository root: two levels above the app module. */
    private val VECTOR_DIR = File(MODULE_DIR, "../../test-vectors")

    /**
     * Loads and parses one vector file.
     *
     * A missing or malformed file fails loudly rather than skipping the suite:
     * a parity check that silently does nothing is worse than none at all.
     *
     * @param name File name without the `.json` extension.
     */
    fun load(name: String): JSONObject {
        val file = File(VECTOR_DIR, "$name.json")
        check(file.isFile) {
            "Shared test vectors not found: ${file.absolutePath}. " +
                "Run unit tests from the app module, or set -Dpotillus.project.dir=<path to android/app>."
        }
        return JSONObject(file.readText())
    }
}
