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
// Reached from the overflow menu. The twin of the Android AboutScreen: same
// chapters, same wording, same order. What differs is the component list, and
// only because the two packages genuinely contain different libraries — this app
// ships GRDB and nothing else; the APK ships the AndroidX/Kotlin stack.
//
// WHY THE WHOLE SCREEN IS ENGLISH, NOT LOCALISED
//   Licence text is a legal artifact: paraphrasing or machine-translating it
//   changes its meaning, and a translated licence is not the licence. Once the
//   licence prose is fixed English, translating the labels AROUND it would give a
//   screen that switches language halfway down. So the whole body is fixed
//   English literals, with no `Loc.string` — until 0.83.0 this screen localised
//   its headings while Android hard-coded the same words, which meant the two
//   platforms answered the same question differently. Only the OVERFLOW-MENU
//   entry stays localised ("Über" in German): that label is navigation, not
//   licence text, and a user has to recognise it to get here.
//
// WHY THE LICENCE CHAPTER IS NOT THE FILE HEADER VERBATIM
//   The first three paragraphs are exactly the GPL notice every source file
//   carries. The fourth is not: the file headers end with a POINTER — "any such
//   permissions ... are stated in the accompanying COPYING.md file" — which made
//   sense while the app bundled COPYING.md inside a combined copyright document.
//   It no longer does (0.83.0), so that sentence would send a reader to a file
//   that is not on their phone. The actual App Store Distribution Exception text
//   from COPYING.md stands here instead: the permission is stated where it is
//   read, which is what GPL section 7 asks for.
//
// WHY MIT IS INLINE AND GPLv3 IS A LINK
//   The MIT text is nine sentences and COPYING.md already reproduces it whole, so
//   a reader loses nothing by meeting it here. The GPLv3 is 35 kB; it gets a
//   window of its own. Android draws the same line for the Apache text.
// =============================================================================

struct AboutScreen: View {

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: AppInfo.version)
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

            Section("Licence") {
                // Paragraphs one to three: the GPL notice, word for word as every
                // source file carries it.
                AboutParagraph(
                    """
                    This program is free software: you can redistribute it and/or modify it under \
                    the terms of the GNU General Public License as published by the Free Software \
                    Foundation, either version 3 of the License, or (at your option) any later \
                    version.
                    """
                )
                AboutParagraph(
                    """
                    This program is distributed in the hope that it will be useful, but WITHOUT ANY \
                    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A \
                    PARTICULAR PURPOSE. See the GNU General Public License for more details.
                    """
                )
                AboutParagraph(
                    """
                    You should have received a copy of the GNU General Public License along with \
                    this program. If not, see https://www.gnu.org/licenses/.
                    """
                )
                // Paragraph four: the exception itself, from COPYING.md.
                AboutParagraph(
                    """
                    As an additional permission under section 7 of the GNU General Public License, \
                    version 3, you are allowed to distribute the software through an app store, \
                    even if that store has restrictive terms and conditions that are incompatible \
                    with the GPL, provided that the source is also available under the GPL with or \
                    without this permission through a channel without those restrictive terms and \
                    conditions.
                    """
                )
                NavigationLink("GNU General Public License") {
                    DocumentViewerScreen(
                        title: "GNU General Public License, version 3",
                        resource: "license_gpl3"
                    )
                }
            }

            Section("Open-source components") {
                AboutParagraph(
                    """
                    The library below is compiled into this application and is therefore \
                    redistributed with it.
                    """
                )
                AboutParagraph(
                    """
                    Under the MIT License: GRDB.swift (Copyright © 2015–2025 Gwendal Roué). GRDB \
                    is this app's only third-party dependency: typed records, a schema migrator \
                    and database observation on top of the SQLite that ships with the operating \
                    system. It has no transitive dependencies, performs no network access and \
                    collects no telemetry.
                    """
                )
                // The MIT License requires the copyright notice and the permission
                // notice to accompany the software, so the text is reproduced in
                // full — as prose, not monospaced: it is sentences to read, not a
                // code listing. Selectable, so a reader can lift it out verbatim.
                Text(AppInfo.grdbLicense)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
        }
        // "About", in English: the screen body is an English document, so its own
        // title is too. The menu entry that leads here is localised.
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One paragraph of the screen's fixed English prose.
///
/// A named view rather than a bare `Text` so every paragraph gets the same font
/// and spacing from one place, and so the call sites above read as the document
/// they are.
private struct AboutParagraph: View {

    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.vertical, 2)
    }
}
