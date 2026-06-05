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

// JvmTarget enum used by the Kotlin `compilerOptions` DSL (see the top-level
// `kotlin { }` block further down). In a Gradle Kotlin DSL build script, import
// statements must appear before the `plugins { }` block.
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// ── 1. Plugins ────────────────────────────────────────────────────────────────
// Plugins are Gradle extensions that add new build capabilities.
// "alias(libs.plugins.xxx)" refers to an entry in gradle/libs.versions.toml.
plugins {
    // Android Application Plugin:
    // Enables the "android { }" block and knows how to build an APK.
    // As of AGP 9 this plugin also provides built-in Kotlin support, so the
    // separate org.jetbrains.kotlin.android plugin is no longer applied (the
    // Kotlin compiler version is pinned in the root build.gradle.kts).
    alias(libs.plugins.android.application)

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

    defaultConfig {
        // applicationId: normally matches namespace but can differ.
        // For simple projects it is identical to namespace.
        applicationId                    = "de.godisch.potillus"

        // minSdk: minimum Android version the APK supports.
        // Devices running an older version cannot install the app.
        //
        // 30 = Android 11. Lowered from 35 (Android 15) in v0.60.1.
        //
        // WHY 30 IS SAFE — every version-sensitive API this app actually uses is
        // available at API 30 or below, so NO `Build.VERSION.SDK_INT` branches are
        // required anywhere in the codebase:
        //   • MediaStore Downloads + RELATIVE_PATH (CsvExporter, PdfExporter,
        //     BackupManager) — API 29. This is also the FLOOR: it lets the app
        //     write to the public Downloads folder WITHOUT WRITE_EXTERNAL_STORAGE.
        //     Going below API 29 would force a storage permission (or the Storage
        //     Access Framework) and break the app's minimal-permission design, so
        //     29/30 is a deliberate, principled floor — not an arbitrary one.
        //   • Android Keystore AES-256-GCM (KeystoreSecretStore) — API 23.
        //   • androidx.biometric / USE_BIOMETRIC — API 23.
        //   • WindowCompat edge-to-edge insets (MainActivity) — all API levels.
        //   • Runtime locale switching via AppCompatDelegate — back-ported to all.
        //   • Adaptive launcher icons (mipmap-anydpi-v26) with PNG fallbacks — OK.
        //   • No dynamicColor / Material You, so no API-31 colour branch is needed.
        //
        // GRACEFUL DEGRADATION on API 30–32 (documented, no code needed):
        //   • The SYSTEM per-app language picker (android:localeConfig) is API 33+.
        //     On 30–32 the in-app language selector (SettingsScreen) still works;
        //     only the OS Settings integration is absent.
        //   • android:dataExtractionRules is API 31+ and is ignored on API 30, but
        //     allowBackup="false" disables backup outright — so no data leaks.
        //
        // The library stack imposes its own hard floor of API 23 (AndroidX since
        // June 2025; Jetpack Compose since inception), so 30 sits comfortably above
        // it. Reachable devices roughly double versus API 35 (~41% → ~87% of the
        // worldwide install base, per apilevels.com / Statcounter, April 2026).
        minSdk                           = 30

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
        versionCode = 62

        // User-visible version number (String). Keep in sync with CHANGELOG.md.
        versionName = "0.64.0"

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

        // Core library desugaring: let D8/R8 rewrite calls to newer java.* APIs
        // (notably java.time) so they resolve against the bundled desugar_jdk_libs
        // implementation instead of the platform classes.
        //
        // WHY THIS IS REQUIRED:
        //   The app calls java.time.LocalDate.datesUntil(...) (a Java 9 API) in
        //   StatsViewModel, DayResolver and PdfReportData. On Android, java.time
        //   is provided by the *updatable* ART mainline module. datesUntil() was
        //   backported into a later ART revision, so at one and the same API
        //   level a device with a newer (Play-updated) module has the method
        //   while an older emulator system image does not — the missing method
        //   then crashes at runtime with NoSuchMethodError, but only on the
        //   affected runtime. Desugaring ships the implementation inside the APK,
        //   making these APIs available uniformly down to minSdk regardless of
        //   the device's module version.
        //
        //   The matching `coreLibraryDesugaring(...)` dependency is declared in
        //   the dependencies { } block below; both halves are mandatory.
        isCoreLibraryDesugaringEnabled = true
    }

    // Kotlin compiler target: must match compileOptions.targetCompatibility.
    // NOTE: the old `kotlinOptions { jvmTarget = "21" }` proxy (a String setter)
    // was removed by the Kotlin 2.3 Gradle plugin — it is now a hard compile
    // error, not a warning. The replacement lives in the top-level `kotlin { }`
    // block below, using the type-safe `compilerOptions` DSL.

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
            // AGP 9 deprecates AndroidSourceSet.srcDirs(...) in favour of the
            // `directories` mutable set, to which you append String paths with
            // `+=` (instead of passing a FileCollection via files(...)). The
            // resolved location is identical — app/schemas exposed as androidTest
            // assets — only the DSL changed.
            assets.directories += "$projectDir/schemas"
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

// ── 2b. Kotlin compiler options ───────────────────────────────────────────────
// Replacement for the removed `android { kotlinOptions { jvmTarget = "21" } }`.
// `kotlin { }` is the Kotlin Gradle plugin's own extension (top-level, a sibling
// of `android { }`). `compilerOptions.jvmTarget` is a typed Gradle Property of
// type JvmTarget, so we assign the JvmTarget.JVM_21 enum constant rather than the
// old "21" string. This must stay in sync with compileOptions.targetCompatibility
// (JavaVersion.VERSION_21) in the android { } block above.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_21)
    }
}

// ── 3. Dependencies ───────────────────────────────────────────────────────────
// "implementation":      available at runtime, not exported to dependent modules
// "ksp":                 build-time only (code generation), not in APK
// "debugImplementation": debug build only
// "platform(...)":       BOM – pins versions for all sub-modules
dependencies {

    // ── Core library desugaring ───────────────────────────────────────────────
    // Pairs with `isCoreLibraryDesugaringEnabled = true` in compileOptions above.
    // NOTE the special `coreLibraryDesugaring` configuration: it is NOT a normal
    // `implementation` dependency. D8/R8 dexes this artifact separately and links
    // the rewritten java.* calls (e.g. LocalDate.datesUntil) against it, so the
    // backported APIs work on every supported runtime. With R8 shrinking enabled
    // in release builds, only the actually-used classes are kept.
    coreLibraryDesugaring(libs.desugar.jdk.libs)

    // androidx.tracing: pinned explicitly to 1.1.0. The app would otherwise
    // resolve it transitively (via androidx.activity / androidx.startup) to 1.0.0
    // on debugRuntimeClasspath. AGP's "consistent resolution" then mirrors that as
    // a STRICT 1.0.0 constraint onto the androidTest classpaths — but androidx.test
    // (test:core / test:monitor) requires 1.1.0, which made instrumented-test
    // dependency resolution fail. Raising the app's own runtime to 1.1.0 makes the
    // mirrored constraint 1.1.0 too, satisfying androidx.test. (tracing is a tiny
    // diagnostic library; 1.1.0 is backward-compatible with 1.0.0.)
    implementation(libs.tracing)

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
    // room-runtime also provides the coroutine/Flow APIs (suspend DAOs etc.) that
    // used to live in the separate room-ktx artifact; room-ktx was merged into
    // room-runtime in Room 2.8 and is no longer declared.
    implementation(libs.room.runtime)

    // room-compiler: KSP generates DAO implementations → build time only
    ksp(libs.room.compiler)

    // ── DataStore ─────────────────────────────────────────────────────────────
    implementation(libs.datastore.preferences)

    // ── Biometrics ────────────────────────────────────────────────────────────
    implementation(libs.biometric)

    // ── Security ──────────────────────────────────────────────────────────────
    //
    // SQLCipher (net.zetetic:sqlcipher-android): application-level AES-256
    //   encryption for the Room database. SupportOpenHelperFactory wraps Room's
    //   SQLite helper so every read/write goes through the cipher transparently.
    //   The passphrase is a 32-byte random value sealed by the Android Keystore
    //   (KeystoreSecretStore) and stored as a Base64 envelope in a plain
    //   SharedPreferences file (see AppDatabase.kt). The native library is loaded
    //   explicitly via System.loadLibrary("sqlcipher") before the DB is opened.
    implementation(libs.sqlcipher)
    // androidx.sqlite provides the SupportSQLiteOpenHelper interfaces SQLCipher
    // implements and the low-level SQLite API Room builds on.
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
    testImplementation(libs.junit)
    // kotlin-test tracks the Kotlin compiler version: its catalog coordinate
    // references the `kotlin` version (libs.versions.toml), so the stdlib-test
    // artifact can never drift from the compiler and trigger a metadata mismatch.
    testImplementation(libs.kotlin.test)

    // kotlinx-coroutines-test: runTest, UnconfinedTestDispatcher, advanceUntilIdle
    // Required for testing ViewModels that use viewModelScope and StateFlow.
    // Bumped from 1.9.0: that release was built against Kotlin 2.0 and, by the
    // same forward-compatibility rule that affects serialization above, is not
    // guaranteed to load under the Kotlin 2.3.21 compiler. 1.11.0 is the current
    // release (built against Kotlin 2.2.x) and is compatible with 2.3.21. The
    // test-dispatcher semantics (StandardTestDispatcher as the runTest default,
    // advanceUntilIdle, UnconfinedTestDispatcher) are unchanged across this bump,
    // so the existing JVM unit tests keep behaving identically.
    testImplementation(libs.kotlinx.coroutines.test)

    // turbine: concise Flow / SharedFlow / StateFlow assertions in tests.
    // Replaces verbose backgroundScope + collect {} boilerplate.
    testImplementation(libs.turbine)

    // org.json: the SDK's android.jar ships only STUB org.json classes that throw
    // "not mocked" in local unit tests. BackupManager parses and builds JSON with
    // org.json, so the BackupManager/BackupRepository tests need a REAL
    // implementation on the unit-test classpath. This is the same reference
    // implementation Android uses at runtime, and it takes precedence over the
    // stub for unit tests.
    testImplementation(libs.org.json)

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
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.espresso.core)

    // room-testing: MigrationTestHelper validates each Room Migration against the
    // committed schema JSONs (app/schemas/), so a broken migration fails the test
    // suite instead of crashing a user's app on first launch after an update.
    androidTestImplementation(libs.room.testing)

    // ui-test-manifest provides the empty Activity that createComposeRule()
    // launches. It MUST be a debugImplementation (not androidTestImplementation)
    // because it has to be merged into the debug app manifest the tests run against.
    debugImplementation(libs.compose.ui.test.manifest)

}
