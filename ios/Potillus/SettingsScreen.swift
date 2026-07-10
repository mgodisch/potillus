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
import UniformTypeIdentifiers

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

    private let environment: AppEnvironment

    // ── Backup state ─────────────────────────────────────────────────────────

    @State private var exportedDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var includeSettingsInExport = true

    /// Set while the user chooses between replacing and merging.
    @State private var pendingImport: URL?

    /// The outcome of the last import, shown once and dismissed.
    @State private var importSummary: String?
    @State private var backupFailure: String?

    init(environment: AppEnvironment) {
        self.environment = environment
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
                backupSection
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
            .fileExporter(
                isPresented: $isExporting,
                document: exportedDocument,
                contentType: .json,
                defaultFilename: BackupExporter.suggestedFileName()
            ) { result in
                if case .failure(let error) = result {
                    backupFailure = String(describing: error)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url): pendingImport = url
                case .failure(let error): backupFailure = String(describing: error)
                }
            }
            // The choice is destructive one way and not the other, so it is made
            // explicitly, after the file is chosen and before anything is written.
            .confirmationDialog(
                "Import backup",
                isPresented: .constant(pendingImport != nil),
                presenting: pendingImport
            ) { url in
                Button("Merge with my data") { runImport(url, mode: .merge) }
                Button("Replace my data", role: .destructive) { runImport(url, mode: .replace) }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: { _ in
                Text("Replacing deletes your log and the drinks you created. Presets are kept.")
            }
            .alert(
                "Import finished",
                isPresented: .constant(importSummary != nil),
                presenting: importSummary
            ) { _ in
                Button("OK", role: .cancel) { importSummary = nil }
            } message: { summary in
                Text(summary)
            }
            .alert(
                "Backup failed",
                isPresented: .constant(backupFailure != nil),
                presenting: backupFailure
            ) { _ in
                Button("OK", role: .cancel) { backupFailure = nil }
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

// =============================================================================
// Backup section
// =============================================================================

extension SettingsScreen {

    var backupSection: some View {
        Section {
            Toggle("Include settings", isOn: $includeSettingsInExport)

            Button("Export backup") {
                Task { await prepareExport() }
            }
            Button("Import backup") {
                isImporting = true
            }
        } header: {
            Text("Backup")
        } footer: {
            // The one sentence that makes the feature trustworthy, and true.
            Text(
                includeSettingsInExport
                    ? "A JSON file containing your drinks, your log, and your settings — including your body weight. It never leaves this device unless you send it somewhere."
                    : "A JSON file containing your drinks and your log. Your settings, including your body weight, are left out."
            )
        }
    }

    /// Builds the file, then hands it to the system's document browser.
    ///
    /// Assembling before presenting means a failure surfaces as an alert, rather
    /// than as an empty file the user has already saved somewhere.
    private func prepareExport() async {
        do {
            let exporter = BackupExporter(
                drinks: environment.drinks,
                entries: environment.entries,
                preferences: environment.preferences
            )
            exportedDocument = BackupDocument(
                data: try await exporter.makeBackup(includeSettings: includeSettingsInExport)
            )
            isExporting = true
        } catch {
            backupFailure = String(describing: error)
        }
    }

    /// Reads the chosen file and restores it.
    ///
    /// The URL comes from outside the sandbox, so it must be opened inside a
    /// security-scoped access. Forgetting `startAccessingSecurityScopedResource`
    /// is the classic way an import works in the simulator and fails on a device.
    private func runImport(_ url: URL, mode: ImportMode) {
        pendingImport = nil

        Task {
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                let data = try Data(contentsOf: url)
                let file = try BackupReader.parse(data)
                let stats = try await environment.importer.restore(file, mode: mode)

                importSummary = stats.skipped > 0
                    ? "Imported \(stats.imported) entries, skipped \(stats.skipped) already present."
                    : "Imported \(stats.imported) entries."
            } catch {
                backupFailure = String(describing: error)
            }
        }
    }
}
