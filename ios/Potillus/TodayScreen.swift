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

import PotillusKit
import SwiftUI

// =============================================================================
// TodayScreen.swift – layout only
// =============================================================================
//
// Every number on this screen is computed by `TodayModel` in the kit, where it is
// under test. This file decides where things sit, and nothing else. If a
// calculation appears here, it belongs somewhere else.
//
// Strings are English literals for now; they become String Catalog keys when the
// 21 locales are ported.
// =============================================================================

struct TodayScreen: View {

    /// The chosen language, applied at the root; every label resolves against it.
    @Environment(\.appLocale) private var locale

    /// Observed so a return from the background reloads at once (below).
    @Environment(\.scenePhase) private var scenePhase

    /// Owned by the view, rebuilt only when the environment changes.
    @State private var model: TodayModel

    /// Set while the entry sheet is open.
    @State private var isLogging = false

    /// Kept so the overflow menu's Settings sheet can be built; the screen owns
    /// its own model.
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: TodayModel(
            entries: environment.entries,
            drinks: environment.drinks,
            preferences: environment.preferences,
            clock: environment.clock
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                if !model.state.favorites.isEmpty { favouritesSection }
                entriesSection
            }
            .navigationTitle(Loc.string("Today", locale: locale))
            .appOverflowMenu(environment: environment)
            .toolbar {
                // iOS puts the primary action in the toolbar; Android uses a
                // floating action button. Same action, native placement.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isLogging = true
                    } label: {
                        Label(Loc.string("Log a drink", locale: locale), systemImage: "plus")
                    }
                    .disabled(model.state.drinks.isEmpty)
                    .accessibilityIdentifier("nav.addDrink")
                }
            }
            .task { model.start() }
            .onDisappear { model.stop() }
            // A return from the background reloads immediately. `onAppear` does
            // not fire on foregrounding (the view never disappeared), and the
            // model's ticker bounds staleness only to a minute -- after a night
            // in the app switcher the screen would show yesterday for up to
            // that long. Android gets this for free from its lifecycle-aware
            // flow collection; this is the SwiftUI equivalent.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.load() } }
            }
            .refreshable { await model.load() }
            .sheet(isPresented: $isLogging) {
                EntrySheet(
                    drinks: model.state.drinks,
                    // People tend to repeat what they just had.
                    preselected: model.state.lastUsedDrink,
                    now: Date(),
                    // The Today model already holds the day's totals and limits,
                    // so the log sheet gets the capacity dot too, as on Android.
                    capacity: DrinkCapacity(
                        todayGrams: model.state.totalGrams,
                        dailyLimitGrams: model.state.limitInfo.limitGrams,
                        weeklyTotalGrams: model.state.weeklyTotalGrams,
                        weeklyLimitGrams: model.state.limitInfo.weeklyLimitGrams,
                        drinkDaysThisWeek: model.state.drinkDaysThisWeek,
                        maxDrinkDaysPerWeek: model.state.limitInfo.maxDrinkDaysPerWeek
                    ),
                    useSymbols: model.state.settings.alternativeStatusSymbols
                ) { drink, volume, millis, note in
                    await model.addEntry(
                        drink: drink, volumeMl: volume, timestampMillis: millis, note: note
                    )
                    return model.failure == nil
                }
            }
            .alert(
                Loc.string("Something went wrong", locale: locale),
                isPresented: .constant(model.failure != nil),
                presenting: model.failure
            ) { _ in
                Button(Loc.string("OK", locale: locale), role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    // ── Sections ─────────────────────────────────────────────────────────────

    private var summarySection: some View {
        Section {
            // Headline pair, mirroring Android's Today card: today's own gram
            // total on the left, the month-so-far per-day average (with its
            // trend arrow) on the right. On iOS these used to be missing (the
            // total entirely) or placed below the bars (the average); the
            // 0.83.0 UI-parity pass lifts them here so someone who switches
            // platforms reads the same two numbers in the same place. They are
            // a `LabeledContent` each so VoiceOver announces caption + value.
            LabeledContent {
                headlineValue(grams(model.state.totalGrams))
            } label: {
                Text(Loc.string("Today's Total", locale: locale))
            }

            LabeledContent {
                HStack(spacing: 4) {
                    headlineValue(perDay(model.state.monthlyAvgPerDay))
                    // The arrow only when the month differs from the pre-month
                    // baseline; `.flat` means no baseline or no real change.
                    if model.state.monthTrend != .flat {
                        Image(systemName: monthTrendSymbol).foregroundStyle(monthTrendColor)
                    }
                }
            } label: {
                Text(monthlyAverageCaption)
            }

            LimitBar(
                caption: Loc.string("Today", locale: locale),
                value: grams(model.state.totalGrams),
                limit: grams(model.state.limitInfo.limitGrams),
                fill: LimitGauge.fillFraction(
                    totalGrams: model.state.totalGrams,
                    limitGrams: model.state.limitInfo.limitGrams
                ),
                emphasis: LimitGauge.emphasis(
                    totalGrams: model.state.totalGrams,
                    limitGrams: model.state.limitInfo.limitGrams
                )
            )

            LimitBar(
                caption: sevenDayCaption,
                value: grams(model.state.weeklyTotalGrams),
                limit: grams(model.state.limitInfo.weeklyLimitGrams),
                fill: LimitGauge.fillFraction(
                    totalGrams: model.state.weeklyTotalGrams,
                    limitGrams: model.state.limitInfo.weeklyLimitGrams
                ),
                emphasis: LimitGauge.emphasis(
                    totalGrams: model.state.weeklyTotalGrams,
                    limitGrams: model.state.limitInfo.weeklyLimitGrams
                )
            )

            LimitBar(
                caption: Loc.string("Drinking Days (last 7 days)", locale: locale),
                value: "\(model.state.drinkDaysThisWeek)",
                limit: "\(model.state.limitInfo.maxDrinkDaysPerWeek)",
                fill: LimitGauge.drinkDaysFillFraction(
                    drinkDays: model.state.drinkDaysThisWeek,
                    maxDrinkDays: model.state.limitInfo.maxDrinkDaysPerWeek
                ),
                // Today's own status decides the colour. A day already spent as
                // a drink day costs nothing further, so a full bar can stay amber;
                // a dry day at the cap means the next drink spends a day the user
                // does not have, and the bar goes red.
                emphasis: LimitGauge.drinkDaysEmphasis(
                    drinkDays: model.state.drinkDaysThisWeek,
                    maxDrinkDays: model.state.limitInfo.maxDrinkDaysPerWeek,
                    todayIsDrinkDay: model.state.totalGrams > 0
                )
            )

            // Absent rather than zero: without a body weight, or with nothing
            // alcoholic logged, the app does not know — and must not imply 0.0.
            if let bac = model.state.bacPermille {
                LabeledContent(Loc.string("BAC Estimate", locale: locale)) {
                    Text("\(Loc.number(bac, fractionDigits: 2, locale: locale)) ‰").monospacedDigit()
                }
            }
        }
    }

    /// A headline figure in the summary pair: the same monospaced-digit,
    /// title-weight styling for the total and the average so the two read as a
    /// matched pair, echoing Android's `headlineLarge` figures.
    private func headlineValue(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .monospacedDigit()
    }

    /// One tap logs the favourite at its own serving size — the shortcut the
    /// whole screen exists for. The sheet is for anything else.
    private var favouritesSection: some View {
        Section(Loc.string("Quick Selection Favorites", locale: locale)) {
            ForEach(model.state.favorites, id: \.id) { drink in
                Button {
                    Task { await model.addEntry(drink: drink, volumeMl: drink.volumeMl) }
                } label: {
                    LabeledContent(drink.name) {
                        Text("\(drink.volumeMl) ml")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var entriesSection: some View {
        Section(Loc.string("Today's Entries", locale: locale)) {
            if model.state.entries.isEmpty {
                Text(Loc.string("No entries yet today.\nTap “+” to add an entry.", locale: locale))
                    .foregroundStyle(.secondary)
            }
            ForEach(model.state.entries, id: \.id) { entry in
                LabeledContent(entry.drinkName) {
                    Text(grams(entry.gramsAlcohol)).monospacedDigit()
                }
            }
            .onDelete { offsets in
                let doomed = offsets.map { model.state.entries[$0] }
                Task { for entry in doomed { await model.deleteEntry(entry) } }
            }
        }
    }

    // ── Formatting ───────────────────────────────────────────────────────────

    /// Grams, one decimal, in the in-app locale; this is display text, not the
    /// export's fixed POSIX format.
    private func grams(_ value: Double) -> String {
        "\(Loc.number(value, fractionDigits: 1, locale: locale)) g"
    }
}

// Formatting that depends on the in-app locale lives here, off the view body, so
// the body stays within its length budget. `private` is file scope in Swift, so
// a same-file extension still sees the view's `locale` and `model`.
extension TodayScreen {

    /// "Ø <month>" — the average caption. The standalone month name of the logical
    /// day resolves in the in-app locale (Foundation, no catalogue entry); the
    /// "Ø %@" wrapper is the catalogue's, shared with Android's `avg_of_month`.
    private var monthlyAverageCaption: String {
        Loc.string("Ø %@", monthName(model.state.logicalDate), locale: locale)
    }

    /// Standalone month name of a `yyyy-MM-dd` date in the in-app locale, or "".
    /// Standalone is the grammatically correct bare form in cased languages.
    private func monthName(_ isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), (1...12).contains(month) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.standaloneMonthSymbols ?? []
        guard symbols.count == 12 else { return "" }
        return symbols[month - 1]
    }

    /// A per-day gram value with its localized "g/day" unit.
    private func perDay(_ value: Double) -> String {
        "\(Loc.number(value, fractionDigits: 1, locale: locale)) \(Loc.string("g/day", locale: locale))"
    }

    /// The trend arrow's SF Symbol. Only read when the trend is not `.flat`.
    private var monthTrendSymbol: String {
        model.state.monthTrend == .down ? "arrow.down.right" : "arrow.up.right"
    }

    /// Down is the good direction — less alcohol. A rising trend is not a success.
    private var monthTrendColor: Color {
        model.state.monthTrend == .down ? .green : .red
    }

    /// "7 Days (weekStart–logicalDate)" — the trailing window plus its date range.
    private var sevenDayCaption: String {
        let base = Loc.string("7 Days", locale: locale)
        let range = weekRange(model.state.weekStart, model.state.logicalDate)
        return range.isEmpty ? base : "\(base) (\(range))"
    }

    /// A localized "start–end" range, day and month only, ordered per locale. The
    /// dates are logical `yyyy-MM-dd` values parsed in UTC, so the formatter reads
    /// them in UTC too and cannot shift a day across the device's time zone.
    private func weekRange(_ start: String, _ end: String) -> String {
        guard let from = DayResolver.parseDate(start), let to = DayResolver.parseDate(end) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("dM")
        return "\(formatter.string(from: from))–\(formatter.string(from: to))"
    }
}

// =============================================================================
// LimitBar – a labelled progress bar
// =============================================================================
//
// Layout and colour. Both the fill and the emphasis are decided by `LimitGauge`
// in the kit, where they are tested: the fill is clamped so the bar cannot
// overflow its track, while the emphasis comes from the unclamped value so a
// 130 % day still reads as red.
// =============================================================================

struct LimitBar: View {
    let caption: String
    let value: String
    let limit: String
    let fill: Double
    let emphasis: Emphasis

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label order mirrors Android's LimitBar: the CONSUMED value sits on
            // the left, the caption (with its limit) on the right. iOS
            // previously had the caption on the left and the value on the
            // right; the 0.83.0 UI-parity pass flips them so the two platforms
            // read alike. The right group is pinned to one line and allowed to
            // shrink rather than wrap into the value — the rule Android's
            // layout hardening settled on for Greek and Russian.
            HStack {
                Text(value)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text("\(caption) · \(limit)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.subheadline)

            // A thicker track than the default hairline ProgressView, to match
            // Android's 8dp bar. A capsule of fixed height drawn over a track
            // capsule gives full control of the thickness that a plain
            // `ProgressView` does not expose.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                    Capsule()
                        .fill(emphasis.tint)
                        .frame(width: proxy.size.width * fill)
                }
            }
            .frame(height: 8)
            // The bar is decoration; the numbers above already say it.
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }
}

extension Emphasis {
    /// The colour band. `.accentColor` follows the app tint, so a calm bar is
    /// calm in both light and dark mode without a hand-picked hex value.
    var tint: Color {
        switch self {
        case .calm: return .accentColor
        case .warning: return .orange
        case .danger: return .red
        }
    }
}
