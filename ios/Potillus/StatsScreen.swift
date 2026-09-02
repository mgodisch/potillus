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
    /// Foreseeable export failures carry a localized message of their own (an
    /// empty period, an unreadable window — see `StatsScreenExport`); everything
    /// else goes through `describeExportFailure`, which wraps the technical
    /// description in a localized frame. Both are shown by the alert below, whose
    /// title was localized all along.
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
                periodRange
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
            // NO DRAG GESTURE HERE. A swipe across the whole screen used to move
            // the period as well; the arrows in `periodRange` are now the only way,
            // on Android too. A gesture with no affordance has to be known before
            // it can be found, and this one lay over every chart and figure on the
            // screen, where a sideways wobble during vertical scrolling could move
            // the period unasked. The arrows are visible and say which way they go.
            // Entering the screen returns to the current period. `onAppear` fires
            // on a tab change and not on a rotation, which does not rebuild the
            // view here — so no marker is needed, unlike on Android (see
            // StatsScreen.kt).
            .onAppear { Task { await model.resetToCurrentPeriod() } }
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
                    exportFailure = describeExportFailure(error)
                }
            }
            .fileExporter(
                isPresented: $isExportingPdf,
                document: exportedPdf,
                contentType: .pdf,
                defaultFilename: ReportJob.fileName(date: Date())
            ) { result in
                if case .failure(let error) = result {
                    exportFailure = describeExportFailure(error)
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
    // vocabulary. The period is NOT repeated in a section header: it already
    // stands above the cards, formatted for the in-app locale, and the header
    // spelled the same window a second time in raw ISO dates.

    private var keyMetrics: some View {
        Section {
            metricRow(
                Loc.string("Total in Period", locale: locale),
                spokenLabel: gramsSpoken("Total in Period", model.state.totalGrams)
            ) { grams(model.state.totalGrams) }
            metricRow(
                Loc.string("Average per Day", locale: locale),
                spokenLabel: gramsSpoken("Average per Day", model.state.averagePerDay)
            ) { grams(model.state.averagePerDay) }
            metricRow(
                Loc.string("Average per Drinking Day", locale: locale),
                spokenLabel: gramsSpoken("Average per Drinking Day", model.state.averagePerDrinkDay)
            ) {
                grams(model.state.averagePerDrinkDay)
            }
            metricRow(Loc.string("Days Over Daily Limit", locale: locale)) {
                count(model.state.daysOverDailyLimit)
            }
            metricRow(Loc.string("Days Over 7-Day Limit", locale: locale)) {
                count(model.state.daysOverWeeklyLimit)
            }
            metricRow(Loc.string("Days Over Drinking Days Limit", locale: locale)) {
                count(model.state.daysOverDrinkDayLimit)
            }
            metricRow(Loc.string("Abstinent Days", locale: locale)) {
                // Green when positive, plain at zero — never red: a dry-day count
                // is an achievement, not a limit breach. `count` is for the
                // days-over rows (red/green); this needs green/plain.
                Text("\(model.state.abstinentDays)")
                    .monospacedDigit()
                    .foregroundStyle(model.state.abstinentDays > 0 ? Color.green : Color.secondary)
            }
        }
    }

    // ── Abstinence & trend (Android's second card) ───────────────────────────

    private var streaksAndTrend: some View {
        Section(Loc.string("Abstinence & Trend", locale: locale)) {
            // Today is excluded from the current streak: the day is not over, and a
            // drink may still be logged. Green when positive, like Android.
            metricRow(Loc.string("Current Abstinence", locale: locale)) {
                daysColored(model.state.currentStreak)
            }
            metricRow(Loc.string("Longest Abstinence", locale: locale)) {
                daysColored(model.state.longestStreak)
            }
            // The trend belongs in this card on Android, not up in the metrics.
            // Hidden, not zeroed: without a previous period there is nothing to
            // compare against, and "0 %" would claim there was.
            if model.state.hasBaseline {
                // The visible label abbreviates ("Trend ggü. Vorperiode" in
                // German, and Android carries the same short form), which a
                // reader meets as spelled-out letters. The spoken label writes it
                // out; the arrow stays silent, as on the Today screen, because it
                // repeats the sign of the number beside it.
                //
                // Stated through MetricRow rather than as modifiers on the row:
                // MetricRow now speaks as one element for every metric, and a
                // second `accessibilityElement` wrapped around the outside would
                // leave two descriptions of one row to argue over.
                metricRow(
                    Loc.string("Trend vs. Previous Period", locale: locale),
                    spokenLabel: Loc.string("Trend compared to previous period", locale: locale),
                    spokenValue: Loc.string(
                        "%1$@ percent",
                        Loc.number(model.state.trendPercent, fractionDigits: 1, locale: locale, signed: true),
                        locale: locale
                    )
                ) {
                    // Arrow and percentage are one value: they travel together
                    // into whichever arrangement MetricRow picks.
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
                // percentages too, which Swift Charts' cannot. The ring itself is
                // hidden from VoiceOver as well — Swift Charts announced each
                // sector as a bare number, so a reader met the shares twice, once
                // stripped of their category and once whole in the legend below.
                // The legend is where this section's content lives.
                .chartLegend(.hidden)
                .frame(height: 160)
                .accessibilityHidden(true)

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
                        // One sentence per slice, in the order the list is
                        // already sorted in: largest share first. Combining the
                        // children would read "12,3 g · 45 %" with the separator
                        // and the units as characters, so the label is stated.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(legendSpoken(slice, of: total))
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

    /// The same line as a sentence: the category, its share, its grams. The share
    /// comes first because it is what the ring shows and what the eye compares;
    /// the visible line leads with the grams, where the column alignment does that
    /// work instead.
    private func legendSpoken(_ slice: CategorySlice, of total: Double) -> String {
        let percent = total > 0 ? slice.grams / total * 100 : 0
        return Loc.string(
            "%1$@: %2$@ percent, %3$@ grams of alcohol",
            name(slice.category),
            Loc.number(percent, fractionDigits: 0, locale: locale),
            Loc.number(slice.grams, fractionDigits: 1, locale: locale),
            locale: locale
        )
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
// StatsScreen – value formatting
// =============================================================================
//
// The small view-builders that turn a number into its labelled, coloured cell.
// In an extension (not the main type body) so they do not count against the
// type's length budget — the split SwiftLint's `type_body_length` asks for.
// =============================================================================

extension StatsScreen {

    fileprivate func grams(_ value: Double) -> some View {
        Text("\(Loc.number(value, fractionDigits: 1, locale: locale)) g")
            .monospacedDigit()
    }

    /// "Total in Period: 123.4 grams of alcohol" — the row as one sentence.
    ///
    /// The drawn value ends in `g`, which a reader gives back as a letter. The
    /// same pattern carries the limit bars and the Today summary on both
    /// platforms, so the figure sounds the same wherever it appears.
    fileprivate func gramsSpoken(_ label: String, _ value: Double) -> String {
        Loc.string(
            "%1$@: %2$@ grams of alcohol",
            Loc.string(label, locale: locale),
            Loc.number(value, fractionDigits: 1, locale: locale),
            locale: locale
        )
    }

    /// The percentage alone; the trend arrow is put beside it at the call site,
    /// and `MetricRow` arranges the pair as one value.
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

    /// Like `days`, but green when positive — the achievement colour Android
    /// gives the streaks and the dry-day count. Never red: a low streak is not a
    /// failure state.
    ///
    /// PLAIN at zero, not grey. Android colours its current streak
    /// `onSurface` at zero (`StatsScreen.kt`), and grey read as "not applicable"
    /// where the figure is simply nought. Both streak rows use this now; the
    /// longest one was left in the default colour and never turned green at all.
    ///
    /// The plural noun is part of the value, so it agrees with the count in every
    /// language: "1 day" / "7 days", "1 Tag" / "7 Tage", the four Polish forms,
    /// the single Japanese one. The catalogue inflects; the view only asks.
    fileprivate func daysColored(_ value: Int) -> some View {
        Text(Loc.daysPlural(count: value, locale: locale))
            .monospacedDigit()
            .foregroundStyle(value > 0 ? Color.green : Color.primary)
    }
}

// =============================================================================
// Chart data points
// =============================================================================
//
// `Chart` and `ForEach` want identifiable values. Tuples are not, and a key path
// into a tuple element is not a promise worth leaning on.
// =============================================================================

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

    /// The category's display name, in the in-app language.
    ///
    /// Belongs beside the ring's legend, which is its only caller — it briefly sat
    /// in StatsScreenCharts.swift, where `DrinkCategory` is not even in scope.
    private func name(_ category: DrinkCategory) -> String {
        Loc.string(category.categoryDisplayKey, locale: locale)
    }

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
    /// "3 August 2026: 3.0 grams of alcohol" — one bar as a sentence.
    ///
    /// Two phrasings, because a bar means two different things. In the week and
    /// month views it is a DAY and its figure is that day's total; in the year
    /// view it is a MONTH and the figure is a mean over the month's days, which
    /// is why no daily-limit line is drawn there either (see [showsLimitLine]).
    /// One wording for both would state a total where an average stands.
    ///
    /// The date is spelled out. The stored form goes to the chart's x value, and
    /// that is what VoiceOver was reading back as digits.
    private func bucketSpoken(_ bucket: ChartBucket) -> String {
        let grams = Loc.number(bucket.avgPerDay, fractionDigits: 1, locale: locale)
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        let parsed = parser.date(from: bucket.labelDate)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        if model.state.period == .year {
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            let month = parsed.map { formatter.string(from: $0) } ?? bucket.labelDate
            return Loc.string(
                "%1$@: %2$@ grams of alcohol per day on average", month, grams, locale: locale
            )
        }
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let day = parsed.map { formatter.string(from: $0) } ?? bucket.labelDate
        return Loc.string("%1$@: %2$@ grams of alcohol", day, grams, locale: locale)
    }

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

    // ── The consumption chart's x-axis ───────────────────────────────────────
    //
    // Android's rule, adopted here so the two charts read alike
    // (`ChartComponents.kt`): up to twelve bars carry a label each, beyond that a
    // handful of evenly spaced ones give the axis context. Which bars exist
    // depends on the period — seven days, twenty-eight to thirty-one days, or
    // twelve months — so the wording follows the period rather than the count.

    /// The bucket dates that get a label. All of them while they fit; otherwise
    /// six evenly spaced, first and last included. The choice is the kit's
    /// (`ReportChart.labelIndices`, pinned by the shared vectors), so the axis
    /// samples the same buckets as Android's chart and the report.
    fileprivate var chartAxisDates: [String] {
        let dates = model.state.chartBuckets.map(\.labelDate)
        return ReportChart
            .labelIndices(count: dates.count, target: ReportChart.screenAxisLabels)
            .map { dates[$0] }
    }

    /// What one bar says about itself: the weekday over a week, the day of the
    /// month over a month, the month's name over a year — Android's `labelFn`,
    /// in the in-app locale.
    fileprivate func chartAxisLabel(for labelDate: String) -> String {
        switch model.state.period {
        case .month:
            // The stored form is `yyyy-MM-dd`, so the last two characters are the
            // day. Taken from the string rather than from a parsed date: it is
            // already in the shape the label wants.
            return String(labelDate.suffix(2))
        case .week, .year:
            guard let date = DayResolver.parseDate(labelDate) else { return "" }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = TimeZone(identifier: "UTC")
            // A template, not a fixed pattern: the locale decides what a short
            // weekday or month name looks like.
            formatter.setLocalizedDateFormatFromTemplate(
                model.state.period == .week ? "EEE" : "MMM"
            )
            return formatter.string(from: date)
        }
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
                            // Smaller than the surrounding chart text on purpose:
                            // the tick marks a dry day, it does not label one, and
                            // at caption2 it drew heavier than Android's baseline
                            // tick (two strokes, capped at 5 dp). `imageScale`
                            // shrinks the glyph WITHIN its text style, so the mark
                            // still grows and shrinks with Dynamic Type — a fixed
                            // point size would freeze it at one accessibility
                            // setting.
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .imageScale(.small)
                                .foregroundStyle(Color.green)
                        }
                        .foregroundStyle(Color.green)
                        // A dry day states its nought rather than falling silent,
                        // so a reader does not take it for a gap in the series.
                        .accessibilityLabel(bucketSpoken(bucket))
                        .accessibilityValue("")
                    } else {
                        BarMark(
                            x: .value("Date", bucket.labelDate),
                            y: .value("Grams per day", bucket.avgPerDay)
                        )
                        .foregroundStyle(barColor(for: bucket))
                        // Swift Charts speaks a mark from its `.value` labels, and
                        // the x value here is the STORED date — "2026 0 8 0 3 0",
                        // the ISO string read digit by digit with the figure after
                        // it. The sentence replaces both, on the mark itself so the
                        // focus lands on the bar it belongs to.
                        .accessibilityLabel(bucketSpoken(bucket))
                        .accessibilityValue("")
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
                // The dates are STRINGS, so this is a nominal axis, and a nominal
                // axis labels every category it is given — `desiredCount` is for
                // a continuous scale and was quietly ignored here, which is how
                // thirty-one dates ended up on top of one another. The values are
                // therefore chosen explicitly.
                AxisMarks(values: chartAxisDates) { value in
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(String.self) {
                            Text(chartAxisLabel(for: date))
                        }
                    }
                }
            }
            .chartYAxisLabel(Loc.string("g / day", locale: locale))
            .frame(height: 180)
        }
    }
}
