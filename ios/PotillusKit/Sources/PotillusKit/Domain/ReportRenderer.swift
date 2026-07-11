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
// ReportRenderer – ReportData into report_template.html
// =============================================================================
//
// The last step before a PDF exists. `ReportData` has already computed every
// figure and `ReportChart` every bar height; this file only decides which name
// each value is filed under, and formats it for a reader.
//
// It fills 37 document placeholders and ten repeat blocks. If it ever misses one,
// the template leaves `{{THE_NAME}}` visible in the PDF — an outcome the engine
// chooses on purpose, and which a test here relies on to prove nothing was missed.
// =============================================================================

public enum ReportRenderer {

    /// Everything the renderer needs that is not a measured figure.
    public struct Context: Sendable {
        /// The template text, read from `report/report_template.html`.
        public let template: String
        /// `MAJOR.MINOR.PATCH`, any build suffix already stripped.
        public let appVersion: String
        /// The user-facing iOS version, e.g. `"17.4"`.
        public let systemVersion: String
        /// The day the report is exported on. Injected, so a screenshot run pins it.
        public let exportDate: Date
        public let locale: Locale
        public var labels: ReportLabels

        public init(
            template: String,
            appVersion: String,
            systemVersion: String,
            exportDate: Date,
            locale: Locale = .current,
            labels: ReportLabels = ReportLabels()
        ) {
            self.template = template
            self.appVersion = appVersion
            self.systemVersion = systemVersion
            self.exportDate = exportDate
            self.locale = locale
            self.labels = labels
        }
    }

    /// Renders the complete two-page report as one self-contained HTML string.
    public static func render(data: ReportData, context: Context) -> String {
        Template.render(
            template: context.template,
            scalars: scalars(data: data, context: context),
            repeats: repeats(data: data, context: context)
        )
    }

    // ── Document-level values ────────────────────────────────────────────────

    static func scalars(data: ReportData, context: Context) -> [String: String] {
        let labels = context.labels
        let locale = context.locale
        let limits = data.limitInfo

        var values: [String: String] = [:]

        // The root <html lang="…">. A WebView picks its CJK glyph orthography —
        // Simplified vs Traditional Han, Japanese kanji, Korean hanja — from the
        // document language. With no hint it defaults to Simplified forms, so a
        // Japanese report would print Chinese-shaped glyphs for the code points the
        // two scripts share. Latin locales are unaffected, which is precisely why
        // this is easy to forget.
        values["REPORT_LANG"] = locale.identifier.replacingOccurrences(of: "_", with: "-")

        values["TITLE"] = labels.title
        values["FOOTER1"] = labels.footer1
        values["FOOTER2"] = ReportLabels.footer2(
            appVersion: context.appVersion, systemVersion: context.systemVersion
        )

        values["SECTION_KPIS"] = labels.sectionKpis
        values["SECTION_MONTHS"] = labels.sectionMonths
        values["SECTION_TREND"] = labels.sectionTrend
        values["SECTION_CATEGORIES"] = labels.sectionCategories
        values["SECTION_DAYTIME"] = labels.sectionDaytime
        values["SECTION_WEEKDAY"] = labels.sectionWeekday
        values["SECTION_RISK"] = labels.sectionRisk

        // ── Metadata ────────────────────────────────────────────────────────
        values["META_EXPORT_LABEL"] = labels.metaExportDate
        values["META_EXPORT_VALUE"] = longDate(context.exportDate, locale: locale)
        values["META_PERIOD_LABEL"] = labels.metaPeriod
        values["META_PERIOD_VALUE"] = period(
            from: data.firstDate, to: data.lastDate, locale: locale
        )
        values["META_LIMIT_LABEL"] = labels.metaLimit
        values["META_LIMIT_VALUE_DAY"] =
            "\(one(limits.limitGrams, locale)) \(labels.unitGramsPerDay)"
        values["META_LIMIT_VALUE_7DAYS"] =
            "\(one(limits.weeklyLimitGrams, locale)) \(labels.unitGramsPerWeek)"
        values["META_LIMIT_VALUE_DDAYS"] =
            "\(limits.maxDrinkDaysPerWeek) \(labels.unitDrinkDaysPerWeek)"
        values["META_WEIGHT_LABEL"] = labels.metaWeight
        // An en dash, not a hyphen: this is "no value", not "minus".
        values["META_WEIGHT_VALUE"] = data.weightKg > 0
            ? "\(Int(data.weightKg.rounded())) kg"
            : "–"

        // ── Table headings ──────────────────────────────────────────────────
        values["COL_MONTH"] = labels.columnMonth
        values["COL_DRINK_DAYS"] = labels.columnDrinkDays
        values["COL_TOTAL_G"] = labels.columnTotalGrams
        values["COL_AVG_G_DAY"] = labels.columnAvgPerDay
        values["COL_OVER_DAILY"] = labels.columnOverDaily
        values["CAT_HEAD_NAME"] = labels.categoryHeading
        values["CAT_HEAD_G"] = "g"
        values["CAT_HEAD_PCT"] = "%"

        // ── Trend chart ─────────────────────────────────────────────────────
        // The section is always shown; the placeholder survives from a time when it
        // appeared only with two months or more.
        values["TREND_DISPLAY"] = "block"
        values["LIMIT_LINE_PCT"] = zero(
            ReportChart.percent(value: limits.limitGrams, max: trendCeiling(data)), locale
        )

        // ── Risk section ────────────────────────────────────────────────────
        values["RISK_BINGE_LABEL"] = labels.riskBingeDays(
            zero(AlcoholCalculator.bingeThreshold, locale)
        )
        values["RISK_BINGE_VALUE"] = "\(data.bingeDays)"
        values["RISK_LONGEST_LABEL"] = labels.metaLongestAbstinence
        values["RISK_LONGEST_VALUE"] = labels.days(data.longestAbstinence)
        values["RISK_CURRENT_LABEL"] = labels.metaCurrentAbstinence
        values["RISK_CURRENT_VALUE"] = labels.days(data.currentAbstinence)

        return values
    }

    // ── Formatting ───────────────────────────────────────────────────────────
    //
    // `internal`, not private: `private` in Swift means FILE scope, and the row
    // builders live in ReportRendererRows.swift.

    static func one(_ value: Double, _ locale: Locale) -> String {
        ReportFormatting.oneDecimal(value, locale: locale)
    }

    static func zero(_ value: Double, _ locale: Locale) -> String {
        ReportFormatting.noDecimals(value, locale: locale)
    }

    /// Dates are noon-anchored in UTC, so every formatter here reads them in UTC.
    /// A formatter left on the device zone would show the previous day west of
    /// Greenwich for exactly twelve hours a day.
    private static func formatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }

    static func longDate(_ date: Date, locale: Locale) -> String {
        let formatter = self.formatter(locale: locale)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        // The export date is a wall-clock day, so it is read where the reader is.
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func period(from: String, to: String, locale: Locale) -> String {
        guard let start = DayResolver.parseDate(from), let end = DayResolver.parseDate(to) else {
            return "\(from) – \(to)"
        }
        let formatter = self.formatter(locale: locale)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    /// `"2026-06"` → `"Jun 2026"`, and `"2026年6月"` where that is the order.
    ///
    /// The pattern is asked for, not written: CJK reports want the year first, and
    /// inflected languages the standalone month form. Both are CLDR data.
    static func monthAndYear(_ monthKey: String, locale: Locale) -> String {
        guard let date = DayResolver.parseDate("\(monthKey)-01") else { return monthKey }
        let formatter = self.formatter(locale: locale)
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter.string(from: date)
    }

    /// A compact day-and-month tick, in the locale's own field order: `"28.6."` or
    /// `"6/28"`, never a hard-coded European one.
    static func dayAndMonth(_ date: Date, locale: Locale) -> String {
        let formatter = self.formatter(locale: locale)
        formatter.setLocalizedDateFormatFromTemplate("dM")
        return formatter.string(from: date)
    }

    static func bucketLabel(
        _ bucket: ChartBucket, _ granularity: ChartGranularity, _ locale: Locale
    ) -> String {
        guard let date = DayResolver.parseDate(bucket.labelDate) else { return bucket.labelDate }
        switch granularity {
        case .daily, .weekly: return dayAndMonth(date, locale: locale)
        case .monthly: return monthAndYear(String(bucket.labelDate.prefix(7)), locale: locale)
        }
    }

    /// The first two characters of the locale's short weekday name.
    ///
    /// Two, because the column is narrow and seven of them must fit. Android takes
    /// the same two.
    static func shortWeekday(iso: Int, locale: Locale) -> String {
        let formatter = self.formatter(locale: locale)
        // `shortWeekdaySymbols` is Sunday-first; ISO counts Monday as 1, so ISO 7
        // (Sunday) wraps to index 0.
        guard let symbols = formatter.shortWeekdaySymbols, symbols.count == 7 else { return "" }
        return String(symbols[iso % 7].prefix(2))
    }
}
