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
 *
 * UNIT TEST — KeystoreSecretStore
 *
 * The real Android Keystore is unavailable on the plain JVM, so these tests
 * exercise the pure cipher logic via the key-injecting seam
 * (sealWithKey / openWithKey) using an ordinary software AES-256 key. This
 * validates everything that does NOT depend on the Keystore: the IV framing,
 * the encrypt/decrypt round-trip, GCM tamper detection, and malformed input.
 *
 * The Keystore-backed key generation/lookup (getOrCreateKey) is intentionally
 * NOT covered here — it requires an instrumented (androidTest) environment.
 */
package de.godisch.potillus.data.security

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test
import java.security.GeneralSecurityException
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Verifies the envelope-encryption logic of [KeystoreSecretStore].
 */
class KeystoreSecretStoreTest {

    private val store = KeystoreSecretStore(keyAlias = "test-alias")

    /** A fresh software AES-256 key (no Android Keystore involved). */
    private fun softwareKey(): SecretKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    /** seal → open returns the original plaintext. */
    @Test
    fun roundTrip_returnsOriginalPlaintext() {
        val key = softwareKey()
        val plaintext = "the quick brown fox".toByteArray()

        val sealed = store.sealWithKey(key, plaintext)
        val opened = store.openWithKey(key, sealed)

        assertArrayEquals(plaintext, opened)
    }

    /** The sealed blob is framed as [12-byte IV || ciphertext+tag] and is not plaintext. */
    @Test
    fun sealed_hasIvPrefixAndIsNotPlaintext() {
        val key = softwareKey()
        val plaintext = ByteArray(32) { it.toByte() }

        val sealed = store.sealWithKey(key, plaintext)

        // 12-byte IV + ciphertext + 16-byte GCM tag ⇒ strictly longer than plaintext+IV.
        assertEquals(true, sealed.size > plaintext.size + 12)
        assertFalse("ciphertext must not equal plaintext", sealed.copyOfRange(12, sealed.size).contentEquals(plaintext))
    }

    /** Encrypting the same plaintext twice yields different output (fresh IV per call). */
    @Test
    fun sealingTwice_producesDifferentCiphertext() {
        val key = softwareKey()
        val plaintext = "same input".toByteArray()

        val a = store.sealWithKey(key, plaintext)
        val b = store.sealWithKey(key, plaintext)

        assertFalse("two seals of the same input must differ", a.contentEquals(b))
        // ...but both still decrypt back to the same plaintext.
        assertArrayEquals(plaintext, store.openWithKey(key, a))
        assertArrayEquals(plaintext, store.openWithKey(key, b))
    }

    /** A flipped byte in the ciphertext fails the GCM authentication tag check. */
    @Test
    fun tamperedCiphertext_throws() {
        val key = softwareKey()
        val sealed = store.sealWithKey(key, "payload".toByteArray())
        sealed[sealed.size - 1] = (sealed[sealed.size - 1] + 1).toByte() // corrupt the tag

        assertThrows(GeneralSecurityException::class.java) {
            store.openWithKey(key, sealed)
        }
    }

    /** Opening with a different key fails (the key is what protects the data). */
    @Test
    fun wrongKey_throws() {
        val sealed = store.sealWithKey(softwareKey(), "payload".toByteArray())

        assertThrows(GeneralSecurityException::class.java) {
            store.openWithKey(softwareKey(), sealed) // different key
        }
    }

    /** A blob shorter than the IV length is rejected with IllegalArgumentException. */
    /**
     * A truncated blob must throw a [GeneralSecurityException] — the SAME
     * exception family as tampering — because [KeystoreSecretStore.open]'s
     * public contract promises GSE for any malformed blob, and AppPreferences'
     * corruption handling catches exactly that family to reset the file. This
     * test previously pinned an `IllegalArgumentException` here, i.e. it
     * enshrined the contract violation: a truncated on-disk blob bypassed the
     * `ReplaceFileCorruptionHandler` and crashed the preferences read instead
     * of self-healing (found in the v0.79.0 QA delta review).
     */
    @Test
    fun blobTooShort_throwsGeneralSecurityException() {
        assertThrows(GeneralSecurityException::class.java) {
            store.openWithKey(softwareKey(), ByteArray(5))
        }
    }

    /** The boundary case: exactly IV-sized (12-byte) input is parsed (empty
     *  ciphertext), and then fails as a normal GCM authentication error — not
     *  as a length error. Documents where the length guard ends. */
    @Test
    fun blobExactlyIvSized_failsAuthenticationNotLengthCheck() {
        assertThrows(GeneralSecurityException::class.java) {
            store.openWithKey(softwareKey(), ByteArray(12))
        }
    }
}
