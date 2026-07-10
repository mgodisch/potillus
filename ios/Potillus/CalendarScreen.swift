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

    @State private var model: CalendarModel

    init(environment: AppEnvironment) {
        _model = State(initialValue: CalendarModel(
            entries: environment.entries, preferences: environment.preferences
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
            // `start()` loads and then subscribes; a database change in another
            // tab reaches this month without a manual reload.
            .task { await model.start() }
            .onDisappear { model.stop() }
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private var monthHeader: some View {
        HStack {
            Button { Task { await model.previousMonth() } } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthName)
                .font(.headline)
            Spacer()
            Button { Task { await model.nextMonth() } } label: {
                Image(systemName: "chevron.right")
            }
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
        guard let summary else { return "\(date), nothing logged" }
        return String(format: "%@, %.1f grams", date, summary.totalGrams)
    }

    // ── Selected day ─────────────────────────────────────────────────────────

    private var selectedDay: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = model.state.selectedDate {
                HStack {
                    Text(date).font(.headline)
                    Spacer()
                    Text(String(format: "%.1f g", model.state.totalGramsSelected))
                        .monospacedDigit()
                        .foregroundStyle(
                            AlcoholCalculator.isOverLimit(
                                totalGrams: model.state.totalGramsSelected,
                                limitGrams: model.state.limitInfo.limitGrams
                            ) ? .red : .secondary
                        )
                }
            }

            if model.state.selectedEntries.isEmpty {
                Text(Loc.string("Nothing logged on this day.", locale: locale))
                    .foregroundStyle(.secondary)
            }
            ForEach(model.state.selectedEntries, id: \.id) { entry in
                HStack {
                    Text(entry.drinkName)
                    Spacer()
                    Text(String(format: "%.1f g", entry.gramsAlcohol))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        Task { await model.deleteEntry(entry) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Loc.string("Delete %@", entry.drinkName, locale: locale))
                }
            }
        }
        .padding()
    }
}
