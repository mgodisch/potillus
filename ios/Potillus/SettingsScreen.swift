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
// SettingsScreen.swift – the user's own numbers
// =============================================================================
//
// Every control's bounds come from `SettingsSanitizer`, never from a literal.
// A `Stepper` that offered 1…600 while the sanitiser clamps at 500 would let the
// user set a value the app silently discards — precisely the divergence that made
// Android's Save button lie until v0.81.0.
//
// TWO SWITCHES ARE MISSING ON PURPOSE
//   `biometricEnabled` and `allowScreenshots` are stored and ported, but nothing
//   reads them yet. A switch that promises a lock which does not exist is worse
//   than no switch. They appear with LocalAuthentication.
// =============================================================================

struct SettingsScreen: View {

    @State private var model: SettingsModel
    @Environment(\.dismiss) private var dismiss

    init(environment: AppEnvironment) {
        _model = State(initialValue: SettingsModel(preferences: environment.preferences))
    }

    var body: some View {
        NavigationStack {
            Form {
                limitsSection
                dayChangeSection
                bodyWeightSection
                statisticsSection
                appearanceSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { model.start() }
            .onDisappear { model.stop() }
            .alert(
                "Could not save",
                isPresented: .constant(model.failure != nil),
                presenting: model.failure
            ) { _ in
                Button("OK", role: .cancel) { model.clearFailure() }
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Limits ───────────────────────────────────────────────────────────────

    private var limitsSection: some View {
        Section("Limits") {
            Stepper(value: bind(\.dailyLimitGrams), in: SettingsSanitizer.dailyLimitRange, step: 1) {
                LabeledContent("Daily limit") {
                    Text(String(format: "%.0f g", model.settings.dailyLimitGrams)).monospacedDigit()
                }
            }
            Stepper(value: bind(\.weeklyLimitGrams), in: SettingsSanitizer.weeklyLimitRange, step: 5) {
                LabeledContent("Weekly limit") {
                    Text(String(format: "%.0f g", model.settings.weeklyLimitGrams)).monospacedDigit()
                }
            }
            Stepper(value: bind(\.maxDrinkDaysPerWeek), in: SettingsSanitizer.drinkDaysRange) {
                LabeledContent("Drink days per week") {
                    Text("\(model.settings.maxDrinkDaysPerWeek)").monospacedDigit()
                }
            }
        }
    }

    // ── The logical day ──────────────────────────────────────────────────────

    private var dayChangeSection: some View {
        Section {
            DatePicker(
                "Day starts at",
                selection: Binding(
                    get: { dayChangeDate },
                    set: { newValue in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        Task {
                            await model.update {
                                $0.dayChangeHour = parts.hour ?? 4
                                $0.dayChangeMinute = parts.minute ?? 0
                            }
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text("Day change")
        } footer: {
            // The single most confusing setting in the app, if unexplained.
            Text("A drink logged before this time counts towards the previous day.")
        }
    }

    /// The stored hour and minute, as a `Date` the picker can edit. Only the time
    /// components are read back, so the date part is irrelevant.
    private var dayChangeDate: Date {
        var components = DateComponents()
        components.hour = model.settings.dayChangeHour
        components.minute = model.settings.dayChangeMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    // ── Body weight ──────────────────────────────────────────────────────────

    private var bodyWeightSection: some View {
        Section {
            if model.hasWeight {
                Stepper(value: bind(\.weightKg), in: SettingsSanitizer.weightRange, step: 0.5) {
                    LabeledContent("Body weight") {
                        Text(String(format: "%.1f kg", model.settings.weightKg)).monospacedDigit()
                    }
                }
                Button("Clear body weight", role: .destructive) {
                    Task { await model.clearWeight() }
                }
            } else {
                // Absence is offered as absence, not as 0.0 kg in a stepper.
                Button("Set body weight") {
                    Task { await model.update { $0.weightKg = 75.0 } }
                }
            }
        } header: {
            Text("Personal data")
        } footer: {
            Text(
                model.hasWeight
                    ? "Used only to estimate blood alcohol. It never leaves this device."
                    : "Without a body weight, no blood-alcohol estimate is shown."
            )
        }
    }

    // ── Statistics floor ─────────────────────────────────────────────────────

    private var statisticsSection: some View {
        Section {
            if model.hasStatsFloor {
                LabeledContent("Statistics start", value: model.settings.statsFromDate)
                Button("Include all history", role: .destructive) {
                    Task { await model.clearStatsFromDate() }
                }
            } else {
                Text("Statistics cover the whole history.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Statistics")
        } footer: {
            Text("Days before this date are ignored in statistics. Entries are not deleted.")
        }
    }

    // ── Appearance ───────────────────────────────────────────────────────────

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: bind(\.themeMode)) {
                Text("System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.day)
                Text("Dark").tag(ThemeMode.night)
            }
            Toggle("Alternative status symbols", isOn: bind(\.alternativeStatusSymbols))
            Picker("Language", selection: bind(\.language)) {
                // The autonym: a language picker shows "Deutsch", not "German".
                // Someone who needs the list cannot necessarily read the current
                // interface language.
                ForEach(SupportedLocales.all, id: \.tag) { locale in
                    Text(locale.autonym).tag(locale.tag)
                }
            }
        }
    }

    // ── Binding ──────────────────────────────────────────────────────────────

    /// A binding that writes through the model, so every edit is sanitised.
    ///
    /// Writing straight to `model.settings` would bypass the sanitiser and the
    /// store; this is the only way a control changes anything.
    private func bind<Value>(
        _ keyPath: WritableKeyPath<AppSettings, Value>
    ) -> Binding<Value> where Value: Sendable {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                Task { await model.update { $0[keyPath: keyPath] = newValue } }
            }
        )
    }
}
