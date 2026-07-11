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
// ReportLabels – every word the PDF says
// =============================================================================
//
// NOT YET LOCALISED, and the type is shaped so that becoming localised is a change
// of one initialiser rather than a change of the renderer.
//
// The defaults below are the ENGLISH strings from Android's res/values/strings.xml,
// copied so the two reports read alike where they can. When the String Catalogs
// arrive, a second initialiser will fill these from the bundle and every call site
// stays as it is. Until then the property names say `english` nowhere: they are
// simply the labels, and the fact that they are English is a property of the
// default values, not of the type.
//
// Two things here are deliberately NOT translated, on both platforms:
//   - `footer2`, the licence and warranty notice. Legal boilerplate keeps its
//     original English so its meaning never depends on translation quality; the
//     GPL's warranty disclaimer in particular is quoted, not paraphrased.
//   - The category KEYS. Their labels translate; the stored names do not.
// =============================================================================

public struct ReportLabels: Sendable {

    // ── Document ─────────────────────────────────────────────────────────────
    public var title = "Alcohol Consumption Report"
    public var footer1 = "Self-logged estimates – not a medical diagnosis! "
        + "Not intended for driving ability evaluation or diagnostic purposes!"

    // ── Section headings ─────────────────────────────────────────────────────
    public var sectionKpis = "Key Indicators"
    public var sectionMonths = "Monthly Overview"
    public var sectionTrend = "Long-term Trend (Ø Grams/Day)"
    public var sectionCategories = "Consumption Pattern: Drink Categories"
    public var sectionDaytime = "Consumption Pattern: Time of Day (Ø Gram Alcohol)"
    public var sectionWeekday = "Consumption Pattern: Weekday (Ø Gram Alcohol)"
    public var sectionRisk = "Risk Consumption & Abstinence"

    // ── Metadata block ───────────────────────────────────────────────────────
    public var metaExportDate = "Export date"
    public var metaPeriod = "Period"
    public var metaLimit = "Limits"
    public var metaWeight = "Body weight"
    public var metaLongestAbstinence = "Longest abstinence phase"
    public var metaCurrentAbstinence = "Current abstinence"

    // ── Units ────────────────────────────────────────────────────────────────
    public var unitGramsPerDay = "g/day"
    public var unitGramsPerWeek = "g/7 days"
    public var unitDrinkDaysPerWeek = "Drinking days/7 days"

    // ── Key indicators ───────────────────────────────────────────────────────
    public var kpiTotal = "Total alcohol"
    public var kpiAvgPerDay = "Ø per day"
    public var kpiAvgPerDrinkDay = "Ø per drinking day"
    public var kpiMedianPerDay = "Median per day"
    public var kpiMedianPerDrinkDay = "Median per drinking day"
    public var kpiDrinkDays = "Drinking days"
    public var kpiAbstinentDays = "Abstinent days"
    public var kpiMaxPerDay = "Max per day"
    public var kpiMaxPer7Days = "Max per 7 days"
    public var kpiAvgDrinkDaysPerMonth = "Ø drinking days/month"
    public var kpiMedianDrinkDaysPerMonth = "Median drinking days/month"

    // ── Monthly table ────────────────────────────────────────────────────────
    public var columnMonth = "Month"
    public var columnDrinkDays = "Drinking days"
    public var columnTotalGrams = "Total g"
    public var columnAvgPerDay = "Ø g/day"
    public var columnOverDaily = "> day"

    // ── Category table ───────────────────────────────────────────────────────
    public var categoryHeading = "Category"

    public init() {}

    // ── Labels that take a number ────────────────────────────────────────────
    //
    // Android writes these as `%1$s` format strings and lets each translation put
    // the number where its grammar wants it. Passing the formatted number in keeps
    // that freedom for the day these become localised.

    /// `"Binge days (> 60 g)"` — the KPI tile.
    public var kpiBinge: @Sendable (String) -> String = { "Binge days (> \($0) g)" }

    /// `"Binge drinking days (> 60 g)"` — the risk section, which has room.
    public var riskBingeDays: @Sendable (String) -> String = {
        "Binge drinking days (> \($0) g)"
    }

    /// `"days > 24 g/day"`.
    public var kpiOverDaily: @Sendable (String) -> String = { "days > \($0) g/day" }

    /// `"days > 168 g/7 days"`.
    public var kpiOverWeekly: @Sendable (String) -> String = { "days > \($0) g/7 days" }

    /// `"days > 5/7 drinking days"`.
    public var kpiOverDrinkDays: @Sendable (Int) -> String = { "days > \($0)/7 drinking days" }

    /// `"1 day"` / `"7 days"`.
    ///
    /// English has two plural forms and this closure knows both. Other languages
    /// have up to six, which is why the localised initialiser will replace the
    /// whole closure rather than pass a flag: `Days.formatted` and Android's
    /// `R.plurals.days` both take the count and decide for themselves.
    public var days: @Sendable (Int) -> String = { $0 == 1 ? "1 day" : "\($0) days" }

    /// The reader-facing name of a stored category key.
    public var category: @Sendable (String) -> String = { name in
        switch name {
        case "BEER": return "Beer"
        case "WINE": return "Wine / Sparkling Wine"
        case "SPIRITS": return "Spirits"
        case "LONGDRINK": return "Long Drink / Mix"
        case "LIQUEUR": return "Liqueur"
        default: return "Other"
        }
    }

    /// The licence and warranty notice. English on both platforms, by decision.
    ///
    /// - Parameters:
    ///   - appVersion: `MAJOR.MINOR.PATCH`, with any build suffix stripped.
    ///   - systemVersion: The user-facing iOS version, e.g. `"17.4"`.
    public static func footer2(appVersion: String, systemVersion: String) -> String {
        "Created with Libellus Potionis v\(appVersion) on iOS \(systemVersion), "
            + "free software under the GNU GPL v3, WITHOUT ANY WARRANTY."
    }
}
