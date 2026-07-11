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

import SwiftUI

// =============================================================================
// DocumentViewerScreen — a read-only viewer for a bundled text document.
//
// Mirrors Android's DocumentViewerScreen: it shows one bundled document, scrolled,
// read-only. The document here is copyright.md — COPYING.md and the full GPL text
// joined at build time by tools/render-copyright.py, the SAME file Android bundles
// as raw/copyright.md, so the two platforms show identical text. It is not locale-
// qualified: a licence is shown in its own language.
// =============================================================================

struct DocumentViewerScreen: View {

    let title: String
    let resource: String

    @Environment(\.appLocale) private var locale
    @State private var rendered: [Block]?
    @State private var missing = false

    var body: some View {
        ScrollView {
            if let blocks = rendered {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(blocks) { block in
                        block.view
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else if missing {
                // A bundled document that failed to load is a build fault, not a user
                // one; say so plainly rather than showing an empty page.
                Text(Loc.string("This document could not be loaded.", locale: locale))
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func load() {
        guard
            let url = Bundle.main.url(forResource: resource, withExtension: "md"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            missing = true
            return
        }
        rendered = Self.parse(contents)
    }

    // ── A deliberately small Markdown pass ───────────────────────────────────
    //
    // Android renders this document with a full Markdown component. Here the
    // document is a licence: mostly prose, with `#`/`##`/`###` headings and `---`
    // rules. A heavyweight parser on 60 KB earns nothing a few line rules do not,
    // and a licence must never fail to display because a parser choked. So each
    // line becomes one of four blocks — heading, rule, blank, or paragraph — and
    // paragraphs keep any inline Markdown via SwiftUI's own `Text(_:)` markdown.

    private static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        for (index, rawLine) in text.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let id = index
            if line.isEmpty {
                continue
            } else if line == "---" || line == "***" || line == "___" {
                blocks.append(Block(id: id, kind: .rule, text: ""))
            } else if line.hasPrefix("### ") {
                blocks.append(Block(id: id, kind: .heading3, text: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                blocks.append(Block(id: id, kind: .heading2, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(Block(id: id, kind: .heading1, text: String(line.dropFirst(2))))
            } else {
                blocks.append(Block(id: id, kind: .body, text: line))
            }
        }
        return blocks
    }

    struct Block: Identifiable {
        enum Kind { case heading1, heading2, heading3, body, rule }
        let id: Int
        let kind: Kind
        let text: String

        @ViewBuilder var view: some View {
            switch kind {
            case .heading1:
                Text(text).font(.title3.bold())
            case .heading2:
                Text(text).font(.headline)
            case .heading3:
                Text(text).font(.subheadline.bold())
            case .rule:
                Divider()
            case .body:
                // `Text(_:)` parses inline Markdown (links, emphasis) from a plain
                // String, so licence links stay tappable without a parser.
                Text(.init(text)).font(.footnote)
            }
        }
    }
}
