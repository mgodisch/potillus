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
// DrinksScreen.swift – the catalogue, and its editor
// =============================================================================
//
// Layout only. Every rule lives in `DrinkValidator`, and the Save button asks it
// the same question the model will ask — so the button cannot offer to save what
// the model would then reject. On Android those were two different rule sets
// until v0.81.0, and the button lied.
// =============================================================================

struct DrinksScreen: View {

    @State private var model: DrinksModel
    @State private var logger: EntryLogModel
    @State private var editing: DrinkDefinition?
    @State private var logging: DrinkDefinition?
    @State private var isAdding = false

    init(environment: AppEnvironment) {
        _model = State(initialValue: DrinksModel(drinks: environment.drinks))
        _logger = State(initialValue: EntryLogModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            List {
                if model.state.drinks.isEmpty {
                    ContentUnavailableView(
                        "No drinks yet",
                        systemImage: "wineglass",
                        description: Text("Add a drink to start logging.")
                    )
                }
                ForEach(model.state.drinks, id: \.id) { drink in
                    row(drink)
                }
            }
            .navigationTitle("Drinks")
            .toolbar {
                Button {
                    model.clearErrors()
                    isAdding = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .task { model.start() }
            .onDisappear { model.stop() }
            .sheet(isPresented: $isAdding) {
                DrinkEditor(drink: nil) { name, volume, percent, category in
                    model.add(
                        name: name, volumeMl: volume, alcoholPercent: percent, category: category
                    )
                }
            }
            .sheet(item: $editing) { drink in
                DrinkEditor(drink: drink) { name, volume, percent, category in
                    var edited = drink
                    edited.name = name
                    edited.volumeMl = volume
                    edited.alcoholPercent = percent
                    edited.category = category
                    return model.update(edited)
                }
            }
            .sheet(item: $logging) { drink in
                // One drink, so the sheet shows its name instead of a picker.
                EntrySheet(
                    drinks: [drink], preselected: drink, now: logger.now()
                ) { chosen, volume, millis, note in
                    await logger.log(
                        drink: chosen, volumeMl: volume, timestampMillis: millis, note: note
                    )
                }
            }
            .alert(
                "Could not log the drink",
                isPresented: .constant(logger.failure != nil),
                presenting: logger.failure
            ) { _ in
                Button("OK", role: .cancel) { logger.clearFailure() }
            } message: { message in
                Text(message)
            }
            .alert(
                "Cannot delete",
                isPresented: .constant(model.deleteBlocked != nil),
                presenting: model.deleteBlocked
            ) { _ in
                Button("OK", role: .cancel) { model.clearErrors() }
            } message: { blocked in
                // The sentence the user needs, instead of a foreign-key error.
                Text("\(blocked.drinkName) is used by \(blocked.entryCount) entries.")
            }
        }
    }

    private func row(_ drink: DrinkDefinition) -> some View {
        HStack {
            Button {
                model.toggleFavorite(drink)
            } label: {
                Image(systemName: drink.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(drink.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(drink.isFavorite ? "Remove from favourites" : "Add to favourites")

            VStack(alignment: .leading) {
                Text(drink.name)
                Text("\(drink.volumeMl) ml · \(percent(drink.alcoholPercent))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // A preset is part of the app, not the user's data.
            if drink.isPreset {
                Image(systemName: "lock")
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Preset")
            }

            // The pencil, not the row, opens the editor. Tapping a drink LOGS it:
            // that is the action a user performs many times a day, and editing is
            // the rare one. Android makes the same split.
            Button {
                model.clearErrors()
                editing = drink
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("Edit \(drink.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            logger.clearFailure()
            logging = drink
        }
        .accessibilityHint("Logs this drink")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                model.delete(drink)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f %%", value)
    }
}

// =============================================================================
// DrinkEditor – add or edit, with a Save button that cannot lie
// =============================================================================

private struct DrinkEditor: View {

    /// nil when adding.
    let drink: DrinkDefinition?

    /// Returns whether the write succeeded, so the sheet stays open on rejection.
    let onSave: (String, Int, Double, DrinkCategory) -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var volumeText: String
    @State private var percentText: String
    @State private var category: DrinkCategory

    init(drink: DrinkDefinition?, onSave: @escaping (String, Int, Double, DrinkCategory) -> Bool) {
        self.drink = drink
        self.onSave = onSave
        _name = State(initialValue: drink?.name ?? "")
        _volumeText = State(initialValue: drink.map { String($0.volumeMl) } ?? "")
        _percentText = State(initialValue: drink.map { String($0.alcoholPercent) } ?? "")
        _category = State(initialValue: drink?.category ?? .other)
    }

    /// The parsed fields, nil while the text is not a number.
    private var volume: Int? { Int(volumeText) }
    private var percent: Double? { Double(percentText) }

    /// The validator decides, not this view.
    private var violation: DrinkValidator.Violation? {
        guard let volume, let percent else { return nil }
        return DrinkValidator.validate(name: name, volumeMl: volume, alcoholPercent: percent)
    }

    private var canSave: Bool {
        guard let volume, let percent else { return false }
        return DrinkValidator.isValid(name: name, volumeMl: volume, alcoholPercent: percent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Volume (ml)", text: $volumeText)
                        .keyboardType(.numberPad)
                    TextField("Alcohol (%)", text: $percentText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(DrinkCategory.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                } footer: {
                    // Names the offending field, rather than greying out Save in
                    // silence. Empty input is not an error yet — only a start.
                    if let violation, !name.isEmpty || !volumeText.isEmpty {
                        Text(message(for: violation))
                            .foregroundStyle(.red)
                    }
                }

                if let volume, let percent, canSave {
                    LabeledContent("Alcohol") {
                        Text(String(
                            format: "%.1f g",
                            AlcoholCalculator.calculateGrams(
                                volumeMl: volume, alcoholPercent: percent
                            )
                        ))
                        .monospacedDigit()
                    }
                }
            }
            .navigationTitle(drink == nil ? "New drink" : "Edit drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let volume, let percent else { return }
                        if onSave(name, volume, percent, category) { dismiss() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func message(for violation: DrinkValidator.Violation) -> String {
        switch (violation.field, violation.reason) {
        case (.name, .blank): return "The name cannot be empty."
        case (.name, .tooLong): return "The name is too long."
        case (.volumeMl, _):
            // Interpolated, not typed: see EntrySheet.
            return "The volume must be between \(DrinkValidator.volumeMlRange.lowerBound) "
                + "and \(DrinkValidator.volumeMlRange.upperBound) ml."
        case (.alcoholPercent, .notFinite): return "The alcohol content is not a number."
        case (.alcoholPercent, _): return "The alcohol content must be between 0 and 100 %."
        default: return "Please check your input."
        }
    }
}
