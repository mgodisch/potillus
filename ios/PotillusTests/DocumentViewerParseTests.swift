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

import XCTest

@testable import Potillus

// =============================================================================
// DocumentViewerParseTests – the small Markdown pass behind Help and Copyright
// =============================================================================
//
// The guide and the licence are hard-wrapped Markdown files. The viewer's first
// version turned every SOURCE LINE into its own paragraph block, so the screen
// showed ragged shreds of sentences with a gap after each (0.83.0 QA round).
// These tests pin the joining rules: consecutive non-blank lines are ONE
// paragraph, a blank line ends it, and a list item stays whole even when its
// text wraps onto the next source line.
// =============================================================================

final class DocumentViewerParseTests: XCTestCase {

    /// Two hard-wrapped source lines are one on-screen paragraph.
    func testConsecutiveLinesJoinIntoOneParagraph() {
        let blocks = DocumentViewerScreen.parse(
            "our personal alcohol consumption logger!\nThis page describes the features."
        )

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(
            blocks[0].text,
            "our personal alcohol consumption logger! This page describes the features."
        )
    }

    /// A blank line is the paragraph separator, exactly as in Markdown.
    func testABlankLineSeparatesParagraphs() {
        let blocks = DocumentViewerScreen.parse("First paragraph.\n\nSecond paragraph.")

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].text, "First paragraph.")
        XCTAssertEqual(blocks[1].text, "Second paragraph.")
    }

    /// A wrapped ordered-list item joins back together instead of breaking apart —
    /// the shape the backup chapter of the guide actually contains.
    func testAWrappedListItemStaysWhole() {
        let blocks = DocumentViewerScreen.parse(
            "1. On the **old** phone, open **\"Settings\" → Backup →\nExport backup**.\n"
                + "2. Install the app on the **new** phone."
        )

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(
            blocks[0].text, "1. On the **old** phone, open **\"Settings\" → Backup → Export backup**."
        )
        XCTAssertEqual(blocks[1].text, "2. Install the app on the **new** phone.")
    }

    /// An unordered item starts its own block even with no blank line above it.
    func testAListItemEndsThePrecedingParagraph() {
        let blocks = DocumentViewerScreen.parse("Intro line.\n- first item\n- second item")

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].text, "Intro line.")
        XCTAssertEqual(blocks[1].text, "- first item")
        XCTAssertEqual(blocks[2].text, "- second item")
    }

    /// Headings and rules flush the paragraph being gathered and never join.
    func testHeadingsAndRulesInterruptParagraphs() {
        let blocks = DocumentViewerScreen.parse("## Heading\nBody one\nbody two\n---\nAfter.")

        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[0].kind, .heading2)
        XCTAssertEqual(blocks[1].text, "Body one body two")
        XCTAssertEqual(blocks[2].kind, .rule)
        XCTAssertEqual(blocks[3].text, "After.")
    }

    /// The bare "12." of a year like "1996. " must not be mistaken for a list —
    /// only `digits + ". "` at line START counts, and a mid-sentence number never
    /// reaches the check because it is not at the start of a trimmed line.
    func testAnOrderedItemNeedsDigitsDotSpaceAtLineStart() {
        XCTAssertTrue(DocumentViewerScreen.startsListItem("12. twelfth"))
        XCTAssertFalse(DocumentViewerScreen.startsListItem("12.twelfth"))
        XCTAssertFalse(DocumentViewerScreen.startsListItem(".. not a list"))
    }
}
