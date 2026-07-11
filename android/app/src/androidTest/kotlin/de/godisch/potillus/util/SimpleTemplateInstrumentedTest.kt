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

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

// =============================================================================
// SimpleTemplateInstrumentedTest – on-device regex-engine guard
// =============================================================================
//
// WHY ON-DEVICE (and not a plain JVM unit test)?
//   The local unit test (SimpleTemplateTest, app/src/test) compiles regexes with
//   the desktop `java.util.regex` engine, which is lenient about unescaped regex
//   metacharacters. Android devices use the stricter ICU engine
//   (com.android.icu.util.regex), which rejects patterns the JVM accepts.
//
//   In v0.61.0–0.61.2 the PLACEHOLDER pattern contained an unescaped `}`. It
//   compiled fine on the JVM (so unit tests AND `make test` passed) but threw
//   java.util.regex.PatternSyntaxException inside SimpleTemplate's static
//   initialiser on-device, which surfaced only as a swallowed "export failed".
//
//   This instrumented test runs the real device engine: merely touching
//   SimpleTemplate triggers its <clinit> (compiling PLACEHOLDER), so an
//   ICU-incompatible pattern fails here as part of `make test`'s test-device
//   phase — instead of silently in production.
// =============================================================================

@RunWith(AndroidJUnit4::class)
class SimpleTemplateInstrumentedTest {

    @Test fun scalarPlaceholderExpandsUnderDeviceRegexEngine() {
        val out = SimpleTemplate.render("<h1>{{TITLE}}</h1>", mapOf("TITLE" to "Report"))
        assertEquals("<h1>Report</h1>", out)
    }

    @Test fun repeatBlockExpandsUnderDeviceRegexEngine() {
        val out = SimpleTemplate.render(
            "<ul><!-- repeat:ITEMS --><li>{{NAME}}</li><!-- end:ITEMS --></ul>",
            scalars = emptyMap(),
            repeats = mapOf("ITEMS" to listOf(mapOf("NAME" to "a"), mapOf("NAME" to "b"))),
        )
        assertEquals("<ul><li>a</li><li>b</li></ul>", out)
    }
}
