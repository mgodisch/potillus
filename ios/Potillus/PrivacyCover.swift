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

import SwiftUI

// =============================================================================
// PrivacyCover – what the app switcher photographs
// =============================================================================
//
// Android sets FLAG_SECURE, which blanks the Recents thumbnail AND blocks active
// screenshots in one flag. iOS has no such flag. It has two SEPARATE problems, and
// this file solves the one that has a clean, public answer.
//
// WHAT THIS DOES: the app-switcher thumbnail.
//   When the app leaves the foreground, iOS snapshots the window for the switcher.
//   Placing an opaque cover over the content during the `.inactive`/`.background`
//   phases means the snapshot is of the cover, not of the diary. This is ordinary
//   SwiftUI; no private API, nothing App Review can object to.
//
// WHAT THIS DELIBERATELY DOES NOT DO: block an ACTIVE screenshot.
//   The only known way to stop a foreground screenshot on iOS is the
//   `isSecureTextEntry` trick — wrapping the UI in a secure text field so the
//   system excludes it from captures. That is undocumented behaviour, fragile
//   across iOS releases, and a poor fit for a privacy app that is meant to contain
//   no such tricks. Android gets active blocking for free because the platform
//   offers it; iOS would charge a hack for it, and we decline to pay. A user who
//   deliberately screenshots their own diary may do so.
//
// DEFAULT ON, as on Android, where FLAG_SECURE is set unless the user allows
// screenshots. The cover appears unless `allowScreenshots` is true.
//
// INDEPENDENT OF THE APP LOCK. When the lock is on, the lock cover is already up on
// background, so this is redundant then; when the lock is off, this is the only
// thing protecting the thumbnail. Keeping them separate means either can be removed
// without touching the other, and neither has to reason about the other's state.
// =============================================================================

enum PrivacyCoverDecision {

    /// Whether the switcher cover should be showing.
    ///
    /// Covered whenever the app is NOT active, unless the user allowed screenshots.
    /// `.inactive` counts as not-active on purpose: the switcher snapshot is taken
    /// during that transient phase, so waiting for `.background` would photograph
    /// the diary a frame too early.
    ///
    /// - Parameters:
    ///   - isActive: whether the scene phase is `.active`.
    ///   - allowScreenshots: the user's opt-out.
    static func isCovered(isActive: Bool, allowScreenshots: Bool) -> Bool {
        !allowScreenshots && !isActive
    }
}

struct PrivacyCover: View {

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Libellus Potionis")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
