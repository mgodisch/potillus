// vim: set et ts=4 sw=4:
// =============================================================================
// Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp

/**
 * A deliberately tiny Markdown renderer for the in-app user guide.
 *
 * SCOPE — and why it is so small
 *   The bundled guides (`res/raw[-xx]/usersguide.md`) only ever use a fixed,
 *   known subset of Markdown:
 *     * ATX headings  `#`, `##`, `###`
 *     * blank-line-separated paragraphs whose source is hard-wrapped at ~78
 *       columns
 *     * inline links  `[text](url)`
 *   Rendering exactly that subset needs no third-party Markdown library, which
 *   keeps the app dependency-light and matches its privacy-minimal philosophy.
 *   Constructs we do NOT use in the guides (bold, emphasis, lists, code blocks,
 *   images, tables, blockquotes) are intentionally not implemented; their
 *   source markers would simply be shown verbatim. This is documented so a
 *   future maintainer who adds such syntax to a guide knows to extend the
 *   renderer rather than expecting magic.
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

// Matches a single Markdown inline link: [visible text](https://target).
private val LINK_RE = Regex("""\[([^\]]+)\]\(([^)]+)\)""")

/**
 * Converts a paragraph's plain text into an [AnnotatedString], turning every
 * `[text](url)` occurrence into a tappable link and leaving all other text
 * untouched.
 */
@Composable
private fun renderInline(text: String): AnnotatedString {
    val linkColor = MaterialTheme.colorScheme.primary
    return buildAnnotatedString {
        var cursor = 0
        for (match in LINK_RE.findAll(text)) {
            // Emit any literal text before this link.
            if (match.range.first > cursor) {
                append(text.substring(cursor, match.range.first))
            }
            val label = match.groupValues[1]
            val url = match.groupValues[2]
            withLink(
                LinkAnnotation.Url(
                    url = url,
                    styles = TextLinkStyles(
                        style = SpanStyle(
                            color = linkColor,
                            textDecoration = TextDecoration.Underline
                        )
                    )
                )
            ) {
                append(label)
            }
            cursor = match.range.last + 1
        }
        // Emit any trailing literal text after the last link.
        if (cursor < text.length) {
            append(text.substring(cursor))
        }
    }
}
