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
 */
package de.godisch.potillus.util

/**
 * Marks a declaration whose body is bound to the Android runtime — MediaStore,
 * ContentResolver, [android.content.Context], [android.net.Uri], the system
 * print framework, WebView, and similar — and therefore cannot be exercised by
 * JVM unit tests.
 *
 * Such declarations are verified by the instrumented tests in `src/androidTest`
 * (for example `ReportExportTest` and `BackupRepositoryInstrumentedTest`) and are
 * excluded from Kover statement/branch coverage via `annotatedBy(...)` in
 * `app/build.gradle.kts`. This keeps the reported coverage focused on the
 * JVM-unit-testable code, as documented in CONTRIBUTING.md, Section 5.
 *
 * Retention is [AnnotationRetention.BINARY] so the marker is present in the
 * compiled class files that Kover inspects, but it is not visible via reflection
 * at runtime and adds nothing observable to the shipped app.
 */
@Retention(AnnotationRetention.BINARY)
@Target(
    AnnotationTarget.FUNCTION,
    AnnotationTarget.PROPERTY,
    AnnotationTarget.CLASS,
)
annotation class AndroidIoBound
