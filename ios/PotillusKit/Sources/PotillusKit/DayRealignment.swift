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

import Foundation

// =============================================================================
// DayRealignment.swift – keeping the derived logical day in step
// =============================================================================
//
// The iOS counterpart of the collection Android runs in `PotillusApp.onCreate`.
// One place per platform watches the settings and hands each emission to the
// repository, which decides whether anything needs rewriting.
//
// WHY IT LIVES IN THE KIT AND NOT IN THE APP TARGET
//   The app target is not covered by `swift test`. Putting the loop here means a
//   test can drive it with a fake store and a fake repository; the app target is
//   left with one line that starts it.
//
// WHY A COLLECTION AND NOT A SINGLE READ AT LAUNCH
//   The logical day is derived from the day-change time, so moving that setting
//   changes what every screen should show — retroactively, which is the point of
//   the whole design. Reading once at launch would postpone the effect to the
//   next start and leave the app showing days that no longer follow from the
//   setting the user is looking at.
// =============================================================================

/// Watches the day-change setting and realigns `entries.logicalDate` after it moves.
public struct DayRealignment: Sendable {

    private let entries: any EntryRepositoryProtocol
    private let preferences: any PreferencesStoring

    public init(entries: any EntryRepositoryProtocol, preferences: any PreferencesStoring) {
        self.entries = entries
        self.preferences = preferences
    }

    /// Runs until the surrounding task is cancelled.
    ///
    /// WHY EVERY EMISSION IS CHEAP. The store emits for any preference the user
    /// touches, most of which have nothing to do with days.
    /// `realignDays(settings:)` compares the setting against the stored key first
    /// and returns having read one row when they agree, which is almost always.
    ///
    /// WHY THE FIRST EMISSION MATTERS. It usually finds the key unset — a fresh
    /// v4 migration leaves it that way — and performs the initial derivation,
    /// including the repair of pre-0.85.0 calendar entries.
    ///
    /// WHY A FAILURE IS SWALLOWED. There is no screen for it and nothing the user
    /// could do: the transaction rolled back, the key still holds its old value,
    /// and the next emission disagrees with the setting again and retries. What
    /// the user sees in the meantime is the days as stored, which is what the app
    /// showed permanently before any of this existed. Surfacing a technical error
    /// on a screen the user did not open would be noise, not information.
    ///
    /// WHY THERE IS NO GUARD AGAINST OVERLAP. `AsyncStream` delivers one value at
    /// a time to a single consumer, and this awaits each realignment before
    /// taking the next; two runs cannot be in flight together. Should a write
    /// from elsewhere land in between, it goes through `add` or `update`, which
    /// derive under the same key.
    public func run() async {
        for await settings in await preferences.observe() {
            try? entries.realignDays(settings: settings)
        }
    }
}
