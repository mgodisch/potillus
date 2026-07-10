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
// RootView.swift – the four top-level sections
// =============================================================================
//
// The information architecture is the Android one: Today, Calendar, Statistics,
// Drinks. Same sections, same order, same vocabulary — a user who switches
// phones finds the same app.
//
// The PRESENTATION is not the Android one. Compose puts a NavigationBar at the
// bottom with a label under each icon; SwiftUI uses a `TabView`, which looks and
// behaves the way every other iOS app does. Porting Material 3 onto iOS would
// make the app feel foreign to its users and conspicuous to App Review. The rule
// throughout this port: identical behaviour, native idiom.
//
// Settings, Help and Copyright are not tabs on either platform — they hang off
// the toolbar, and arrive with the screens that need them.
// =============================================================================

struct RootView: View {

    let environment: AppEnvironment

    /// The user's theme choice, observed so a change applies immediately.
    @State private var settings = AppSettings()

    var body: some View {
        // `.tabItem` rather than the `Tab { }` builder: that builder is iOS 18,
        // and this app supports iOS 17. The two render identically here.
        //
        // ON THE SYMBOLS
        //   Android pairs `Icons.Default.Today` (a calendar sheet with the day
        //   marked) against `Icons.Default.CalendarMonth` (a month grid): the two
        //   differ by DAY versus MONTH, not by metaphor. SF Symbols has no sheet
        //   with an inner day marker — Apple places badges outside the glyph — so
        //   `calendar.badge.clock` carries the "now" sense while staying in the
        //   same family as its neighbour, and remains legible at tab-bar size.
        //
        //   `sun.max` was the first choice and was wrong: in Apple's own apps it
        //   means weather or screen brightness, so it would read as a different
        //   feature entirely. A tab symbol should depict the content, not a mood.
        //
        //   No `.fill` variants are named anywhere here. SwiftUI selects the
        //   filled form for tab items on iOS and the outlined one on macOS by
        //   itself; spelling it out would defeat that.
        TabView {
            PlaceholderScreen(title: "Today")
                .tabItem { Label("Today", systemImage: "calendar.badge.clock") }

            PlaceholderScreen(title: "Calendar")
                .tabItem { Label("Calendar", systemImage: "calendar") }

            PlaceholderScreen(title: "Statistics")
                .tabItem { Label("Statistics", systemImage: "chart.bar") }

            PlaceholderScreen(title: "Drinks")
                .tabItem { Label("Drinks", systemImage: "wineglass") }
        }
        // nil means "follow the system", which is exactly what ThemeMode.system
        // asks for. Reading the device setting directly would ignore the user's
        // in-app override — the trap the Android Color.kt comments call out.
        .preferredColorScheme(settings.themeMode.colorScheme)
        .task {
            // The stream yields the current value at once, then after every
            // change, so the theme applies without a restart.
            for await updated in await environment.preferences.observe() {
                settings = updated
            }
        }
    }
}

extension ThemeMode {
    /// The SwiftUI colour scheme this mode asks for.
    ///
    /// `.system` maps to `nil`, SwiftUI's way of saying "do not override".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .day: return .light
        case .night: return .dark
        }
    }
}

/// Stands in for a screen that has not been built yet.
///
/// Kept until the real screen lands, so the shell is runnable at every commit
/// and the tab bar can be exercised on a device from day one.
struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: "hammer",
                description: Text("This screen is not built yet.")
            )
            .navigationTitle(title)
        }
    }
}
