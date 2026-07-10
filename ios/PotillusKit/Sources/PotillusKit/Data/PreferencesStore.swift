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

// =============================================================================
// PreferencesStore.swift – encrypted, observable user settings
// =============================================================================
//
// The iOS counterpart of Android's encrypted Jetpack DataStore
// (`data/prefs/AppPreferences.kt`), and a deliberate refusal of the easy option.
//
// WHY NOT `UserDefaults`
//   UserDefaults writes a plist into the app container. iOS Data Protection
//   encrypts that at rest, but the file is plain text whenever the device is
//   unlocked, and it is copied into unencrypted Finder/iTunes backups. The app
//   stores body weight and alcohol limits — health-adjacent data — and PRIVACY.md
//   makes its promise without qualifying it by platform. Android encrypts these
//   values on top of the OS's own file-based encryption; iOS does the same here.
//
// ON-DISK FORMAT, identical to Android's EncryptedPreferencesSerializer:
//   [12-byte nonce] || [AES-256-GCM ciphertext] || [16-byte authentication tag]
//   which is exactly CryptoKit's `AES.GCM.SealedBox.combined`. A fresh nonce per
//   write means two saves of the same settings never produce the same bytes.
//   The tag makes tampering detectable: a flipped bit fails authentication
//   rather than silently changing a limit.
//
// KEY LOSS IS A NORMAL EVENT, NOT AN ERROR
//   The key is `ThisDeviceOnly`, so restoring a device backup brings the
//   encrypted file but not the key. Decryption then fails — and the right answer
//   is the canonical defaults, not a crash: the user's real settings travel in
//   the JSON backup, which is the supported path. The store therefore treats an
//   unreadable file exactly like a missing one.
//
// CONCURRENCY
//   An `actor`, so reads and writes serialise without a lock. Observers receive
//   an `AsyncStream`, the same shape the repositories expose, so a SwiftUI view
//   consumes settings and drinks the same way.
// =============================================================================

/// Reads, writes and observes the user's settings.
public protocol PreferencesStoring: Sendable {
    /// The current settings, defaults on first launch.
    func load() async -> AppSettings

    /// Applies `transform` and persists the result.
    func update(_ transform: @Sendable (inout AppSettings) -> Void) async throws

    /// Replaces every setting at once. Used by the backup restore.
    func replace(with settings: AppSettings) async throws

    /// Emits the current value immediately, then after every change.
    func observe() async -> AsyncStream<AppSettings>
}

public actor PreferencesStore: PreferencesStoring {

    private let fileURL: URL
    private let keyProvider: any SecretKeyProviding

    /// The in-memory truth. The file is a durable copy of it.
    private var cached: AppSettings?

    /// Live observers, keyed so they can unsubscribe on termination.
    private var observers: [UUID: AsyncStream<AppSettings>.Continuation] = [:]

    /// - Parameters:
    ///   - fileURL: Where the encrypted blob lives.
    ///   - keyProvider: Supplies the AES key; the app passes `KeychainKeyProvider`.
    public init(fileURL: URL, keyProvider: any SecretKeyProviding) {
        self.fileURL = fileURL
        self.keyProvider = keyProvider
    }

    /// The store at the app's default location, `Application Support/prefs.bin`.
    public static func makeDefault() throws -> PreferencesStore {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return PreferencesStore(
            fileURL: directory.appendingPathComponent("prefs.bin"),
            keyProvider: KeychainKeyProvider()
        )
    }

    // ── Reading ──────────────────────────────────────────────────────────────

    public func load() async -> AppSettings {
        if let cached { return cached }
        let settings = readFromDisk() ?? AppSettings()
        cached = settings
        return settings
    }

    /// Returns nil for "no usable file": absent, unreadable, wrong key, tampered,
    /// or written by a version whose JSON we cannot decode. Every one of those
    /// means "start from defaults", and none of them is worth crashing over.
    private func readFromDisk() -> AppSettings? {
        guard let blob = try? Data(contentsOf: fileURL), !blob.isEmpty else { return nil }
        guard let key = try? keyProvider.key() else { return nil }
        guard let box = try? AES.GCM.SealedBox(combined: blob),
              let plaintext = try? AES.GCM.open(box, using: key)
        else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: plaintext)
    }

    // ── Writing ──────────────────────────────────────────────────────────────

    public func update(_ transform: @Sendable (inout AppSettings) -> Void) async throws {
        var settings = await load()
        transform(&settings)
        try persist(settings)
    }

    public func replace(with settings: AppSettings) async throws {
        try persist(settings)
    }

    private func persist(_ settings: AppSettings) throws {
        let plaintext = try JSONEncoder().encode(settings)
        let key = try keyProvider.key()
        // CryptoKit generates a fresh random nonce per seal; `combined` is
        // nonce || ciphertext || tag, the layout Android writes.
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let blob = sealed.combined else {
            throw PreferencesError.sealFailed
        }

        try writeAtomically(blob)

        cached = settings
        for continuation in observers.values { continuation.yield(settings) }
    }

    /// Writes to a sibling temp file and renames it over the target.
    ///
    /// A crash mid-write must never leave a half-encrypted file, which would be
    /// indistinguishable from tampering and would silently reset the user's
    /// settings. Rename within one filesystem is atomic.
    private func writeAtomically(_ blob: Data) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )

        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        // Unreadable while the device is locked, matching the key's own class.
        options.insert(.completeFileProtection)
        #endif
        try blob.write(to: fileURL, options: options)
    }

    // ── Observing ────────────────────────────────────────────────────────────

    public func observe() async -> AsyncStream<AppSettings> {
        let current = await load()
        let id = UUID()

        // `makeStream` hands back the continuation directly, so registration
        // happens here, inside the actor. The older `AsyncStream { ... }` builder
        // runs its closure outside actor isolation, and touching `observers` from
        // there would be a data race the Swift 6 mode rejects.
        let (stream, continuation) = AsyncStream<AppSettings>.makeStream()
        observers[id] = continuation

        // Emit the current value at once, as Room's Flow and GRDB's
        // ValueObservation both do, so a view never renders an empty state.
        continuation.yield(current)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}

/// The one failure that is not "fall back to defaults".
public enum PreferencesError: Error, Equatable, CustomStringConvertible {
    case sealFailed

    public var description: String {
        switch self {
        case .sealFailed:
            return "Could not encrypt the preferences."
        }
    }
}
