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
// TodayScreen.swift – layout only
// =============================================================================
//
// Every number on this screen is computed by `TodayModel` in the kit, where it is
// under test. This file decides where things sit, and nothing else. If a
// calculation appears here, it belongs somewhere else.
//
// Strings are English literals for now; they become String Catalog keys when the
// 21 locales are ported.
// =============================================================================

struct TodayScreen: View {

    /// The chosen language, applied at the root; every label resolves against it.
    @Environment(\.appLocale) private var locale

    /// Owned by the view, rebuilt only when the environment changes.
    @State private var model: TodayModel

    /// Set while the entry sheet is open.
    @State private var isLogging = false

    /// Set while the settings sheet is open.
    @State private var isConfiguring = false

    /// Kept so the settings sheet can be built; the screen owns its own model.
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: TodayModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences,
            clock: environment.clock
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                if !model.state.favorites.isEmpty { favouritesSection }
                entriesSection
            }
            .navigationTitle(Loc.string("Today", locale: locale))
            .toolbar {
                // The gear, as on Android: settings sit above the tabs, not in
                // them. Leading, so the primary action keeps the trailing corner.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isConfiguring = true
                    } label: {
                        Label(Loc.string("Settings", locale: locale), systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("nav.settings")
                }
                // iOS puts the primary action in the toolbar; Android uses a
                // floating action button. Same action, native placement.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isLogging = true
                    } label: {
                        Label(Loc.string("Log a drink", locale: locale), systemImage: "plus")
                    }
                    .disabled(model.state.drinks.isEmpty)
                    .accessibilityIdentifier("nav.addDrink")
                }
            }
            .task { model.start() }
            .onDisappear { model.stop() }
            .refreshable { await model.load() }
            .sheet(isPresented: $isConfiguring) {
                SettingsScreen(environment: environment)
            }
            .sheet(isPresented: $isLogging) {
                EntrySheet(
                    drinks: model.state.drinks,
                    // People tend to repeat what they just had.
                    preselected: model.state.lastUsedDrink,
                    now: Date()
                ) { drink, volume, millis, note in
                    await model.addEntry(
                        drink: drink, volumeMl: volume, timestampMillis: millis, note: note
                    )
                    return model.failure == nil
                }
            }
            .alert(
                Loc.string("Something went wrong", locale: locale),
                isPresented: .constant(model.failure != nil),
                presenting: model.failure
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Sections ─────────────────────────────────────────────────────────────

    private var summarySection: some View {
        Section {
            LimitBar(
                caption: Loc.string("Today", locale: locale),
                value: grams(model.state.totalGrams),
                limit: grams(model.state.limitInfo.limitGrams),
                fill: LimitGauge.fillFraction(
                    totalGrams: model.state.totalGrams,
                    limitGrams: model.state.limitInfo.limitGrams
                ),
                emphasis: LimitGauge.emphasis(
                    totalGrams: model.state.totalGrams,
                    limitGrams: model.state.limitInfo.limitGrams
                )
            )

            LimitBar(
                caption: Loc.string("7 Days", locale: locale),
                value: grams(model.state.weeklyTotalGrams),
                limit: grams(model.state.limitInfo.weeklyLimitGrams),
                fill: LimitGauge.fillFraction(
                    totalGrams: model.state.weeklyTotalGrams,
                    limitGrams: model.state.limitInfo.weeklyLimitGrams
                ),
                emphasis: LimitGauge.emphasis(
                    totalGrams: model.state.weeklyTotalGrams,
                    limitGrams: model.state.limitInfo.weeklyLimitGrams
                )
            )

            LimitBar(
                caption: Loc.string("Drink days", locale: locale),
                value: "\(model.state.drinkDaysThisWeek)",
                limit: "\(model.state.limitInfo.maxDrinkDaysPerWeek)",
                fill: LimitGauge.drinkDaysFillFraction(
                    drinkDays: model.state.drinkDaysThisWeek,
                    maxDrinkDays: model.state.limitInfo.maxDrinkDaysPerWeek
                ),
                // Today's own status decides the colour. A day already spent as
                // a drink day costs nothing further, so a full bar can stay amber;
                // a dry day at the cap means the next drink spends a day the user
                // does not have, and the bar goes red.
                emphasis: LimitGauge.drinkDaysEmphasis(
                    drinkDays: model.state.drinkDaysThisWeek,
                    maxDrinkDays: model.state.limitInfo.maxDrinkDaysPerWeek,
                    todayIsDrinkDay: model.state.totalGrams > 0
                )
            )

            // Absent rather than zero: without a body weight, or with nothing
            // alcoholic logged, the app does not know — and must not imply 0.0.
            if let bac = model.state.bacPermille {
                LabeledContent(Loc.string("Estimated BAC", locale: locale)) {
                    Text(String(format: "%.2f ‰", bac)).monospacedDigit()
                }
            }
        }
    }

    /// One tap logs the favourite at its own serving size — the shortcut the
    /// whole screen exists for. The sheet is for anything else.
    private var favouritesSection: some View {
        Section(Loc.string("Favourites", locale: locale)) {
            ForEach(model.state.favorites, id: \.id) { drink in
                Button {
                    Task { await model.addEntry(drink: drink, volumeMl: drink.volumeMl) }
                } label: {
                    LabeledContent(drink.name) {
                        Text("\(drink.volumeMl) ml")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var entriesSection: some View {
        Section(Loc.string("Entries", locale: locale)) {
            if model.state.entries.isEmpty {
                Text(Loc.string("Nothing logged yet.", locale: locale))
                    .foregroundStyle(.secondary)
            }
            ForEach(model.state.entries, id: \.id) { entry in
                LabeledContent(entry.drinkName) {
                    Text(grams(entry.gramsAlcohol)).monospacedDigit()
                }
            }
            .onDelete { offsets in
                let doomed = offsets.map { model.state.entries[$0] }
                Task { for entry in doomed { await model.deleteEntry(entry) } }
            }
        }
    }

    // ── Formatting ───────────────────────────────────────────────────────────

    /// Grams, one decimal. A `NumberFormatter` and its locale arrive with the
    /// String Catalogs; this is display text, not the export's fixed format.
    private func grams(_ value: Double) -> String {
        String(format: "%.1f g", value)
    }
}

// =============================================================================
// LimitBar – a labelled progress bar
// =============================================================================
//
// Layout and colour. Both the fill and the emphasis are decided by `LimitGauge`
// in the kit, where they are tested: the fill is clamped so the bar cannot
// overflow its track, while the emphasis comes from the unclamped value so a
// 130 % day still reads as red.
// =============================================================================

struct LimitBar: View {
    let caption: String
    let value: String
    let limit: String
    let fill: Double
    let emphasis: Emphasis

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(caption)
                Spacer(minLength: 8)
                Text("\(value) / \(limit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    // The label may be long once translated; let it shrink rather
                    // than wrap into the caption, the defect the Android layout
                    // hardening fixed for Greek and Russian.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.subheadline)

            ProgressView(value: fill)
                .tint(emphasis.tint)
                // The bar is decoration; the numbers above already say it.
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }
}

extension Emphasis {
    /// The colour band. `.accentColor` follows the app tint, so a calm bar is
    /// calm in both light and dark mode without a hand-picked hex value.
    var tint: Color {
        switch self {
        case .calm: return .accentColor
        case .warning: return .orange
        case .danger: return .red
        }
    }
}
