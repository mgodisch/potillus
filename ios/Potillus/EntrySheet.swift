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

    /// Today's budget snapshot, for the capacity dot next to the grams preview.
    /// `nil` hides the dot (the caller had no snapshot to give).
    let capacity: DrinkCapacity?

    /// Whether the capacity dot uses colour-blind glyphs.
    let useSymbols: Bool

    /// When set, the sheet edits this existing entry instead of logging a new
    /// one: the fields start prefilled from it and the title changes. The
    /// `onSave` closure is the same either way — the caller decides whether its
    /// action adds or updates — so this stays one sheet, as Android keeps one
    /// `AddEditEntryDialog`.
    let editing: ConsumptionEntry?

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
        capacity: DrinkCapacity? = nil,
        useSymbols: Bool = false,
        editing: ConsumptionEntry? = nil,
        onSave: @escaping (DrinkDefinition, Int, Int64, String) async -> Bool
    ) {
        self.drinks = drinks
        self.preselected = preselected
        self.capacity = capacity
        self.useSymbols = useSymbols
        self.editing = editing
        self.onSave = onSave

        let initial = preselected ?? drinks.first
        _selection = State(initialValue: initial)
        // In edit mode the entry's own volume, time and note win over the
        // drink's defaults; otherwise the preselected drink's serving size seeds
        // the field and the timestamp is `now`.
        if let editing {
            _volumeText = State(initialValue: String(editing.volumeMl))
            _note = State(initialValue: editing.note)
            _timestamp = State(initialValue: Date(
                timeIntervalSince1970: Double(editing.timestampMillis) / 1000.0
            ))
        } else {
            _volumeText = State(initialValue: initial.map { String($0.volumeMl) } ?? "")
            _timestamp = State(initialValue: now)
        }
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

                    TextField(Loc.string("Amount", locale: locale), text: $volumeText)
                        .keyboardType(.numberPad)

                    DatePicker(Loc.string("Time", locale: locale), selection: $timestamp)

                    TextField(Loc.string("Note", locale: locale), text: $note, axis: .vertical)
                } footer: {
                    if let volume, !DrinkValidator.volumeMlRange.contains(volume) {
                        // Interpolated, not typed: a message that names a bound
                        // it does not read is a message that will one day lie.
                        Text(
                            Loc.string("The volume must be between ", locale: locale)
                            + "\(DrinkValidator.volumeMlRange.lowerBound) and "
                            + "\(DrinkValidator.volumeMlRange.upperBound) ml."
                        )
                            .foregroundStyle(.red)
                    }
                }

                if let drink = selection, let volume, canSave {
                    let grams = AlcoholCalculator.calculateGrams(
                        volumeMl: volume, alcoholPercent: drink.alcoholPercent
                    )
                    LabeledContent(Loc.string("Alcohol Content", locale: locale)) {
                        HStack(spacing: 8) {
                            if let capacity {
                                // Same dot as the drinks list, recomputed for the
                                // volume actually entered here.
                                TrafficLightDot(
                                    light: capacity.status(forServing: grams),
                                    useSymbols: useSymbols
                                )
                            }
                            Text("\(Loc.number(grams, fractionDigits: 1, locale: locale)) g")
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(Loc.string(
                editing == nil ? "Log a drink" : "Edit Entry", locale: locale
            ))
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
