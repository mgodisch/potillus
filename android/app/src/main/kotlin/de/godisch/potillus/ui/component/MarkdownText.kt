// vim: set et ts=4 sw=4:
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
// =============================================================================

package de.godisch.potillus.ui.component

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp

/**
 * A deliberately tiny Markdown renderer for the in-app user guide.
 *
 * SCOPE — and why it is so small
 *   The renderer implements exactly the Markdown subset the bundled documents
 *   (`res/raw[-xx]/usersguide.md`, plus COPYING.md / LICENSE.md) rely on:
 *     * ATX headings  `#`, `##`, `###`
 *     * blank-line-separated paragraphs whose source is hard-wrapped at ~78
 *       columns
 *     * inline links  `[text](url)`
 *     * inline bold  `**text**`
 *     * ordered lists  `1.` `2.` … (one item per source line; continuation
 *       lines are reflowed into their item)
 *   That needs no third-party Markdown library, which keeps the app
 *   dependency-light and matches its privacy-minimal philosophy. Other
 *   constructs (italic emphasis, unordered/bulleted lists, code blocks, images,
 *   tables, blockquotes) are intentionally not implemented; their markers are
 *   rendered as literal text inside the reflowed paragraph. A future maintainer
 *   who adds such syntax to a guide should extend the renderer rather than
 *   expect magic.
 *
 * REFLOW
 *   Guide paragraphs are wrapped at a fixed column in the source file. If we
 *   rendered the lines as-is they would break at the source's wrap points
 *   rather than the screen width, so each paragraph's lines are joined back
 *   into one string and Compose re-wraps it to the available width.
 *
 * LINKS
 *   `[text](url)` becomes a [LinkAnnotation.Url] span. A plain [Text] that
 *   contains link annotations handles taps itself (via the ambient
 *   `LocalUriHandler`), so no extra click wiring is required here.
 *
 * @param markdown The guide contents (already locale-resolved and
 *                 header-stripped by the build step).
 * @param modifier Layout modifier applied to the root [Column].
 */
@Composable
fun MarkdownText(markdown: String, modifier: Modifier = Modifier) {
    // Split into blocks on one-or-more blank lines. `\R` matches any line
    // terminator; trim() drops a trailing newline so we don't get an empty
    // final block.
    val blocks = markdown.trim().split(Regex("\\R[ \\t]*\\R"))

    Column(modifier = modifier) {
        for (block in blocks) {
            val firstLine = block.trimStart()
            when {
                firstLine.startsWith("### ") -> Text(
                    text = firstLine.removePrefix("### ").trim(),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
                )
                firstLine.startsWith("## ") -> Text(
                    text = firstLine.removePrefix("## ").trim(),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(top = 16.dp, bottom = 4.dp)
                )
                firstLine.startsWith("# ") -> Text(
                    text = firstLine.removePrefix("# ").trim(),
                    style = MaterialTheme.typography.headlineSmall,
                    // A top inset larger than the `## ` heading's (16.dp). An h1
                    // is the most prominent heading, so it deserves the largest
                    // gap above it; without a top inset an h1 that appears in the
                    // MIDDLE of a document — e.g. "# GNU GENERAL PUBLIC LICENSE"
                    // at the seam where COPYING.md and LICENSE.md are joined —
                    // would sit closer to the preceding paragraph than the lower
                    // "## Preamble" heading below it, which looks wrong. The
                    // leading h1 of a document gains a little top space too,
                    // which reads fine inside the scrolling, padded viewer.
                    modifier = Modifier.padding(top = 20.dp, bottom = 8.dp)
                )
                ORDERED_ITEM_RE.matches(firstLine.substringBefore('\n')) -> {
                    // An ordered list: render one row per item — the item number
                    // and its body, where the body still gets inline bold/link
                    // handling. Source lines wrapped within an item are reflowed
                    // back together by parseOrderedList(). The body Text wraps to
                    // the screen width, so its second and later lines hang-indent
                    // under the body rather than under the number.
                    Column(modifier = Modifier.padding(bottom = 12.dp)) {
                        for ((number, itemText) in parseOrderedList(block)) {
                            Row(modifier = Modifier.padding(bottom = 4.dp)) {
                                Text(
                                    text = "$number.",
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier.padding(end = 8.dp)
                                )
                                Text(
                                    text = renderInline(itemText),
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                    }
                }
                else -> Text(
                    // Reflow: collapse the hard-wrapped source lines of this
                    // paragraph into a single, screen-wrapped string.
                    text = renderInline(block.replace(Regex("\\s*\\R\\s*"), " ").trim()),
                    style = MaterialTheme.typography.bodyMedium,
                    // 12.dp leaves a clear blank-line gap between paragraphs (the
                    // source separates them with a blank line); a touch more than
                    // the previous 8.dp without being a full empty text line.
                    modifier = Modifier.padding(bottom = 12.dp)
                )
            }
        }
    }
}

// Maps the HTML character-entity references that appear in the bundled Markdown
// documents to their Unicode equivalents. The set is intentionally small and
// covers only entities present in the shipped files (COPYING.md / LICENSE.md /
// usersguide.md). Numeric entities (&#NN; / &#xNN;) and the full HTML5 named
// entity table are out of scope; adding them here would be premature, and a
// real HTML parser would be the right tool if the documents ever needed them.
private val HTML_ENTITIES = mapOf(
    "&amp;"  to "&",
    "&lt;"   to "<",
    "&gt;"   to ">",
    "&quot;" to "\"",
    "&apos;" to "'",
    "&nbsp;" to "\u00A0",
    "&copy;" to "©",
    "&reg;"  to "®",
    "&trade;" to "™"
)

/** Replaces every key in [HTML_ENTITIES] with its Unicode equivalent. */
private fun decodeHtmlEntities(text: String): String =
    HTML_ENTITIES.entries.fold(text) { acc, (entity, ch) -> acc.replace(entity, ch) }

// Matches the inline Markdown the documents use: a bold span **like this** OR a
// link [visible text](https://target), whichever comes next. Group 1 captures a
// bold span's content; groups 2 and 3 capture a link's label and URL. The bold
// pattern is non-greedy so adjacent **a** **b** spans match separately. Since
// renderInline() receives an already-reflowed (single-line) paragraph, `.` never
// has to cross a newline.
private val INLINE_RE = Regex("""\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)""")

/**
 * Converts a paragraph's plain text into an [AnnotatedString], turning every
 * `[text](url)` occurrence into a tappable link and every `**text**` span into
 * bold, and leaving all other text untouched. HTML character entities (e.g.
 * `&copy;`) are decoded first so they appear as their Unicode glyphs rather than
 * raw markup.
 */
@Composable
private fun renderInline(text: String): AnnotatedString {
    val linkColor = MaterialTheme.colorScheme.primary
    // Decode HTML entities before scanning so an entity inside a link label or a
    // bold span (e.g. `[&copy; Foo](https://…)`) is also handled.
    val decoded = decodeHtmlEntities(text)
    return buildAnnotatedString {
        var cursor = 0
        for (match in INLINE_RE.findAll(decoded)) {
            // Emit any literal text before this match.
            if (match.range.first > cursor) {
                append(decoded.substring(cursor, match.range.first))
            }
            val boldText = match.groupValues[1]
            if (boldText.isNotEmpty()) {
                // **bold** — group 1 is only non-empty on the bold alternative.
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                    append(boldText)
                }
            } else {
                // [label](url) — groups 2 and 3.
                withLink(
                    LinkAnnotation.Url(
                        url = match.groupValues[3],
                        styles = TextLinkStyles(
                            style = SpanStyle(
                                color = linkColor,
                                textDecoration = TextDecoration.Underline
                            )
                        )
                    )
                ) {
                    append(match.groupValues[2])
                }
            }
            cursor = match.range.last + 1
        }
        // Emit any trailing literal text after the last match.
        if (cursor < decoded.length) {
            append(decoded.substring(cursor))
        }
    }
}

// Matches a single ordered-list item line: an integer, a dot, whitespace, then
// the item text. Used both to detect an ordered-list block and to split it into
// items. A line such as "3.5 grams" does NOT match (no whitespace after the
// dot), so decimals that appear in a wrapped continuation line are kept as
// continuation text rather than mistaken for a new item.
private val ORDERED_ITEM_RE = Regex("""\s*(\d+)\.\s+(.*)""")

/**
 * Splits an ordered-list [block] into `(number, text)` pairs. Every source line
 * matching [ORDERED_ITEM_RE] starts a new item; any other non-blank line is a
 * continuation of the current item and is appended with a single space, since
 * the guide source hard-wraps long items across several lines.
 */
private fun parseOrderedList(block: String): List<Pair<String, String>> {
    val items = mutableListOf<Pair<String, StringBuilder>>()
    for (rawLine in block.trim().lines()) {
        val line = rawLine.trim()
        if (line.isEmpty()) continue
        val match = ORDERED_ITEM_RE.matchEntire(line)
        if (match != null) {
            items += match.groupValues[1] to StringBuilder(match.groupValues[2])
        } else if (items.isNotEmpty()) {
            items.last().second.append(' ').append(line)
        }
    }
    return items.map { it.first to it.second.toString() }
}
