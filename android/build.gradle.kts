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

// =============================================================================
// build.gradle.kts – project-level build file (repository root's android/)
// =============================================================================
//
// DIFFERENCE TO app/build.gradle.kts:
//   This file applies to the WHOLE project (every module).
//   app/build.gradle.kts applies to the ":app" module only.
//
//   In a simple project with a single app module this file contains
//   almost nothing – it merely declares which plugins are AVAILABLE,
//   without applying them directly (apply false).
//
// WHY "apply false"?
//   The plugins are only "made known" here (with a fixed version) and
//   are actually applied in the submodules. That prevents version
//   conflicts if several modules were to need the same plugins in
//   different versions.
// =============================================================================

// ── built-in Kotlin: pin the compiler version ───────────────────────────────
// AGP 9 has built-in Kotlin support: the Android plugin compiles Kotlin itself
// and no longer needs org.jetbrains.kotlin.android. To provide this, AGP 9 has
// a runtime dependency on the Kotlin Gradle plugin (KGP) and bundles 2.2.10 as
// a floor; a lower KGP is silently upgraded to 2.2.10.
//
// This project wants Kotlin 2.4.0 (see `kotlin` in libs.versions.toml: the
// Compose compiler, serialization plugin and several test libraries are aligned
// to it). The officially documented way to make built-in Kotlin use a HIGHER
// KGP than the bundled one is to put it on the buildscript classpath here:
buildscript {
    dependencies {
        // Forces AGP's built-in Kotlin to compile with 2.4.0 rather than the
        // bundled 2.2.10. Keep this in sync with `kotlin` in libs.versions.toml
        // (a buildscript block cannot read the version catalog, hence the
        // literal). KSP (2.3.9) is applied normally via the plugins block in
        // app/build.gradle.kts; because 2.3.9 is above AGP's KSP floor it is not
        // force-upgraded. If a future build reports a KGP/KSP mismatch, add:
        //   classpath("com.google.devtools.ksp:symbol-processing-gradle-plugin:2.3.9")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.0")
    }
}

plugins {
    // Android Gradle Plugin – the core tool for Android builds.
    // "apply false": only registered here, not activated
    alias(libs.plugins.android.application) apply false

    // No kotlin-android plugin: AGP 9's built-in Kotlin replaces it (the
    // compiler version is pinned via the buildscript block above).

    // Kotlin Compose plugin – the Compose compiler extension
    alias(libs.plugins.kotlin.compose)      apply false

    // KSP – Kotlin Symbol Processor (for Room code generation)
    alias(libs.plugins.ksp)                 apply false

    // CycloneDX – generates a standardized SBOM for the release APK. Registered
    // here with "apply false" (consistent with the other plugins) and actually
    // applied in app/build.gradle.kts, where it is scoped to the release
    // runtime classpath.
    alias(libs.plugins.cyclonedx)           apply false

    // ktlint – enforces the Kotlin coding style automatically. Registered here
    // with "apply false" (consistent with the other plugins) and actually
    // applied in app/build.gradle.kts. Its ktlintCheck task is a build-time
    // verification only; it is not part of the release-assembly path, so the
    // APK output and reproducible builds are unaffected.
    alias(libs.plugins.ktlint)              apply false

    // Kover – measures Kotlin statement/branch test coverage. Registered here
    // with "apply false" (consistent with the other plugins) and actually
    // applied in app/build.gradle.kts. Its report tasks are build-time only and
    // not part of the release-assembly path, so the APK output and reproducible
    // builds are unaffected.
    alias(libs.plugins.kover)               apply false
}
