/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * =============================================================================
 *
 * UNIT TEST — MarkdownText pure helpers
 *
 * The in-app guide/licence viewer renders Markdown with a tiny in-house
 * renderer ([MarkdownText]). Its Compose-facing parts need a UI test, but its
 * parsing logic is pure and is exercised here on the JVM (no device):
 *
 *   - [decodeHtmlEntities] — the small HTML-entity table the bundled docs use.
 *   - [ORDERED_ITEM_RE]    — the match/no-match boundary that decides whether a
 *                            line starts a numbered item or is continuation text
 *                            (notably: a wrapped decimal such as "3.5 g" must
 *                            NOT be read as a new item).
 *   - [parseOrderedList]   — item splitting plus continuation-line reflow.
 *
 * These three pieces carry the renderer's only real branching logic, so a
 * regression here would silently mis-render the user guide.
 */
package de.godisch.potillus.ui.component

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Verifies the pure parsing helpers behind [MarkdownText]. */
class MarkdownTextTest {

    // ── decodeHtmlEntities ────────────────────────────────────────────────────

    /** Each supported named entity is replaced by its Unicode equivalent. */
    @Test fun `known html entities are decoded`() {
        assertEquals("&", decodeHtmlEntities("&amp;"))
        assertEquals("<", decodeHtmlEntities("&lt;"))
        assertEquals(">", decodeHtmlEntities("&gt;"))
        assertEquals("\"", decodeHtmlEntities("&quot;"))
        assertEquals("'", decodeHtmlEntities("&apos;"))
        assertEquals("©", decodeHtmlEntities("&copy;"))
        assertEquals("\u00A0", decodeHtmlEntities("&nbsp;"))
    }

    /** Entities are decoded even when embedded in surrounding prose. */
    @Test fun `entities are decoded inside surrounding text`() {
        assertEquals("Tom & Jerry <3", decodeHtmlEntities("Tom &amp; Jerry &lt;3"))
    }

    /**
     * Unsupported forms (numeric character references) are intentionally left
     * verbatim — the table is deliberately limited to the entities the bundled
     * documents actually use.
     */
    @Test fun `unsupported numeric entity is left untouched`() {
        assertEquals("&#39;", decodeHtmlEntities("&#39;"))
    }

    // ── ORDERED_ITEM_RE ───────────────────────────────────────────────────────

    /** A genuine "N. text" line matches and exposes the number and body groups. */
    @Test fun `ordered item regex matches a numbered line`() {
        val m = ORDERED_ITEM_RE.matchEntire("1. First step")
        assertTrue(m != null)
        assertEquals("1", m!!.groupValues[1])
        assertEquals("First step", m.groupValues[2])
    }

    /**
     * A decimal like "3.5 grams" must NOT match: there is no whitespace after
     * the dot, so a wrapped continuation line containing a decimal is not
     * mistaken for the start of a new list item.
     */
    @Test fun `ordered item regex rejects a decimal number`() {
        assertFalse(ORDERED_ITEM_RE.matches("3.5 grams"))
    }

    // ── parseOrderedList ──────────────────────────────────────────────────────

    /** Consecutive numbered lines become one (number, text) pair each. */
    @Test fun `parseOrderedList splits consecutive items`() {
        val items = parseOrderedList("1. Alpha\n2. Beta\n3. Gamma")
        assertEquals(
            listOf("1" to "Alpha", "2" to "Beta", "3" to "Gamma"),
            items
        )
    }

    /**
     * A hard-wrapped item (its body continues on the next, non-numbered line) is
     * reflowed back into a single body with one joining space — and a decimal in
     * the continuation stays part of the body rather than starting a new item.
     */
    @Test fun `parseOrderedList reflows wrapped continuation lines`() {
        val items = parseOrderedList("1. Pour about\n3.5 grams of sugar\n2. Stir well")
        assertEquals(
            listOf("1" to "Pour about 3.5 grams of sugar", "2" to "Stir well"),
            items
        )
    }

    /** Blank lines inside the block are skipped, not treated as items. */
    @Test fun `parseOrderedList ignores blank lines`() {
        val items = parseOrderedList("1. One\n\n2. Two\n")
        assertEquals(listOf("1" to "One", "2" to "Two"), items)
    }
}
