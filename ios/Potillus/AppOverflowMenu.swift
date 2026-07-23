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
//   The entries match Android (Settings, Help, Lock app, About). The FORM is
//   native: a SwiftUI `Menu` behind the ellipsis "More" affordance at the
//   trailing edge of the navigation bar — where Photos, Files and Notes put
//   theirs — not a Material dropdown. Same choices, native idiom — the rule the
//   rest of this port follows. (Until the 0.84.0 QA round the menu wore
//   Android's hamburger at the LEADING edge; iOS has no hamburger convention,
//   so it was the one Android-ism left in the navigation.)
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
    @State private var showingHelp = false
    @State private var showingAbout = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                // Trailing, as iOS's own apps place their More menus. The
                // screen's primary action ("+") and its edit toggle declare their
                // own trailing items; SwiftUI orders items from separate toolbar
                // blocks itself, so the exact neighbour order is the platform's
                // call — confirm it looks right on a device after changes here.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label(Loc.string("Settings", locale: locale), systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("nav.settings")
                        Button {
                            showingHelp = true
                        } label: {
                            Label(Loc.string("Help", locale: locale), systemImage: "questionmark.circle")
                        }
                        // "Lock app" appears whenever the device can authenticate,
                        // matching Android: a manual lock no longer requires auto-lock
                        // to be armed, and lockNow()/retry() can always clear the cover
                        // again. Hidden only when there is no biometric and no passcode,
                        // where a cover would strand the user.
                        if lock?.deviceCanAuthenticate() == true {
                            Button {
                                Task { await lock?.lockNow() }
                            } label: {
                                Label(Loc.string("Lock app", locale: locale), systemImage: "lock")
                            }
                        }
                        // About LAST, after the conditional "Lock app", as on
                        // Android: version and licenses are looked up once, not
                        // daily, so the entry yields the prime positions to the
                        // three that do real work.
                        Button {
                            showingAbout = true
                        } label: {
                            Label(Loc.string("About", locale: locale), systemImage: "info.circle")
                        }
                    } label: {
                        // ellipsis.circle is the platform's "More" glyph; the
                        // label keeps the catalogue's translated "Menu", which
                        // says what opens without needing a 22nd translation run.
                        Label(Loc.string("Menu", locale: locale), systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("nav.menu")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsScreen(environment: environment)
            }
            .sheet(isPresented: $showingHelp) {
                // The user guide, in the app's language with an English fallback.
                NavigationStack {
                    DocumentViewerScreen(
                        title: Loc.string("Help", locale: locale),
                        resource: guideResource()
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(Loc.string("Done", locale: locale)) {
                                showingHelp = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                // About is now reached from the overflow menu (as on Android),
                // not from Settings. It carries its own stack so its "Copyright &
                // license" link can push the full document, and a Done button to
                // dismiss the sheet.
                NavigationStack {
                    AboutScreen()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(Loc.string("Done", locale: locale)) {
                                    showingAbout = false
                                }
                            }
                        }
                }
            }
    }

    /// The bundled guide for the app's language, English as the guaranteed
    /// fallback. Tries the exact tag (`usersguide_zh-Hant`), then the base
    /// language (`usersguide_de` for a `de-DE` system locale), then
    /// `usersguide_en`. Only the guides whose templates have been authored ship,
    /// so an as-yet-untranslated language resolves to English rather than a blank
    /// page.
    private func guideResource() -> String {
        var candidates: [String] = []
        let tag = locale.identifier(.bcp47)
        if !tag.isEmpty {
            candidates.append("usersguide_\(tag)")
            if let dash = tag.firstIndex(of: "-") {
                candidates.append("usersguide_\(tag[..<dash])")
            }
        }
        candidates.append("usersguide_en")
        for name in candidates where Bundle.main.url(forResource: name, withExtension: "md") != nil {
            return name
        }
        return "usersguide_en"
    }
}

extension View {
    /// Add the shared overflow menu (Settings, Help, Copyright, Lock app) to a
    /// screen's navigation bar. Apply it inside the screen's `NavigationStack`, on
    /// the same view that carries `.navigationTitle`, so the button lands in that
    /// bar.
    func appOverflowMenu(environment: AppEnvironment) -> some View {
        modifier(AppOverflowMenu(environment: environment))
    }
}
