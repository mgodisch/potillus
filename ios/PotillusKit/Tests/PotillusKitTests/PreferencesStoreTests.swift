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
import XCTest
@testable import PotillusKit

// =============================================================================
// PreferencesStoreTests.swift – the settings file must be unreadable and durable
// =============================================================================
//
// Real AES-256-GCM, a real file, a temporary directory. Only the KEY is injected:
// the Keychain is unreachable from a plain `swift test` process, which has no
// keychain access entitlement. Everything the store actually does — sealing,
// nonce freshness, atomic replacement, tamper detection, graceful degradation on
// key loss — is exercised against the code that ships.
// =============================================================================

final class PreferencesStoreTests: XCTestCase {

    private var directory: URL!
    private var fileURL: URL!
    private var key: SymmetricKey!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("prefs.bin")
        key = SymmetricKey(size: .bits256)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func makeStore(key overrideKey: SymmetricKey? = nil) -> PreferencesStore {
        PreferencesStore(
            fileURL: fileURL,
            keyProvider: InMemoryKeyProvider(key: overrideKey ?? key)
        )
    }

    // ── Round trip ───────────────────────────────────────────────────────────

    func testFirstLaunchYieldsTheCanonicalDefaults() async {
        let settings = await makeStore().load()
        XCTAssertEqual(settings, AppSettings())
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: fileURL.path),
            "reading must not create a file"
        )
    }

    func testSettingsSurviveAReopen() async throws {
        let store = makeStore()
        try await store.update { $0.weightKg = 82.5; $0.themeMode = .night }

        // A second store over the same file and key: the app after a restart.
        let reopened = await makeStore().load()
        XCTAssertEqual(reopened.weightKg, 82.5, accuracy: 1e-9)
        XCTAssertEqual(reopened.themeMode, .night)
    }

    func testReplaceOverwritesEveryField() async throws {
        let store = makeStore()
        try await store.update { $0.weightKg = 70.0 }

        var wanted = AppSettings()
        wanted.language = "de"
        try await store.replace(with: wanted)

        let reopened = await makeStore().load()
        XCTAssertEqual(reopened, wanted)
        XCTAssertEqual(reopened.weightKg, 0.0, "replace must not merge with the old value")
    }

    // ── The file is genuinely encrypted ──────────────────────────────────────

    /// The plainest possible check, and the one that matters: no field value may
    /// be findable in the bytes on disk.
    func testTheFileOnDiskRevealsNothing() async throws {
        try await makeStore().update {
            $0.weightKg = 82.5
            $0.language = "de"
            $0.statsFromDate = "2026-01-01"
        }

        let blob = try Data(contentsOf: fileURL)
        for secret in ["weightKg", "82.5", "2026-01-01", "themeMode", "SYSTEM"] {
            XCTAssertNil(
                blob.range(of: Data(secret.utf8)),
                "plaintext '\(secret)' found in the encrypted file"
            )
        }
    }

    /// A fresh nonce per write means two saves of identical settings differ.
    /// Otherwise an observer of the file could tell that nothing changed — or
    /// worse, that the same value was restored twice.
    func testEveryWriteUsesAFreshNonce() async throws {
        let store = makeStore()
        try await store.replace(with: AppSettings())
        let first = try Data(contentsOf: fileURL)

        try await store.replace(with: AppSettings())
        let second = try Data(contentsOf: fileURL)

        XCTAssertNotEqual(first, second, "identical settings must not produce identical bytes")
        XCTAssertEqual(first.count, second.count, "same plaintext, same length")
    }

    /// GCM's authentication tag makes tampering detectable rather than silently
    /// effective: a flipped bit must not become a changed alcohol limit.
    func testATamperedFileFallsBackToDefaults() async throws {
        try await makeStore().update { $0.dailyLimitGrams = 42.0 }

        var blob = try Data(contentsOf: fileURL)
        blob[blob.count - 1] ^= 0x01  // flip one bit of the authentication tag
        try blob.write(to: fileURL)

        let settings = await makeStore().load()
        XCTAssertEqual(settings, AppSettings(), "tampering must not yield usable settings")
    }

    /// The key is `ThisDeviceOnly`, so a restored device backup brings the file
    /// without the key. That is a normal event: fall back to defaults, do not
    /// crash. The user's real settings travel in the JSON backup.
    func testAWrongKeyFallsBackToDefaultsInsteadOfThrowing() async throws {
        try await makeStore().update { $0.weightKg = 82.5 }

        let otherDevice = makeStore(key: SymmetricKey(size: .bits256))
        let settings = await otherDevice.load()
        XCTAssertEqual(settings, AppSettings())
    }

    func testAnEmptyOrTruncatedFileFallsBackToDefaults() async throws {
        // The awaits are hoisted out of the assertions: XCTAssert* takes its
        // arguments as autoclosures, which are synchronous, so `await` cannot
        // appear inside one. Naming the values also makes a failure report say
        // which of the two cases broke.
        try Data().write(to: fileURL)
        let fromEmptyFile = await makeStore().load()
        XCTAssertEqual(fromEmptyFile, AppSettings(), "an empty file must read as defaults")

        try Data([0x00, 0x01, 0x02]).write(to: fileURL)
        let fromTruncatedFile = await makeStore().load()
        XCTAssertEqual(fromTruncatedFile, AppSettings(), "a truncated file must read as defaults")
    }

    /// After falling back, a save must succeed and produce a readable file, so a
    /// user whose key was lost is not stuck with an unwritable store.
    func testTheStoreRecoversAfterAnUnreadableFile() async throws {
        try Data([0xDE, 0xAD, 0xBE, 0xEF]).write(to: fileURL)

        let store = makeStore()
        try await store.update { $0.weightKg = 64.0 }

        let reopened = await makeStore().load()
        XCTAssertEqual(reopened.weightKg, 64.0, accuracy: 1e-9)
    }

    // ── Observation ──────────────────────────────────────────────────────────

    /// A view must render immediately, so the stream opens with the current value.
    func testObservationEmitsTheCurrentValueImmediately() async throws {
        let store = makeStore()
        try await store.update { $0.language = "fr" }

        var iterator = await store.observe().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first?.language, "fr")
    }

    func testObservationEmitsAgainAfterAWrite() async throws {
        let store = makeStore()
        var iterator = await store.observe().makeAsyncIterator()

        _ = await iterator.next()  // the initial value
        try await store.update { $0.maxDrinkDaysPerWeek = 3 }

        let updated = await iterator.next()
        XCTAssertEqual(updated?.maxDrinkDaysPerWeek, 3)
    }

    // ── Atomicity ────────────────────────────────────────────────────────────

    /// The write goes through a temp file and a rename, so no stray file may be
    /// left behind. A half-written blob is indistinguishable from tampering.
    func testWritingLeavesNoTemporaryFilesBehind() async throws {
        try await makeStore().update { $0.weightKg = 70.0 }

        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(contents, ["prefs.bin"])
    }
}
