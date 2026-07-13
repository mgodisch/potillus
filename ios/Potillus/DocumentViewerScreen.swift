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
    // Android renders these documents with a full Markdown component. Here the
    // documents are the licence and the user guide: prose with `#`/`##`/`###`
    // headings, `---` rules, and the guide's short lists. A heavyweight parser
    // on 60 KB earns nothing a few line rules do not, and a licence must never
    // fail to display because a parser choked. So the text becomes a sequence
    // of four block kinds — heading, rule, paragraph, or blank-separated list
    // item — and paragraphs keep any inline Markdown via SwiftUI's own
    // `Text(_:)` markdown.
    //
    // WHY LINES ARE JOINED
    //   The sources are hard-wrapped at ~79 columns (they are readable Markdown
    //   files first). The first version of this pass made every SOURCE LINE its
    //   own block, so each wrapped line rendered as a separate paragraph with a
    //   10-point gap — the guide showed ragged shreds of sentences, and a list
    //   item broke apart mid-entry (0.83.0 QA round). Markdown's own rule is
    //   the fix: consecutive non-blank lines are ONE paragraph, a blank line
    //   ends it. A line starting a list item (`- `, `* `, or `1. `) also starts
    //   a new block, and its own wrapped continuation lines join INTO it, so
    //   the item stays whole.

    /// Internal, not private: the smoke-test bundle drives it with wrapped
    /// paragraphs and list items to pin the joining rules above.
    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        // The lines of the paragraph being accumulated, joined on flush. The id
        // of a block is the index of its FIRST source line — stable across
        // renders, which is all `Identifiable` needs.
        var paragraph: [String] = []
        var paragraphStart = 0

        func flush() {
            guard !paragraph.isEmpty else { return }
            blocks.append(
                Block(id: paragraphStart, kind: .body, text: paragraph.joined(separator: " "))
            )
            paragraph = []
        }

        for (index, rawLine) in text.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line == "---" || line == "***" || line == "___" {
                flush()
                blocks.append(Block(id: index, kind: .rule, text: ""))
            } else if line.hasPrefix("### ") {
                flush()
                blocks.append(Block(id: index, kind: .heading3, text: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                flush()
                blocks.append(Block(id: index, kind: .heading2, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flush()
                blocks.append(Block(id: index, kind: .heading1, text: String(line.dropFirst(2))))
            } else if Self.startsListItem(line) {
                // A list item is its own paragraph; its wrapped continuation
                // lines (which do not look like item starts) join into it.
                flush()
                paragraph = [line]
                paragraphStart = index
            } else {
                if paragraph.isEmpty { paragraphStart = index }
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    /// Whether a (trimmed) line opens a Markdown list item: `- `, `* `, `+ `,
    /// or an ordered `12. `. Kept deliberately literal — the two documents this
    /// viewer shows use exactly these forms, and a false negative merely joins
    /// an item into the previous paragraph rather than losing text.
    static func startsListItem(_ line: String) -> Bool {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return true }
        let digits = line.prefix { $0.isNumber }
        return !digits.isEmpty && line.dropFirst(digits.count).hasPrefix(". ")
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
