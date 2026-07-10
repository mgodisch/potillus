// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import CryptoKit
import Foundation
import Security

// =============================================================================
// SecretKeyProviding.swift – where the preferences encryption key lives
// =============================================================================
//
// The iOS counterpart of the Android Keystore alias "potillus_prefs_key".
//
// The key is a protocol, not a global, for one reason: the Keychain is not
// reachable from a plain `swift test` process (it has no code-signing entitlement
// for a keychain access group). Injecting the provider lets the store be tested
// against an in-memory key, while the app injects the real Keychain one. The
// crypto under test is then exactly the crypto that ships.
// =============================================================================

/// Supplies the symmetric key used to encrypt the preferences file.
public protocol SecretKeyProviding: Sendable {
    /// The key, created on first use and stable thereafter.
    func key() throws -> SymmetricKey
}

/// Everything that can go wrong reaching the Keychain.
public enum KeychainError: Error, Equatable, CustomStringConvertible {
    case unexpectedStatus(OSStatus)
    case unexpectedKeySize(Int)

    public var description: String {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .unexpectedKeySize(let bytes):
            return "Stored key has \(bytes) bytes, expected 32."
        }
    }
}

/// Stores a 256-bit key in the Keychain, generating it on first launch.
public struct KeychainKeyProvider: SecretKeyProviding {

    /// Bytes in an AES-256 key.
    private static let keyByteCount = 32

    private let service: String
    private let account: String

    /// - Parameters:
    ///   - service: Keychain service, defaults to the bundle identifier.
    ///   - account: Item name; the analogue of the Android Keystore alias.
    public init(
        service: String = "de.godisch.potillus",
        account: String = "potillus_prefs_key"
    ) {
        self.service = service
        self.account = account
    }

    public func key() throws -> SymmetricKey {
        if let existing = try loadKey() { return existing }
        return try createKey()
    }

    // ── Keychain plumbing ────────────────────────────────────────────────────

    /// The query identifying our one item.
    ///
    /// `kSecUseDataProtectionKeychain` opts in to the modern, iOS-style keychain
    /// on every platform, so the same code behaves identically on macOS.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private func loadKey() throws -> SymmetricKey? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.unexpectedStatus(status) }
            guard data.count == Self.keyByteCount else {
                throw KeychainError.unexpectedKeySize(data.count)
            }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func createKey() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let bytes = key.withUnsafeBytes { Data($0) }

        var attributes = baseQuery
        attributes[kSecValueData as String] = bytes
        // WhenUnlockedThisDeviceOnly is the strictest sensible class:
        //   - "WhenUnlocked": unreadable while the device is locked, so a stolen
        //     locked phone yields nothing.
        //   - "ThisDeviceOnly": the item is excluded from every backup, iCloud
        //     and encrypted local alike, and never migrates to a new device.
        // The consequence is deliberate and matches the Android design: restoring
        // a device backup does NOT carry the key across, so the encrypted
        // preferences file becomes unreadable. That is acceptable because the
        // preferences are re-derivable — the JSON backup carries them — while a
        // key that travels in backups would undo the point of encrypting at all.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        return key
    }
}

/// A key held only in memory, for tests. Never used by the app.
public struct InMemoryKeyProvider: SecretKeyProviding {
    private let symmetricKey: SymmetricKey

    public init(key: SymmetricKey = SymmetricKey(size: .bits256)) {
        self.symmetricKey = key
    }

    public func key() throws -> SymmetricKey { symmetricKey }
}
