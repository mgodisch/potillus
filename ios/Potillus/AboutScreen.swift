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
// AboutScreen — the app's name, version, and the licenses it must show.
//
// Reached from the overflow menu. The twin of the Android AboutScreen: same
// chapters, same wording, same order. What differs is the component list, and
// only because the two packages genuinely contain different libraries — this app
// ships GRDB and nothing else; the APK ships the AndroidX/Kotlin stack.
//
// WHY THE WHOLE SCREEN IS ENGLISH, NOT LOCALISED
//   License text is a legal artifact: paraphrasing or machine-translating it
//   changes its meaning, and a translated license is not the license. Once the
//   license prose is fixed English, translating the labels AROUND it would give a
//   screen that switches language halfway down. So the whole body is fixed
//   English literals, with no `Loc.string` — until 0.83.0 this screen localised
//   its headings while Android hard-coded the same words, which meant the two
//   platforms answered the same question differently. Only the OVERFLOW-MENU
//   entry stays localised ("Über" in German): that label is navigation, not
//   license text, and a user has to recognise it to get here.
//
// WHY THE LICENSE CHAPTER IS NOT THE FILE HEADER VERBATIM
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

            Section("License") {
                // Each paragraph is its own List row, and a List draws a separator
                // between rows -- which put a rule between every sentence of the
                // notice and chopped one legal text into four. The paragraphs hide
                // their bottom separator; the FOURTH does not, because that one is
                // the rule above the link, separating the notice from the way out
                // to its full text.
                //
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
                .listRowSeparator(.hidden, edges: .bottom)
                AboutParagraph(
                    """
                    This program is distributed in the hope that it will be useful, but WITHOUT ANY \
                    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A \
                    PARTICULAR PURPOSE. See the GNU General Public License for more details.
                    """
                )
                .listRowSeparator(.hidden, edges: .bottom)
                AboutParagraph(
                    """
                    You should have received a copy of the GNU General Public License along with \
                    this program. If not, see https://www.gnu.org/licenses/.
                    """
                )
                .listRowSeparator(.hidden, edges: .bottom)
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
                NavigationLink("GNU General Public License v3") {
                    DocumentViewerScreen(
                        title: "GPL 3.0",
                        resource: "license_gpl3"
                    )
                }
            }

            Section("Open-source components") {
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
                // .callout and no .foregroundStyle(): the same size and the same
                // primary colour as every other paragraph here. It had been
                // .footnote and .secondary grey, which reads as a disclaimer to
                // skip -- but this text is the MIT License's permission notice, the
                // thing the licence actually obliges us to put in front of a
                // reader.
                Text(AppInfo.grdbLicense)
                    .font(.callout)
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
        // .callout: one step below .body, which is what a List row -- and so the
        // "Version" row above -- renders at. The prose is long and there is a lot
        // of it, so it reads better a notch down from the label it sits under;
        // .footnote, where it started, was two steps further and shrank the screen
        // below its own first line.
        Text(text)
            .font(.callout)
            .padding(.vertical, 2)
    }
}
