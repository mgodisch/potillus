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
    ///
    /// Takes the whole reading — the composed instant AND the frame it is read in
    /// — because the sheet is what composes it. The models used to place a bare
    /// time on a day of their own choosing.
    let onSave: (DrinkDefinition, Int, Int64, Int, String) async -> Bool

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
    /// The logical day the sheet was opened ON — today's on the Today screen and
    /// in the drinks list, the tapped cell's in the calendar, the entry's own when
    /// editing. The sheet does NOT file the entry under it: the day follows from
    /// the reading its two fields compose. What this is for is the note — when the
    /// composed reading falls on another logical day, the sheet says which,
    /// because the entry then disappears from the list it was made on and the
    /// user should not have to discover that afterwards.
    let logicalDay: String

    /// Where the sheet was opened, which decides how the date follows a changed
    /// time while the user has not touched it. See `EntrySheetDate`.
    let origin: EntryDayOrigin

    let dayChangeHour: Int
    let dayChangeMinute: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLocale) private var locale

    @State private var selection: DrinkDefinition?
    @State private var volumeText: String
    @State private var note: String = ""
    @State private var timestamp: Date
    @State private var isSaving = false

    /// Set the moment the user picks a date. See `dateBinding`.
    @State private var dateTouched = false

    /// The instant the sheet was opened at, which the `.now` follow-up measures
    /// a typed time against. Held rather than read afresh so the rule cannot
    /// change its answer while the sheet is open.
    private let now: Date

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
        logicalDay: String,
        origin: EntryDayOrigin,
        dayChangeHour: Int = 4,
        dayChangeMinute: Int = 0,
        onSave: @escaping (DrinkDefinition, Int, Int64, Int, String) async -> Bool
    ) {
        self.drinks = drinks
        self.preselected = preselected
        self.capacity = capacity
        self.useSymbols = useSymbols
        self.editing = editing
        self.logicalDay = logicalDay
        self.origin = origin
        self.now = now
        self.dayChangeHour = dayChangeHour
        self.dayChangeMinute = dayChangeMinute
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
            // The sheet's own opening rule, not simply `now`: from the calendar it
            // offers the tapped evening. See `EntrySheetDate`.
            let opening = EntrySheetDate.initial(
                origin: origin, logicalDay: logicalDay,
                changeHour: dayChangeHour, changeMinute: dayChangeMinute, now: now
            )
            initialTimestamp = Self.compose(day: opening.date, hour: opening.hour, minute: opening.minute)
        }
        _timestamp = State(initialValue: initialTimestamp)
    }

    /// The instant of `hour:minute` on the calendar day `day` falls on, in the
    /// device zone. The sheet keeps one `Date` and edits its two halves through
    /// the bindings below; this is where they are put back together.
    private static func compose(day: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return calendar.date(from: parts) ?? day
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

                    // TWO PICKERS, NOT ONE COMBINED. A picker showing both halves
                    // cannot say WHICH the user turned, and the follow-up rule
                    // hangs on that difference. Each binding below edits its own
                    // half of `timestamp`.
                    //
                    // SELECTABLE UP TO TODAY, DISPLAYED WITHOUT LIMIT. A drink
                    // cannot be had in the future, so the picker does not offer
                    // one; the bound is raised to the current value when that
                    // already lies ahead, because an entry the previous release
                    // wrote into the future must not be moved merely by opening
                    // it, and the calendar follow-up legitimately puts a time
                    // before the boundary on tomorrow's date.
                    DatePicker(
                        Loc.string("Date", locale: locale),
                        selection: dateBinding,
                        in: ...max(Date(), timestamp),
                        displayedComponents: .date
                    )
                    .accessibilityElement(children: .combine)

                    DatePicker(
                        Loc.string("Time", locale: locale),
                        selection: timeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    // Caption and value as one stop. `.combine` rather than
                    // `.ignore`: it joins what the children say while leaving their
                    // actions in place, and the picker has to stay operable.
                    .accessibilityElement(children: .combine)

                    // The note: one condition, no special cases. The entry is not
                    // wrong when the reading falls on another logical day, it just
                    // belongs elsewhere — so no warning colour, no symbol, nothing
                    // blocking the save. It is its OWN element rather than folded
                    // into either picker, because both of them can bring it up.
                    if let countsToward {
                        Text(Loc.string("Counts toward %@", countsToward, locale: locale))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                    }

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
                            .foregroundStyle(Color.statusError)
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
            let stored = await onSave(drink, volume, millis, utcOffsetSeconds, note)
            isSaving = false
            if stored { dismiss() }
        }
    }
}

// =============================================================================
// The two halves of one instant
// =============================================================================
//
// IN AN EXTENSION, NOT IN THE TYPE BODY: `check-swift-length` holds the body to
// what SwiftLint's `type_body_length` allows, and an extension is not counted.
// =============================================================================

extension EntrySheet {

    // ── The two halves of one instant ────────────────────────────────────────

    /// The DATE half. Setting it marks the date as the user's, after which the
    /// follow-up below falls silent — otherwise the next turn of the time wheel
    /// would take back the date they had just chosen.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { timestamp },
            set: { picked in
                let parts = Calendar(identifier: .gregorian)
                    .dateComponents([.hour, .minute], from: timestamp)
                timestamp = Self.compose(
                    day: picked, hour: parts.hour ?? 0, minute: parts.minute ?? 0
                )
                dateTouched = true
            }
        )
    }

    /// The TIME half. Setting it lets the date follow, per `EntrySheetDate`.
    private var timeBinding: Binding<Date> {
        Binding(
            get: { timestamp },
            set: { picked in
                let calendar = Calendar(identifier: .gregorian)
                let parts = calendar.dateComponents([.hour, .minute], from: picked)
                let hour = parts.hour ?? 0
                let minute = parts.minute ?? 0
                var day = timestamp
                if !dateTouched, let followed = EntrySheetDate.followUp(
                    origin: origin, logicalDay: logicalDay,
                    changeHour: dayChangeHour, changeMinute: dayChangeMinute,
                    hour: hour, minute: minute, now: now
                ) {
                    day = followed
                }
                timestamp = Self.compose(day: day, hour: hour, minute: minute)
            }
        )
    }

    /// The frame the composed reading is read in.
    ///
    /// The one the user is in NOW, except while an edit leaves the date alone:
    /// correcting a time inside a recorded reading must not reframe it, or the
    /// row would come back at an hour nobody typed.
    private var utcOffsetSeconds: Int {
        let millis = Int64((timestamp.timeIntervalSince1970 * 1000).rounded())
        if let editing, !dateTouched, sameDay(timestamp, initialTimestamp) {
            return editing.utcOffsetSeconds
        }
        return DayResolver.utcOffsetSeconds(timestampMillis: millis)
    }

    private func sameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar(identifier: .gregorian).isDate(lhs, inSameDayAs: rhs)
    }

    /// The logical day the composed reading counts toward, formatted, or `nil`
    /// while it is the day the sheet was opened on.
    private var countsToward: String? {
        let millis = Int64((timestamp.timeIntervalSince1970 * 1000).rounded())
        let offset = utcOffsetSeconds
        guard DayResolver.logicalDayDiffers(
            timestampMillis: millis, utcOffsetSeconds: offset,
            changeHour: dayChangeHour, changeMinute: dayChangeMinute, logicalDay: logicalDay
        ) else { return nil }
        let day = DayResolver.resolve(
            timestampMillis: millis, utcOffsetSeconds: offset,
            changeHour: dayChangeHour, changeMinute: dayChangeMinute
        )
        guard let date = DayResolver.parseDate(day) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")  // `parseDate` anchors at noon UTC
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
