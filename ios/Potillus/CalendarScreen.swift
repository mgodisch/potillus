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
// CalendarScreen.swift – a month at a glance
// =============================================================================
//
// Layout only. The grid's arithmetic — how many blank cells precede the first of
// the month, in which order the weekdays run — lives in `MonthGrid`, where it is
// tested. That is deliberate: an off-by-one there shifts every date onto the
// wrong weekday and nothing crashes.
// =============================================================================

struct CalendarScreen: View {

    @Environment(\.appLocale) private var locale

    /// Observed so a return from the background reloads at once (below).
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: CalendarModel

    /// The entry being edited, if any — drives the edit sheet (UI parity with
    /// Android's calendar edit action).
    @State private var editingEntry: ConsumptionEntry?

    /// The entry a delete gesture is asking to remove, if any. Set by the swipe or
    /// the edit-mode badge, cleared by the confirmation alert; the calendar never
    /// deleted an entry without a dialog on Android (`delete_confirm`), and now iOS
    /// does not either. See `pendingDeletion` on the Today screen for the full
    /// rationale — this is the same guard on the same kind of record.
    @State private var pendingDeletion: ConsumptionEntry?

    /// Set while the "+" sheet is open, logging onto the selected day.
    @State private var isLogging = false

    /// The day list's edit mode, owned here and injected into the List so the
    /// localized `EditToggleButton` can drive it (see that file: the stock
    /// `EditButton` titles itself in the SYSTEM language, not the app's).
    @State private var editMode: EditMode = .inactive

    /// Kept so the overflow menu's Settings sheet can be built.
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: CalendarModel(
            entries: environment.entries, drinks: environment.drinks,
            preferences: environment.preferences,
            clock: environment.clock
        ))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            // A `List`, not a `ScrollView`: the day's entries need `.onDelete` for
            // the swipe and the edit-mode badge, and those live only in a List's
            // `ForEach`. The month — header, weekday row, grid — rides along as a
            // Section whose separators are hidden and whose insets are zeroed, so it
            // keeps the edge-to-edge look it had in the ScrollView (each of those
            // views carries its own `.padding(.horizontal)`).
            List {
                Section {
                    monthHeader
                    weekdayHeader
                    grid
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if model.state.selectedDate != nil { selectedDay }
            }
            .listStyle(.plain)
            .navigationTitle(Loc.string("Calendar", locale: locale))
            .appOverflowMenu(environment: environment)
            .toolbar {
                // The counterpart of Android's floating action button, which is
                // likewise shown only once a day is picked: without a selection
                // there is no day to book onto, and a "+" that asks "which day?"
                // after being tapped is a worse question than one that waits to be
                // asked. `.primaryAction` is where iOS puts this — top trailing,
                // beside the overflow menu, rather than floating over the grid.
                if model.state.selectedDate != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isLogging = true
                        } label: {
                            Label(Loc.string("Add Entry", locale: locale), systemImage: "plus")
                        }
                        .disabled(model.state.drinks.isEmpty)
                    }
                }
                // Edit mode for the day's entries, the visible delete path that
                // replaces the per-row trash icon. Shown only when the selected day
                // actually has entries to act on; localized via EditToggleButton
                // (0.84.0 QA round).
                if !model.state.selectedEntries.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditToggleButton(editMode: $editMode, locale: locale)
                    }
                }
            }
            // Feed the List the edit mode the toggle drives (see
            // EditToggleButton) — and leave edit mode whenever the day's entry
            // list empties, which here happens not only on the last delete but
            // also when the user taps a different, empty day: the toggle is
            // hidden then, and a stale `.active` would badge the next day's rows
            // with no Done button in sight.
            .environment(\.editMode, $editMode)
            .onChange(of: model.state.selectedEntries.isEmpty) { _, empty in
                if empty { editMode = .inactive }
            }
            .sheet(isPresented: $isLogging) {
                EntrySheet(
                    drinks: model.state.drinks,
                    // No "last used" preselection here: on Today that guesses well
                    // because the user is logging what they just drank. Recording a
                    // past day is a different act — the drink is remembered, not
                    // repeated — so the sheet opens unbiased.
                    preselected: nil,
                    // The instant the sheet offers, and Android's dialog too: now.
                    // What makes the entry land on the CHOSEN day is not this
                    // timestamp but the logicalDate the model attaches; the two are
                    // deliberately separate facts.
                    now: Date()
                    // capacity: omitted, so the sheet hides the capacity dot. Its
                    // figures — today's grams, this week's total, this week's
                    // drinking days — are all about TODAY, and this entry is not.
                    // A dot answering the wrong day's question is worse than none.
                ) { drink, volume, millis, note in
                    await model.addEntry(
                        drink: drink, volumeMl: volume, timestampMillis: millis, note: note
                    )
                    return model.failure == nil
                }
            }
            // The edit sheet, moved here from the selected-day block: it now hangs
            // off the List rather than the VStack that block used to be. Its body is
            // unchanged — a one-element catalogue built from the entry, the same
            // scope as Android's calendar edit.
            .sheet(item: $editingEntry) { entry in
                EntrySheet(
                    drinks: [drink(from: entry)],
                    preselected: drink(from: entry),
                    now: Date(),
                    editing: entry
                ) { drink, volume, millis, note in
                    var updated = entry
                    updated.volumeMl = volume
                    updated.timestampMillis = millis
                    updated.note = note
                    updated.gramsAlcohol = AlcoholCalculator.calculateGrams(
                        volumeMl: volume, alcoholPercent: drink.alcoholPercent
                    )
                    await model.updateEntry(updated)
                    return model.failure == nil
                }
            }
            // The delete confirmation, shown by the swipe and the edit-mode badge
            // alike. It mirrors Android's calendar `AlertDialog`: a red "Delete" and
            // a "Cancel", naming the drink, so an entry is never removed by a single
            // stray gesture. Built like the Today screen's, down to the `Binding`.
            .alert(
                Loc.string("Delete", locale: locale),
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { presented in if !presented { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { entry in
                Button(Loc.string("Delete", locale: locale), role: .destructive) {
                    Task { await model.deleteEntry(entry) }
                    pendingDeletion = nil
                }
                Button(Loc.string("Cancel", locale: locale), role: .cancel) {
                    pendingDeletion = nil
                }
            } message: { entry in
                Text(Loc.string("Really delete “%@”?", entry.drinkName, locale: locale))
            }
            // `start()` loads and then subscribes; a database change in another
            // tab reaches this month without a manual reload.
            .task { await model.start() }
            .onDisappear { model.stop() }
            // Reload on foregrounding; see TodayScreen for the full rationale
            // (onAppear does not fire, the ticker only bounds staleness).
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.load() } }
            }
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private var monthHeader: some View {
        HStack {
            Button { Task { await model.previousMonth() } } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Loc.string("Previous month", locale: locale))
            Spacer()
            Text(monthName)
                .font(.headline)
            Spacer()
            Button { Task { await model.nextMonth() } } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Loc.string("Next month", locale: locale))
        }
        .padding(.horizontal)
    }

    /// The month's name in the user's locale. `DateFormatter` is asked for a
    /// month-and-year template rather than a fixed pattern, so the ORDER follows
    /// the locale too — "January 2026", but "2026年1月" where that is right.
    private var monthName: String {
        var components = DateComponents()
        components.year = model.state.year
        components.month = model.state.month
        components.day = 1
        components.hour = 12

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: components) else { return "" }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(model.state.grid.weekdayOrder, id: \.self) { iso in
                Text(weekdaySymbol(iso))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    /// `DateFormatter.veryShortStandaloneWeekdaySymbols` is Sunday-indexed; the
    /// grid speaks ISO. The same conversion as in `DayResolver`, inverted.
    private func weekdaySymbol(_ iso: Int) -> String {
        let symbols = DateFormatter().veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return "" }
        let sundayIndex = iso == 7 ? 0 : iso
        return symbols[sundayIndex]
    }

    // ── Grid ─────────────────────────────────────────────────────────────────

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<model.state.grid.leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(model.state.grid.days, id: \.self) { date in
                dayCell(date)
            }
        }
        .padding(.horizontal)
    }

    private func dayCell(_ date: String) -> some View {
        let summary = model.state.summaries[date]
        let isToday = date == model.state.today
        let isSelected = date == model.state.selectedDate

        return Button {
            Task { await model.select(date) }
        } label: {
            VStack(spacing: 2) {
                Text(dayNumber(date))
                    .font(.callout)
                    .monospacedDigit()
                // A dot only when something was logged: an empty day says nothing,
                // rather than saying zero.
                Circle()
                    .fill(model.isOverLimit(date) ? Color.red : Color.accentColor)
                    .frame(width: 5, height: 5)
                    .opacity(summary == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? Color.accentColor.opacity(0.2) : .clear)
            .overlay(
                Circle()
                    .strokeBorder(isToday ? Color.accentColor : .clear, lineWidth: 1)
                    .frame(width: 30, height: 30)
                    .offset(y: -6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(date, summary: summary))
    }

    /// "2026-01-02" → "2". Sliced, not parsed: the string is the truth.
    private func dayNumber(_ date: String) -> String {
        let parts = date.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[2]) else { return "" }
        return String(day)
    }

    private func accessibilityLabel(_ date: String, summary: DaySummary?) -> String {
        guard let summary else {
            return Loc.string("%@, nothing logged", date, locale: locale)
        }
        // The grams number is formatted in the in-app locale (one decimal) and
        // passed as the second positional argument, so VoiceOver reads it in the
        // same language as the rest of the label.
        let grams = Loc.number(summary.totalGrams, fractionDigits: 1, locale: locale)
        return Loc.string("%1$@, %2$@ grams", date, grams, locale: locale)
    }

    // ── Selected day ─────────────────────────────────────────────────────────

}

// ============================================================================
// CalendarScreen – the selected day
// ============================================================================
//
// Split off because the view outgrew SwiftLint's type_body_length, and this is
// the seam that was already there: above, the month as a grid of days; here, one
// day as a list of entries. An extension IN THIS FILE, not a new one -- unlike
// StatsScreenExport, which had to drop `private` from the members it reaches
// across the file boundary. Nothing here needs to be visible to anything else,
// so nothing is.
// ============================================================================

extension CalendarScreen {

    /// The selected day as List sections: a summary block (date, grams, the daily
    /// bar) with its separators hidden so it reads as a caption, and a second
    /// section of the day's entries. The entries carry `.onDelete`, so the swipe
    /// and the edit-mode badge both reach the confirmation. The edit sheet and the
    /// delete alert moved to the `body`'s List — this block is now content, not a
    /// container. A `Group` lets the property hand the List two sections at once.
    private var selectedDay: some View {
        Group {
            Section {
                if let date = model.state.selectedDate {
                    HStack {
                        Text(date).font(.headline)
                        Spacer()
                        Text("\(Loc.number(model.state.totalGramsSelected, fractionDigits: 1, locale: locale)) g")
                            .monospacedDigit()
                            .foregroundStyle(
                                AlcoholCalculator.isOverLimit(
                                    totalGrams: model.state.totalGramsSelected,
                                    limitGrams: model.state.limitInfo.limitGrams
                                ) ? .red : .secondary
                            )
                    }

                    // The daily-limit bar under the selected day, as on Android's
                    // calendar. Only the daily gram limit is meaningful for a single
                    // historical day, so the weekly/drink-day bars are not shown.
                    LimitBar(
                        caption: Loc.string("Today", locale: locale),
                        value: "\(Loc.number(model.state.totalGramsSelected, fractionDigits: 1, locale: locale)) g",
                        limit: "\(Loc.number(model.state.limitInfo.limitGrams, fractionDigits: 0, locale: locale)) g",
                        fill: LimitGauge.fillFraction(
                            totalGrams: model.state.totalGramsSelected,
                            limitGrams: model.state.limitInfo.limitGrams
                        ),
                        emphasis: LimitGauge.emphasis(
                            totalGrams: model.state.totalGramsSelected,
                            limitGrams: model.state.limitInfo.limitGrams
                        )
                    )
                }
            }
            .listRowSeparator(.hidden)

            Section {
                if model.state.selectedEntries.isEmpty {
                    Text(Loc.string("No entries for this day.", locale: locale))
                        .foregroundStyle(.secondary)
                }
                ForEach(model.state.selectedEntries, id: \.id) { entry in
                    entryRow(entry)
                }
                // The swipe and the edit-mode badge land here. Without a
                // `List(selection:)` the edit mode deletes one row at a time, so the
                // set holds a single entry; it is handed to the confirmation alert
                // (see `pendingDeletion`), never deleted on the spot.
                .onDelete { offsets in
                    if let first = offsets.map({ model.state.selectedEntries[$0] }).first {
                        pendingDeletion = first
                    }
                }
            }
        }
    }

    /// One entry row: name and the full "time · ml · % · g" detail line (plus the
    /// note when present). The whole row is the edit affordance — tapping it opens
    /// the sheet the pencil used to. Like Today's row it is a `Button`, so SwiftUI
    /// suppresses the tap while the list is in edit mode and a delete-tap never also
    /// opens the editor. The pencil and trash icons are gone: edit is the row tap,
    /// delete is the swipe or the edit-mode badge, matching Today.
    private func entryRow(_ entry: ConsumptionEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.drinkName)
                    Text(entryDetail(entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "<time> · <ml> ml · <percent> % · <grams> g" in the in-app locale, the
    /// same fields Android's row shows. The time uses the device zone (a wall
    /// clock the user recognises); its format follows the in-app locale via
    /// `setLocalizedDateFormatFromTemplate("Hm")` — 12- or 24-hour as the locale
    /// dictates — the setup the Today row now shares.
    private func entryDetail(_ entry: ConsumptionEntry) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        let time = formatter.string(
            from: Date(timeIntervalSince1970: Double(entry.timestampMillis) / 1000.0)
        )
        let percent = Loc.number(entry.alcoholPercent, fractionDigits: 1, locale: locale)
        let grams = Loc.number(entry.gramsAlcohol, fractionDigits: 1, locale: locale)
        return "\(time) · \(entry.volumeMl) ml · \(percent) % · \(grams) g"
    }

    /// The entry's own drink, rebuilt as a single-item catalogue for the edit
    /// sheet. Editing does not swap the drink, so the id/category are cosmetic.
    private func drink(from entry: ConsumptionEntry) -> DrinkDefinition {
        DrinkDefinition(
            id: entry.drinkId,
            name: entry.drinkName,
            volumeMl: entry.volumeMl,
            alcoholPercent: entry.alcoholPercent
        )
    }
}
