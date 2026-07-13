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

import PotillusKit
import SwiftUI

// =============================================================================
// AppOverflowMenu – the toolbar menu shared by all four main screens
// =============================================================================
//
// Android carries one `AppOverflowMenu` composable in the top bar of every main
// screen, so the menu's entries live in exactly one place instead of being
// copied four times. This is the iOS twin: a single `ViewModifier` that each of
// Today / Calendar / Statistics / Drinks applies with `.appOverflowMenu(...)`.
//
// WHY A MODIFIER, NOT A PLAIN VIEW
//   The menu is not just a button — it owns the sheets it opens (Settings and
//   the Copyright viewer) and the state that drives them. A `ViewModifier` lets
//   all of that ride along on the screen it decorates, so a screen adds the menu,
//   its two destinations and their presentation state in one line.
//
// PRESENTATION, NOT PORT
//   The entries match Android (Settings, Copyright, Lock app — Help is added in a
//   later step, once the user guide is bundled). The FORM is native: a SwiftUI
//   `Menu` in the navigation bar, not a Material dropdown. Same choices, native
//   idiom — the rule the rest of this port follows.
// =============================================================================

struct AppOverflowMenu: ViewModifier {

    /// Needed to build the Settings sheet; the value struct is passed in rather
    /// than read from the environment because `AppEnvironment` is a plain
    /// `Sendable` struct, not an `@Observable` the environment can vend by type.
    let environment: AppEnvironment

    @Environment(\.appLocale) private var locale

    /// The lock is an `@Observable` injected once by `RootView`, so it is read
    /// from the environment rather than threaded through four screen initialisers.
    /// Optional so a screen previewed without the injection renders instead of
    /// trapping; the "Lock app" entry simply does not appear.
    @Environment(AppLockModel.self) private var lock: AppLockModel?

    @State private var showingSettings = false
    @State private var showingCopyright = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                // Leading, where Android's burger sits and where Today's gear used
                // to sit, so the primary action keeps the trailing corner.
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label(Loc.string("Settings", locale: locale), systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("nav.settings")
                        Button {
                            showingCopyright = true
                        } label: {
                            Label(Loc.string("Copyright", locale: locale), systemImage: "book")
                        }
                        // "Lock app" appears only while the lock is enabled: a manual
                        // lock is meaningful only then, and AppLockModel.lockNow()
                        // refuses otherwise so it can never strand the user behind a
                        // cover the authenticate/retry path would decline to clear.
                        if lock?.isEnabled == true {
                            Button {
                                Task { await lock?.lockNow() }
                            } label: {
                                Label(Loc.string("Lock app", locale: locale), systemImage: "lock")
                            }
                        }
                    } label: {
                        Label(Loc.string("Menu", locale: locale), systemImage: "line.3.horizontal")
                    }
                    .accessibilityIdentifier("nav.menu")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsScreen(environment: environment)
            }
            .sheet(isPresented: $showingCopyright) {
                // Pushed with a back button under Settings > About; in the menu it
                // is presented on its own, so it carries its own stack and a Done
                // button to dismiss the sheet.
                NavigationStack {
                    DocumentViewerScreen(
                        title: Loc.string("Copyright & licence", locale: locale),
                        resource: "copyright"
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(Loc.string("Done", locale: locale)) {
                                showingCopyright = false
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    /// Add the shared overflow menu (Settings, Copyright, Lock app) to a screen's
    /// navigation bar. Apply it inside the screen's `NavigationStack`, on the same
    /// view that carries `.navigationTitle`, so the button lands in that bar.
    func appOverflowMenu(environment: AppEnvironment) -> some View {
        modifier(AppOverflowMenu(environment: environment))
    }
}
