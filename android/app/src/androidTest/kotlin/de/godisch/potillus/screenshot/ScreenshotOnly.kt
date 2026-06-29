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
package de.godisch.potillus.screenshot

// =============================================================================
// ScreenshotOnly.kt — opt-out marker for the Play-Store screenshot suite
// =============================================================================
//
// WHY THIS ANNOTATION EXISTS
//   The Play-Store screenshot-capture suite (ScreenshotTest) is a *normal*
//   instrumented test: by project decision it runs as part of the everyday
//   `connectedDebugAndroidTest` / `make test-device` gate, so a regression in
//   the capture flow is noticed immediately and not only at release time.
//
//   Occasionally, though, you want a fast device-test run WITHOUT the (slower)
//   screenshot suite — for example while iterating on an unrelated UI test. This
//   annotation is the documented, switchable opt-out: every class/method tagged
//   with it can be excluded from a run via AndroidX Test's standard
//   `notAnnotation` instrumentation-runner filter.
//
// HOW TO EXCLUDE THE SUITE (the "switch")
//   Gradle property (wired in app/build.gradle.kts defaultConfig):
//       ./gradlew connectedDebugAndroidTest -PexcludeScreenshotTests
//   Makefile convenience wrapper:
//       make test-device EXCLUDE_SCREENSHOTS=1
//   Raw instrumentation argument (equivalent, for reference):
//       -e notAnnotation de.godisch.potillus.screenshot.ScreenshotOnly
//
//   The `make screenshots` capture flow is unaffected by the switch: the
//   `fastlane screengrab` run selects the screenshot package explicitly
//   (Screengrabfile `use_tests_in_packages`) rather than relying on this tag.
//
// RETENTION / TARGET
//   AndroidX Test reads the annotation reflectively at runtime, so it MUST be
//   retained at runtime. It is applicable to a whole test class (the common
//   case) or to an individual test method.
// =============================================================================

/**
 * Marks a test (class or method) as belonging to the Play-Store screenshot
 * capture suite so it can be excluded from an ordinary instrumented-test run via
 * the `notAnnotation` filter (see the file header for the exact switch).
 */
@Retention(AnnotationRetention.RUNTIME)
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION)
annotation class ScreenshotOnly
