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
// BOTH SECURITY SWITCHES ARE NOW WIRED
//   `biometricEnabled` gates the app behind Face ID / Touch ID / passcode; its
//   toggle refuses to arm on a device that can satisfy none of those, which would
//   lock the owner out permanently. `allowScreenshots` controls the app-switcher
//   privacy cover — NOT active screenshots, which iOS has no clean way to block
//   (see PrivacyCover.swift). The toggle's wording says what it actually does on
//   this platform rather than promising Android's FLAG_SECURE behaviour.
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

    /// Asked when the lock toggle is drawn, to decide whether it may be armed.
    /// Stateless, so the screen owns one rather than receiving the whole lock model.
    private let biometrics = DeviceBiometricAuthenticator()

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
                securitySection
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
            Stepper(
                value: bind(\.dailyLimitGrams, set: { $0.dailyLimitGrams = $1 }),
                in: SettingsSanitizer.dailyLimitRange, step: 1
            ) {
                LabeledContent("Daily limit") {
                    Text(String(format: "%.0f g", model.settings.dailyLimitGrams)).monospacedDigit()
                }
            }
            Stepper(
                value: bind(\.weeklyLimitGrams, set: { $0.weeklyLimitGrams = $1 }),
                in: SettingsSanitizer.weeklyLimitRange, step: 5
            ) {
                LabeledContent("Weekly limit") {
                    Text(String(format: "%.0f g", model.settings.weeklyLimitGrams)).monospacedDigit()
                }
            }
            Stepper(
                value: bind(\.maxDrinkDaysPerWeek, set: { $0.maxDrinkDaysPerWeek = $1 }),
                in: SettingsSanitizer.drinkDaysRange
            ) {
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
                Stepper(
                    value: bind(\.weightKg, set: { $0.weightKg = $1 }),
                    in: SettingsSanitizer.weightRange, step: 0.5
                ) {
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
            Picker("Theme", selection: bind(\.themeMode, set: { $0.themeMode = $1 })) {
                Text("System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.day)
                Text("Dark").tag(ThemeMode.night)
            }
            Toggle(
                "Alternative status symbols",
                isOn: bind(\.alternativeStatusSymbols, set: { $0.alternativeStatusSymbols = $1 })
            )
            Picker("Language", selection: bind(\.language, set: { $0.language = $1 })) {
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
    ///
    /// WHY THE WRITE IS A CLOSURE AND NOT A `WritableKeyPath`.
    ///   `SettingsModel.update` takes a `@Sendable` transform, because the change
    ///   travels from the main actor into the store's. A key path handed to that
    ///   transform is CAPTURED by it, and a `WritableKeyPath<AppSettings, Value>`
    ///   is not `Sendable` — the compiler said so, and under Swift 6 it will refuse
    ///   rather than warn.
    ///
    ///   Passing the write as a closure LITERAL at each call site captures nothing
    ///   at all, so the transform is trivially sendable. The read still uses a key
    ///   path: it runs on the main actor and never crosses.
    ///
    ///   The cost is one repeated property name per control. The alternative was to
    ///   wrap the key path in an unchecked-sendable box, which would silence the
    ///   compiler by asserting something no-one had checked.
    private func bind<Value>(
        _ keyPath: KeyPath<AppSettings, Value>,
        set write: @escaping @Sendable (inout AppSettings, Value) -> Void
    ) -> Binding<Value> where Value: Sendable {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                Task { await model.update { write(&$0, newValue) } }
            }
        )
    }
}

// =============================================================================
// Backup section
// =============================================================================

extension SettingsScreen {

    private var securitySection: some View {
        Section {
            if biometrics.canEvaluate() {
                Toggle(
                    "App lock",
                    isOn: bind(\.biometricEnabled, set: { $0.biometricEnabled = $1 })
                )
            } else {
                // No biometrics enrolled and no passcode set. Offering the toggle
                // would arm a lock the device cannot open, locking the diary away
                // for good. Android runs the same check before showing its switch.
                Text("App lock needs Face ID, Touch ID, or a device passcode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Show in app switcher",
                isOn: bind(\.allowScreenshots, set: { $0.allowScreenshots = $1 })
            )
        } header: {
            Text("Security")
        } footer: {
            // Two footers would be tidier but a Section takes one. Both switches are
            // explained here, in the order they appear.
            Text(
                """
                When app lock is on, Libellus Potionis asks to unlock after 30 \
                seconds in the background. When "Show in app switcher" is off, the \
                app's preview is hidden while it is in the background.
                """
            )
        }
    }

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
                    ? "A JSON file containing your drinks, your log, and your settings"
                        + " — including your body weight. It never leaves this device"
                        + " unless you send it somewhere."
                    : "A JSON file containing your drinks and your log. Your settings,"
                        + " including your body weight, are left out."
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
