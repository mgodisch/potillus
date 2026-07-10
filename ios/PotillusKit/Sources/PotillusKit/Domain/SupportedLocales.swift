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

import Foundation

// =============================================================================
// SupportedLocales.swift – the languages the app ships
// =============================================================================
//
// The Swift counterpart of `l10n/SupportedLocales.kt`. The tag list is asserted
// against `test-vectors/backup-settings.json`, which is GENERATED from the Kotlin
// source — so adding a translation on one platform and forgetting the other
// turns the suite red rather than silently degrading a restored `language`
// setting to "follow the system".
//
// Adding a language: add it to the Kotlin `ALL` list, regenerate the vector, add
// it here. The test enforces the third step.
// =============================================================================

public enum SupportedLocales {

    /// One shipped language.
    public struct Locale: Sendable, Equatable {
        /// BCP-47 tag, e.g. `de` or `pt-BR`.
        public let tag: String
        /// The language's own name for itself, shown in the picker.
        public let autonym: String
    }

    /// Every shipped language, in the order the Kotlin catalogue lists them.
    public static let all: [Locale] = [
        Locale(tag: "da", autonym: "Dansk"),
        Locale(tag: "de", autonym: "Deutsch"),
        Locale(tag: "en", autonym: "English"),
        Locale(tag: "es", autonym: "Español"),
        Locale(tag: "fr", autonym: "Français"),
        Locale(tag: "it", autonym: "Italiano"),
        Locale(tag: "nl", autonym: "Nederlands"),
        Locale(tag: "nb", autonym: "Norsk bokmål"),
        Locale(tag: "pl", autonym: "Polski"),
        Locale(tag: "pt", autonym: "Português"),
        Locale(tag: "pt-BR", autonym: "Português (Brasil)"),
        Locale(tag: "ro", autonym: "Română"),
        Locale(tag: "sv", autonym: "Svenska"),
        Locale(tag: "cs", autonym: "Čeština"),
        Locale(tag: "el", autonym: "Ελληνικά"),
        Locale(tag: "ru", autonym: "Русский"),
        Locale(tag: "uk", autonym: "Українська"),
        Locale(tag: "zh-CN", autonym: "简体中文"),
        Locale(tag: "zh-TW", autonym: "繁體中文"),
        Locale(tag: "ja", autonym: "日本語"),
        Locale(tag: "ko", autonym: "한국어"),
    ]

    /// Just the tags, for validation.
    public static let tags: [String] = all.map(\.tag)

    /// Canonicalises `raw` against the catalogue, case-insensitively.
    ///
    /// Returns the catalogue's own spelling (so `"DE"` becomes `"de"` and
    /// `"pt-br"` becomes `"pt-BR"`), or the empty string — "follow the system" —
    /// for a tag this build does not ship. A backup written by a newer app that
    /// added a language therefore restores gracefully.
    public static func canonicalTag(_ raw: String) -> String {
        tags.first { $0.compare(raw, options: .caseInsensitive) == .orderedSame } ?? ""
    }
}
