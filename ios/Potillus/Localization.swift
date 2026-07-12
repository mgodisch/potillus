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
import PotillusKit
import SwiftUI

// =============================================================================
// Loc – localisation that obeys the in-app language, not the system's
// =============================================================================
//
// Android has an in-app language picker; this port keeps it (same feature, native
// idiom). That is the whole reason this file exists, because it fights SwiftUI's
// grain.
//
// THE PROBLEM SwiftUI's `Text("Today")` becomes a `LocalizedStringKey` and looks up
// the translation for the ENVIRONMENT locale — which tracks the SYSTEM language.
// Setting `.environment(\.locale, chosen)` moves some views but, by Apple's own
// documentation and wide report, not reliably all of them. A privacy app that
// promises a language must not show half its labels in another.
//
// THE FIX Every user-facing string goes through `Loc.string(_:locale:)`, which calls
// `String(localized:locale:)` with the CHOSEN locale explicitly. That initialiser
// takes a locale parameter (since iOS 16) and resolves against the String Catalog
// regardless of the system language. The result is a plain `String`, so it is a
// runtime value — which is exactly why the views must call this rather than pass a
// literal to `Text`, since `Text(runtimeString)` does NOT re-localise.
//
// THE KEY is the English source text, as Apple's String Catalog uses it.
// `Loc.string("Today")` looks up "Today" in Localizable.xcstrings — the committed,
// hand-maintained catalogue (no generator, no android/). A missing key returns
// itself, so an un-added string shows in English rather than crashing — visible,
// not fatal — and tools/check-l10n-parity.py flags any literal with no catalogue
// key so it does not slip through.
// =============================================================================

enum Loc {

    /// The chosen language as a `Locale`. Empty (the "System" choice) falls back to
    /// the system locale, so "System" behaves like ordinary iOS localisation.
    static func locale(for language: String) -> Locale {
        language.isEmpty ? .current : Locale(identifier: language)
    }

    /// Looks up `key` in the chosen language.
    ///
    /// - Parameters:
    ///   - key: the English source string, which is the catalogue key.
    ///   - locale: the resolved locale (see `locale(for:)`).
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    /// A string whose catalogue key differs from its English text. This is needed
    /// when one English word must be translated two ways by context: the tab bar
    /// wants a label short enough not to wrap under its icon, while the screen title
    /// wants the full word. `nav_statistics` (French "Stats") sits beside the full
    /// `Statistics` title (French "Statistiques"), mirroring Android's
    /// `nav_statistics` / `statistics` split. `defaultValue` gives the English text,
    /// so the key need not be an English phrase.
    static func string(
        key: StaticString, english: String.LocalizationValue, locale: Locale
    ) -> String {
        String(localized: key, defaultValue: english, locale: locale)
    }

    /// One interpolated argument. The catalogue key carries a single `%@`/`%lld`.
    static func string(_ key: String, _ arg: CVarArg, locale: Locale) -> String {
        String(format: string(key, locale: locale), locale: locale, arg)
    }

    /// Two interpolated arguments, positional (`%1$…`, `%2$…`).
    static func string(
        _ key: String, _ arg: CVarArg, _ arg2: CVarArg, locale: Locale
    ) -> String {
        String(format: string(key, locale: locale), locale: locale, arg, arg2)
    }

    /// A pluralised string with one count. The catalogue key carries plural
    /// variations (one/few/many/other, per language); the runtime picks the form
    /// for `count` in the CHOSEN locale.
    ///
    /// The key is built by interpolating `count` as an `Int` into a
    /// `String.LocalizationValue`, exactly as `Text("\(count) days")` would — that is
    /// what makes the lookup key `"%lld days"` and lets iOS inflect. Passing the
    /// number as a String instead would defeat both, which is the whole subtlety
    /// here. Only two shapes exist in this app, so they are written out rather than
    /// built from a format string.
    static func daysPlural(count: Int, locale: Locale) -> String {
        String(localized: "\(count) days", locale: locale)
    }

    /// "%lld entries imported." — the replace-import summary.
    static func importedPlural(count: Int, locale: Locale) -> String {
        String(localized: "\(count) entries imported.", locale: locale)
    }

    /// "%lld entries imported, %lld skipped." — the merge-import summary. The FIRST
    /// count drives the plural form; the second is a plain number in the string.
    static func importedMergedPlural(
        imported: Int, skipped: Int, locale: Locale
    ) -> String {
        String(localized: "\(imported) entries imported, \(skipped) skipped.", locale: locale)
    }
}

// =============================================================================
// SwiftUI glue
// =============================================================================
//
// `\.appLocale` carries the chosen locale down the view tree, set once at the root
// from `settings.language`. A view reads it and passes it to `Loc.string`, so no
// screen needs to know where the language came from.
// =============================================================================

private struct AppLocaleKey: EnvironmentKey {
    static let defaultValue: Locale = .current
}

extension EnvironmentValues {
    var appLocale: Locale {
        get { self[AppLocaleKey.self] }
        set { self[AppLocaleKey.self] = newValue }
    }
}

extension View {
    /// A `Text` whose content is resolved against the chosen locale at render time.
    /// The `@Environment(\.appLocale)` read means it updates when the language does.
    func localizedText(_ key: String) -> some View {
        modifier(LocalizedTextModifier(key: key))
    }
}

private struct LocalizedTextModifier: ViewModifier {
    let key: String
    @Environment(\.appLocale) private var locale

    func body(content: Content) -> some View {
        // content is ignored; the modifier exists to inject the environment read.
        Text(Loc.string(key, locale: locale))
    }
}
