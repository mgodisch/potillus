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
// DayPlural – "1 day", "2 days", and the twenty other ways to say it
// =============================================================================
//
// WHAT THIS IS FOR
//   The report prints two day counts, the longest and the current abstinence.
//   Until the 0.84.0 review it printed them in English in every language: a
//   German report read "Längste Abstinenzphase 8 days". `ReportLabels.days` was
//   an English closure and no language replaced it, while Android had carried
//   translated forms in `<plurals name="days">` all along.
//
// WHY THE RULE LIVES HERE AND THE WORDS LIVE IN THE CATALOGUE
//   The words are translations and belong beside the other translations, one set
//   per language in ReportLabelsCatalog. The RULE that picks among them is not a
//   translation — it is CLDR, the same for every project — so it is written once,
//   here, rather than twenty times over.
//
// THE RULES, AND WHY THESE AND NOT OTHERS
//   Most languages this app ships need two forms and pick the singular at
//   exactly one. Five need more, and each for its own reason:
//
//     fr           counts ZERO as singular. "0 jour", not "0 jours".
//     ro           has a third form for 0 and for 2..19, and again from 101.
//     cs           has a third form for 2, 3 and 4 only.
//     pl, ru, uk   pick from the LAST TWO DIGITS: 21 takes the singular, 22..24
//                  a second form, and 11..14 a third one despite ending in 1..4.
//
//   Those teens are the whole reason this is a function and not a comparison
//   against 1. `test-vectors/plural-days.json` carries 11, 12, 14, 21, 22, 25,
//   101 and 111 for exactly that reason, with the expected words taken from
//   Android's resources.
//
// WHO IS RIGHT WHEN THE TWO DISAGREE
//   Android, whose `getQuantityString` resolves these through the platform's own
//   CLDR data. This file reproduces that selection; the shared vector is where
//   the two meet.
// =============================================================================

/// The plural categories this app's languages distinguish for a whole number.
public enum PluralCategory: String, Sendable, Equatable {
    case one
    case few
    case many
    case other
}

/// The translated forms of a day count, as one language spells them.
///
/// Only `other` is required. A language that makes no distinction — Japanese,
/// Korean, both Chinese scripts — carries that one and nothing else, and every
/// count falls back to it.
public struct DayForms: Sendable, Equatable {
    public let one: String?
    public let few: String?
    public let many: String?
    public let other: String

    public init(one: String? = nil, few: String? = nil, many: String? = nil, other: String) {
        self.one = one
        self.few = few
        self.many = many
        self.other = other
    }

    /// The form for `category`, falling back to `other` where a language has none.
    public func form(_ category: PluralCategory) -> String {
        switch category {
        case .one: return one ?? other
        case .few: return few ?? other
        case .many: return many ?? other
        case .other: return other
        }
    }
}

public enum DayPlural {

    /// The CLDR plural category a whole `count` selects in `language`.
    ///
    /// - Parameters:
    ///   - count: A day count. Negative values are not expected; they take the
    ///     same branch as their absolute value would, which keeps the function
    ///     total rather than correct about a case that cannot arise.
    ///   - language: A bare language tag as the catalogue spells it: `"de"`,
    ///     `"pt-BR"`, `"zh-Hans"`. Anything unknown falls to the English rule,
    ///     which is what an unlocalised report would have used anyway.
    public static func category(_ count: Int, language: String) -> PluralCategory {
        let days = abs(count)
        switch language {
        case "ja", "ko", "zh-Hans", "zh-Hant":
            return .other

        case "fr":
            // Zero is singular in French.
            return days <= 1 ? .one : .other

        case "ro":
            if days == 1 { return .one }
            if days == 0 || (1...19).contains(days % 100) { return .few }
            return .other

        case "cs":
            if days == 1 { return .one }
            if (2...4).contains(days) { return .few }
            return .other

        case "pl":
            if days == 1 { return .one }
            if (2...4).contains(days % 10) && !(12...14).contains(days % 100) { return .few }
            return .many

        case "ru", "uk":
            if days % 10 == 1 && days % 100 != 11 { return .one }
            if (2...4).contains(days % 10) && !(12...14).contains(days % 100) { return .few }
            return .many

        default:
            return days == 1 ? .one : .other
        }
    }

    /// `count` spelled out in `language`, using that language's own forms.
    ///
    /// The forms carry Android's `%1$d`, which is substituted here rather than by
    /// a formatter: the number's own digits are Western in every language this app
    /// ships, and a locale-aware formatter would print Eastern Arabic numerals on
    /// a device configured for them, disagreeing with every other figure in the
    /// report.
    public static func format(_ count: Int, language: String, forms: DayForms) -> String {
        forms.form(category(count, language: language))
            .replacingOccurrences(of: "%1$d", with: "\(count)")
    }
}
