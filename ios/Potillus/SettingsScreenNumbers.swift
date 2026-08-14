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
// SettingsScreen - typing a numeric setting
// =============================================================================
//
// Split from SettingsScreen.swift the way the Statistics section was: the file
// outgrew SwiftLint's `file_length`, and the four numeric rows - the two gram
// limits, the drinking-day count and the body weight - are a seam that stands on
// its own. They share one enum, one row builder and one field, because they
// differ only in title, range and decimal count.
// =============================================================================

extension SettingsScreen {

    /// The four numeric settings a user can type instead of stepping to.
    ///
    /// Internal rather than private, as are `numberRow` and `commitNumber`: the
    /// rows and the field that use them sit in `SettingsScreen.swift`, and
    /// Swift's `private` reaches only the same file. `value(of:)` stays private
    /// — it is called from this file alone.
    ///
    /// One enum rather than four flags and four drafts: the alert takes a title,
    /// a range and a decimal count, and those are all this differs in. `weightKg`
    /// is the only one with a fractional part, and the only one whose zero means
    /// "not set" — but the field is offered only while a weight EXISTS, so the
    /// sentinel never reaches this code.
    enum NumericSetting: String, Identifiable {
        case dailyLimit, weeklyLimit, drinkDays, bodyWeight

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .dailyLimit: return "Daily Limit in Grams"
            case .weeklyLimit: return "7-Day Limit in Grams"
            case .drinkDays: return "Max. Drinking Days/7 Days"
            case .bodyWeight: return "Body Weight"
            }
        }

        /// What a screen reader says instead of [titleKey], where the two differ.
        ///
        /// "Max. Drinking Days/7 Days" is read as an abbreviation and a slash. The
        /// row keeps it — spelled out it does not fit beside its value — and the
        /// spoken form writes it out. Android carries the same pair.
        var spokenTitleKey: String {
            self == .drinkDays ? "Maximum drinking days per seven days" : titleKey
        }

        /// The unit shown beside the value, or none where the value counts days.
        var unit: String {
            switch self {
            case .dailyLimit, .weeklyLimit: return "g"
            case .drinkDays: return ""
            case .bodyWeight: return "kg"
            }
        }

        var fractionDigits: Int { self == .bodyWeight ? 1 : 0 }

        /// The same bounds the sanitiser applies to an imported file, so typing a
        /// value and importing one cannot disagree about what is allowed.
        var range: ClosedRange<Double> {
            switch self {
            case .dailyLimit: return SettingsSanitizer.dailyLimitRange
            case .weeklyLimit: return SettingsSanitizer.weeklyLimitRange
            case .drinkDays:
                // On one statement: a `return` followed by a line break ends the
                // statement, so the `...` on the next line was parsed as an
                // expression of its own and the range never formed.
                let days = SettingsSanitizer.drinkDaysRange
                return Double(days.lowerBound)...Double(days.upperBound)
            case .bodyWeight: return SettingsSanitizer.weightRange
            }
        }
    }

    /// The label of a stepper row, with its value as a button that opens the field.
    ///
    /// `.buttonStyle(.plain)` because a tinted value in a settings row reads as a
    /// link; the affordance here is the tap, not the colour.
    func numberRow(_ setting: NumericSetting) -> some View {
        LabeledContent(Loc.string(setting.titleKey, locale: locale)) {
            Button {
                numberDraft = Loc.number(
                    value(of: setting), fractionDigits: setting.fractionDigits, locale: locale
                )
                editingNumber = setting
            } label: {
                Text(measure(
                    value(of: setting), fractionDigits: setting.fractionDigits, unit: setting.unit
                ))
                .monospacedDigit()
            }
            .buttonStyle(.plain)
        }
        // The label alone, spelled out where the visible one abbreviates. The
        // value keeps its own element, so the button stays reachable and its
        // number is announced as the row's value.
        .accessibilityLabel(Loc.string(setting.spokenTitleKey, locale: locale))
    }

    private func value(of setting: NumericSetting) -> Double {
        switch setting {
        case .dailyLimit: return model.settings.dailyLimitGrams
        case .weeklyLimit: return model.settings.weeklyLimitGrams
        case .drinkDays: return Double(model.settings.maxDrinkDaysPerWeek)
        case .bodyWeight: return model.settings.weightKg
        }
    }

    /// Reads the typed number and writes it, clamped to the setting's range.
    ///
    /// A draft that is not a number leaves the setting alone — the keypad offers
    /// digits, but a paste can still put anything in the field. Parsing goes
    /// through the in-app locale, so a comma-decimal language reads "1.500" as
    /// fifteen hundred rather than as one and a half. The day count rounds to a
    /// whole number; the others keep what the range allows.
    func commitNumber(_ setting: NumericSetting) {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        guard let typed = formatter.number(from: numberDraft)?.doubleValue else { return }
        let range = setting.range
        let clamped = min(max(typed, range.lowerBound), range.upperBound)
        Task {
            await model.update { settings in
                switch setting {
                case .dailyLimit: settings.dailyLimitGrams = clamped.rounded()
                case .weeklyLimit: settings.weeklyLimitGrams = clamped.rounded()
                case .drinkDays: settings.maxDrinkDaysPerWeek = Int(clamped.rounded())
                case .bodyWeight: settings.weightKg = clamped
                }
            }
        }
    }
}
