// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
// settings.gradle.kts – Projektstruktur und Repository-Konfiguration
// =============================================================================
//
// This file is read by Gradle FIRST, before any build.gradle.kts.
// It configures:
//   1. Where Gradle downloads plugins from (pluginManagement)
//   2. Where Gradle downloads libraries from (dependencyResolutionManagement)
//   3. Which modules belong to this project (include)
//
// REPOSITORIES:
//   google()             – Google's Maven repository (AndroidX, AGP, Compose etc.)
//   mavenCentral()       – Central Maven repository (most open-source libraries)
//   gradlePluginPortal() – Gradle's own plugin repository
// =============================================================================

// pluginManagement: for Gradle plugins only (not for app libraries)
pluginManagement {
    repositories {
        // Google repository: Android-specific plugins (AGP, KSP)
        google {
            // content { }: restricts which groups are loaded from here.
            // Prevents unnecessary network requests to the wrong repository.
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()  // for Kotlin plugins and KSP
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.10.0"
}

// dependencyResolutionManagement: for app libraries (Compose, Room etc.)
dependencyResolutionManagement {
    // FAIL_ON_PROJECT_REPOS: prevents individual modules from defining their own
    // repository lists. All repositories must be declared here.
    // Improves reproducibility and security of the build.
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()
        mavenCentral()
    }

    // gradle/libs.versions.toml is automatically recognised by Gradle 8.x as the
    // "libs" version catalog – no explicit versionCatalogs block needed.
}

// Project name (shown in the IDE and build output)
rootProject.name = "potillus"

// Modules that belong to this project.
// ":app" = the "app/" subdirectory with its own build.gradle.kts.
// Larger projects would list additional modules here:
//   include(":app", ":shared", ":feature-stats")
include(":app")
