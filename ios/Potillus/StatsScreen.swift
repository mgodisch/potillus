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

import Charts
import PotillusKit
import SwiftUI
import UniformTypeIdentifiers

// =============================================================================
// StatsScreen.swift – the period, and what it says
// =============================================================================
//
// Layout only. Every number arrives from `StatsModel`, and every aggregation from
// `StatsAggregator`, both under test. Nothing is computed here.
//
// THREE ABSENCES THE VIEW MUST RESPECT
//   - `hasBaseline == false`: the user's stats floor cuts into the current period,
//     so there is nothing to compare against. The trend row is hidden, not shown
//     as 0 %.
//   - A weekday average of `nil`: no such weekday fell in the period. Its bar is
//     omitted, which is different from a bar of height zero (a dry Tuesday).
//   - An empty `categoryBreakdown`: nothing was drunk. No empty pie.
// =============================================================================

struct StatsScreen: View {

    @State private var model: StatsModel

    private let environment: AppEnvironment

    @State private var exportedCsv: CsvDocument?
    @State private var isExporting = false
    @State private var exportFailure: String?

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: StatsModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                periodPicker
                headline
                if !model.state.chartBuckets.isEmpty { consumptionChart }
                limits
                streaks
                if !model.state.categoryBreakdown.isEmpty { categories }
                timeOfDay
                weekdays
            }
            .navigationTitle("Statistics")
            .toolbar {
                Button {
                    prepareCsv()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(model.state.dataPoints.isEmpty)
            }
            .task { await model.load() }
            .refreshable { await model.load() }
            .fileExporter(
                isPresented: $isExporting,
                document: exportedCsv,
                contentType: .commaSeparatedText,
                defaultFilename: CsvExporter.suggestedFileName()
            ) { result in
                if case .failure(let error) = result {
                    exportFailure = String(describing: error)
                }
            }
            .alert(
                "Export failed",
                isPresented: .constant(exportFailure != nil),
                presenting: exportFailure
            ) { _ in
                Button("OK", role: .cancel) { exportFailure = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Period ───────────────────────────────────────────────────────────────

    private var periodPicker: some View {
        Picker("Period", selection: Binding(
            get: { model.state.period },
            set: { period in Task { await model.setPeriod(period) } }
        )) {
            Text("Week").tag(StatsPeriod.week)
            Text("Month").tag(StatsPeriod.month)
            Text("Year").tag(StatsPeriod.year)
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ── Headline figures ─────────────────────────────────────────────────────

    private var headline: some View {
        Section {
            LabeledContent("Total") { grams(model.state.totalGrams) }
            LabeledContent("Per day") { grams(model.state.averagePerDay) }
            // A different question from "per day": how much when I drink at all.
            LabeledContent("Per drink day") { grams(model.state.averagePerDrinkDay) }

            // Hidden, not zeroed: without a previous period there is nothing to
            // compare against, and "0 %" would claim there was.
            if model.state.hasBaseline {
                LabeledContent("Trend") {
                    HStack(spacing: 4) {
                        Image(systemName: trendSymbol)
                            .foregroundStyle(trendColor)
                        Text(String(format: "%+.1f %%", model.state.trendPercent))
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            Text(model.state.from.isEmpty ? "" : "\(model.state.from) – \(model.state.to)")
        }
    }

    /// The arrow follows `Trend`, which rounds before comparing; the percentage
    /// does not. They may disagree by a hair, deliberately — see `StatsAggregator`.
    private var trendSymbol: String {
        switch model.state.trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    /// Down is good here. A rising trend in alcohol consumption is not a success.
    private var trendColor: Color {
        switch model.state.trend {
        case .up: return .red
        case .down: return .green
        case .flat: return .secondary
        }
    }

    // ── Consumption over time ────────────────────────────────────────────────

    private var consumptionChart: some View {
        Section("Consumption") {
            Chart(model.state.chartBuckets, id: \.labelDate) { bucket in
                BarMark(
                    x: .value("Date", bucket.labelDate),
                    y: .value("Grams per day", bucket.avgPerDay)
                )
                // An abstinent bucket has zero height and would be invisible; the
                // colour lets it be read as "dry", not "missing".
                .foregroundStyle(bucket.isAbstinent ? Color.green : Color.accentColor)
            }
            .chartXAxis {
                // Labels only every few buckets: 31 dates do not fit.
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .chartYAxisLabel("g / day")
            .frame(height: 180)
        }
    }

    // ── Limits ───────────────────────────────────────────────────────────────

    private var limits: some View {
        Section("Days over limit") {
            LabeledContent("Daily limit") {
                count(model.state.daysOverDailyLimit)
            }
            LabeledContent("Weekly limit") {
                count(model.state.daysOverWeeklyLimit)
            }
            LabeledContent("Drink days") {
                count(model.state.daysOverDrinkDayLimit)
            }
        }
    }

    private var streaks: some View {
        Section("Abstinence") {
            // Today is excluded from the current streak: the day is not over, and a
            // drink may still be logged.
            LabeledContent("Current streak") { days(model.state.currentStreak) }
            LabeledContent("Longest streak") { days(model.state.longestStreak) }
            LabeledContent("Dry days in period") { days(model.state.abstinentDays) }
        }
    }

    // ── Breakdowns ───────────────────────────────────────────────────────────

    private var categories: some View {
        Section("By category") {
            let total = model.state.categoryBreakdown.values.reduce(0, +)
            ForEach(sortedCategories, id: \.category) { entry in
                let (category, value) = (entry.category, entry.grams)
                LabeledContent(name(category)) {
                    HStack(spacing: 8) {
                        Text(String(format: "%.0f %%", total > 0 ? value / total * 100 : 0))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        grams(value)
                    }
                }
            }
        }
    }

    /// Largest first: the list answers "what do I drink" at a glance.
    private var sortedCategories: [CategorySlice] {
        model.state.categoryBreakdown
            .map { CategorySlice(category: $0.key, grams: $0.value) }
            .sorted { $0.grams > $1.grams }
    }

    private var timeOfDay: some View {
        Section("Time of day") {
            Chart(hourPoints) { point in
                BarMark(
                    x: .value("Hour", point.label),
                    y: .value("Grams per day", point.average)
                )
            }
            .chartYAxisLabel("g / day")
            .frame(height: 140)
        }
    }

    /// Named rather than a tuple: `Chart` wants `Identifiable`, and a key path
    /// into a tuple element is not something to rely on.
    private var hourPoints: [HourPoint] {
        model.state.hourBucketAverages.enumerated().map { index, average in
            HourPoint(id: index, label: bucketLabel(index), average: average)
        }
    }

    /// "00", "03" … "21". The bucket covers three hours starting there.
    private func bucketLabel(_ index: Int) -> String {
        String(format: "%02d", index * 3)
    }

    private var weekdays: some View {
        Section("By weekday") {
            Chart(weekdayPoints) { point in
                BarMark(
                    x: .value("Weekday", point.label),
                    y: .value("Grams", point.average)
                )
            }
            .chartYAxisLabel("g")
            .frame(height: 140)
        }
    }

    /// Columns whose average is nil are DROPPED, not drawn as zero: that weekday
    /// never occurred in the period, which is not the same as a dry weekday.
    private var weekdayPoints: [WeekdayPoint] {
        zip(model.state.weekdayOrder, model.state.weekdayAverages)
            .compactMap { iso, average in
                average.map { WeekdayPoint(id: iso, label: weekdaySymbol(iso), average: $0) }
            }
    }

    /// `veryShortStandaloneWeekdaySymbols` is Sunday-indexed; the model speaks ISO.
    private func weekdaySymbol(_ iso: Int) -> String {
        let symbols = DateFormatter().shortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return "" }
        return symbols[iso == 7 ? 0 : iso]
    }

    private func name(_ category: DrinkCategory) -> String {
        category.rawValue.capitalized
    }

    // ── Formatting ───────────────────────────────────────────────────────────

    private func grams(_ value: Double) -> some View {
        Text(String(format: "%.1f g", value)).monospacedDigit()
    }

    private func count(_ value: Int) -> some View {
        Text("\(value)")
            .monospacedDigit()
            .foregroundStyle(value > 0 ? .red : .secondary)
    }

    private func days(_ value: Int) -> some View {
        Text("\(value)").monospacedDigit()
    }

    // ── CSV ──────────────────────────────────────────────────────────────────

    /// Builds the CSV for the VISIBLE period, then presents the document browser.
    ///
    /// The range is `state.from ... state.to`, so what the user exports is what
    /// the screen shows. Filtering happens in SQLite, over the index on
    /// `logicalDate`, rather than by loading the whole log into memory — the same
    /// choice Android's `exportCsv` makes, and for the same reason.
    private func prepareCsv() {
        do {
            let entries = try environment.entries.inRange(
                from: model.state.from, to: model.state.to
            )
            // Android refuses an empty export rather than writing a lone header.
            // A file with no rows looks like a broken export, not an empty period.
            guard !entries.isEmpty else {
                exportFailure = "No entries in this period."
                return
            }

            let csv = CsvExporter.buildCsv(
                headerCells: CsvExporter.englishHeaderCells,
                entries: entries,
                drinks: try environment.drinks.allOnce()
            )
            exportedCsv = CsvDocument(data: CsvExporter.fileData(csv: csv))
            isExporting = true
        } catch {
            exportFailure = String(describing: error)
        }
    }
}

// =============================================================================
// Chart data points
// =============================================================================
//
// `Chart` and `ForEach` want identifiable values. Tuples are not, and a key path
// into a tuple element is not a promise worth leaning on.
// =============================================================================

private struct HourPoint: Identifiable {
    let id: Int
    let label: String
    let average: Double
}

private struct WeekdayPoint: Identifiable {
    /// The ISO weekday number, which is already unique within a week.
    let id: Int
    let label: String
    let average: Double
}

private struct CategorySlice {
    let category: DrinkCategory
    let grams: Double
}
