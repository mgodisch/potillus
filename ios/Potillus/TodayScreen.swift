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
// Every user-facing string goes through `Loc` against the committed String
// Catalog (21 languages); see Localization.swift for why the environment locale
// alone is not enough.
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

    /// The entry being edited, if any — drives the edit sheet, as on the calendar.
    @State private var editingEntry: ConsumptionEntry?

    /// The entry a delete gesture is asking to remove, if any. Set by the swipe
    /// or the edit-mode badge and cleared by the confirmation alert; a delete is
    /// never performed the instant the gesture fires. This is the parity with
    /// Android, whose Today screen removes an entry only through an `AlertDialog`
    /// (`delete_confirm`) — a consumption record is a fact the user cannot
    /// reconstruct, so it costs a confirmation, not a single stray tap.
    @State private var pendingDeletion: ConsumptionEntry?

    /// The list's edit mode, owned here and injected into the List so the
    /// localized `EditToggleButton` can drive it (see that file: the stock
    /// `EditButton` titles itself in the SYSTEM language, not the app's).
    @State private var editMode: EditMode = .inactive

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
                // The visible way into deletion, as Apple's own list apps do it:
                // the edit toggle puts the list into edit mode, where each row
                // shows a red delete badge. It replaces the per-row trash icon the
                // row used to carry — a control Apple's guidance keeps in an edit
                // mode or a detail view, not stamped on every row. Shown only when
                // there is something to edit, so it never toggles an empty list;
                // localized via EditToggleButton (0.84.0 QA round).
                if !model.state.entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditToggleButton(editMode: $editMode, locale: locale)
                    }
                }
            }
            // Feed the List the edit mode the toggle drives (see
            // EditToggleButton) — and leave edit mode when the last entry goes:
            // the toggle is hidden then, so a stale `.active` would greet the
            // NEXT entry with an unexplained delete badge and no Done button.
            .environment(\.editMode, $editMode)
            .onChange(of: model.state.entries.isEmpty) { _, empty in
                if empty { editMode = .inactive }
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
            .sheet(item: $editingEntry) { entry in
                // Editing keeps the entry's own drink: a one-element catalogue built
                // from the entry, so the sheet shows the name and lets volume, time
                // and note change. The same scope, and the same code, as the
                // calendar's edit — this row is not a lesser row for being today's.
                EntrySheet(
                    drinks: [drink(from: entry)],
                    preselected: drink(from: entry),
                    now: Date(),
                    editing: entry
                ) { drink, volume, millis, note in
                    var updated = entry
                    updated.volumeMl = volume
                    updated.timestampMillis = millis
                    updated.note = note
                    updated.gramsAlcohol = AlcoholCalculator.calculateGrams(
                        volumeMl: volume, alcoholPercent: drink.alcoholPercent
                    )
                    await model.updateEntry(updated)
                    return model.failure == nil
                }
            }
            .alert(
                Loc.string("Something went wrong", locale: locale),
                isPresented: .constant(model.failure != nil),
                presenting: model.failure
            ) { _ in
                // OK acknowledges AND clears: `failure` is `private(set)`, so
                // without this call the alert's still-true `isPresented` binding
                // could re-present it until the next successful load. Mirrors
                // the Drinks and Settings screens' OK buttons.
                Button(Loc.string("OK", locale: locale), role: .cancel) { model.clearFailure() }
            } message: { message in
                Text(message)
            }
            // The delete confirmation, shown by both the swipe and the edit-mode
            // badge. It mirrors Android's Today `AlertDialog`: a red "Delete" and a
            // "Cancel", naming the drink, so removing a logged entry is always a
            // two-step, reversible act. Built like the Drinks screen's own delete
            // alert, down to the `Binding` that clears the pending entry on
            // dismissal.
            .alert(
                Loc.string("Delete", locale: locale),
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { presented in if !presented { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { entry in
                Button(Loc.string("Delete", locale: locale), role: .destructive) {
                    Task { await model.deleteEntry(entry) }
                    pendingDeletion = nil
                }
                Button(Loc.string("Cancel", locale: locale), role: .cancel) {
                    pendingDeletion = nil
                }
            } message: { entry in
                Text(Loc.string("Really delete “%@”?", entry.drinkName, locale: locale))
            }
        }
    }

    // ── Sections ─────────────────────────────────────────────────────────────
    //
    // The summary section sits in the extension below, with the formatting it
    // needs; see the note there.

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
                entryRow(entry)
            }
            // The swipe and the edit-mode badge both land here. Without a
            // `List(selection:)` the edit mode deletes one row at a time, so the
            // set holds a single entry; we take the first and hand it to the
            // confirmation alert rather than deleting on the spot (see
            // `pendingDeletion`).
            .onDelete { offsets in
                if let first = offsets.map({ model.state.entries[$0] }).first {
                    pendingDeletion = first
                }
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

// The summary section and the formatting it depends on live here, off the view
// body, so the body stays within its length budget — the section moved out when
// the spoken labels pushed `TodayScreen` past SwiftLint's type_body_length.
// `private` is file scope in Swift, so a same-file extension still sees the
// view's `locale` and `model`.
extension TodayScreen {

    private var summarySection: some View {
        Section {
            // Headline pair, mirroring Android's Today card: today's own gram
            // total on the left, the month-so-far per-day average (with its
            // trend arrow) on the right. On iOS these used to be missing (the
            // total entirely) or placed below the bars (the average); the
            // 0.83.0 UI-parity pass lifts them here so someone who switches
            // platforms reads the same two numbers in the same place.
            //
            // WHAT THE FIRST ROW SHOWS. Someone who has set out to abstain is
            // served better by the length of the run than by a gram total that
            // reads 0.0 every day, so while a streak is running the caption and
            // the value switch to it, green as on the Statistics screen. Logging
            // a drink puts the streak at 0 and the gram total back, until a full
            // dry day has been completed again.
            //
            // `currentAbstinence > 0` is the whole condition:
            // `DayResolver.computeCurrentAbstinence` returns 0 as soon as today
            // holds alcohol, so a positive value already implies 0.0 g today.
            // Testing the grams as well would be a second source for one
            // decision. Android's Today card switches on the same value.
            //
            // WHY EACH ROW CARRIES ITS OWN SPOKEN LABEL. A `LabeledContent` in a
            // List is TWO accessibility elements, not one: VoiceOver reads the
            // caption, stops, and reads the value as if it belonged to nothing.
            // `children: .ignore` collapses the row to a single element and the
            // label below says the whole sentence. The label also spells out what
            // the eye reads from a symbol — "g" as grams, "Ø" as average — because
            // a screen reader speaks those as the characters they are.
            if model.state.currentAbstinence > 0 {
                LabeledContent {
                    headlineValue(Loc.daysPlural(count: model.state.currentAbstinence, locale: locale))
                        .foregroundStyle(Color.green)
                } label: {
                    Text(Loc.string("Current Abstinence", locale: locale))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Loc.string(
                    "%1$@: %2$@",
                    Loc.string("Current Abstinence", locale: locale),
                    Loc.daysPlural(count: model.state.currentAbstinence, locale: locale),
                    locale: locale
                ))
            } else {
                LabeledContent {
                    headlineValue(grams(model.state.totalGrams))
                } label: {
                    Text(Loc.string("Today's Total", locale: locale))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Loc.string(
                    "%1$@: %2$@ grams",
                    Loc.string("Today's Total", locale: locale),
                    Loc.number(model.state.totalGrams, fractionDigits: 1, locale: locale),
                    locale: locale
                ))
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
            // The trend arrow stays silent: it is a second reading of a number
            // the sentence has just given, and naming it would make every
            // average end in a direction the eye takes in at a glance.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(monthlyAverageSpoken)

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
                ),
                spokenSummary: gramsSpoken(
                    caption: Loc.string("Today", locale: locale),
                    value: model.state.totalGrams,
                    limit: model.state.limitInfo.limitGrams
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
                ),
                // The caption on screen carries the window's dates; the spoken
                // one does not. A date range read out on every pass buries the
                // two figures the row exists for, and the calendar states the
                // same window in a form a reader can navigate.
                spokenSummary: gramsSpoken(
                    caption: Loc.string("7 Days", locale: locale),
                    value: model.state.weeklyTotalGrams,
                    limit: model.state.limitInfo.weeklyLimitGrams
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
                    todayIsDrinkDay: AlcoholCalculator.isDrinkDay(totalGrams: model.state.totalGrams)
                ),
                // The spoken caption is the parenthesis-free form: read aloud, a
                // bracket is either silence or the word "bracket", and neither
                // helps. The counted noun sits in the caption rather than after
                // the limit, so the sentence needs no plural agreement — the app
                // ships 21 languages and four of them inflect this in four ways.
                spokenSummary: Loc.string(
                    "%1$@: %2$@ of at most %3$@",
                    Loc.string("Drinking days, last 7 days", locale: locale),
                    "\(model.state.drinkDaysThisWeek)",
                    "\(model.state.limitInfo.maxDrinkDaysPerWeek)",
                    locale: locale
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

    /// One entry: the drink, its detail line and its note. The whole row is the
    /// edit affordance now — tapping it opens the same sheet the pencil used to.
    ///
    /// The row is a `Button`, not an `HStack` with an `.onTapGesture`, on purpose:
    /// SwiftUI suppresses a row button's action while the list is in edit mode, so
    /// tapping a row to delete it never also opens the editor. The pencil and trash
    /// icons the row used to carry are gone — edit is the row tap, delete is the
    /// swipe or the edit-mode badge — matching how Apple's list apps behave once
    /// the row's primary tap is spoken for.
    private func entryRow(_ entry: ConsumptionEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.drinkName)
                    Text(entryDetail(entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "<time> · <ml> ml · <percent> % · <grams> g" in the in-app locale, the same
    /// fields — and now the same time rendering — the calendar's row shows. The
    /// time uses the device zone (a wall clock the user recognises); its FORMAT
    /// follows the in-app locale via `setLocalizedDateFormatFromTemplate("Hm")`,
    /// so a 12-hour locale reads "6:30 PM" and a 24-hour one "18:30". This used to
    /// be a hard-coded "HH:mm", which showed the same entry as "18:30" here but
    /// "6:30 PM" on the calendar for a 12-hour locale — the two rows claimed to be
    /// identical while disagreeing. They now share the calendar's formatter setup.
    private func entryDetail(_ entry: ConsumptionEntry) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("Hm")
        let time = formatter.string(
            from: Date(timeIntervalSince1970: Double(entry.timestampMillis) / 1000.0)
        )
        let percent = Loc.number(entry.alcoholPercent, fractionDigits: 1, locale: locale)
        let grams = Loc.number(entry.gramsAlcohol, fractionDigits: 1, locale: locale)
        return "\(time) · \(entry.volumeMl) ml · \(percent) % · \(grams) g"
    }

    /// The entry's own drink, rebuilt as a single-item catalogue for the edit
    /// sheet. Editing does not swap the drink, so the id/category are cosmetic.
    private func drink(from entry: ConsumptionEntry) -> DrinkDefinition {
        DrinkDefinition(
            id: entry.drinkId,
            name: entry.drinkName,
            volumeMl: entry.volumeMl,
            alcoholPercent: entry.alcoholPercent
        )
    }

    /// What VoiceOver says for a gram bar: "<caption>: <value> of at most <limit>
    /// grams". The numbers arrive as `Double`s and are formatted here rather than
    /// taken from the visible strings, because those carry a "g" that a reader
    /// speaks as the letter.
    private func gramsSpoken(caption: String, value: Double, limit: Double) -> String {
        Loc.string(
            "%1$@: %2$@ of at most %3$@ grams",
            caption,
            Loc.number(value, fractionDigits: 1, locale: locale),
            Loc.number(limit, fractionDigits: 1, locale: locale),
            locale: locale
        )
    }

    /// "Average <month>: <value> grams per day" — the spoken form of the caption
    /// and value above. The visible pair abbreviates both halves ("Ø", "g/day");
    /// spelled out they are the same sentence a sighted user reads at a glance.
    private var monthlyAverageSpoken: String {
        Loc.string(
            "Average %1$@: %2$@ grams per day",
            monthName(model.state.logicalDate),
            Loc.number(model.state.monthlyAvgPerDay, fractionDigits: 1, locale: locale),
            locale: locale
        )
    }

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

    /// The whole row as one sentence, for VoiceOver. The caller assembles it,
    /// because only the caller still has the raw numbers: by the time they reach
    /// `value` and `limit` they are display strings carrying a "g", and the
    /// caption may carry a date range that is worth showing and not worth saying.
    /// Without this the row was three elements — the value, the "caption · limit"
    /// pair, and nothing at all for the bar — and a reader met the figures with no
    /// statement of which limit they belonged to.
    let spokenSummary: String

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
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
