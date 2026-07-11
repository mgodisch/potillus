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
// EntrySheet.swift – logging a drink
// =============================================================================
//
// Reached from two places: the Today screen's "+", where the drink is picked, and
// a tap on a row of the Drinks screen, where it is already chosen. One sheet, so
// the two cannot offer different fields.
//
// The volume bound is `DrinkValidator.volumeMlRange`, the same range a drink's
// own serving size must satisfy — a fifth copy of "1...5000" would be a fifth
// chance to disagree.
// =============================================================================

struct EntrySheet: View {

    /// The catalogue to choose from. A single-element list when the sheet was
    /// opened from a drink's row.
    let drinks: [DrinkDefinition]

    /// Which drink starts selected: the last one logged, or the row that was
    /// tapped.
    let preselected: DrinkDefinition?

    /// Returns whether the entry was stored, so the sheet stays open on failure.
    let onSave: (DrinkDefinition, Int, Int64, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLocale) private var locale

    @State private var selection: DrinkDefinition?
    @State private var volumeText: String
    @State private var note: String = ""
    @State private var timestamp: Date
    @State private var isSaving = false

    init(
        drinks: [DrinkDefinition],
        preselected: DrinkDefinition?,
        now: Date,
        onSave: @escaping (DrinkDefinition, Int, Int64, String) async -> Bool
    ) {
        self.drinks = drinks
        self.preselected = preselected
        self.onSave = onSave

        let initial = preselected ?? drinks.first
        _selection = State(initialValue: initial)
        _volumeText = State(initialValue: initial.map { String($0.volumeMl) } ?? "")
        _timestamp = State(initialValue: now)
    }

    private var volume: Int? { Int(volumeText) }

    private var canSave: Bool {
        guard let volume else { return false }
        return selection != nil && DrinkValidator.volumeMlRange.contains(volume)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if drinks.count > 1 {
                        Picker(Loc.string("Drink", locale: locale), selection: $selection) {
                            ForEach(drinks, id: \.id) { drink in
                                Text(drink.name).tag(Optional(drink))
                            }
                        }
                        // Changing the drink offers its own serving size, which is
                        // what the user almost always wants; they can still edit it.
                        .onChange(of: selection) { _, drink in
                            if let drink { volumeText = String(drink.volumeMl) }
                        }
                    } else if let only = drinks.first {
                        LabeledContent(Loc.string("Drink", locale: locale), value: only.name)
                    }

                    TextField(Loc.string("Volume (ml)", locale: locale), text: $volumeText)
                        .keyboardType(.numberPad)

                    DatePicker(Loc.string("Time", locale: locale), selection: $timestamp)

                    TextField(Loc.string("Note", locale: locale), text: $note, axis: .vertical)
                } footer: {
                    if let volume, !DrinkValidator.volumeMlRange.contains(volume) {
                        // Interpolated, not typed: a message that names a bound
                        // it does not read is a message that will one day lie.
                        Text(
                            "The volume must be between "
                            + "\(DrinkValidator.volumeMlRange.lowerBound) and "
                            + "\(DrinkValidator.volumeMlRange.upperBound) ml."
                        )
                            .foregroundStyle(.red)
                    }
                }

                if let drink = selection, let volume, canSave {
                    LabeledContent(Loc.string("Alcohol", locale: locale)) {
                        Text(String(
                            format: "%.1f g",
                            AlcoholCalculator.calculateGrams(
                                volumeMl: volume, alcoholPercent: drink.alcoholPercent
                            )
                        ))
                        .monospacedDigit()
                    }
                }
            }
            .navigationTitle(Loc.string("Log a drink", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.string("Cancel", locale: locale)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Loc.string("Save", locale: locale)) { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() {
        guard let drink = selection, let volume else { return }
        isSaving = true
        Task {
            let millis = Int64((timestamp.timeIntervalSince1970 * 1000).rounded())
            let stored = await onSave(drink, volume, millis, note)
            isSaving = false
            if stored { dismiss() }
        }
    }
}
