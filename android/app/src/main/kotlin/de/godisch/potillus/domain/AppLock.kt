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
// AppLock.kt – the re-auth threshold, decided without a device
// =============================================================================
//
// The one arithmetic decision behind the biometric lock: has the app been in the
// background long enough that returning to it must prompt again? Everything that
// needs a sensor, a prompt, or an Activity lifecycle stays in MainActivity; this
// object is the part both platforms must agree on, and it is pinned by the
// shared golden vectors in `test-vectors/app-lock.json` — the same file the
// Swift suite asserts (`AppLockVectorTest.swift` against `AppLock.requiresReauth`
// in PotillusKit).
//
// WHY THIS WAS EXTRACTED (0.83.0 QA round)
//   The arithmetic used to live inline in MainActivity, untestable without an
//   instrumented device, and it silently diverged from iOS at the boundary:
//   Android compared with a strict `>` while the vectors — and the Swift port
//   that adopted them first — pin `>=` ("exactly at the threshold: prompt").
//   One millisecond of user-visible difference, but exactly the class of drift
//   the vector mechanism exists to catch, and it could not catch what only one
//   platform loaded. The comparison is now `>=` on both platforms, and this
//   side loads the vectors too.
// =============================================================================

/** The biometric gate's platform-neutral arithmetic. */
object AppLock {

    /**
     * Minimum background duration after which re-authentication is required.
     * 30 seconds is a common default for health and finance apps; long enough
     * to survive a brief pocket-lock but short enough to deter casual snooping.
     * The shared vector file repeats this value (`thresholdSeconds`), so a
     * change here shows up as a vector mismatch on the other platform.
     */
    const val REAUTH_THRESHOLD_MS = 30_000L

    /**
     * Whether returning to the foreground now requires another prompt.
     *
     * Two monotonic readings ([android.os.SystemClock.elapsedRealtime] in
     * production), one subtraction, no clock access — which is what makes this
     * testable against the shared vectors on the JVM.
     *
     * @param backgroundedAtMillis The monotonic reading recorded when the app
     *        last went to the background, or `null` if it has not been
     *        backgrounded since it unlocked (MainActivity's `0L` sentinel maps
     *        to `null` at the call site). Nothing can have expired then.
     * @param nowMillis The monotonic reading on return.
     * @return `true` when the gap MEETS OR EXCEEDS the threshold (`>=`, the
     *         boundary the vectors pin). A negative gap — which a monotonic
     *         source should never produce — is treated as "no time passed"
     *         rather than trusted, mirroring the Swift port: the only way to
     *         get one is a bug or a tampered reading, and neither should
     *         unlock anything.
     */
    fun requiresReauth(backgroundedAtMillis: Long?, nowMillis: Long): Boolean {
        if (backgroundedAtMillis == null) return false
        val elapsed = nowMillis - backgroundedAtMillis
        if (elapsed < 0L) return false
        return elapsed >= REAUTH_THRESHOLD_MS
    }
}
