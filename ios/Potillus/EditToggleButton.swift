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

import SwiftUI

// =============================================================================
// EditToggleButton – the system EditButton, in the in-app language
// =============================================================================
//
// SwiftUI's `EditButton` titles itself "Edit"/"Done" against the SYSTEM
// language, not the app's own language setting — the environment it consults is
// the one the in-app language feature exists to override. With the device on
// English and the app on German, three screens showed an English "Edit" over an
// otherwise German toolbar (0.84.0 QA round): exactly the "half its labels in
// another language" failure Localization.swift's header forbids.
//
// This is the drop-in replacement: the same toggle, titled through `Loc` with
// the "Edit"/"Done" keys the catalogue already carries for every language.
//
// HOW THE WIRING DIFFERS FROM EditButton
//   `EditButton` and the `List` meet through the `\.editMode` environment value
//   SwiftUI provides for them. A CUSTOM toggle cannot rely on that binding being
//   present, so each screen owns the state instead: an
//   `@State private var editMode: EditMode = .inactive`, injected into the List
//   with `.environment(\.editMode, $editMode)` and bound into this button. That
//   is Apple's own documented pattern for driving edit mode programmatically
//   (the environment value is a Binding one feeds, not a value one reads), and
//   it has a second payoff: the screen can READ the same state directly — the
//   Drinks screen's tap-to-log guard does — instead of hoping the environment
//   binding it observes is the one the List obeys.
// =============================================================================

/// Toggles a screen's list edit mode, titled in the in-app language.
struct EditToggleButton: View {

    /// The screen's edit-mode state, shared with its `List` via
    /// `.environment(\.editMode, $editMode)` at the call site.
    @Binding var editMode: EditMode

    /// The in-app language, passed in because the button titles itself via
    /// `Loc` rather than the system localization the stock control uses.
    let locale: Locale

    var body: some View {
        Button(Loc.string(editMode.isEditing ? "Done" : "Edit", locale: locale)) {
            // The same animation the stock EditButton drives, so rows slide
            // their delete badges in and out instead of snapping.
            withAnimation {
                editMode = editMode.isEditing ? .inactive : .active
            }
        }
    }
}
