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

plugins {
    // Android Gradle Plugin – Kernwerkzeug für Android-Builds
    // "apply false": hier nur registrieren, nicht aktivieren
    alias(libs.plugins.android.application) apply false

    // Kotlin Android Plugin – Kotlin-Compiler für Android
    alias(libs.plugins.kotlin.android)      apply false

    // Kotlin Compose Plugin – Compose-Compiler-Erweiterung
    alias(libs.plugins.kotlin.compose)      apply false

    // KSP – Kotlin Symbol Processor (für Room-Code-Generierung)
    alias(libs.plugins.ksp)                 apply false
}
