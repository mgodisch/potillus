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

import Foundation
import Observation

// =============================================================================
// SettingsModel.swift – the user's own numbers
// =============================================================================
//
// Thin on purpose. `PreferencesStore` already encrypts, `SettingsSanitizer`
// already clamps, and both are tested. What this adds is an observable surface
// and the guarantee that every write goes through the sanitizer — including the
// ones a view might think are safe.
//
// WHY SANITISE A VALUE THE SLIDER COULD NOT PRODUCE
//   Because the slider is not the only writer. A restored backup, a future screen,
//   or a bug in a `Stepper`'s bounds can all reach this. Sanitising once, here,
//   means the invariant holds for the store rather than for the current set of
//   views, and the store is what survives.
//
// TWO SETTINGS THIS SCREEN DOES NOT SHOW
//   `biometricEnabled` and `allowScreenshots` are stored, ported, and NOT offered.
//   A switch that flips a flag nothing reads is worse than a missing switch: it
//   promises a lock that does not exist. They appear when LocalAuthentication and
//   the screenshot suppression land.
// =============================================================================

@MainActor
@Observable
public final class SettingsModel {

    public private(set) var settings = AppSettings()

    /// Set when a write failed — a Keychain refusal, a full disk. Never swallowed.
    public private(set) var failure: String?

    private let preferences: any PreferencesStoring
    private var observation: Task<Void, Never>?

    public init(preferences: any PreferencesStoring) {
        self.preferences = preferences
    }

    // ── Observation ──────────────────────────────────────────────────────────

    /// Subscribes to the store, so a change made elsewhere — a backup import —
    /// reaches this screen without a manual reload.
    public func start() {
        observation?.cancel()
        observation = Task { [weak self] in
            guard let self else { return }
            for await stored in await self.preferences.observe() {
                self.settings = stored
            }
        }
    }

    public func stop() {
        observation?.cancel()
        observation = nil
    }

    // ── Writing ──────────────────────────────────────────────────────────────

    /// Applies `transform`, sanitises the result, and stores it.
    ///
    /// The sanitiser runs on the WHOLE settings value, not on the changed field:
    /// clamping is defined over the value, and a caller cannot know which other
    /// field a change invalidates.
    public func update(_ transform: @escaping @Sendable (inout AppSettings) -> Void) async {
        do {
            try await preferences.update { draft in
                transform(&draft)
                draft = SettingsSanitizer.sanitize(draft)
            }
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }

    /// Clears the body weight, which disables the blood-alcohol estimate.
    ///
    /// Zero is the sentinel for "not set", and the sanitiser deliberately does not
    /// clamp it up to the 1 kg floor. Exposed as its own operation so no view has
    /// to know that a magic zero means absence.
    public func clearWeight() async {
        await update { $0.weightKg = 0.0 }
    }

    /// Whether a body weight has been entered at all.
    public var hasWeight: Bool { settings.weightKg > 0 }

    /// Clears the statistics floor, so statistics cover the whole history again.
    public func clearStatsFromDate() async {
        await update { $0.statsFromDate = "" }
    }

    public var hasStatsFloor: Bool { !settings.statsFromDate.isEmpty }

    public func clearFailure() { failure = nil }
}
