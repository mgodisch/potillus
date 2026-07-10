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

    /// Owned by the view, rebuilt only when the environment changes.
    @State private var model: TodayModel

    init(environment: AppEnvironment) {
        _model = State(initialValue: TodayModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                if !model.state.favorites.isEmpty { favouritesSection }
                entriesSection
            }
            .navigationTitle("Today")
            .task { await model.load() }
            .refreshable { await model.load() }
            .alert(
                "Something went wrong",
                isPresented: .constant(model.failure != nil),
                presenting: model.failure
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Sections ─────────────────────────────────────────────────────────────

    private var summarySection: some View {
        Section {
            LabeledContent("Today") {
                Text(grams(model.state.totalGrams))
                    .monospacedDigit()
            }
            LabeledContent("Daily limit") {
                Text(grams(model.state.limitInfo.limitGrams))
                    .monospacedDigit()
                    .foregroundStyle(isOverLimit ? .red : .primary)
            }
            LabeledContent("This week") {
                Text(grams(model.state.weeklyTotalGrams))
                    .monospacedDigit()
            }
            LabeledContent("Drink days") {
                Text("\(model.state.drinkDaysThisWeek) / \(model.state.limitInfo.maxDrinkDaysPerWeek)")
                    .monospacedDigit()
            }
            // Absent rather than zero: without a body weight, or with nothing
            // alcoholic logged, the app does not know — and must not imply 0.0.
            if let bac = model.state.bacPermille {
                LabeledContent("Estimated BAC") {
                    Text(String(format: "%.2f ‰", bac)).monospacedDigit()
                }
            }
        }
    }

    private var favouritesSection: some View {
        Section("Favourites") {
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
        Section("Entries") {
            if model.state.entries.isEmpty {
                Text("Nothing logged yet.")
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

    private var isOverLimit: Bool {
        AlcoholCalculator.isOverLimit(
            totalGrams: model.state.totalGrams, limitGrams: model.state.limitInfo.limitGrams
        )
    }

    /// Grams, one decimal. A `NumberFormatter` and its locale arrive with the
    /// String Catalogs; this is display text, not the export's fixed format.
    private func grams(_ value: Double) -> String {
        String(format: "%.1f g", value)
    }
}
