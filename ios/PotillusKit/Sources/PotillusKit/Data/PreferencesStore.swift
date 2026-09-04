// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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
// EXCEPT WHEN THE FILE IS MERELY NOT READABLE YET
//   Both the key (`WhenUnlocked`) and the file (`completeFileProtection`) are
//   unreachable while the device is locked. That is a transient state, and it
//   must not be mistaken for "unusable": if `load()` cached the defaults on it,
//   the next `update()` would seal those defaults over the user's real settings.
//   So a read that fails for that reason is `unavailable`: `load()` answers with
//   defaults but caches nothing, `update()` throws `PreferencesError.unavailable`
//   instead of writing, and the next call tries the disk again. (Android has no
//   such state: a Keystore key without `setUnlockedDeviceRequired` is readable
//   at any time.) Found in the v0.86.0 security review; before it, `readFromDisk`
//   folded this case into "wrong key".
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

    /// Whether a first launch seeds `statsFromDate` with today's date.
    ///
    /// Only `makeDefault()` — the one production path — passes `true`. Tests,
    /// previews and screenshot runs build the store directly and leave this
    /// `false`, so they keep starting from a pristine `AppSettings()`. This is
    /// the same line `AppDatabase` draws between `makeDefault()` and
    /// `init(inMemory:)` for the preset drinks.
    private let seedsStatsFloor: Bool

    /// Supplies "now" for the seed. Injectable so a test can pin the date.
    private let clock: any Clock

    /// The in-memory truth. The file is a durable copy of it.
    private var cached: AppSettings?

    /// Live observers, keyed so they can unsubscribe on termination.
    private var observers: [UUID: AsyncStream<AppSettings>.Continuation] = [:]

    /// - Parameters:
    ///   - fileURL: Where the encrypted blob lives.
    ///   - keyProvider: Supplies the AES key; the app passes `KeychainKeyProvider`.
    ///   - seedsStatsFloor: See the property. Defaults to `false`, so only the
    ///     deliberate caller seeds.
    ///   - clock: Source of "now" for the seed.
    public init(
        fileURL: URL,
        keyProvider: any SecretKeyProviding,
        seedsStatsFloor: Bool = false,
        clock: any Clock = SystemClock()
    ) {
        self.fileURL = fileURL
        self.keyProvider = keyProvider
        self.seedsStatsFloor = seedsStatsFloor
        self.clock = clock
    }

    /// The store at the app's default location, `Application Support/prefs.bin`.
    public static func makeDefault() throws -> PreferencesStore {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return PreferencesStore(
            fileURL: directory.appendingPathComponent("prefs.bin"),
            keyProvider: KeychainKeyProvider(),
            seedsStatsFloor: true
        )
    }

    // ── Reading ──────────────────────────────────────────────────────────────

    public func load() async -> AppSettings {
        (try? loadOrThrow()) ?? AppSettings()
    }

    /// `load()` with the transient case kept apart: throws
    /// `PreferencesError.unavailable` when the disk or the key cannot be read
    /// RIGHT NOW, so `update()` can refuse to write rather than overwrite.
    private func loadOrThrow() throws -> AppSettings {
        if let cached { return cached }
        // Asked BEFORE the read, because the seed below turns on THIS and not on
        // whether the read succeeded. `readFromDisk()` is `unusable` for a whole
        // family of reasons — absent, wrong key, tampered — and only the first of
        // them means "this user has never been asked". See `seedOnFirstLaunch()`.
        // It is the same probe `AppDatabase.openOrCreate` makes before opening
        // the database, for the same reason.
        let fileExisted = FileManager.default.fileExists(atPath: fileURL.path)
        switch readFromDisk() {
        case .settings(let stored):
            cached = stored
            return stored
        case .unavailable:
            // Nothing is cached: the next call must look at the disk again.
            throw PreferencesError.unavailable
        case .unusable:
            let settings = seedsStatsFloor && !fileExisted ? seedOnFirstLaunch() : AppSettings()
            cached = settings
            return settings
        }
    }

    /// Builds the settings a brand-new installation starts with: the defaults,
    /// but with the statistics floor set to today.
    ///
    /// WHY THIS EXISTS
    ///   Android has done this since day one: `AppPreferences` falls back to the
    ///   package's `firstInstallTime` when no start date was ever stored, "so
    ///   statistics start at the install date until the user picks another". The
    ///   Swift port copied the SETTING but not that default, so `statsFromDate`
    ///   stayed empty, no floor applied, and the Statistics screen counted every
    ///   day of the current period from the 1st — including the days before the
    ///   app was installed, which it then reported as abstinent days and drew as
    ///   green ticks. Install on the 16th, and the 1st to the 15th were fifteen
    ///   days the user was congratulated for.
    ///
    /// WHY WRITE IT DOWN INSTEAD OF COMPUTING IT
    ///   The date must not move. Android can recompute its default forever
    ///   because `firstInstallTime` is a fixed fact about the package; iOS has no
    ///   equivalent, so "today" is only correct on the day it is first asked. It
    ///   is persisted here, once, and never derived again.
    ///
    /// WHY THE FILE'S ABSENCE, AND NOT "statsFromDate IS EMPTY"
    ///   Empty is a MEANINGFUL user choice: `SettingsModel.clearStatsFromDate()`
    ///   writes it to mean "cover my whole history". Seeding whenever the value
    ///   is empty would silently undo that on the next launch. The absence of the
    ///   file is the only honest signal for "this user has never been asked", and
    ///   it is the same signal `AppDatabase.openOrCreate` uses to seed the preset
    ///   drinks. Android draws the same distinction differently: its DataStore
    ///   tells a missing key from a key holding "".
    ///
    /// WHY THE FILE'S ABSENCE, AND NOT "THE FILE COULD NOT BE READ"
    ///   `load()` probes `fileExists` itself rather than treating an `unusable`
    ///   read as "first launch". The two are not the same: `unusable` also
    ///   means wrong key or tampered (and a merely locked file is `unavailable`,
    ///   which never reaches the seed at all). The wrong-key
    ///   case is REAL and reachable — the key is `ThisDeviceOnly`, so restoring a
    ///   device backup onto a new phone brings this file back without it. Seeding
    ///   there would set the floor to the RESTORE date; and a user who opted the
    ///   database into the backup (`BackupExclusion.setIncludesInBackup(true)`,
    ///   whose marker lives in UserDefaults and is restored too) would find their
    ///   whole restored history silently dropped out of every statistic, with
    ///   nothing on screen to say why. A file that exists has been written by this
    ///   app; whatever went wrong with it, its owner HAS been asked, so the
    ///   defaults — no floor, the whole history — are the honest answer, and the
    ///   real settings come back through the JSON backup, which is the supported
    ///   path (see "KEY LOSS IS A NORMAL EVENT" in the file header).
    ///   (0.83.0 QA round: the code seeded on the nil read while this very
    ///   paragraph's predecessor claimed it seeded on the file's absence.)
    ///
    /// CONSEQUENCE, DELIBERATE
    ///   An installation that already has a prefs.bin is NOT seeded, exactly as
    ///   an existing database is not seeded with presets. Those users keep no
    ///   floor until they pick a date in Settings.
    ///
    /// A failed write is not worth crashing over: the seed is a convenience, not
    /// a correctness requirement. It is cached for this session either way; if
    /// the write failed, the next launch seeds again, with that day's date.
    private func seedOnFirstLaunch() -> AppSettings {
        var settings = AppSettings()
        let nowMillis = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        // changeHour/changeMinute 0: the PLAIN calendar day, not the logical one.
        // A user installing at 02:00 with a 04:00 day-change boundary installed
        // today, whatever their drinking day says. Android reads the calendar
        // date of firstInstallTime the same way.
        settings.statsFromDate = DayResolver.today(
            now: nowMillis,
            changeHour: 0,
            changeMinute: 0
        )
        try? persist(settings)
        return settings
    }

    /// The three things a read can come back with.
    private enum DiskRead {
        case settings(AppSettings)
        /// No usable file: absent, empty, wrong key, tampered, or written by a
        /// version whose JSON we cannot decode. Every one of those means "start
        /// from defaults", and none of them is worth crashing over.
        case unusable
        /// A file that exists but cannot be read NOW, or a key the Keychain holds
        /// but will not hand over while the device is locked. Not a verdict on
        /// the file; see EXCEPT WHEN THE FILE IS MERELY NOT READABLE YET above.
        case unavailable
    }

    private func readFromDisk() -> DiskRead {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .unusable }
        // The file is there. A read that still fails is the protection class
        // (`completeFileProtection`) refusing while locked — or an I/O error, which
        // is equally not a reason to seal defaults over it.
        guard let blob = try? Data(contentsOf: fileURL) else { return .unavailable }
        guard !blob.isEmpty else { return .unusable }
        let key: SymmetricKey
        do {
            key = try keyProvider.key()
        } catch KeychainError.unavailableWhileLocked {
            return .unavailable
        } catch {
            return .unusable
        }
        guard let box = try? AES.GCM.SealedBox(combined: blob),
              let plaintext = try? AES.GCM.open(box, using: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: plaintext)
        else { return .unusable }
        return .settings(settings)
    }

    // ── Writing ──────────────────────────────────────────────────────────────

    public func update(_ transform: @Sendable (inout AppSettings) -> Void) async throws {
        // `loadOrThrow`, not `load`: a transient read failure must not be
        // patched over with defaults and then written back. The caller gets
        // `PreferencesError.unavailable` and the file stays as it was.
        var settings = try loadOrThrow()
        transform(&settings)
        try persist(settings)
    }

    public func replace(with settings: AppSettings) async throws {
        try persist(settings)
    }

    private func persist(_ settings: AppSettings) throws {
        let plaintext = try JSONEncoder().encode(settings)
        let key: SymmetricKey
        do {
            key = try keyProvider.key()
        } catch KeychainError.unavailableWhileLocked {
            throw PreferencesError.unavailable // same word as the read side
        }
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

/// The two failures that are not "fall back to defaults".
public enum PreferencesError: Error, Equatable, CustomStringConvertible {
    case sealFailed
    /// The file or its key cannot be read right now (device locked). Nothing was
    /// written; try again once the device is unlocked.
    case unavailable

    public var description: String {
        switch self {
        case .sealFailed:
            return "Could not encrypt the preferences."
        case .unavailable:
            return "The preferences cannot be read while the device is locked."
        }
    }
}
