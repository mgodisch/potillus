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

import PotillusKit
import SwiftUI

// =============================================================================
// ExportRangeSheet – which days go into the file
// =============================================================================
//
// Android asks before every export, CSV and PDF alike: a full-screen date-range
// picker, pre-filled with the "statistics from" date and today, with future days
// greyed out. The exported range is INDEPENDENT of the period shown on screen —
// you may be looking at this month and export the whole year.
//
// The first iOS draft silently exported whatever window the statistics screen
// happened to show, and disabled the button when that window was empty. Importing
// a backup of last spring and finding the export button greyed out in July is not
// a bug in the data; it is a bug in the question the app failed to ask.
//
// SwiftUI has no range picker, so this is two `DatePicker`s. The native idiom for
// the same question, which is the rule this port follows: same information
// architecture, native controls.
//
// ON UTC NOON
//   `DayResolver` anchors every logical day at 12:00 UTC, so that a day survives
//   any time-zone shift and any daylight-saving jump. `DatePicker` shows a `Date`
//   in the device's zone. Noon-UTC lands on the same calendar day everywhere from
//   UTC-11 to UTC+12, which is every zone in use. The conversion back is
//   `DayResolver.formatDate`, which reads the date in UTC. Round-trip is exact.
// =============================================================================

struct ExportRangeSheet: View {

    /// What the confirmed range will be used for. The sheet does not care; the
    /// caller does, and carrying it here keeps one sheet instead of two.
    /// `Identifiable` because `.sheet(item:)` wants it; the case IS the identity.
    enum Kind: Equatable, Identifiable {
        case csv
        case pdf

        var id: Self { self }

        var title: String {
            switch self {
            case .csv: return "Export CSV"
            case .pdf: return "Export PDF report"
            }
        }
    }

    let kind: Kind

    /// The latest selectable day: the logical today, not the wall-clock one.
    let latest: Date

    let onConfirm: (_ from: String, _ to: String) -> Void
    let onCancel: () -> Void

    @State private var from: Date
    @State private var to: Date

    init(
        kind: Kind,
        initialFrom: Date,
        initialTo: Date,
        latest: Date,
        onConfirm: @escaping (_ from: String, _ to: String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.kind = kind
        self.latest = latest
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _from = State(initialValue: min(initialFrom, latest))
        _to = State(initialValue: min(initialTo, latest))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "From",
                        selection: $from,
                        in: ...latest,
                        displayedComponents: .date
                    )
                    // The lower bound is `from`, so an inverted range cannot be
                    // expressed. Android greys out the same days; this control
                    // refuses to scroll to them at all.
                    DatePicker(
                        "To",
                        selection: $to,
                        in: from...latest,
                        displayedComponents: .date
                    )
                } footer: {
                    Text("Days after today cannot be selected.")
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        onConfirm(DayResolver.formatDate(from), DayResolver.formatDate(to))
                    }
                }
            }
        }
        // Raising `from` past `to` would leave `to` outside its own bounds, which
        // SwiftUI clamps silently on the next layout. Doing it here means the value
        // the user sees is the value that will be exported.
        .onChange(of: from) { _, newValue in
            if to < newValue { to = newValue }
        }
    }
}
