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
// PotillusApp.swift – the application entry point
// =============================================================================
//
// Builds the composition root once, then hands it to the view tree. Nothing
// below this point constructs a database, a keychain, or a repository.
//
// STARTUP CAN FAIL
//   Opening the database runs migrations, and creating the preferences key
//   touches the Keychain. Both can fail on a device with no free space or a
//   damaged container. A crash at launch is the worst possible report ("it just
//   closes"), so the failure is caught and shown, with the error the user can
//   quote. The app deliberately does not delete and recreate the database: that
//   would trade a visible failure for silent data loss.
// =============================================================================

@main
struct PotillusApp: App {

    /// Built once, at launch. `@State` because the environment is a value that
    /// the view tree observes, and SwiftUI must own its lifetime.
    @State private var startup: StartupState = .loading

    /// The biometric gate. Built here, at the scene, because only the scene sees
    /// the phase transitions that arm and disarm it. The real LAContext sensor is
    /// injected now; the tests inject a fake into the same model.
    @State private var lock = AppLockModel(
        authenticator: DeviceBiometricAuthenticator(),
        uptime: { ProcessInfo.processInfo.systemUptime }
    )

    @Environment(\.scenePhase) private var scenePhase

    /// Whether the user has allowed screenshots. Default false — secure by default,
    /// as on Android. Observed from the environment once it is ready, so a change in
    /// Settings takes effect without a relaunch.
    @State private var allowScreenshots = false

    /// The chosen language, for the covers that sit above the root and so cannot
    /// read `\.appLocale`. Observed alongside `allowScreenshots`.
    @State private var language = ""

    var body: some Scene {
        WindowGroup {
            Group {
                switch startup {
                case .loading:
                    // The database opens in milliseconds; this is a guard against a
                    // blank window, not a real loading screen.
                    ProgressView()
                        .task { startup = StartupState.make() }

                case .ready(let environment):
                    RootView(environment: environment, lock: lock)

                case .failed(let message):
                    StartupFailureView(message: message)
                }
            }
            // The cover sits ABOVE everything, including the failure view: a locked
            // app reveals nothing, not even why it could not start.
            .overlay {
                // The app-switcher cover sits UNDER the lock cover: when both apply
                // the lock wins, but neither depends on the other. It shows in the
                // transient .inactive phase too, so the switcher never photographs
                // the diary. `allowScreenshots` lets the user opt out.
                if PrivacyCoverDecision.isCovered(
                    isActive: scenePhase == .active, allowScreenshots: allowScreenshots
                ) {
                    PrivacyCover(locale: Loc.locale(for: language))
                }
                if lock.state != .unlocked {
                    AppLockCover(state: lock.state, locale: Loc.locale(for: language)) { await lock.retry() }
                }
            }
            .task { await lock.onLaunch() }
            // Keyed on readiness so the observing task RESTARTS when the
            // environment appears. A plain `.task` fires once, while `startup` is
            // still `.loading`, sees no environment, and never observes the flag —
            // leaving the cover stuck on. `.task(id:)` re-runs when the id changes.
            .task(id: startup.isReady) {
                if case .ready(let environment) = startup {
                    for await updated in await environment.preferences.observe() {
                        allowScreenshots = updated.allowScreenshots
                        language = updated.language
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                // .inactive is the transient state during the switcher animation;
                // only .background is a real departure, and only .active a real
                // return. Acting on .inactive would prompt every time the app
                // briefly lost focus.
                switch phase {
                case .background: lock.onBackground()
                case .active: Task { await lock.onForeground() }
                default: break
                }
            }
        }
    }
}

/// The three states a launch can be in.
enum StartupState {
    case loading
    case ready(AppEnvironment)
    case failed(String)

    /// Whether the environment is ready. Drives `.task(id:)` so the scene's
    /// observation starts the moment the environment exists, not a moment before.
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    /// Assembles the live environment, converting a throw into a shown message.
    static func make() -> StartupState {
        do {
            return .ready(try AppEnvironment.makeLive())
        } catch {
            return .failed(String(describing: error))
        }
    }
}

/// Shown when the database or the keychain could not be opened.
///
/// Deliberately plain and un-localised for now: it must render even when the app
/// could not finish starting, and it exists to be quoted in a bug report.
struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            // NOT localised, deliberately: this renders before the environment —
            // and therefore the chosen language — exists, and it is meant to be
            // quoted verbatim into a bug report. Same reasoning as the kit's
            // technical error strings.
            Label("Libellus Potionis could not start", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
                .font(.footnote)
                .textSelection(.enabled)
        }
    }
}
