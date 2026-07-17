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

    /// Set while the "+" sheet is open, logging onto the selected day.
    @State private var isLogging = false

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
            ScrollView {
                monthHeader
                weekdayHeader
                grid
                if model.state.selectedDate != nil { selectedDay }
            }
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

    private var selectedDay: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if model.state.selectedEntries.isEmpty {
                Text(Loc.string("No entries for this day.", locale: locale))
                    .foregroundStyle(.secondary)
            }
            ForEach(model.state.selectedEntries, id: \.id) { entry in
                entryRow(entry)
            }
        }
        .padding()
        .sheet(item: $editingEntry) { entry in
            // Editing keeps the entry's own drink: a one-element catalogue built
            // from the entry, so the sheet shows the name and lets volume, time
            // and note change — the same scope as Android's calendar edit.
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
    }

    /// One entry row: name and the full "time · ml · % · g" detail line (plus
    /// the note when present), an edit pencil, and a delete in the destructive
    /// red — matching Android's calendar `EntryListItem`. iOS previously showed
    /// only name and grams with a plain trash and no edit (0.83.0 UI parity).
    private func entryRow(_ entry: ConsumptionEntry) -> some View {
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
            Button {
                editingEntry = entry
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel(Loc.string("Edit %@", entry.drinkName, locale: locale))

            Button(role: .destructive) {
                Task { await model.deleteEntry(entry) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel(Loc.string("Delete %@", entry.drinkName, locale: locale))
        }
    }

    /// "HH:mm · <ml> ml · <percent> % · <grams> g" in the in-app locale, the
    /// same fields Android's row shows. The time uses the device zone (a wall
    /// clock the user recognises), the numbers the in-app locale.
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
