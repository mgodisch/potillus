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
    @Environment(\.scenePhase) private var scenePhase

    /// The list's edit mode, owned here and injected into the List so the
    /// localized `EditToggleButton` can drive it (see that file: the stock
    /// `EditButton` titles itself in the SYSTEM language, not the app's).
    ///
    /// Also read by the row, whose tap means two different things: outside edit
    /// mode it logs the drink, inside it opens that drink's editor. A row is a
    /// raw `.onTapGesture` here — it cannot be a `Button`, because it already
    /// contains one (the favourite star), and SwiftUI does not suppress a raw
    /// gesture in edit mode the way it suppresses a button. That is what makes
    /// the second meaning possible at all: the gesture still fires while the
    /// delete badges are showing. Owning the state (rather than reading the
    /// `\.editMode` environment, as before the 0.84.0 QA round) makes the row
    /// read the very value the List obeys.
    @State private var editMode: EditMode = .inactive

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
                        Loc.string("No drinks defined yet.", locale: locale),
                        systemImage: "wineglass",
                        description: Text(Loc.string("Add a drink to start logging.", locale: locale))
                    )
                }
                ForEach(model.state.drinks, id: \.id) { drink in
                    row(drink)
                }
                // This drives the delete badge in `EditToggleButton`'s edit mode —
                // the visible, swipe-free delete path. Without a `List(selection:)`
                // the edit mode removes one row at a time, so the set holds a single
                // drink; it opens the same confirmation the swipe's Delete uses
                // (`deleting`), never deleting on the spot. The trailing swipe adds
                // its own Delete and Edit alongside (see `row`); the two mechanisms
                // are complementary, not duplicates.
                .onDelete { offsets in
                    if let first = offsets.map({ model.state.drinks[$0] }).first {
                        model.clearErrors()
                        deleting = first
                    }
                }
            }
            .navigationTitle(Loc.string("Drinks", locale: locale))
            .appOverflowMenu(environment: environment)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.clearErrors()
                        isAdding = true
                    } label: {
                        Label(Loc.string("Add Drink", locale: locale), systemImage: "plus")
                    }
                }
                // The visible path to both rare actions, replacing the per-row
                // pencil and trash icons: the edit toggle puts the list into edit
                // mode, where each row shows a red delete badge and answers a tap
                // with its editor (see `row`). The trailing swipe keeps offering
                // the same two, for the user who reaches for it; neither is a
                // hidden-only gesture any more. Shown only when there is a drink
                // to act on. (An earlier revision of this comment claimed a
                // long-press context menu; none was ever built — corrected in the
                // 0.84.0 QA round.)
                if !model.state.drinks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditToggleButton(
                            editMode: $editMode,
                            locale: locale,
                            editLabel: Loc.string("Edit drinks", locale: locale)
                        )
                    }
                }
            }
            // Feed the List the edit mode the toggle drives (see
            // EditToggleButton) — and leave edit mode when the last drink goes:
            // the toggle is hidden then, so a stale `.active` would greet the
            // NEXT drink with an unexplained delete badge and no Done button.
            .environment(\.editMode, $editMode)
            .onChange(of: model.state.drinks.isEmpty) { _, empty in
                if empty { editMode = .inactive }
            }
            .task { model.start(); capacity.start(); await logger.refreshDayContext() }
            .onDisappear { model.stop(); capacity.stop() }
            // Reload the capacity snapshot on foregrounding; see TodayScreen for
            // the full rationale (onAppear does not fire, the ticker only bounds
            // staleness). `model` needs no counterpart: the catalogue is not a
            // function of time, it changes only when something writes to it.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await capacity.load(); await logger.refreshDayContext() } }
            }
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
                    capacity: capacity.capacity, useSymbols: capacity.useSymbols,
                    logicalDay: logger.logicalDay,
                    // The drinks list logs a drink as it happens, exactly as the
                    // Today screen does, so it follows the same rule.
                    origin: .now,
                    dayChangeHour: logger.dayChangeHour, dayChangeMinute: logger.dayChangeMinute
                ) { chosen, volume, millis, offset, note in
                    await logger.log(
                        drink: chosen, volumeMl: volume,
                        timestampMillis: millis, utcOffsetSeconds: offset, note: note
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
            // The star is gone while the list is in edit mode, and on purpose:
            // SwiftUI suppresses a row button's action there, so it would sit in
            // the row looking tappable and do nothing — and, being a button, it
            // would swallow the tap that the rest of the row answers with the
            // editor. Hiding it makes the whole row give one answer.
            if !editMode.isEditing {
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
                // Read AFTER the row it belongs to, though it is drawn before it:
                // what the row is comes first, what can be done with it second.
                // A sort priority reorders the reading without moving anything on
                // screen; higher goes first, so the row's group carries 1.
                .accessibilitySortPriority(0)
            }

            // ONE SENTENCE FOR VOICEOVER: the drink, its category, its figures,
            // its capacity state — the order a reader searches in. Left alone the
            // HStack is four elements, and the dot comes FIRST on screen, so every
            // row opened with a warning and named the drink two swipes later. The
            // star stays outside this group and keeps its own focus and label.
            //
            // The category is spoken though the row does not show it: it is a
            // real property of the drink (the statistics group by it), and Android
            // states it here through its category glyph.
            // An HStack, NOT a Group: a Group hands its modifiers to each child
            // separately, so `children: .ignore` made the dot and the text column
            // two elements that each announced the whole sentence, and the dot
            // stayed audible (0.85.0). A real container takes the modifier once.
            // Default spacing throughout, so the row looks as it did.
            HStack {
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
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenDrink(drink))
            .accessibilitySortPriority(1)
            // The hint sits HERE, not on the enclosing HStack: a hint on a
            // container is inherited by every element inside it, so the star
            // announced "logs this drink" over a button that does no such thing.
            .accessibilityHint(editMode.isEditing
                ? ""
                : Loc.string("Logs this drink", locale: locale))
            .accessibilityAction {
                if editMode.isEditing {
                    model.clearErrors()
                    editing = drink
                } else {
                    logger.clearFailure()
                    logging = drink
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        // Tapping a drink LOGS it: the action a user performs many times a day.
        // Editing and deleting are the rare ones, and this is the one screen whose
        // row tap is already spoken for — so they belong to edit mode, which is
        // what a user enters when the intent is to change the catalogue rather
        // than to drink from it. There the same tap opens the drink's editor,
        // alongside the delete badge. The trailing swipe keeps both actions for
        // the user who reaches for it (Mail is the model: tap acts, swipe acts
        // too); the per-row pencil and trash icons the row used to carry are gone.
        .onTapGesture {
            if editMode.isEditing {
                model.clearErrors()
                editing = drink
            } else {
                logger.clearFailure()
                logging = drink
            }
        }
        // Trailing swipe: Edit (blue) and Delete (red). Both actions live in this
        // one `.swipeActions` on purpose — putting only one here would let it
        // replace `.onDelete`'s automatic swipe and drop the other. `.onDelete`
        // itself stays (below), because it is what still draws the delete badge in
        // `EditToggleButton`'s edit mode: that, with the row tap beside it, is the
        // swipe-free path to both actions Apple's accessibility guidance asks for,
        // so neither swipe action is the only way to its dialog.
        //
        // `allowsFullSwipe` is off so a long swipe cannot commit a delete past
        // the confirmation — Delete only opens the same dialog the edit-mode
        // badge and the context of a drink-in-use share (`deleting`), never
        // removing on the spot. Delete is declared first so it sits at the row's
        // trailing edge.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                model.clearErrors()
                deleting = drink
            } label: {
                Label(Loc.string("Delete", locale: locale), systemImage: "trash")
            }
            Button {
                model.clearErrors()
                editing = drink
            } label: {
                Label(Loc.string("Edit", locale: locale), systemImage: "square.and.pencil")
            }
            .tint(.blue)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Loc.percent(value, locale: locale)) %"
    }

    /// The whole row as one sentence for VoiceOver: name, category, volume,
    /// strength, grams, capacity state.
    ///
    /// Assembled rather than combined from the row's views, because the order
    /// differs from the visual one — the dot is drawn first and spoken last —
    /// and because the units on screen are symbols ("ml", "%", "≈ … g") that a
    /// reader meets as characters. The "≈" is dropped rather than resolved: the
    /// figure is an estimate either way, and a word for it on every row buys
    /// nothing.
    private func spokenDrink(_ drink: DrinkDefinition) -> String {
        let grams = AlcoholCalculator.calculateGrams(
            volumeMl: drink.volumeMl, alcoholPercent: drink.alcoholPercent
        )
        let light = capacity.capacity.status(forServing: grams)
        return Loc.string(
            "%1$@, %2$@, %3$lld millilitres, %4$@ percent, %5$@ grams of alcohol, %6$@",
            drink.name,
            Loc.string(drink.category.categoryDisplayKey, locale: locale),
            drink.volumeMl,
            Loc.percent(drink.alcoholPercent, locale: locale),
            Loc.number(grams, fractionDigits: 1, locale: locale),
            TrafficLightDot.statusDescription(for: light, locale: locale),
            locale: locale
        )
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

    /// Whether any field differs from what `init` seeded — the guard for the
    /// swipe-to-dismiss below. Each comparison mirrors one seeding line above;
    /// keep the two in step.
    private var isDirty: Bool {
        name != (drink?.name ?? "")
            || volumeText != (drink.map { String($0.volumeMl) } ?? "")
            || percentText != (drink.map { String($0.alcoholPercent) } ?? "")
            || category != (drink?.category ?? .other)
    }

    /// The parsed fields, nil while the text is not a number.
    ///
    /// The percent goes through `DrinkValidator.parseDecimal`, which accepts a
    /// comma as well as a dot: the decimal keyboard below offers only the
    /// LOCALE's separator key, and on the comma-decimal locales `Double("4,9")`
    /// is nil — before the 0.84.0 QA round that made every fractional ABV
    /// unenterable there, with the Save button greyed out and no message.
    private var volume: Int? { Int(volumeText) }
    private var percent: Double? { DrinkValidator.parseDecimal(percentText) }

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
                    TextField(Loc.string("Amount", locale: locale), text: $volumeText)
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
                    //
                    // The first branch exists because an unparseable percent
                    // never REACHES the validator (`percent` is nil, so
                    // `violation` is nil too): without it, typing "4,9,9" would
                    // grey out Save with no words at all — the silent-lie
                    // failure mode this editor's header forbids.
                    if percent == nil && !percentText.isEmpty {
                        Text(message(for: DrinkValidator.Violation(
                            field: .alcoholPercent, reason: .notFinite
                        )))
                            .foregroundStyle(Color.statusError)
                    } else if let violation, !name.isEmpty || !volumeText.isEmpty {
                        Text(message(for: violation))
                            .foregroundStyle(Color.statusError)
                    }
                }

                if let volume, let percent, canSave {
                    LabeledContent(Loc.string("Alcohol Content", locale: locale)) {
                        Text(grams(volumeMl: volume, alcoholPercent: percent))
                            .monospacedDigit()
                    }
                }
            }
            // Through Loc, like every user-facing string: the bare ternary of
            // literals this used to be rendered English in all twenty non-English
            // languages (0.84.0 QA round). The keys are Android's `add_drink` /
            // `edit_drink`, so the parity gate keeps the wording in step.
            .navigationTitle(Loc.string(drink == nil ? "Add Drink" : "Edit Drink", locale: locale))
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
        // A half-typed drink must not vanish under an accidental swipe: with
        // unsaved input, only the explicit Cancel and Save leave the sheet.
        // Apple's own compose sheets guard the same way, and the modifier does
        // not touch programmatic dismissal, so both buttons keep working
        // (0.84.0 QA round).
        .interactiveDismissDisabled(isDirty)
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

    /// The user-facing sentence for a rejected field, in the in-app language.
    ///
    /// Every message is a catalogue key equal to its Android string
    /// (`drink_validation_*`), so the parity gate holds the two platforms to the
    /// same words in every language. These used to be raw English literals,
    /// which put English into the footer of all twenty non-English languages
    /// (0.84.0 QA round). The volume sentence carries its bound in prose — the
    /// price of the verbatim key; see the same note in EntrySheet.
    private func message(for violation: DrinkValidator.Violation) -> String {
        switch (violation.field, violation.reason) {
        case (.name, .blank):
            return Loc.string("The name of the drink must not be empty.", locale: locale)
        case (.name, .tooLong):
            return Loc.string("The drink name is too long (max. 100 characters).", locale: locale)
        case (.volumeMl, _):
            return Loc.string("The amount must be between 1 ml and 5,000 ml.", locale: locale)
        case (.alcoholPercent, .notFinite):
            return Loc.string("The alcohol content is not a valid number.", locale: locale)
        case (.alcoholPercent, _):
            return Loc.string("The alcohol content must be between 0 % and 100 %.", locale: locale)
        default:
            return Loc.string("Please check your input.", locale: locale)
        }
    }
}
