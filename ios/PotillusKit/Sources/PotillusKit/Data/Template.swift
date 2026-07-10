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

import Foundation

// =============================================================================
// Template – a tiny, dependency-free string templating engine
// =============================================================================
//
// The Swift counterpart of Android's `SimpleTemplate`. Both fill the SAME file,
// report/report_template.html, which is why they must agree character for
// character: their agreement is pinned by test-vectors/template-render.json,
// which both test suites read.
//
// WHY IT EXISTS
//   The PDF report is authored as HTML/CSS so its LAYOUT can be edited by hand —
//   column widths, fonts, page breaks — without touching code. This engine is the
//   glue that injects the computed numbers and the labels into that template.
//
//   It is deliberately not a template language. No conditionals, no expressions,
//   no nested loops. Two features suffice, and the template stays readable to
//   someone who does not program:
//
//     1. SCALAR PLACEHOLDERS   {{KEY}}
//        Replaced by `scalars["KEY"]`.
//
//     2. REPEAT BLOCKS         <!-- repeat:NAME --> … <!-- end:NAME -->
//        The body is emitted once per row in `repeats["NAME"]`, each row
//        substituting its own values. An empty list removes the block AND its
//        markers, so a caller may always pass every block name and never leave a
//        stray marker in the output.
//
// SAFETY
//   Substituted VALUES are HTML-escaped, so a drink named `Beer & <b>Cider</b>`
//   cannot break the markup. The TEMPLATE ITSELF is trusted and never escaped —
//   it ships with the app and is the thing being edited on purpose.
//
// UNKNOWN PLACEHOLDERS
//   A `{{KEY}}` with no value is left verbatim. That is a kindness to whoever
//   edits the template: a typo appears in the PDF instead of vanishing.
// =============================================================================

public enum Template {

    // ── Patterns ─────────────────────────────────────────────────────────────

    /// Matches `{{TOTAL_GRAMS}}`; capture group 1 is the key.
    ///
    /// The character class is written out rather than as `\w`, and that is not
    /// pedantry. Kotlin's `\w` on the JVM means ASCII `[a-zA-Z0-9_]`, while
    /// `NSRegularExpression` follows ICU, where `\w` also matches `ä`, `Я`, and
    /// every other Unicode letter. Written as `\w` on both sides, the two engines
    /// would silently disagree about `{{TÖTAL}}` — Android leaving it verbatim,
    /// iOS substituting it. Spelling the class out makes them agree.
    private static let placeholderPattern = "\\{\\{([A-Za-z0-9_]+)\\}\\}"

    /// Builds the pattern for one named repeat block.
    ///
    /// `.dotMatchesLineSeparators` lets the body span lines; the lazy `(.*?)`
    /// stops at the FIRST matching end marker, so two adjacent blocks cannot
    /// swallow one another.
    private static func repeatPattern(_ name: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        return "<!--[ \\t\\r\\n]*repeat:\(escaped)[ \\t\\r\\n]*-->"
            + "(.*?)"
            + "<!--[ \\t\\r\\n]*end:\(escaped)[ \\t\\r\\n]*-->"
    }

    // ── Rendering ────────────────────────────────────────────────────────────

    /// Expands every repeat block, then substitutes every document-level scalar.
    ///
    /// ORDER MATTERS, and the order is: blocks first, scalars last.
    ///
    /// Each row substitutes its own values into its copy of the block body. What a
    /// row leaves unresolved — a `{{DOC_TITLE}}` inside a table row, say — is
    /// filled afterwards by the document pass, because that pass runs over the
    /// WHOLE expanded text. A row value that happens to contain `{{X}}` is
    /// therefore expanded too, if `scalars` knows `X`. That is Android's behaviour,
    /// and the vectors pin it.
    ///
    /// - Parameters:
    ///   - template: The raw template text. Trusted, and never escaped.
    ///   - scalars: Document-level values, by placeholder name.
    ///   - repeats: Rows per block name. Pass an empty array to erase a block.
    /// - Returns: The expanded text, with unknown placeholders left verbatim.
    public static func render(
        template: String,
        scalars: [String: String],
        repeats: [String: [[String: String]]] = [:]
    ) -> String {
        var output = template

        // Blocks are disjoint regions of the template, so the order in which the
        // dictionary hands them to us cannot change the result.
        for (name, rows) in repeats {
            output = expandBlock(named: name, rows: rows, in: output)
        }

        return substitute(output, values: scalars)
    }

    // ── The two passes ───────────────────────────────────────────────────────

    /// Replaces each occurrence of one block with its body repeated per row.
    private static func expandBlock(
        named name: String,
        rows: [[String: String]],
        in text: String
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: repeatPattern(name),
            options: [.dotMatchesLineSeparators]
        ) else {
            return text  // An un-compilable name cannot occur; do no harm if it does.
        }

        return replaceMatches(of: regex, in: text) { body in
            rows.map { substitute(body, values: $0) }.joined()
        }
    }

    /// Replaces every `{{KEY}}` whose key is known, escaping the value.
    private static func substitute(_ text: String, values: [String: String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: placeholderPattern) else {
            return text
        }

        return replaceMatches(of: regex, in: text, capture: 1) { key in
            // An unknown key keeps its braces, to surface a typo in the template.
            guard let value = values[key] else { return nil }
            return escapeHTML(value)
        }
    }

    // ── Regex plumbing ───────────────────────────────────────────────────────

    /// Rewrites `text`, replacing each match with `transform(captured)`.
    ///
    /// Written by hand rather than with `stringByReplacingMatches(in:withTemplate:)`,
    /// because that method reads `$1` and `\` in the REPLACEMENT as references into
    /// the match. A drink named `$1` would then interpolate itself. Kotlin's
    /// replacement lambda has no such behaviour, so neither may this.
    ///
    /// The result is BUILT FORWARD, slice by slice, rather than by mutating the
    /// input in place. A `String.Index` belongs to the string it was taken from;
    /// carrying indices of `text` into a partially rewritten copy would be reading
    /// a map of a city that has since been rebuilt.
    ///
    /// Returning `nil` from `transform` copies the match through untouched.
    private static func replaceMatches(
        of regex: NSRegularExpression,
        in text: String,
        capture: Int = 1,
        transform: (String) -> String?
    ) -> String {
        let full = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: full)
        guard !matches.isEmpty else { return text }

        var output = ""
        var cursor = text.startIndex

        for match in matches {
            guard
                let whole = Range(match.range, in: text),
                let captured = Range(match.range(at: capture), in: text)
            else { continue }

            output += text[cursor..<whole.lowerBound]
            output += transform(String(text[captured])) ?? String(text[whole])
            cursor = whole.upperBound
        }

        output += text[cursor...]
        return output
    }

    // ── Escaping ─────────────────────────────────────────────────────────────

    /// Escapes the five characters that carry meaning in HTML text and attributes.
    ///
    /// The ampersand goes first. Escaping it after `<` would turn the `&` of
    /// `&lt;` into `&amp;lt;`, and the page would show the markup rather than the
    /// text — the classic double-escape.
    private static func escapeHTML(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }
}
