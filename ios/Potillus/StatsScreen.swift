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

import Charts
import PotillusKit
import SwiftUI
import UIKit
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

    // `internal`, not private: `private` in Swift is FILE scope, and the export
    // code in StatsScreenExport.swift reads both the locale and the model.
    @Environment(\.appLocale) var locale

    /// Observed so a return from the background reloads at once (below).
    @Environment(\.scenePhase) private var scenePhase

    @State var model: StatsModel

    let environment: AppEnvironment

    @State var exportedCsv: CsvDocument?
    @State var isExporting = false
    @State var exportedPdf: PdfDocument?
    @State var isExportingPdf = false
    @State var isBuildingPdf = false
    @State var exportFailure: String?

    /// Non-nil while the range sheet is up; carries what the range is for.
    @State var pendingExport: ExportRangeSheet.Kind?

    /// Pre-fill for the sheet, resolved when the button is tapped.
    @State var exportDefaults: (from: Date, to: Date)?

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: StatsModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences, clock: environment.clock
        ))
    }

    var body: some View {
        NavigationStack {
            // Order follows Android's, section for section. The consumption chart
            // comes FIRST, right under the period picker: it is the answer to the
            // question the screen is opened with, and the figures below read as its
            // footnotes. It had sat fourth here, behind two blocks of numbers.
            List {
                periodPicker
                if !model.state.chartBuckets.isEmpty { consumptionChart }
                keyMetrics
                streaksAndTrend
                timeOfDay
                weekdays
                categories
            }
            .navigationTitle(Loc.string("Statistics", locale: locale))
            .appOverflowMenu(environment: environment)
            .toolbar {
                Menu {
                    Button {
                        Task { await beginExport(.csv) }
                    } label: {
                        Label(Loc.string("Export CSV", locale: locale), systemImage: "tablecells")
                    }
                    Button {
                        Task { await beginExport(.pdf) }
                    } label: {
                        Label(Loc.string("Export PDF report", locale: locale), systemImage: "doc.richtext")
                    }
                } label: {
                    if isBuildingPdf {
                        ProgressView()
                    } else {
                        Label(Loc.string("Export", locale: locale), systemImage: "square.and.arrow.up")
                    }
                }
                // NOT disabled on an empty window. The range is chosen in the sheet,
                // and the window on screen has no say in it. Android asks first too.
                .disabled(isBuildingPdf)
            }
            .sheet(item: $pendingExport) { kind in
                exportRangeSheet(for: kind)
            }
            // `start()` subscribes; the first emission of each stream loads the
            // screen. Pull-to-refresh stays: it costs nothing and it is the gesture
            // people reach for when they doubt what they see.
            .task { model.start() }
            .onDisappear { model.stop() }
            // Reload on foregrounding; see TodayScreen for the full rationale
            // (onAppear does not fire, the ticker only bounds staleness).
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.load() } }
            }
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
            .fileExporter(
                isPresented: $isExportingPdf,
                document: exportedPdf,
                contentType: .pdf,
                defaultFilename: ReportJob.fileName(date: Date())
            ) { result in
                if case .failure(let error) = result {
                    exportFailure = String(describing: error)
                }
            }
            .alert(
                Loc.string("Export failed", locale: locale),
                isPresented: .constant(exportFailure != nil),
                presenting: exportFailure
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) { exportFailure = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Period ───────────────────────────────────────────────────────────────

    private var periodPicker: some View {
        Picker(Loc.string("Period", locale: locale), selection: Binding(
            get: { model.state.period },
            set: { period in Task { await model.setPeriod(period) } }
        )) {
            Text(Loc.string("Week", locale: locale)).tag(StatsPeriod.week)
            Text(Loc.string("Month", locale: locale)).tag(StatsPeriod.month)
            Text(Loc.string("Year", locale: locale)).tag(StatsPeriod.year)
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ── Headline figures ─────────────────────────────────────────────────────

    // ── Key metrics ──────────────────────────────────────────────────────────
    //
    // The order and the labels track Android's key-metrics card exactly: the
    // three averages, then the three "days over" counts (red when breached,
    // green when held), then the abstinent-day count (green when positive).
    // iOS used to shorten these ("Total", "Per day") and split the days-over
    // rows into a separate "Days over limit" section; the 0.83.0 UI-parity pass
    // adopts Android's wording and grouping so a platform switcher reads one
    // vocabulary. The period stays in the section header, iOS-idiomatic.

    private var keyMetrics: some View {
        Section {
            LabeledContent(Loc.string("Total in Period", locale: locale)) { grams(model.state.totalGrams) }
            LabeledContent(Loc.string("Average per Day", locale: locale)) { grams(model.state.averagePerDay) }
            LabeledContent(Loc.string("Average per Drinking Day", locale: locale)) {
                grams(model.state.averagePerDrinkDay)
            }
            LabeledContent(Loc.string("Days Over Daily Limit", locale: locale)) {
                count(model.state.daysOverDailyLimit)
            }
            LabeledContent(Loc.string("Days Over 7-Day Limit", locale: locale)) {
                count(model.state.daysOverWeeklyLimit)
            }
            LabeledContent(Loc.string("Days Over Drinking Days Limit", locale: locale)) {
                count(model.state.daysOverDrinkDayLimit)
            }
            LabeledContent(Loc.string("Abstinent Days", locale: locale)) {
                // Green when positive, plain at zero — never red: a dry-day count
                // is an achievement, not a limit breach. `count` is for the
                // days-over rows (red/green); this needs green/plain.
                Text("\(model.state.abstinentDays)")
                    .monospacedDigit()
                    .foregroundStyle(model.state.abstinentDays > 0 ? Color.green : Color.secondary)
            }
        } header: {
            Text(model.state.from.isEmpty ? "" : "\(model.state.from) – \(model.state.to)")
        }
    }

    // ── Abstinence & trend (Android's second card) ───────────────────────────

    private var streaksAndTrend: some View {
        Section(Loc.string("Abstinence & Trend", locale: locale)) {
            // Today is excluded from the current streak: the day is not over, and a
            // drink may still be logged. Green when positive, like Android.
            LabeledContent(Loc.string("Current Abstinence", locale: locale)) {
                daysColored(model.state.currentStreak)
            }
            LabeledContent(Loc.string("Longest Abstinence", locale: locale)) {
                days(model.state.longestStreak)
            }
            // The trend belongs in this card on Android, not up in the metrics.
            // Hidden, not zeroed: without a previous period there is nothing to
            // compare against, and "0 %" would claim there was.
            if model.state.hasBaseline {
                LabeledContent(Loc.string("Trend vs. Previous Period", locale: locale)) {
                    HStack(spacing: 4) {
                        Image(systemName: trendSymbol)
                            .foregroundStyle(trendColor)
                        trend(model.state.trendPercent)
                    }
                }
            }
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

    // ── Breakdowns ───────────────────────────────────────────────────────────

    private var categories: some View {
        Section(Loc.string("Categories", locale: locale)) {
            let total = model.state.categoryBreakdown.values.reduce(0, +)
            // Shown even for a period with nothing in it, like the time-of-day and
            // weekday sections above: an empty ring is "you drank nothing", a
            // vanished section is "this app has no such feature". The reader cannot
            // tell the second from a bug. Android hides its card here; that is the
            // divergence, and it is deliberate.
            VStack(spacing: 12) {
                // A ring, not a pie: the hole is what makes proportions readable
                // without a scale. .ratio(0.62) is Android's geometry (a stroke 38 %
                // of the radius) restated the way Swift Charts asks for it, and
                // angularInset gives the hairline gap Android carves out of every
                // sweep so neighbouring slices stay apart when their shares are
                // close.
                Chart(sortedCategories, id: \.category) { slice in
                    SectorMark(
                        angle: .value("Grams", slice.grams),
                        innerRadius: .ratio(0.62),
                        angularInset: 1
                    )
                    .foregroundStyle(CategoryPalette.color(for: slice.category))
                }
                // The built-in legend is hidden: the one below carries grams and
                // percentages too, which Swift Charts' cannot. The arcs themselves
                // are unlabelled, but every slice is named in that legend, and each
                // legend item is combined into one accessibility element -- so the
                // ring is decoration over text, not text replaced by a ring.
                .chartLegend(.hidden)
                .frame(height: 160)

                // Two columns, as on Android. The legend is not decoration: it
                // carries the grams and the percentage the plain list used to show,
                // which is why the list could go.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                    ],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(sortedCategories, id: \.category) { slice in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CategoryPalette.color(for: slice.category))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(name(slice.category))
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(legendValue(slice.grams, of: total))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    /// One legend line: "12.3 g · 45 %", the pairing Android's legend uses.
    private func legendValue(_ grams: Double, of total: Double) -> String {
        let percent = total > 0 ? grams / total * 100 : 0
        let gramsText = Loc.number(grams, fractionDigits: 1, locale: locale)
        let percentText = Loc.number(percent, fractionDigits: 0, locale: locale)
        return "\(gramsText) g · \(percentText) %"
    }

    /// Largest first, so the biggest slice starts at twelve o'clock and the legend
    /// reads top-down in the order the ring reads clockwise.
    private var sortedCategories: [CategorySlice] {
        model.state.categoryBreakdown
            .map { CategorySlice(category: $0.key, grams: $0.value) }
            .sorted { $0.grams > $1.grams }
    }
}

// =============================================================================
// StatsScreen – the hour and weekday charts
// =============================================================================
//
// Two more chart sections, in an extension for the same length-budget reason as
// the formatting helpers below (SwiftLint `type_body_length`).
// =============================================================================

extension StatsScreen {

    fileprivate var timeOfDay: some View {
        Section(Loc.string("Time of Day", locale: locale)) {
            Chart(hourPoints) { point in
                BarMark(
                    x: .value("Hour", point.label),
                    y: .value("Grams per day", point.average)
                )
            }
            .chartYAxisLabel(Loc.string("g / day", locale: locale))
            .frame(height: 140)
        }
    }

    /// Named rather than a tuple: `Chart` wants `Identifiable`, and a key path
    /// into a tuple element is not something to rely on.
    fileprivate var hourPoints: [HourPoint] {
        model.state.hourBucketAverages.enumerated().map { index, average in
            HourPoint(id: index, label: bucketLabel(index), average: average)
        }
    }

    /// "00", "03" … "21". The bucket covers three hours starting there.
    fileprivate func bucketLabel(_ index: Int) -> String {
        String(format: "%02d", index * 3)
    }

    fileprivate var weekdays: some View {
        Section(Loc.string("Weekday", locale: locale)) {
            Chart(weekdayPoints) { point in
                BarMark(
                    x: .value("Weekday", point.label),
                    y: .value("Grams", point.average)
                )
            }
            .chartYAxisLabel(Loc.string("g", locale: locale))
            .frame(height: 140)
        }
    }

    /// Columns whose average is nil are DROPPED, not drawn as zero: that weekday
    /// never occurred in the period, which is not the same as a dry weekday.
    fileprivate var weekdayPoints: [WeekdayPoint] {
        zip(model.state.weekdayOrder, model.state.weekdayAverages)
            .compactMap { iso, average in
                average.map { WeekdayPoint(id: iso, label: weekdaySymbol(iso), average: $0) }
            }
    }
}

// =============================================================================
// Presentation helpers
// =============================================================================
//
// These live in a same-file extension rather than the main type so that
// `StatsScreen`'s body stays within SwiftLint's `type_body_length`. A same-file
// extension shares the type's `private` scope, so the view code above still
// reaches them.
// =============================================================================

extension StatsScreen {
    private func weekdaySymbol(_ iso: Int) -> String {
        let symbols = DateFormatter().shortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return "" }
        return symbols[iso == 7 ? 0 : iso]
    }

    private func name(_ category: DrinkCategory) -> String {
        Loc.string(category.categoryDisplayKey, locale: locale)
    }
}

// =============================================================================
// StatsScreen – value formatting
// =============================================================================
//
// The small view-builders that turn a number into its labelled, coloured cell.
// In an extension (not the main type body) so they do not count against the
// type's length budget — the split SwiftLint's `type_body_length` asks for.
// =============================================================================

extension StatsScreen {

    fileprivate func grams(_ value: Double) -> some View {
        Text("\(Loc.number(value, fractionDigits: 1, locale: locale)) g").monospacedDigit()
    }

    fileprivate func trend(_ value: Double) -> some View {
        Text("\(Loc.number(value, fractionDigits: 1, locale: locale, signed: true)) %").monospacedDigit()
    }

    fileprivate func count(_ value: Int) -> some View {
        // Red when the limit was breached on any day, green when it held — the
        // same two-colour cue Android's StatRow uses for the days-over rows.
        Text("\(value)")
            .monospacedDigit()
            .foregroundStyle(value > 0 ? Color.red : Color.green)
    }

    fileprivate func days(_ value: Int) -> some View {
        // The plural noun is part of the value now, so it agrees with the count in
        // every language: "1 day" / "7 days", "1 Tag" / "7 Tage", the four Polish
        // forms, the single Japanese one. The catalogue inflects; the view only asks.
        Text(Loc.daysPlural(count: value, locale: locale)).monospacedDigit()
    }

    /// Like `days`, but green when positive — the achievement colour Android
    /// gives the current streak and the dry-day count. Grey at zero (nothing to
    /// celebrate yet), never red: a low streak is not a failure state.
    fileprivate func daysColored(_ value: Int) -> some View {
        Text(Loc.daysPlural(count: value, locale: locale))
            .monospacedDigit()
            .foregroundStyle(value > 0 ? Color.green : Color.secondary)
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

// =============================================================================
// StatsScreen – the consumption chart
// =============================================================================
//
// In an extension for the same length-budget reason as the sections below
// (SwiftLint `type_body_length`): the 0.83.0 QA round gave this chart its
// daily-limit rule and its over-limit colouring, and that pushed the view's body
// past the limit. The seam is a real one — this is the one chart the screen is
// opened for.
// =============================================================================

extension StatsScreen {

    /// Whether the daily-limit line is meaningful for the period on screen.
    ///
    /// The YEAR view's buckets are per-month averages of grams per day, and a
    /// DAILY limit is not the reference those are read against — so Android passes
    /// `showLimitLine = false` there (`StatsScreen.kt`: `showLimitLine = !isYear`)
    /// and reddens no bar either. This mirrors that, including the coupling: the
    /// line and the reddening are one decision, not two.
    private var showsLimitLine: Bool { model.state.period != .year }

    /// The colour of one consumption bar.
    ///
    /// `isOverLimit` rather than a bare `>`: the totals are summed from a 0.1 g
    /// grid and float drift puts an exactly-at-limit day either side of a strict
    /// comparison. The predicate carries the 1e-6 epsilon both platforms share, so
    /// the bar reddens on exactly the days the days-over-limit count above it
    /// counts — the alternative is a screen that contradicts itself.
    private func barColor(for bucket: ChartBucket) -> Color {
        guard showsLimitLine else { return Color.accentColor }
        let over = AlcoholCalculator.isOverLimit(
            totalGrams: bucket.avgPerDay,
            limitGrams: model.state.limitInfo.limitGrams
        )
        // Color.red / Color.green, not Android's hand-tuned hexes: this screen
        // already reads the system semantic colours (the trend arrow, the
        // days-over counts, the dry-day ticks). Same meaning, native palette —
        // the porting stance the rest of the app takes.
        return over ? Color.red : Color.accentColor
    }

    fileprivate var consumptionChart: some View {
        Section(Loc.string("Consumption", locale: locale)) {
            // `Chart { ForEach ... }` rather than `Chart(data, id:)`: the limit
            // rule is a mark that belongs to the chart, not to a bucket, so it
            // has to sit beside the loop rather than inside it.
            Chart {
                ForEach(model.state.chartBuckets, id: \.labelDate) { bucket in
                    if bucket.isAbstinent {
                        // A dry day has zero height, so a bar would be invisible. Android
                        // draws a small green check-mark at the baseline to say "dry",
                        // not "missing"; this is the Swift Charts equivalent — a point at
                        // y = 0 carrying a green checkmark symbol.
                        PointMark(
                            x: .value("Date", bucket.labelDate),
                            y: .value("Grams per day", 0)
                        )
                        .symbol {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.green)
                        }
                        .foregroundStyle(Color.green)
                    } else {
                        BarMark(
                            x: .value("Date", bucket.labelDate),
                            y: .value("Grams per day", bucket.avgPerDay)
                        )
                        .foregroundStyle(barColor(for: bucket))
                    }
                }
                if showsLimitLine {
                    // The daily limit, as a dashed red rule across the plot area —
                    // Android has drawn one since the chart existed, and until the
                    // 0.83.0 QA round iOS drew every bar in the accent colour with
                    // no reference line at all: the screen showed the numbers but
                    // not the one line that says what they mean. The state already
                    // carried `limitInfo`; nothing read it. The app's own PDF report
                    // draws this line too (`ReportRendererRows`).
                    //
                    // The constant-y form spans the plotting area, which is what a
                    // threshold wants. The label passed to `.value` is what Swift
                    // Charts speaks to VoiceOver.
                    RuleMark(
                        y: .value("Daily limit", model.state.limitInfo.limitGrams)
                    )
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
            }
            .chartXAxis {
                // Labels only every few buckets: 31 dates do not fit.
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .chartYAxisLabel(Loc.string("g / day", locale: locale))
            .frame(height: 180)
        }
    }
}
