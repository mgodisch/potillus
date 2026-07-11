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

import XCTest
@testable import PotillusKit

// =============================================================================
// BackupExclusionTests – the device-backup exclusion on the database file.
//
// These use a REAL temporary file, because isExcludedFromBackup is a file-system
// resource value: there is nothing to test without a file on disk. Each test makes
// its own file and its own isolated UserDefaults suite, removed in tearDown, so the
// preference of one test never leaks into another.
// =============================================================================

final class BackupExclusionTests: XCTestCase {

    private var fileURL: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("exclusion-test-\(UUID().uuidString).sqlite")
        try Data("db".utf8).write(to: fileURL)
        suiteName = "backup-exclusion-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
        defaults.removePersistentDomain(forName: suiteName)
    }

    // ── The raw attribute ────────────────────────────────────────────────────

    /// A freshly written file carries no exclusion, so `isExcluded` reads false.
    func testAFreshFileIsNotExcluded() {
        XCTAssertFalse(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }

    /// Setting the exclusion is read back by `isExcluded`.
    func testSetExcludedIsReadBack() throws {
        try BackupExclusion.setExcluded(true, databasePath: fileURL.path)
        XCTAssertTrue(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }

    /// The exclusion can be cleared again — the switch is reversible.
    func testExclusionCanBeCleared() throws {
        try BackupExclusion.setExcluded(true, databasePath: fileURL.path)
        try BackupExclusion.setExcluded(false, databasePath: fileURL.path)
        XCTAssertFalse(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }

    /// Setting on a path with no file is not an error: the journal sidecar often
    /// does not exist, and the main file may not be created yet.
    func testSettingOnAMissingFileDoesNotThrow() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).sqlite")
        XCTAssertNoThrow(try BackupExclusion.setExcluded(true, databasePath: missing.path))
    }

    // ── The preference (UserDefaults marker) ─────────────────────────────────

    /// The default is EXCLUDED (opted out), matching Android's allowBackup="false".
    func testDefaultIsExcluded() {
        XCTAssertFalse(BackupExclusion.includesInBackup(defaults: defaults))
    }

    /// `applyPreference` on a fresh default excludes the file.
    func testApplyPreferenceExcludesByDefault() throws {
        try BackupExclusion.applyPreference(databasePath: fileURL.path, defaults: defaults)
        XCTAssertTrue(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }

    /// Opting in records the preference AND clears the file's exclusion.
    func testOptingInRecordsAndClears() throws {
        try BackupExclusion.setIncludesInBackup(true, databasePath: fileURL.path, defaults: defaults)
        XCTAssertTrue(BackupExclusion.includesInBackup(defaults: defaults))
        XCTAssertFalse(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }

    /// The opt-in survives a re-apply: this is the whole point of the marker. Even
    /// if a file write reset the attribute to included, `applyPreference` must NOT
    /// re-exclude an opted-in file — the marker, not the attribute, is the truth.
    func testOptInSurvivesReapply() throws {
        try BackupExclusion.setIncludesInBackup(true, databasePath: fileURL.path, defaults: defaults)
        try BackupExclusion.applyPreference(databasePath: fileURL.path, defaults: defaults)
        XCTAssertFalse(
            BackupExclusion.isExcluded(databasePath: fileURL.path),
            "an opted-in file must stay included after a re-apply"
        )
    }

    /// The mirror case: an excluded file that a write reset to included is
    /// re-excluded by the next `applyPreference`, since the marker says "excluded".
    func testReapplyRenewsAResetExclusion() throws {
        // Default preference is excluded. Simulate a file write clearing the flag:
        try BackupExclusion.setExcluded(false, databasePath: fileURL.path)
        // The next launch re-applies the preference and restores the exclusion.
        try BackupExclusion.applyPreference(databasePath: fileURL.path, defaults: defaults)
        XCTAssertTrue(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }

    /// Opting back out records the preference and re-excludes.
    func testOptingBackOut() throws {
        try BackupExclusion.setIncludesInBackup(true, databasePath: fileURL.path, defaults: defaults)
        try BackupExclusion.setIncludesInBackup(false, databasePath: fileURL.path, defaults: defaults)
        XCTAssertFalse(BackupExclusion.includesInBackup(defaults: defaults))
        XCTAssertTrue(BackupExclusion.isExcluded(databasePath: fileURL.path))
    }
}
