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
/*
 * PARITY TEST — the sealed-preferences byte layout
 *
 * Asserts KeystoreSecretStore's OPENING path against
 * `test-vectors/sealed-blob.json`, the same file the iOS Swift suite loads
 * (`SealedBlobVectorTest.swift` against CryptoKit's AES.GCM). The assurance
 * case claims both platforms write the identical `nonce || ciphertext || tag`
 * layout; until this file that claim rested on comments alone. A fixed key
 * and a fixed blob that open on both sides is the strongest pin available,
 * because neither platform can inject a nonce into its sealing path.
 */
package de.godisch.potillus.data.security

import de.godisch.potillus.domain.SharedTestVectors
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.security.GeneralSecurityException
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec

class SealedBlobVectorTest {

    private companion object {
        val VECTORS = SharedTestVectors.load("sealed-blob")

        /** Lower-case hex, as the vector file writes every byte string. */
        fun hex(value: String): ByteArray =
            ByteArray(value.length / 2) { value.substring(it * 2, it * 2 + 2).toInt(16).toByte() }

        val KEY: SecretKey = SecretKeySpec(hex(VECTORS.getString("keyHex")), "AES")
    }

    private val store = KeystoreSecretStore(keyAlias = "vector-alias")

    /** The vector's framing numbers are the constants the implementation uses. */
    @Test
    fun `the vector framing matches the implementation`() {
        assertEquals(12, VECTORS.getInt("nonceLength"))
        assertEquals(16, VECTORS.getInt("tagLength"))
        assertEquals(32, KEY.encoded.size)
    }

    @Test
    fun `openWithKey matches the shared vectors`() {
        val cases = VECTORS.getJSONArray("open")
        (0 until cases.length()).map { cases.getJSONObject(it) }.forEach { case ->
            val description = case.getString("description")
            val blob = hex(case.getString("blobHex"))
            if (case.optBoolean("expectFailure", false)) {
                assertThrows(description, GeneralSecurityException::class.java) {
                    store.openWithKey(KEY, blob)
                }
            } else {
                assertArrayEquals(
                    description,
                    case.getString("expected").toByteArray(Charsets.UTF_8),
                    store.openWithKey(KEY, blob),
                )
            }
        }
    }
}
