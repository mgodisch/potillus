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

import SwiftUI

// =============================================================================
// AboutScreen — the app's name, version, and the licences it must show.
//
// Reached from Settings. COPYING.md requires the iOS app to reproduce GRDB's
// licence here before release, as Android already does. This shows the app's own
// GPL notice, the GRDB MIT notice verbatim, and a link into the full combined
// copyright/GPL document (the same text Android bundles).
// =============================================================================

struct AboutScreen: View {

    @Environment(\.appLocale) private var locale

    var body: some View {
        List {
            Section {
                LabeledContent(Loc.string("Version", locale: locale), value: AppInfo.version)
            } header: {
                // The Latin title of the work, centred above the version, is the
                // app's identity — not a localised string.
                Text(AppInfo.name)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textCase(nil)
                    .padding(.bottom, 4)
            }

            Section(Loc.string("Licence", locale: locale)) {
                Text(Loc.string(
                    "Libellus Potionis is free software under the GNU GPL, version 3 or later.",
                    locale: locale
                ))
                .font(.footnote)
                NavigationLink(Loc.string("Copyright & licence", locale: locale)) {
                    DocumentViewerScreen(
                        title: Loc.string("Copyright & licence", locale: locale),
                        resource: "copyright"
                    )
                }
            }

            Section(Loc.string("Open-source components", locale: locale)) {
                // GRDB is the app's one third-party dependency. Its MIT licence is
                // reproduced in full, as the licence itself and COPYING.md require.
                VStack(alignment: .leading, spacing: 8) {
                    Text("GRDB.swift").font(.footnote.bold())
                    Text(AppInfo.grdbLicense)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(Loc.string("About", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
    }
}
