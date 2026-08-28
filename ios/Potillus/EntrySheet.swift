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

    /// What `timestamp` was seeded with — `now`, or the edited entry's time —
    /// kept so `isDirty` can tell a touched date wheel from an untouched one
    /// (the other seeds are recomputable from the stored lets; `now` is not
    /// stored, so its value is remembered here).
    private let initialTimestamp: Date

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
            // Editing shows the time the entry RECORDS, not what its instant
            // reads in the device's present frame. The picker is then round-trip
            // honest: the user sees 23:30, confirms 23:30, and the row still
            // says 23:30 afterwards — the save builds a new instant in the frame
            // they are in now, and the model records that frame with it.
            let instant = Date(timeIntervalSince1970: Double(editing.timestampMillis) / 1000.0)
            let shown = DayResolver.displayTimeZone(utcOffsetSeconds: editing.utcOffsetSeconds)
            initialTimestamp = instant.addingTimeInterval(
                TimeInterval(shown.secondsFromGMT(for: instant) - TimeZone.current.secondsFromGMT(for: instant))
            )
        } else {
            _volumeText = State(initialValue: initial.map { String($0.volumeMl) } ?? "")
            initialTimestamp = now
        }
        _timestamp = State(initialValue: initialTimestamp)
    }

    /// Whether any field differs from what `init` seeded — the guard for the
    /// swipe-to-dismiss below. Each comparison mirrors one seeding line above;
    /// keep the two in step.
    private var isDirty: Bool {
        selection != (preselected ?? drinks.first)
            || volumeText != (editing.map { String($0.volumeMl) }
                ?? (preselected ?? drinks.first).map { String($0.volumeMl) } ?? "")
            || note != (editing?.note ?? "")
            || timestamp != initialTimestamp
    }

    private var volume: Int? { Int(volumeText) }

    private var canSave: Bool {
        guard let volume else { return false }
        return selection != nil && DrinkValidator.volumeMlRange.contains(volume)
    }

    /// "11.0 grams of pure alcohol: within your limits" — the preview row as one
    /// sentence, matching what Android's preview says.
    ///
    /// Without the dot's state it is just the figure; the caption "Alcohol
    /// Content" drops out, having been the least useful of the three stops — a
    /// reader who has just typed an amount knows what the row is about.
    private func alcoholSpoken(_ grams: Double, capacity: DrinkCapacity?) -> String {
        let amount = Loc.string(
            "%1$@: %2$@ grams of alcohol",
            Loc.string("Alcohol Content", locale: locale),
            Loc.number(grams, fractionDigits: 1, locale: locale),
            locale: locale
        )
        guard let capacity else { return amount }
        let status = TrafficLightDot.statusDescription(
            for: capacity.status(forServing: grams), locale: locale
        )
        return Loc.string("%1$@: %2$@", amount, status, locale: locale)
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

                    // A bare TextField shows its placeholder only while empty, so
                    // once a value was typed the row read "40" with nothing naming
                    // it — on screen and to a reader alike. LabeledContent keeps the
                    // name in view beside the value, as the rows below it do, and
                    // the unit sits in the name rather than in a suffix node.
                    LabeledContent(Loc.string("Amount in millilitres", locale: locale)) {
                        TextField("", text: $volumeText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    // Hours and minutes only. The picker offered a date as well,
                    // which the field's own name contradicts and which the screen
                    // behind it already fixes — the Today screen is today, and from
                    // the calendar the view model overrides the logical date anyway,
                    // so the date part of this timestamp is never the one that
                    // counts. A reader heard it read out digit by digit before
                    // reaching the time.
                    DatePicker(
                        Loc.string("Time", locale: locale),
                        selection: $timestamp,
                        displayedComponents: .hourAndMinute
                    )
                    // Caption and value as one stop. `.combine` rather than
                    // `.ignore`: it joins what the children say while leaving their
                    // actions in place, and the picker has to stay operable.
                    .accessibilityElement(children: .combine)

                    TextField(Loc.string("Note", locale: locale), text: $note, axis: .vertical)
                } footer: {
                    if let volume, !DrinkValidator.volumeMlRange.contains(volume) {
                        // The whole sentence is ONE catalogue key, verbatim equal
                        // to Android's `drink_validation_volume_range`, so the
                        // parity gate holds the two platforms to the same words.
                        // The earlier form appended the numbers to a translated
                        // fragment — "Das Volumen muss liegen zwischen 1 and
                        // 5000 ml." — leaving the glue words English in every
                        // language (0.84.0 QA round). The price of the verbatim
                        // key is a literal bound in prose: when
                        // `DrinkValidator.volumeMlRange` moves, this string must
                        // move with it, on both platforms.
                        Text(Loc.string(
                            "The amount must be between 1 ml and 5,000 ml.",
                            locale: locale
                        ))
                            .foregroundStyle(.red)
                    }
                }

                if let drink = selection, let volume, canSave {
                    let grams = AlcoholCalculator.calculateGrams(
                        volumeMl: volume, alcoholPercent: drink.alcoholPercent
                    )
                    // Three stops became one: the caption, the dot's status and the
                    // figure each spoke for themselves, so a reader met "Alcohol
                    // Content", "Within your limits" and "11.0 g" with nothing
                    // joining them. The sentence states the amount and how it
                    // stands against the limit, as Android's preview row does.
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(alcoholSpoken(grams, capacity: capacity))
                }
            }
            .navigationTitle(Loc.string(
                editing == nil ? "Log a drink" : "Edit Entry", locale: locale
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.string("Cancel", locale: locale)) { dismiss() }
                        // The screenshot run waits for this before it shoots, so the
                        // frame is never of the presenting screen mid-animation. On
                        // the button rather than on the Form: an identifier on the
                        // Form did not surface in the element tree, and a button is
                        // addressable whatever SwiftUI renders the container as. The
                        // title would be the natural anchor and is not usable — it is
                        // localized into 21 languages.
                        .accessibilityIdentifier("sheet.entryCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Loc.string("Save", locale: locale)) { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
        // A half-typed entry must not vanish under an accidental swipe: with
        // unsaved input, only the explicit Cancel and Save leave the sheet.
        // Apple's own compose sheets guard the same way, and the modifier does
        // not touch programmatic dismissal, so both buttons keep working
        // (0.84.0 QA round).
        .interactiveDismissDisabled(isDirty)
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
