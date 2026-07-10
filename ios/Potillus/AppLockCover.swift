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

import PotillusKit
import SwiftUI

// =============================================================================
// AppLockCover – what is shown while the app is locked
// =============================================================================
//
// An opaque screen over the whole app whenever the lock model is not `.unlocked`.
// It hides the diary behind it — not only from a shoulder, but from anyone who
// picks up an unlocked phone — and offers the one action available: prompt again.
//
// It is deliberately plain and carries no data. Its whole job is to be a wall.
// =============================================================================

struct AppLockCover: View {

    let state: AppLockState
    let locale: Locale
    let onUnlock: () async -> Void

    var body: some View {
        ZStack {
            // Opaque, so nothing behind it shows through, and it fills the safe area.
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)

                Text(Loc.string("Libellus Potionis is locked", locale: locale))
                    .font(.headline)

                if state == .locked {
                    Button {
                        Task { await onUnlock() }
                    } label: {
                        Label(Loc.string("Unlock", locale: locale), systemImage: "faceid")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    // .authenticating: the system prompt is up; show nothing to press.
                    ProgressView()
                }
            }
            .padding()
        }
    }
}
