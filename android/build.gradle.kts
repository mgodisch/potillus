// vim: set et ts=4:
// =============================================================================
// Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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
//
// =============================================================================

// =============================================================================
// build.gradle.kts – Projekt-level Build-Datei (Wurzelverzeichnis)
// =============================================================================
//
// UNTERSCHIED ZU app/build.gradle.kts:
//   Diese Datei gilt für das GESAMTE Projekt (alle Module).
//   app/build.gradle.kts gilt nur für das ":app"-Modul.
//
//   In einem einfachen Projekt mit nur einem App-Modul enthält diese
//   Datei fast nichts – sie deklariert lediglich welche Plugins
//   VERFÜGBAR sind, ohne sie direkt anzuwenden (apply false).
//
// WARUM "apply false"?
//   Die Plugins werden hier nur "bekannt gemacht" (mit fester Version),
//   aber erst in den Untermodulen tatsächlich angewendet.
//   Das verhindert Versionskonflikte wenn mehrere Module dieselben
//   Plugins in unterschiedlichen Versionen benötigen würden.
// =============================================================================

// ── built-in Kotlin: pin the compiler version ───────────────────────────────
// AGP 9 has built-in Kotlin support: the Android plugin compiles Kotlin itself
// and no longer needs org.jetbrains.kotlin.android. To provide this, AGP 9 has
// a runtime dependency on the Kotlin Gradle plugin (KGP) and bundles 2.2.10 as
// a floor; a lower KGP is silently upgraded to 2.2.10.
//
// This project wants Kotlin 2.3.21 (see `kotlin` in libs.versions.toml: the
// Compose compiler, serialization plugin and several test libraries are aligned
// to it). The officially documented way to make built-in Kotlin use a HIGHER
// KGP than the bundled one is to put it on the buildscript classpath here:
buildscript {
    dependencies {
        // Forces AGP's built-in Kotlin to compile with 2.3.21 rather than the
        // bundled 2.2.10. Keep this in sync with `kotlin` in libs.versions.toml
        // (a buildscript block cannot read the version catalog, hence the
        // literal). KSP (2.3.7) is applied normally via the plugins block in
        // app/build.gradle.kts; because 2.3.7 is above AGP's KSP floor it is not
        // force-upgraded. If a future build reports a KGP/KSP mismatch, add:
        //   classpath("com.google.devtools.ksp:symbol-processing-gradle-plugin:2.3.7")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.21")
    }
}

plugins {
    // Android Gradle Plugin – Kernwerkzeug für Android-Builds
    // "apply false": hier nur registrieren, nicht aktivieren
    alias(libs.plugins.android.application) apply false

    // No kotlin-android plugin: AGP 9's built-in Kotlin replaces it (the
    // compiler version is pinned via the buildscript block above).

    // Kotlin Compose Plugin – Compose-Compiler-Erweiterung
    alias(libs.plugins.kotlin.compose)      apply false

    // KSP – Kotlin Symbol Processor (für Room-Code-Generierung)
    alias(libs.plugins.ksp)                 apply false
}
