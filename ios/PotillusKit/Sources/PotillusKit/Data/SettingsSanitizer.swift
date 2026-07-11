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

import Foundation

// =============================================================================
// SettingsSanitizer.swift – turning a backup's settings into trustworthy ones
// =============================================================================
//
// A faithful Swift port of the clamping in Android's
// `BackupManager.parseSettings`.
//
// WHY CLAMP AT ALL
//   A backup file is plain JSON in the user's Files app. It can be hand-edited,
//   truncated, or written by a newer version of the app. Its numbers then flow
//   straight into the alcohol maths: a `weeklyLimitGrams` of 1e9 makes every
//   limit unreachable, a `dayChangeHour` of 25 makes `DayResolver` produce a
//   date that does not exist. Validating at the boundary means every screen
//   downstream can treat `AppSettings` as sound.
//
// TWO RULES THAT LOOK LIKE BUGS AND ARE NOT
//
//   1. `weightKg == 0` is a SENTINEL for "the user has not told us their
//      weight", not a measurement. It must NOT be clamped up to the 1 kg floor;
//      an unset weight would become a one-kilogram body and the Widmark estimate
//      would be absurd. Only a POSITIVE weight is clamped into 1...500.
//
//   2. `statsFromDate` is kept only when it round-trips through the canonical
//      `yyyy-MM-dd` formatter. "2026-1-1" parses in some formatters but is not
//      canonical, and "2026-02-30" does not exist at all. Either would silently
//      mis-bucket every statistic, so both become "" — "from the first entry".
// =============================================================================

public enum SettingsSanitizer {

    // The ranges. Named, because a bare `1...500` in two places is two chances
    // to disagree with Android.
    // PUBLIC, because the settings screen must offer exactly the values this type
    // will accept. A view that carried its own copy of "1...500" would eventually
    // offer a value the sanitizer then silently clamps — the same divergence that
    // let Android's drink dialog and view model disagree until v0.81.0.

    /// Hour of the day the logical day rolls over.
    public static let hourRange = 0...23

    /// Minute of that hour.
    public static let minuteRange = 0...59

    /// Permitted drink days per week.
    public static let drinkDaysRange = 1...7

    /// Grams of pure alcohol per day.
    public static let dailyLimitRange = 1.0...500.0

    /// Grams of pure alcohol per week.
    public static let weeklyLimitRange = 1.0...3500.0

    /// Body weight in kilograms. Note that `0` is the sentinel for "not set" and
    /// is NOT clamped up to this floor; only a positive weight is clamped.
    public static let weightRange = 1.0...500.0

    /// Converts the raw `settings` block of a backup into `AppSettings`, forcing
    /// every value into a range the rest of the app can rely on.
    ///
    /// Anything unusable falls back to the canonical default rather than raising:
    /// a single bad field must not cost the user the whole restore.
    public static func sanitize(_ raw: BackupSettings) -> AppSettings {
        let defaults = AppSettings()

        return AppSettings(
            // An unknown theme (a future "AMOLED", say) decays to `.system`.
            themeMode: ThemeMode.from(stored: raw.themeMode),
            dayChangeHour: clamp(raw.dayChangeHour, to: hourRange),
            dayChangeMinute: clamp(raw.dayChangeMinute, to: minuteRange),
            dailyLimitGrams: clamp(raw.dailyLimitGrams, to: dailyLimitRange, default: defaults.dailyLimitGrams),
            weeklyLimitGrams: clamp(raw.weeklyLimitGrams, to: weeklyLimitRange, default: defaults.weeklyLimitGrams),
            maxDrinkDaysPerWeek: clamp(raw.maxDrinkDaysPerWeek, to: drinkDaysRange),
            statsFromDate: canonicalDate(raw.statsFromDate),
            biometricEnabled: raw.biometricEnabled,
            allowScreenshots: raw.allowScreenshots,
            alternativeStatusSymbols: raw.alternativeStatusSymbols,
            language: SupportedLocales.canonicalTag(raw.language),
            weightKg: sanitizedWeight(raw.weightKg, default: defaults.weightKg)
        )
    }

    /// The same rules applied to a value that is already an `AppSettings`.
    ///
    /// `BackupSettings` is what a FILE contains: strings where the app has enums,
    /// and any number a writer felt like. `AppSettings` is what the app holds. Both
    /// need clamping — a settings screen can hand over an out-of-range number as
    /// easily as a backup can — so both go through the same helpers below. Only
    /// the field list is repeated; not one rule.
    ///
    /// A test asserts that the two overloads agree on every field.
    public static func sanitize(_ raw: AppSettings) -> AppSettings {
        let defaults = AppSettings()

        return AppSettings(
            themeMode: raw.themeMode,
            dayChangeHour: clamp(raw.dayChangeHour, to: hourRange),
            dayChangeMinute: clamp(raw.dayChangeMinute, to: minuteRange),
            dailyLimitGrams: clamp(
                raw.dailyLimitGrams, to: dailyLimitRange, default: defaults.dailyLimitGrams
            ),
            weeklyLimitGrams: clamp(
                raw.weeklyLimitGrams, to: weeklyLimitRange, default: defaults.weeklyLimitGrams
            ),
            maxDrinkDaysPerWeek: clamp(raw.maxDrinkDaysPerWeek, to: drinkDaysRange),
            statsFromDate: canonicalDate(raw.statsFromDate),
            biometricEnabled: raw.biometricEnabled,
            allowScreenshots: raw.allowScreenshots,
            alternativeStatusSymbols: raw.alternativeStatusSymbols,
            language: SupportedLocales.canonicalTag(raw.language),
            weightKg: sanitizedWeight(raw.weightKg, default: defaults.weightKg)
        )
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /// Integers need no fallback: `BackupReader` has already substituted the
    /// default for a missing or wrongly-typed key, so there is always a number.
    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Non-finite doubles cannot come from strict JSON, but they can come from a
    /// future writer or a lenient parser, and `min`/`max` on a NaN silently
    /// propagates it. Reject rather than clamp.
    private static func clamp(
        _ value: Double, to range: ClosedRange<Double>, default fallback: Double
    ) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// See rule 1 in the file header: zero and below mean "unset".
    private static func sanitizedWeight(_ value: Double, default fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        guard value > 0.0 else { return 0.0 }
        return min(max(value, weightRange.lowerBound), weightRange.upperBound)
    }

    /// See rule 2: kept only when it is exactly what the formatter would write.
    private static func canonicalDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        guard let parsed = DayResolver.parseDate(raw),
              DayResolver.formatDate(parsed) == raw
        else { return "" }
        return raw
    }
}
