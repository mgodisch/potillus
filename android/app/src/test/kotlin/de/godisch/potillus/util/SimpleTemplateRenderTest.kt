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

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Branch tests for [SimpleTemplate.render]: HTML-escaping of substituted values
 * (all metacharacters) and the fall-through for an unknown placeholder.
 */
class SimpleTemplateRenderTest {

    @Test fun `present placeholders are HTML-escaped and unknown ones are left intact`() {
        val out = SimpleTemplate.render(
            template = "{{name}} and {{missing}}",
            scalars = mapOf("name" to "a&b<c>d\"e'f"),
        )
        assertTrue(
            "all HTML metacharacters must be escaped",
            out.contains("a&amp;b&lt;c&gt;d&quot;e&#39;f"),
        )
        assertTrue("an unknown placeholder must be left untouched", out.contains("{{missing}}"))
    }
}
