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
// SettingsScreen - the Statistics section
// =============================================================================
//
// Split from SettingsScreen.swift the way StatsScreenPeriod was split from
// StatsScreen: the view outgrew SwiftLint's type-body limit, and this section is
// the seam that offered itself. It holds the two rows Android groups under
// Statistics - when a day begins, and how far back the figures reach - plus the
// sheet the second one opens.
// =============================================================================

extension SettingsScreen {

    // ── The logical day ──────────────────────────────────────────────────────
    // The day-change time now lives inside the Statistics section (below),
    // matching Android, where it is the first row of that section.

    /// The stored hour and minute, as a `Date` the picker can edit. Only the time
    /// components are read back, so the date part is irrelevant.
    private var dayChangeDate: Date {
        var components = DateComponents()
        components.hour = model.settings.dayChangeHour
        components.minute = model.settings.dayChangeMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    // ── Statistics floor ─────────────────────────────────────────────────────

    // `body` in SettingsScreen.swift inserts this one, so it is internal;
    // `private` would not reach across the file boundary. The three helpers
    // below are used only here and stay private, as StatsScreenExport does.
    var statisticsSection: some View {
        Section {
            // The day-change time — Android's first Statistics row. An inline
            // hour/minute picker, iOS-idiomatic (Android opens a dialog).
            DatePicker(
                Loc.string("New Day Starts At", locale: locale),
                selection: Binding(
                    get: { dayChangeDate },
                    set: { newValue in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        Task {
                            await model.update {
                                $0.dayChangeHour = parts.hour ?? 4
                                $0.dayChangeMinute = parts.minute ?? 0
                            }
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )

            // THE FLOOR HAS THREE STATES AND A `DatePicker` CAN SHOW TWO.
            //   "No floor" is a value the user chooses: "Include all history"
            //   writes the empty string, and both platforms store it AS a value.
            //   Android's `toAppSettings` maps only a MISSING key to the install
            //   date, so a stored "" survives the next launch instead of decaying
            //   back into a floor.
            //
            //   A `DatePicker` has no empty state. The row therefore fell back to
            //   today and displayed a floor that was not set — and a stray scroll
            //   on the wheel then set it for real. Two states shown where there
            //   are three, and the missing one silently overwritten.
            //
            //   Android's row shows the date only while one is set
            //   (`SettingsScreen.kt`: `if (settings.statsFromDate.isNotEmpty())`)
            //   and opens its picker from a pencil that is always present. This
            //   row is the same shape: it states what is true, and the sheet is
            //   reachable either way. That preserves what the inline picker was
            //   introduced for in 0.83.0 — a way back to picking a date after
            //   clearing — without the control having to invent a value.
            Button {
                statsFloorDraft = Self.day(from: model.settings.statsFromDate) ?? Date()
                isPickingStatsFloor = true
            } label: {
                LabeledContent(Loc.string("Statistics From", locale: locale)) {
                    Text(statsFloorValue)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            if model.hasStatsFloor {
                Button(Loc.string("Include all history", locale: locale), role: .destructive) {
                    Task { await model.clearStatsFromDate() }
                }
            }
        } header: {
            Text(Loc.string("Statistics", locale: locale))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                // The day-change footnote (kept from the old day-change section).
                Text(Loc.string("A drink logged before this time counts towards the previous day.", locale: locale))
                // Only while a floor is set: without one there is no such date,
                // and the sentence would state a rule that is not in force.
                if model.hasStatsFloor {
                    Text(Loc.string("Entries before this date are ignored in all statistics.", locale: locale))
                }
            }
        }
        .sheet(isPresented: $isPickingStatsFloor) { statsFloorSheet }
    }

    /// What the row states: the date, or that there is no floor.
    ///
    /// A `String` computed outside the view builder rather than a conditional
    /// inside `Text`. A ternary in a `ViewBuilder` is a known way to send Swift's
    /// type checker off for a long walk — "unable to type-check this expression in
    /// reasonable time" — and this one sits inside a `Button` label inside a
    /// `LabeledContent` inside a `Form`, which is exactly the depth where that
    /// bites.
    private var statsFloorValue: String {
        model.hasStatsFloor ? statsFloorText : Loc.string("All history", locale: locale)
    }

    /// The floor as the in-app locale writes it, medium style — the same style the
    /// statistics screen's period label uses, so one date reads alike in both.
    private var statsFloorText: String {
        guard let day = Self.day(from: model.settings.statsFromDate) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: day)
    }

    /// Picking a floor.
    ///
    /// The draft is committed on Done and dropped on Cancel, so opening the sheet
    /// out of curiosity sets nothing. The inline picker it replaces had no such
    /// step: it wrote on every change of the wheel.
    private var statsFloorSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    Loc.string("Statistics From", locale: locale),
                    selection: $statsFloorDraft,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
            .navigationTitle(Loc.string("Statistics From", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.string("Cancel", locale: locale)) { isPickingStatsFloor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Loc.string("Done", locale: locale)) {
                        let picked = Self.isoDay(from: statsFloorDraft)
                        isPickingStatsFloor = false
                        Task { await model.update { $0.statsFromDate = picked } }
                    }
                }
            }
        }
    }
}
