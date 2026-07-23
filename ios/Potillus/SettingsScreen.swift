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

    @Environment(\.appLocale) private var locale

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
    /// Mirrors the database file's `isExcludedFromBackup` attribute. Not an
    /// AppSettings field: the attribute on the file is the single source of truth,
    /// so this is loaded from it on appear and written straight back on change.
    @State private var includeInDeviceBackup = false
    @State private var backupFailure: String?

    /// Asked when the lock toggle is drawn, to decide whether it may be armed.
    /// Stateless, so the screen owns one rather than receiving the whole lock model.
    private let biometrics = DeviceBiometricAuthenticator()

    /// Drives the App-lock switch. Kept separate from the stored preference so a
    /// flip can be gated behind a prompt: the switch moves at once, the preference
    /// only after the device owner authenticates, and this snaps back if they don't.
    @State private var appLockArmed = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: SettingsModel(preferences: environment.preferences))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section order mirrors Android: Personal · Limits · Statistics
                // (which now carries the day-change time, as on Android) · Backup ·
                // Security · Appearance. iOS previously led with Limits and kept
                // the day-change and body-weight in their own sections; the
                // 0.83.0 UI-parity pass aligns the grouping and order so a
                // platform switcher finds each setting in the same place.
                personalDataSection
                limitsSection
                statisticsSection
                backupSection
                securitySection
                appearanceSection
            }
            .navigationTitle(Loc.string("Settings", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Loc.string("Done", locale: locale)) { dismiss() }
                }
            }
            .task { model.start() }
            .onDisappear { model.stop() }
            .alert(
                Loc.string("Could not save", locale: locale),
                isPresented: .constant(model.failure != nil),
                presenting: model.failure
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) { model.clearFailure() }
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
                    backupFailure = describeBackupFailure(error)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url): pendingImport = url
                case .failure(let error): backupFailure = describeBackupFailure(error)
                }
            }
            // The choice is destructive one way and not the other, so it is made
            // explicitly, after the file is chosen and before anything is written.
            .confirmationDialog(
                Loc.string("Import", locale: locale),
                isPresented: .constant(pendingImport != nil),
                presenting: pendingImport
            ) { url in
                Button(Loc.string("Merge", locale: locale)) { runImport(url, mode: .merge) }
                Button(Loc.string("Replace", locale: locale), role: .destructive) {
                    runImport(url, mode: .replace)
                }
                Button(Loc.string("Cancel", locale: locale), role: .cancel) { pendingImport = nil }
            } message: { _ in
                Text(Loc.string(
                    "Replacing deletes your log and the drinks you created. Presets are kept.",
                    locale: locale
                ))
            }
            .alert(
                Loc.string("Import finished", locale: locale),
                isPresented: .constant(importSummary != nil),
                presenting: importSummary
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) { importSummary = nil }
            } message: { summary in
                Text(summary)
            }
            .alert(
                Loc.string("Backup failed.", locale: locale),
                isPresented: .constant(backupFailure != nil),
                presenting: backupFailure
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) { backupFailure = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Limits ───────────────────────────────────────────────────────────────

    private var limitsSection: some View {
        Section(Loc.string("Limits", locale: locale)) {
            Stepper(
                value: bind(\.dailyLimitGrams, set: { $0.dailyLimitGrams = $1 }),
                in: SettingsSanitizer.dailyLimitRange, step: 1
            ) {
                LabeledContent(Loc.string("Daily Limit in Grams", locale: locale)) {
                    Text(measure(model.settings.dailyLimitGrams, fractionDigits: 0, unit: "g")).monospacedDigit()
                }
            }
            Stepper(
                value: bind(\.weeklyLimitGrams, set: { $0.weeklyLimitGrams = $1 }),
                in: SettingsSanitizer.weeklyLimitRange, step: 5
            ) {
                LabeledContent(Loc.string("7-Day Limit in Grams", locale: locale)) {
                    Text(measure(model.settings.weeklyLimitGrams, fractionDigits: 0, unit: "g")).monospacedDigit()
                }
            }
            Stepper(
                value: bind(\.maxDrinkDaysPerWeek, set: { $0.maxDrinkDaysPerWeek = $1 }),
                in: SettingsSanitizer.drinkDaysRange
            ) {
                LabeledContent(Loc.string("Max. Drinking Days/7 Days", locale: locale)) {
                    Text("\(model.settings.maxDrinkDaysPerWeek)").monospacedDigit()
                }
            }
        }
    }

    // ── The logical day ──────────────────────────────────────────────────────
    // The day-change time now lives inside the Statistics section (below),
    // matching Android, where it is the first row of that section.

    /// The stored hour and minute, as a `Date` the picker can edit. Only the time
    /// components are read back, so the date part is irrelevant.
    private var dayChangeDate: Date {
        var components = DateComponents()
        components.hour = model.settings.dayChangeHour
        components.minute = model.settings.dayChangeMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    // ── Body weight ──────────────────────────────────────────────────────────

    private var personalDataSection: some View {
        Section {
            if model.hasWeight {
                Stepper(
                    value: bind(\.weightKg, set: { $0.weightKg = $1 }),
                    in: SettingsSanitizer.weightRange, step: 0.5
                ) {
                    LabeledContent(Loc.string("Body Weight", locale: locale)) {
                        Text(measure(model.settings.weightKg, fractionDigits: 1, unit: "kg")).monospacedDigit()
                    }
                }
                Button(Loc.string("Clear body weight", locale: locale), role: .destructive) {
                    Task { await model.clearWeight() }
                }
            } else {
                // Absence is offered as absence, not as 0.0 kg in a stepper.
                Button(Loc.string("Set body weight", locale: locale)) {
                    Task { await model.update { $0.weightKg = 75.0 } }
                }
            }
        } header: {
            Text(Loc.string("Personal Data", locale: locale))
        } footer: {
            // Through Loc, like every user-facing string: the bare ternary of
            // literals this used to be bypassed the in-app language entirely and
            // had no catalogue keys, so the privacy sentence — of all sentences —
            // read English in every non-English language (0.84.0 QA round).
            Text(Loc.string(
                model.hasWeight
                    ? "Used only to estimate blood alcohol. It never leaves this device."
                    : "Without a body weight, no blood-alcohol estimate is shown.",
                locale: locale
            ))
        }
    }

    // ── Statistics floor ─────────────────────────────────────────────────────

    private var statisticsSection: some View {
        Section {
            // The day-change time — Android's first Statistics row. An inline
            // hour/minute picker, iOS-idiomatic (Android opens a dialog).
            DatePicker(
                Loc.string("New Day Starts At", locale: locale),
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

            // The statistics-start date is ALWAYS editable, matching Android's
            // always-present date row. iOS previously showed it as read-only text
            // with an "include all history" button, and once history was included
            // there was no way to pick a date again (0.83.0 bug). The picker is
            // always shown; when no floor is set it seeds from today, and picking
            // a date sets the floor. A clear button removes the floor without
            // hiding the control.
            DatePicker(
                Loc.string("Statistics From", locale: locale),
                selection: Binding(
                    get: { Self.day(from: model.settings.statsFromDate) ?? Date() },
                    set: { newValue in
                        Task { await model.update { $0.statsFromDate = Self.isoDay(from: newValue) } }
                    }
                ),
                displayedComponents: .date
            )
            if model.hasStatsFloor {
                Button(Loc.string("Include all history", locale: locale), role: .destructive) {
                    Task { await model.clearStatsFromDate() }
                }
            }
        } header: {
            Text(Loc.string("Statistics", locale: locale))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                // The day-change footnote (kept from the old day-change section).
                Text(Loc.string("A drink logged before this time counts towards the previous day.", locale: locale))
                Text(Loc.string("Entries before this date are ignored in all statistics.", locale: locale))
            }
        }
    }

    // ── Appearance ───────────────────────────────────────────────────────────

    private var appearanceSection: some View {
        Section(Loc.string("Appearance", locale: locale)) {
            Picker(
                Loc.string("Color Scheme", locale: locale),
                selection: bind(\.themeMode, set: { $0.themeMode = $1 })
            ) {
                Text(Loc.string("System", locale: locale)).tag(ThemeMode.system)
                Text(Loc.string("Light", locale: locale)).tag(ThemeMode.day)
                Text(Loc.string("Dark", locale: locale)).tag(ThemeMode.night)
            }
            Toggle(
                Loc.string("Alternative Status Symbols", locale: locale),
                isOn: bind(\.alternativeStatusSymbols, set: { $0.alternativeStatusSymbols = $1 })
            )
            Picker(Loc.string("Language", locale: locale), selection: bind(\.language, set: { $0.language = $1 })) {
                // The empty tag means "follow the system language" — the app
                // default. Offered first as "(System)" so a user can return to it
                // after choosing a fixed language (0.83.0: previously the picker
                // listed only the fixed languages, with no way back to system).
                Text(Loc.string("(System)", locale: locale)).tag("")
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

    /// Prompt, then commit the App-lock change — or snap the switch back.
    ///
    /// Required for BOTH arming and disarming, so neither turning the lock on nor
    /// off happens without the device owner present; Android gates its switch the
    /// same way (`authenticateForToggle`). On success the preference is written
    /// through the model like any other setting; on cancel or failure nothing is
    /// written, and re-reading the unchanged stored value returns the switch to
    /// where it was.
    @MainActor
    private func confirmAppLock(desired: Bool) async {
        if await biometrics.evaluate(reason: Loc.string("Please authenticate", locale: locale)) {
            await model.update { $0.biometricEnabled = desired }
        } else {
            appLockArmed = model.settings.biometricEnabled
        }
    }
}

// =============================================================================
// SettingsScreen – statistics-start date conversion
// =============================================================================
//
// The statistics-start floor is stored as an ISO `yyyy-MM-dd` string; these
// convert to and from the `Date` the picker edits. In an extension so they do
// not count against the type's length budget (SwiftLint `type_body_length`).
// A fixed POSIX formatter, not a locale-formatted one, so the stored value
// round-trips regardless of the display locale. Both are `nonisolated`: they
// touch no main-actor state (only a local formatter), and `isoDay(from:)` is
// called from the settings-mutation closure, which runs off the main actor.
// =============================================================================

extension SettingsScreen {
    nonisolated fileprivate static func isoDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Parses an ISO `yyyy-MM-dd` back to a `Date`, or `nil` when empty/invalid.
    nonisolated fileprivate static func day(from iso: String) -> Date? {
        guard !iso.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }
}

// =============================================================================
// Backup section
// =============================================================================

extension SettingsScreen {

    /// A measured value in the in-app locale plus its unit, e.g. "140 g" / "80,0 kg"
    /// — kept here in the extension so the row call sites stay short and the main
    /// type body stays within SwiftLint's `type_body_length`.
    private func measure(_ value: Double, fractionDigits: Int, unit: String) -> String {
        "\(Loc.number(value, fractionDigits: fractionDigits, locale: locale)) \(unit)"
    }

    private var securitySection: some View {
        Section {
            if biometrics.canEvaluate() {
                Toggle(
                    Loc.string("Biometric Lock", locale: locale),
                    isOn: $appLockArmed
                )
                .onChange(of: appLockArmed) { _, desired in
                    // A programmatic sync (below) always leaves `desired` equal to
                    // the stored value; only a real finger on the switch differs
                    // from it, and only that asks for a prompt.
                    guard desired != model.settings.biometricEnabled else { return }
                    Task { await confirmAppLock(desired: desired) }
                }
                .onChange(of: model.settings.biometricEnabled) { _, stored in
                    // Keep the switch in step with the stored value: the async
                    // initial load and the snap-back after a cancelled prompt both
                    // arrive here.
                    if appLockArmed != stored { appLockArmed = stored }
                }
                .onAppear { appLockArmed = model.settings.biometricEnabled }
            } else {
                // No biometrics enrolled and no passcode set. Offering the toggle
                // would arm a lock the device cannot open, locking the diary away
                // for good. Android runs the same check before showing its switch.
                Text(Loc.string("App lock needs Face ID, Touch ID, or a device passcode.", locale: locale))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                Loc.string("Show in app switcher", locale: locale),
                isOn: bind(\.allowScreenshots, set: { $0.allowScreenshots = $1 })
            )

            // The consumption log is kept out of the device backup by default
            // (Android's allowBackup="false" equivalent). This lets a user opt back
            // in, so a new phone restored from backup keeps the diary. The choice is
            // stored as a preference and re-applied each launch; see BackupExclusion.
            Toggle(Loc.string("Include in device backup", locale: locale), isOn: $includeInDeviceBackup)
                .onChange(of: includeInDeviceBackup) { _, include in
                    if let path = environment.database.path {
                        try? BackupExclusion.setIncludesInBackup(include, databasePath: path)
                    }
                }
        } header: {
            Text(Loc.string("Security", locale: locale))
        } footer: {
            // Two footers would be tidier but a Section takes one. All switches are
            // explained here, in the order they appear.
            Text(
                """
                When app lock is on, Libellus Potionis asks to unlock after 30 \
                seconds in the background. When "Show in app switcher" is off, the \
                app's preview is hidden while it is in the background. When "Include \
                in device backup" is off, your consumption log is kept out of every \
                device backup — both iCloud and a computer backup — so it never \
                leaves the device; the JSON backup remains the way to move data to a \
                new device.
                """
            )
        }
        .task {
            includeInDeviceBackup = BackupExclusion.includesInBackup()
        }
    }

    var backupSection: some View {
        Section {
            Toggle(Loc.string("Include settings", locale: locale), isOn: $includeSettingsInExport)

            Button(Loc.string("Export", locale: locale)) {
                Task { await prepareExport() }
            }
            Button(Loc.string("Import", locale: locale)) {
                isImporting = true
            }
        } header: {
            Text(Loc.string("Backup", locale: locale))
        } footer: {
            // The one sentence that makes the feature trustworthy, and true —
            // and, since the 0.84.0 QA round, in the user's language: the
            // concatenated literals this used to be were plain `String`s, so
            // they bypassed the in-app language AND had no catalogue keys.
            Text(Loc.string(
                includeSettingsInExport
                    ? "A JSON file containing your drinks, your log, and your settings"
                        + " — including your body weight. It never leaves this device"
                        + " unless you send it somewhere."
                    : "A JSON file containing your drinks and your log. Your settings,"
                        + " including your body weight, are left out.",
                locale: locale
            ))
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
            backupFailure = describeBackupFailure(error)
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

                // A bounded read, not `Data(contentsOf:)`: an over-sized file is
                // refused before it is loaded, so a hostile pick cannot exhaust
                // memory. See `BackupReader.readData`.
                let data = try BackupReader.readData(from: url)
                let file = try BackupReader.parse(data)
                let stats = try await environment.importer.restore(file, mode: mode)

                // Both messages are plurals (see the catalogue): the noun agrees
                // with the count in every language. The merge form's FIRST count
                // drives the plural; the replace form has one count.
                importSummary = stats.skipped > 0
                    ? Loc.importedMergedPlural(
                        imported: stats.imported, skipped: stats.skipped, locale: locale
                    )
                    : Loc.importedPlural(count: stats.imported, locale: locale)
            } catch {
                backupFailure = describeBackupFailure(error)
            }
        }
    }

    /// The user-facing text for a failed backup export or import.
    ///
    /// Android maps every import failure onto a localized resource
    /// (`SettingsViewModel`'s `import_error_*` strings); this view used to show
    /// `String(describing: error)` instead, which put raw English — or a raw
    /// Swift error dump — into the alert in all twenty non-English languages
    /// (0.83.0 QA round). The mapping mirrors Android's keys:
    ///
    ///   - the four failures a user can act on (empty file, broken JSON, a
    ///     newer format, an oversized file) get their own sentence;
    ///   - every structural reader error (a missing field, an out-of-range
    ///     value, a malformed date, an entry pointing at an undefined drink)
    ///     folds into the generic "Read error: %@" with the typed description
    ///     as the detail — exactly how Android folds its parse failures into
    ///     `import_error_read`. The detail stays technical BY DESIGN: it names
    ///     the offending field for a bug report, as the kit's error strings do.
    ///   - anything else (a system file error from the pickers or the export
    ///     path) takes the same generic form; Android reuses that string for
    ///     its export failures too.
    private func describeBackupFailure(_ error: Error) -> String {
        switch error {
        case BackupError.fileEmpty:
            return Loc.string("Backup file is empty.", locale: locale)
        case BackupError.invalidJSON:
            return Loc.string("Invalid JSON format.", locale: locale)
        case let BackupError.versionTooHigh(found, max):
            return Loc.string(
                "Backup version %1$lld is not supported (max. %2$lld).",
                found, max, locale: locale
            )
        case let BackupError.fileTooLarge(_, maxBytes):
            // Bytes → whole mebibytes, the unit Android's message uses.
            return Loc.string(
                "Backup file too large (max. %lld MB).",
                maxBytes / 1_024 / 1_024, locale: locale
            )
        default:
            return Loc.string("Read error: %@", String(describing: error), locale: locale)
        }
    }
}
