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
// app/build.gradle.kts – Build configuration for the app module
// =============================================================================
//
// GRADLE BASICS:
//   Gradle is Android's build system. It reads this file to know how to compile
//   the source code into an APK.
//
//   ".kts" = Kotlin Script. Since AGP 7+, Kotlin (instead of Groovy) is the
//   recommended language for build scripts. Kotlin provides type safety and
//   IDE auto-completion in Android Studio.
//
//   Structure of this file:
//     1. plugins { }      – which build tools to use
//     2. android { }      – all Android-specific settings
//     3. dependencies { } – external libraries
// =============================================================================

// ── 1. Plugins ────────────────────────────────────────────────────────────────
// Plugins are Gradle extensions that add new build capabilities.
// "alias(libs.plugins.xxx)" refers to an entry in gradle/libs.versions.toml.
plugins {
    // Android Application Plugin:
    // Enables the "android { }" block and knows how to build an APK.
    alias(libs.plugins.android.application)

    // Kotlin Android Plugin:
    // Enables the Kotlin compiler for Android source code.
    alias(libs.plugins.kotlin.android)

    // Kotlin Compose Compiler Plugin:
    // Required so that @Composable functions are compiled correctly.
    // Since Kotlin 1.9.20 this is a separate plugin (was built-in before).
    alias(libs.plugins.kotlin.compose)

    // Kotlin Serialization Plugin:
    // Processes @Serializable annotations on Navigation route objects.
    // Required for type-safe Navigation 2.8+ routes.
    alias(libs.plugins.kotlin.serialization)

    // KSP (Kotlin Symbol Processing):
    // Reads annotations like @Entity, @Dao, @PrimaryKey in Room classes
    // and generates the SQLite implementation at build time.
    // Advantage over kapt: ~2× faster, incremental.
    alias(libs.plugins.ksp)
}

// ── 2. Android Configuration ──────────────────────────────────────────────────
android {
    // Unique application identifier in the Android ecosystem.
    // Format: reversed domain (like Java packages).
    // This string identifies the app on GrapheneOS, in the Google Play Store
    // (if ever published there), and during ADB installation.
    // WARNING: Never change after the first installation –
    //          it would be treated as a new app and all user data would be lost.
    namespace         = "de.godisch.potillus"

    // compileSdk: the Android API level to *compile* against.
    // This is the SDK version installed on the developer machine.
    // May be higher than targetSdk and minSdk.
    // 36 = Android 16 (latest API at development time)
    compileSdk        = 36

    // buildToolsVersion: explicitly set to 36.0.0 so that D8 recognises API levels
    // 35/36 and does not emit "API level not supported" warnings.
    buildToolsVersion = "36.0.0"

    defaultConfig {
        // applicationId: normally matches namespace but can differ.
        // For simple projects it is identical to namespace.
        applicationId                    = "de.godisch.potillus"

        // minSdk: minimum Android version the APK supports.
        // Devices running an older version cannot install the app.
        // 35 = Android 15
        // GrapheneOS users typically have current Pixel devices,
        // so 35 is a reasonable minimum.
        minSdk                           = 35

        // targetSdk: the Android version the app is OPTIMISED for.
        // Android uses this to decide whether to activate compatibility modes.
        // targetSdk = 36 means: the app expects full Android 16 behaviour
        // (no compatibility shims).
        targetSdk                        = 36

        // versionCode: opaque monotonic integer, bumped by at least 1 for every
        // published APK. Android uses it (not versionName) to order updates.
        // versionName: human-readable MAJOR.MINOR.PATCH string.
        // Keep both in lock-step with the CHANGELOG, the README title and the
        // proguard-rules.pro header — release-check.sh §1 enforces this.
        versionCode = 49

        // User-visible version number (String). Keep in sync with CHANGELOG.md.
        versionName = "0.56.0"

        // ─────────────────────────────────────────────────────────────────────
        // LOCALISATION — how to add a new language (all steps are required)
        // ─────────────────────────────────────────────────────────────────────
        // Step 1: Create app/src/main/res/values-<bcp47>/strings.xml
        //         Translate all 181 keys. Source of truth: values-de/strings.xml.
        //         (The exact count is verified by LocaleSyncTest — treat that test,
        //          not this comment, as the authoritative source if they ever differ.)
        //         Qualifier syntax:  values-fr/  values-pt-rBR/  values-zh-rCN/
        //
        // Step 2: Register the locale in app/src/main/res/xml/locale_config.xml
        //         !! MOST COMMONLY FORGOTTEN STEP !!
        //         Add: <locale android:name="<bcp47-without-r>"/>
        //         e.g. values-pt-rBR/ → android:name="pt-BR"
        //              values-zh-rCN/ → android:name="zh-CN"
        //         Without this entry the language never appears in the picker.
        //
        // Step 3 (RTL only): android:supportsRtl="true" is already set in
        //         AndroidManifest.xml — no further action needed.
        //
        // See also: AndroidManifest.xml for the full three-step checklist.
        // ─────────────────────────────────────────────────────────────────────

        // Test runner for instrumented tests (run on device/emulator).
        // Not relevant for pure JVM unit tests.
        testInstrumentationRunner        = "androidx.test.runner.AndroidJUnitRunner"

        // KSP argument for Room:
        // Room writes the database schema as JSON into this folder.
        // Useful for tracking migrations (version 1 → 2 etc.)
        ksp {
            arg("room.schemaLocation", "$projectDir/schemas")
        }
    }

    // Build types: "debug" and "release" are predefined.
    // More can be added here (e.g. "staging").
    buildTypes {

        // Release build: for actual distribution
        release {
            // isMinifyEnabled: enables R8 (code shrinking + obfuscation)
            // R8 removes unused code and shortens class names.
            // Result: smaller APK, harder to reverse-engineer.
            isMinifyEnabled  = true

            // isShrinkResources: removes unused resources (images, strings).
            // Only works when isMinifyEnabled = true.
            isShrinkResources = true

            // ProGuard rules: specify what R8 must NOT remove or rename.
            // Important for reflection-based libraries such as Room and Biometric.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        // Debug build: for development and ADB installation
        debug {
            isMinifyEnabled   = false   // kein R8 → schnellerer Build

            // Suffix prevents conflicts: debug and release APK
            // can be installed side-by-side on the same device.
            applicationIdSuffix = ".debug"
            versionNameSuffix   = "-debug"
        }
    }

    // Java compatibility:
    // sourceCompatibility/targetCompatibility = which Java version the *source*
    // uses and which JVM it is *compiled* for.
    // JDK 21 is LTS (Long-Term Support) and officially supported by AGP 8.x.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    // Kotlin compiler target: must match compileOptions.targetCompatibility.
    kotlinOptions {
        jvmTarget = "21"
    }

    // buildFeatures: enable/disable optional build capabilities
    buildFeatures {
        // compose = true: activates the Compose compiler for this module.
        // Without this flag, @Composable annotations are not processed.
        compose = true

        // buildConfig = true: generates the BuildConfig class (package de.godisch.potillus).
        // AGP 8.0+ disables this by default to reduce build times for projects that do
        // not need it. We need it for BuildConfig.DEBUG guards around Log calls so that
        // R8 can eliminate all logging from release builds at compile time.
        buildConfig = true
    }

    // packaging: prevents conflicts when multiple libraries ship files
    // with the same name under META-INF/.
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    // MIGRATION TESTING (room-testing / MigrationTestHelper):
    //   MigrationTestHelper reads the exported schema JSONs (app/schemas/) from
    //   the test APK's assets at runtime. Exposing the schema directory as an
    //   androidTest asset source makes createDatabase(name, version) able to find
    //   the historical schema for each version. Without this, the migration test
    //   fails with "Cannot find the schema file in the assets folder".
    sourceSets {
        getByName("androidTest") {
            assets.srcDirs(files("$projectDir/schemas"))
        }
    }

    // UNIT-TEST JVM ENVIRONMENT:
    //   Local unit tests run against a stubbed android.jar in which every method
    //   throws "Method ... not mocked" by default. isReturnDefaultValues makes
    //   those stubs return defaults (0 / null / false) instead — required because
    //   several ViewModels call android.util.Log.w(...) in their input-rejection
    //   paths, which would otherwise throw RuntimeException during pure-logic tests.
    //   (org.json, used by BackupManager, is handled separately by adding a real
    //   org.json:json dependency to the test classpath; see the dependencies block.)
    testOptions {
        unitTests {
            isReturnDefaultValues = true
        }
    }
}

// ── 3. Dependencies ───────────────────────────────────────────────────────────
// "implementation":      available at runtime, not exported to dependent modules
// "ksp":                 build-time only (code generation), not in APK
// "debugImplementation": debug build only
// "platform(...)":       BOM – pins versions for all sub-modules
dependencies {

    // androidx.tracing: pinned explicitly to 1.1.0. The app would otherwise
    // resolve it transitively (via androidx.activity / androidx.startup) to 1.0.0
    // on debugRuntimeClasspath. AGP's "consistent resolution" then mirrors that as
    // a STRICT 1.0.0 constraint onto the androidTest classpaths — but androidx.test
    // (test:core / test:monitor) requires 1.1.0, which made instrumented-test
    // dependency resolution fail. Raising the app's own runtime to 1.1.0 makes the
    // mirrored constraint 1.1.0 too, satisfying androidx.test. (tracing is a tiny
    // diagnostic library; 1.1.0 is backward-compatible with 1.0.0.)
    implementation("androidx.tracing:tracing:1.1.0")

    // ── Kotlin & AndroidX Base ────────────────────────────────────────────────
    // core-ktx: Kotlin extension functions for Android APIs
    implementation(libs.core.ktx)

    // appcompat: base for AppCompatActivity (biometrics, language switching)
    implementation(libs.appcompat)

    // activity-compose: setContent { } entry point for Compose
    implementation(libs.activity.compose)

    // lifecycle-runtime-ktx: lifecycleScope for coroutines in Activity/Fragment
    implementation(libs.lifecycle.runtime.ktx)

    // lifecycle-runtime-compose: collectAsStateWithLifecycle()
    // Observes Kotlin Flows lifecycle-safely in composables
    implementation(libs.lifecycle.runtime.compose)

    // lifecycle-viewmodel-compose: viewModel() composable
    implementation(libs.lifecycle.viewmodel.compose)

    // ── Jetpack Compose ───────────────────────────────────────────────────────
    // BOM zuerst einbinden – legt Versionen aller compose-* Module fest
    implementation(platform(libs.compose.bom))

    // Danach einzelne Module ohne Versionsangabe (BOM bestimmt sie):
    implementation(libs.compose.ui)             // Kern-UI-Primitiven
    implementation(libs.compose.ui.graphics)    // Canvas, Farben, Grafik
    implementation(libs.compose.ui.tooling.preview)  // @Preview
    implementation(libs.compose.material3)      // Material Design 3 Widgets
    implementation(libs.compose.material.icons) // Icons.Default.*

    // ── Navigation ────────────────────────────────────────────────────────────
    implementation(libs.navigation.compose)
    // kotlinx-serialization-core: required by type-safe Navigation 2.8+
    // route objects annotated with @Serializable
    implementation(libs.kotlinx.serialization.core)

    // ── Room (SQLite) ─────────────────────────────────────────────────────────
    implementation(libs.room.runtime)   // core runtime
    implementation(libs.room.ktx)       // coroutine support

    // room-compiler: KSP generates DAO implementations → build time only
    ksp(libs.room.compiler)

    // ── DataStore ─────────────────────────────────────────────────────────────
    implementation(libs.datastore.preferences)

    // ── Biometrics ────────────────────────────────────────────────────────────
    implementation(libs.biometric)

    // ── Security ──────────────────────────────────────────────────────────────
    //
    // SQLCipher: application-level AES-256 encryption for the Room database.
    //   SupportFactory wraps Room's SQLite helper so every read/write goes
    //   through the cipher transparently. The passphrase is a 32-byte random
    //   value sealed by the Android Keystore (KeystoreSecretStore) and stored as
    //   a Base64 envelope in a plain SharedPreferences file (see AppDatabase.kt).
    // Migrated to version catalog (libs.versions.toml → sqlcipher).
    // @aar is handled via the catalog artifact classifier field.
    implementation(libs.sqlcipher)
    // androidx.sqlite is required by SQLCipher as the SupportSQLiteDatabase
    // adapter; it replaces Android's own bundled SQLite JNI bindings.
    implementation(libs.sqlite)

    // NOTE: androidx.security:security-crypto is intentionally not used (Google deprecated it).
    //   It was deprecated by Google in April 2025 in favour of using the Android
    //   Keystore directly. Its only use (storing the SQLCipher passphrase via
    //   EncryptedSharedPreferences in AppDatabase) was migrated to the app's own
    //   KeystoreSecretStore (de.godisch.potillus.data.security), which is the same
    //   primitive AppPreferences already used for the encrypted DataStore.

    // ── Debug build only ──────────────────────────────────────────────────────
    // compose-ui-tooling: Layout Inspector, recomposition tracking
    // Stripped from release builds by R8/ProGuard
    debugImplementation(libs.compose.ui.tooling)
    // ── Unit Tests (JVM) ──────────────────────────────────────────────────────
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test:2.0.21")

    // kotlinx-coroutines-test: runTest, UnconfinedTestDispatcher, advanceUntilIdle
    // Required for testing ViewModels that use viewModelScope and StateFlow.
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")

    // turbine: concise Flow / SharedFlow / StateFlow assertions in tests.
    // Replaces verbose backgroundScope + collect {} boilerplate.
    testImplementation("app.cash.turbine:turbine:1.2.0")

    // org.json: the SDK's android.jar ships only STUB org.json classes that throw
    // "not mocked" in local unit tests. BackupManager parses and builds JSON with
    // org.json, so the BackupManager/BackupRepository tests need a REAL
    // implementation on the unit-test classpath. This is the same reference
    // implementation Android uses at runtime, and it takes precedence over the
    // stub for unit tests.
    testImplementation("org.json:json:20240303")

    // ── Instrumented UI Tests (androidTest) ─────────────────────────
    // These run on a device/emulator. The Compose BOM (added again here for the
    // androidTest classpath) pins ui-test-junit4 to the same Compose version as
    // the app, so the test artifacts and the UI under test never diverge.
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.androidx.test.ext.junit)   // AndroidJUnit4
    androidTestImplementation(libs.compose.ui.test.junit4)    // createComposeRule, finders, actions

    // androidx.test runner + espresso, pinned to current versions. Compose 1.8's
    // ui-test integrates with the Espresso / instrumentation-runner machinery to
    // register and query Compose roots (the ComposeRootRegistry that backs
    // onNodeWith* finders). The versions pulled in transitively by Compose's
    // ui-test (runner 1.5.0 / espresso-core 3.5.0, from 2022) predate Android 15 /
    // SDK 35 and can leave that registry unpopulated, surfacing as
    // "No compose hierarchies found". Aligning them with the modern test
    // infrastructure is the supported configuration. androidTest-only.
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")

    // room-testing: MigrationTestHelper validates each Room Migration against the
    // committed schema JSONs (app/schemas/), so a broken migration fails the test
    // suite instead of crashing a user's app on first launch after an update.
    androidTestImplementation(libs.room.testing)

    // ui-test-manifest provides the empty Activity that createComposeRule()
    // launches. It MUST be a debugImplementation (not androidTestImplementation)
    // because it has to be merged into the debug app manifest the tests run against.
    debugImplementation(libs.compose.ui.test.manifest)

}
