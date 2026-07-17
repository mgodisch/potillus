/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [GplNotice], the single source of truth for the GPL notice used
 * by the export formats.
 */
class GplNoticeTest {

    @Test fun `header lines expose the GPL notice`() {
        val lines = GplNotice.HEADER_LINES
        assertTrue("header must not be empty", lines.isNotEmpty())
        assertEquals(
            "Libellus Potionis - Privacy-Friendly Alcohol Tracker",
            lines.first(),
        )
        assertTrue(
            "header must mention the license",
            lines.any { it.contains("GNU General Public License") },
        )
    }

    @Test fun `pdf footer is a single condensed line`() {
        val footer = GplNotice.PDF_FOOTER
        assertTrue("footer must mention GPL v3", footer.contains("GNU GPL v3"))
        assertFalse("footer must be a single line", footer.contains("\n"))
    }
}
