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
// DrinksScreen.swift – the catalogue, and its editor
// =============================================================================
//
// Layout only. Every rule lives in `DrinkValidator`, and the Save button asks it
// the same question the model will ask — so the button cannot offer to save what
// the model would then reject. On Android those were two different rule sets
// until v0.81.0, and the button lied.
// =============================================================================

struct DrinksScreen: View {

    @Environment(\.appLocale) private var locale

    @State private var model: DrinksModel
    @State private var logger: EntryLogModel
    @State private var capacity: DrinkCapacityModel
    @State private var editing: DrinkDefinition?
    @State private var logging: DrinkDefinition?
    @State private var isAdding = false
    @State private var deleting: DrinkDefinition?

    /// Kept so the overflow menu's Settings sheet can be built.
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: DrinksModel(drinks: environment.drinks))
        _logger = State(initialValue: EntryLogModel(environment: environment))
        _capacity = State(initialValue: DrinkCapacityModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            List {
                if model.state.drinks.isEmpty {
                    ContentUnavailableView(
                        Loc.string("No drinks yet", locale: locale),
                        systemImage: "wineglass",
                        description: Text(Loc.string("Add a drink to start logging.", locale: locale))
                    )
                }
                ForEach(model.state.drinks, id: \.id) { drink in
                    row(drink)
                }
            }
            .navigationTitle(Loc.string("Drinks", locale: locale))
            .appOverflowMenu(environment: environment)
            .toolbar {
                Button {
                    model.clearErrors()
                    isAdding = true
                } label: {
                    Label(Loc.string("Add", locale: locale), systemImage: "plus")
                }
            }
            .task { model.start(); capacity.start() }
            .onDisappear { model.stop(); capacity.stop() }
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
                    drinks: [drink], preselected: drink, now: logger.now(),
                    capacity: capacity.capacity, useSymbols: capacity.useSymbols
                ) { chosen, volume, millis, note in
                    await logger.log(
                        drink: chosen, volumeMl: volume, timestampMillis: millis, note: note
                    )
                }
            }
            .alert(
                Loc.string("Could not log the drink", locale: locale),
                isPresented: .constant(logger.failure != nil),
                presenting: logger.failure
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) { logger.clearFailure() }
            } message: { message in
                Text(message)
            }
            .alert(
                Loc.string("Cannot delete", locale: locale),
                isPresented: .constant(model.deleteBlocked != nil),
                presenting: model.deleteBlocked
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) { model.clearErrors() }
            } message: { blocked in
                // The sentence the user needs, instead of a foreign-key error.
                Text(Loc.string(
                    "%1$@ is used by %2$lld entries.",
                    blocked.drinkName, blocked.entryCount, locale: locale
                ))
            }
            // Delete confirmation, shown by both the row's trash button and the
            // swipe action. Mirrors Android's AlertDialog: a red "Delete" and a
            // "Cancel", so removing a drink is always a two-step, reversible tap.
            .alert(
                Loc.string("Delete", locale: locale),
                isPresented: Binding(
                    get: { deleting != nil },
                    set: { presented in if !presented { deleting = nil } }
                ),
                presenting: deleting
            ) { drink in
                Button(Loc.string("Delete", locale: locale), role: .destructive) {
                    model.delete(drink)
                    deleting = nil
                }
                Button(Loc.string("Cancel", locale: locale), role: .cancel) {
                    deleting = nil
                }
            } message: { drink in
                Text(Loc.string("Really delete “%@”?", drink.name, locale: locale))
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
            .accessibilityLabel(drink.isFavorite
                ? Loc.string("Remove from favourites", locale: locale)
                : Loc.string("Add to favourites", locale: locale))

            // Capacity dot: how many more of this drink fit within today's
            // remaining budget, against the same snapshot for every row. Between
            // the star and the name, as on Android.
            TrafficLightDot(
                light: capacity.capacity.status(
                    forServing: AlcoholCalculator.calculateGrams(
                        volumeMl: drink.volumeMl, alcoholPercent: drink.alcoholPercent
                    )
                ),
                useSymbols: capacity.useSymbols
            )

            VStack(alignment: .leading) {
                Text(drink.name)
                // "ml · % · ≈ N g" — the grams-per-serving Android shows too, so
                // the two platforms' drink rows carry the same figure. The
                // skeleton is punctuation and units only (language-invariant);
                // the numbers resolve in the in-app locale.
                Text(Loc.string(
                    "%1$lld ml · %2$@ · ≈ %3$@ g",
                    drink.volumeMl,
                    percent(drink.alcoholPercent),
                    Loc.number(
                        AlcoholCalculator.calculateGrams(
                            volumeMl: drink.volumeMl, alcoholPercent: drink.alcoholPercent
                        ),
                        fractionDigits: 1,
                        locale: locale
                    ),
                    locale: locale
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

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
            .accessibilityLabel(Loc.string("Edit %@", drink.name, locale: locale))

            // A little breathing room so the pencil and trash do not crowd each
            // other, matching the gap Android's row leaves between them.
            Spacer().frame(width: 12)

            // The trash button mirrors Android's row, which shows a delete
            // affordance without requiring a swipe. It does not delete on the spot:
            // it opens the same confirmation the swipe now uses, so a misplaced tap
            // costs a dialog, not a drink. Drawn in the system red to read as
            // destructive, matching Android's danger tint.
            Button {
                model.clearErrors()
                deleting = drink
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel(Loc.string("Delete %@", drink.name, locale: locale))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            logger.clearFailure()
            logging = drink
        }
        .accessibilityHint(Loc.string("Logs this drink", locale: locale))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                model.clearErrors()
                deleting = drink
            } label: {
                Label(Loc.string("Delete", locale: locale), systemImage: "trash")
            }
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Loc.number(value, fractionDigits: 1, locale: locale)) %"
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
    @Environment(\.appLocale) private var locale

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
                    TextField(Loc.string("Name", locale: locale), text: $name)
                    TextField(Loc.string("Volume (ml)", locale: locale), text: $volumeText)
                        .keyboardType(.numberPad)
                    TextField(Loc.string("Alcohol (%)", locale: locale), text: $percentText)
                        .keyboardType(.decimalPad)
                    Picker(Loc.string("Category", locale: locale), selection: $category) {
                        ForEach(DrinkCategory.allCases, id: \.self) { value in
                            Text(Loc.string(value.categoryDisplayKey, locale: locale)).tag(value)
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
                    LabeledContent(Loc.string("Alcohol", locale: locale)) {
                        Text(grams(volumeMl: volume, alcoholPercent: percent))
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(drink == nil ? "New drink" : "Edit drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.string("Cancel", locale: locale)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Loc.string("Save", locale: locale)) {
                        guard let volume, let percent else { return }
                        if onSave(name, volume, percent, category) { dismiss() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    /// The pure-alcohol grams for the live volume/percent, in the in-app locale.
    /// Computing the value here keeps the number interpolation single-level, which
    /// the display and the l10n scanner both prefer, and the unit stays a neutral
    /// "g".
    private func grams(volumeMl: Int, alcoholPercent: Double) -> String {
        let value = AlcoholCalculator.calculateGrams(
            volumeMl: volumeMl, alcoholPercent: alcoholPercent
        )
        return "\(Loc.number(value, fractionDigits: 1, locale: locale)) g"
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
