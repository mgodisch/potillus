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

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .loading:
                // The database opens in milliseconds; this is a guard against a
                // blank window, not a real loading screen.
                ProgressView()
                    .task { startup = StartupState.make() }

            case .ready(let environment):
                RootView(environment: environment)

            case .failed(let message):
                StartupFailureView(message: message)
            }
        }
    }
}

/// The three states a launch can be in.
enum StartupState {
    case loading
    case ready(AppEnvironment)
    case failed(String)

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
            Label("Libellus Potionis could not start", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
                .font(.footnote)
                .textSelection(.enabled)
        }
    }
}
