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
// ReportRenderer – the ten repeat blocks
// =============================================================================
//
// Split from ReportRenderer.swift because the type outgrew SwiftLint's body
// limit, and the seam it offered was the honest one: that file decides the
// document's values, this one builds its rows.
// =============================================================================

extension ReportRenderer {

    static func repeats(data: ReportData, context: Context) -> [String: [[String: String]]] {
        [
            "KPIS": kpiRows(data: data, context: context),
            "MONTHS": monthRows(data: data, context: context),
            "BARS": trendBarRows(data: data, context: context),
            "BARSLABELS": trendLabelRows(data: data, context: context),
            "CATEGORIES": categoryRows(data: data, context: context),
            "PIE_SLICES": pieRows(data: data),
            "HBARS": hourBarRows(data: data, context: context),
            "HLABELS": (0...23).map { ["H_LABEL": "\($0)"] },
            "WDBARS": weekdayBarRows(data: data, context: context),
            "WDLABELS": weekdayLabelRows(data: data, context: context),
        ]
    }

    /// One KPI tile. `warn` paints it red.
    private static func kpi(_ label: String, _ value: String, warn: Bool = false) -> [String: String] {
        ["KPI_LABEL": label, "KPI_VALUE": value, "KPI_CLASS": warn ? "kpi warn" : "kpi"]
    }

    /// Sixteen tiles, in Android's order. The order is the layout: the template
    /// flows them into a four-column grid, so moving one moves a column.
    static func kpiRows(data: ReportData, context: Context) -> [[String: String]] {
        let labels = context.labels
        let locale = context.locale
        let limits = data.limitInfo
        let violations = data.violations

        return [
            kpi(labels.kpiAbstinentDays, "\(data.abstinentDays)"),
            kpi(labels.metaLongestAbstinence, "\(data.longestAbstinence)"),
            kpi(labels.kpiDrinkDays, "\(data.drinkDays)"),
            kpi(labels.kpiTotal, "\(one(data.totalGrams, locale)) g"),

            kpi(
                labels.kpiOverDaily(zero(limits.limitGrams, locale)),
                "\(violations.daysOverDailyLimit)",
                warn: violations.daysOverDailyLimit > 0
            ),
            kpi(
                labels.kpiOverWeekly(zero(limits.weeklyLimitGrams, locale)),
                "\(violations.daysOverWeeklyLimit)",
                warn: violations.daysOverWeeklyLimit > 0
            ),
            kpi(
                labels.kpiOverDrinkDays(limits.maxDrinkDaysPerWeek),
                "\(violations.daysOverDrinkDayLimit)",
                warn: violations.daysOverDrinkDayLimit > 0
            ),
            kpi(
                labels.kpiBinge(zero(AlcoholCalculator.bingeThreshold, locale)),
                "\(data.bingeDays)",
                warn: data.bingeDays > 0
            ),

            kpi(
                labels.kpiMaxPerDay, "\(one(data.maxPerDay, locale)) g",
                warn: AlcoholCalculator.isOverLimit(
                    totalGrams: data.maxPerDay, limitGrams: limits.limitGrams
                )
            ),
            kpi(
                labels.kpiMaxPer7Days, "\(one(data.maxPer7Days, locale)) g",
                warn: AlcoholCalculator.isOverLimit(
                    totalGrams: data.maxPer7Days, limitGrams: limits.weeklyLimitGrams
                )
            ),
            kpi(labels.kpiAvgDrinkDaysPerMonth, one(data.avgDrinkDaysPerMonth, locale)),
            kpi(labels.kpiMedianDrinkDaysPerMonth, one(data.medianDrinkDaysPerMonth, locale)),

            kpi(labels.kpiAvgPerDay, "\(one(data.avgPerDay, locale)) g"),
            kpi(labels.kpiMedianPerDay, "\(one(data.medianPerDay, locale)) g"),
            kpi(labels.kpiAvgPerDrinkDay, "\(one(data.avgPerDrinkDay, locale)) g"),
            kpi(labels.kpiMedianPerDrinkDay, "\(one(data.medianPerDrinkDay, locale)) g"),
        ]
    }

    static func monthRows(data: ReportData, context: Context) -> [[String: String]] {
        data.months.map { month in
            let over = month.daysOverDailyLimit
            return [
                "M_MONTH": monthAndYear(month.monthKey, locale: context.locale),
                "M_DRINK_DAYS": "\(month.drinkDays)",
                "M_TOTAL": one(month.totalGrams, context.locale),
                "M_AVG": one(month.avgPerCalendarDay, context.locale),
                // An en dash for "none", so a column of numbers stays a column.
                "M_OVER": over > 0 ? "\(over)" : "–",
                "M_ROW_CLASS": over > 0 ? "warn" : "",
            ]
        }
    }

    /// The tallest bar, or the limit line, whichever is higher — plus headroom, so
    /// neither touches the top edge of the plot.
    static func trendCeiling(_ data: ReportData) -> Double {
        let tallest = data.chartBuckets.map(\.avgPerDay).max() ?? 0.0
        return max(tallest, data.limitInfo.limitGrams) * ReportChart.trendHeadroom
    }

    static func trendBarRows(data: ReportData, context: Context) -> [[String: String]] {
        let ceiling = trendCeiling(data)
        let limit = data.limitInfo.limitGrams

        return data.chartBuckets.map { bucket in
            let dry = bucket.isAbstinent
            return [
                "BAR_HEIGHT_PCT": dry
                    ? "0"
                    : zero(
                        ReportChart.barHeight(value: bucket.avgPerDay, ceiling: ceiling),
                        context.locale
                    ),
                "BAR_CLASS": AlcoholCalculator.isOverLimit(
                    totalGrams: bucket.avgPerDay, limitGrams: limit
                ) ? "bar over" : "bar",
                "BAR_VALUE": dry ? "" : one(bucket.avgPerDay, context.locale),
                // A green tick marks a dry bucket, where the bar has nothing to say.
                "BAR_TICK_DISPLAY": dry ? "block" : "none",
            ]
        }
    }

    /// The x-axis row. Every bucket gets a cell; most of them are empty, so that a
    /// label always sits under its own bar.
    static func trendLabelRows(data: ReportData, context: Context) -> [[String: String]] {
        let labelled = Set(ReportChart.labelIndices(count: data.chartBuckets.count))

        return data.chartBuckets.enumerated().map { index, bucket in
            guard labelled.contains(index) else { return ["BAR_LABEL": ""] }
            return ["BAR_LABEL": bucketLabel(bucket, data.chartGranularity, context.locale)]
        }
    }

    static func categoryRows(data: ReportData, context: Context) -> [[String: String]] {
        data.categories.map { category in
            [
                "C_NAME": context.labels.category(category.categoryName),
                "C_COLOR": ReportPalette.color(forCategory: category.categoryName),
                "C_G": one(category.grams, context.locale),
                "C_PCT": "\(category.percent) %",
            ]
        }
    }

    /// The donut. Fractions come from grams, not from the rounded percents, so the
    /// segments butt up exactly.
    static func pieRows(data: ReportData) -> [[String: String]] {
        let total = data.categories.reduce(0.0) { $0 + $1.grams }
        let fractions = data.categories.map { total > 0 ? $0.grams / total * 100.0 : 0.0 }
        let slices = ReportChart.donutSlices(fractions: fractions)

        return zip(data.categories, slices).map { category, slice in
            [
                "PIE_FILL": ReportPalette.color(forCategory: category.categoryName),
                "PIE_DASH": slice.dash,
                "PIE_GAP": slice.gap,
                "PIE_OFFSET": slice.offset,
            ]
        }
    }

    static func hourBarRows(data: ReportData, context: Context) -> [[String: String]] {
        let ceiling = (data.hourlyGrams.max() ?? 0.0) * ReportChart.barChartHeadroom
        // Grams in an hour, spread across the period's days: an average, like every
        // other figure on this page.
        let days = Double(max(data.totalDays, 1))

        return data.hourlyGrams.map { grams in
            [
                "H_HEIGHT_PCT": zero(
                    ReportChart.barHeight(value: grams, ceiling: ceiling), context.locale
                ),
                "H_VALUE": grams <= 0 ? "" : one(grams / days, context.locale),
            ]
        }
    }

    static func weekdayBarRows(data: ReportData, context: Context) -> [[String: String]] {
        let ceiling = (data.weekdayAverages.compactMap { $0 }.max() ?? 0.0)
            * ReportChart.barChartHeadroom

        return data.weekdayAverages.map { average in
            [
                "WD_HEIGHT_PCT": zero(
                    ReportChart.barHeight(value: average, ceiling: ceiling), context.locale
                ),
                // Blank for a weekday the period never contained.
                "WD_VALUE": average.map { one($0, context.locale) } ?? "",
            ]
        }
    }

    static func weekdayLabelRows(data: ReportData, context: Context) -> [[String: String]] {
        data.weekdayOrder.map { ["WD_NAME": shortWeekday(iso: $0, locale: context.locale)] }
    }

}
