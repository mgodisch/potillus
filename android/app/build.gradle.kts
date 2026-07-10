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
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
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

// Script-level imports. In a Gradle Kotlin DSL build script every `import` must
// appear BEFORE the `plugins { }` block, and ktlint requires them contiguous, in
// lexicographic order, with no comments or blank lines between them (java/javax/
// kotlin sort last). Per-import notes therefore live here, above the block:
//   - kotlinx…CoverageUnit: selects LINE vs BRANCH for the Kover verification
//     bounds in the `kover { reports { verify { … } } }` block below.
//   - org.cyclonedx.Version / model.Component: pin the SBOM to CycloneDX 1.6 and
//     tag its subject as an application, for the cyclonedxDirectBom config below;
//     on the build-script classpath via the org.cyclonedx.bom plugin.
//   - org.jetbrains.kotlin.gradle.dsl.JvmTarget: used by the Kotlin
//     `compilerOptions` DSL in the top-level `kotlin { }` block below.
//   - java.util.Properties: reads the optional android/keystore.properties file in
//     the `signingConfigs` block below. It MUST be referenced as the bare
//     `Properties` (not `java.util.Properties`): inside that block the identifier
//     `java` resolves to the Gradle Java-plugin extension accessor, so a
//     fully-qualified `java.util.…` fails to compile ("Unresolved reference 'util'").
import kotlinx.kover.gradle.plugin.dsl.CoverageUnit
import org.cyclonedx.Version
import org.cyclonedx.model.Component
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

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

    // CycloneDX SBOM generator:
    // Adds the cyclonedxDirectBom task that writes a CycloneDX 1.6 JSON SBOM for
    // the release runtime classpath. Configured in the cyclonedxDirectBom block
    // at the end of this file. Build-time only; nothing is added to the APK.
    alias(libs.plugins.cyclonedx)

    // ktlint (org.jlleitschuh.gradle.ktlint):
    // Enforces the Kotlin coding style declared in CONTRIBUTING.md §4. It adds
    // the ktlintCheck task (hooked into `check`) and the ktlintFormat task
    // (auto-formats sources). Style settings are read from the repository-root
    // .editorconfig. This is build-time verification only: ktlintCheck is not on
    // the release-assembly path (assembleRelease), so it adds nothing to the APK
    // and does not affect reproducible builds. ktlint is downloaded from the
    // central repository already configured in settings.gradle.kts.
    alias(libs.plugins.ktlint)

    // Kover (org.jetbrains.kotlinx.kover):
    // Measures statement and branch coverage from the JVM unit tests, toward the
    // silver 80% and gold 90%/branch-80% coverage criteria. Coverage is measured
    // over the unit-testable code; the Compose UI layer, the framework entry
    // points, and generated code are excluded (see the kover { } block at the end
    // of this file) because they are exercised by instrumented tests rather than
    // JVM unit tests. Report tasks are build-time only and not on the
    // release-assembly path, so they add nothing to the APK.
    alias(libs.plugins.kover)
}

// ── 2. Android Configuration ──────────────────────────────────────────────────
android {
    // Unique application identifier in the Android ecosystem.
    // Format: reversed domain (like Java packages).
    // This string identifies the app on GrapheneOS, in the Google Play Store
    // (if ever published there), and during ADB installation.
    // WARNING: Never change after the first installation –
    //          it would be treated as a new app and all user data would be lost.
    namespace = "de.godisch.potillus"

    // compileSdk: the Android API level to *compile* against.
    // This is the SDK version installed on the developer machine.
    // May be higher than targetSdk and minSdk.
    // 36 = Android 16 (latest API at development time)
    compileSdk = 36

    defaultConfig {
        // applicationId: normally matches namespace but can differ.
        // For simple projects it is identical to namespace.
        applicationId = "de.godisch.potillus"

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
        minSdk = 30

        // targetSdk: the Android version the app is OPTIMISED for.
        // Android uses this to decide whether to activate compatibility modes.
        // targetSdk = 36 means: the app expects full Android 16 behaviour
        // (no compatibility shims).
        targetSdk = 36

        // versionCode: opaque monotonic integer, bumped by at least 1 for every
        // published APK. Android uses it (not versionName) to order updates.
        // versionName: human-readable MAJOR.MINOR.PATCH string.
        // Keep both in lock-step with the CHANGELOG, the README title and the
        // proguard-rules.pro header — release-check.sh §1 enforces this.
        versionCode = 92

        // User-visible version number (String). Keep in sync with CHANGELOG.md.
        versionName = "0.81.0"

        // ─────────────────────────────────────────────────────────────────────
        // LOCALISATION — how to add a new language (all steps are required)
        // ─────────────────────────────────────────────────────────────────────
        // Step 1: Create app/src/main/res/values-<bcp47>/strings.xml
        //         Translate ALL keys — LocaleSyncTest pins the exact set, so the
        //         authoritative count lives in that test, never in a comment.
        //         Source of truth: values-de/strings.xml.
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
        // See also: AndroidManifest.xml for the full checklist, including
        //         Step 4 (the Google Play store-locale directory under
        //         fastlane/metadata/android/ — its code usually differs from the
        //         resource tag, e.g. values-ja/ → ja-JP/; release-check §4 Check D
        //         enforces the mapping).
        // ─────────────────────────────────────────────────────────────────────

        // Test runner for instrumented tests (run on device/emulator).
        // Not relevant for pure JVM unit tests.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // ─────────────────────────────────────────────────────────────────────
        // SCREENSHOT-TEST OPT-OUT SWITCH (documented; OFF by default)
        // ─────────────────────────────────────────────────────────────────────
        //   The Play-Store screenshot-capture suite (ScreenshotTest, tagged with
        //   the @de.godisch.potillus.screenshot.ScreenshotOnly annotation) runs as
        //   part of the ordinary `connectedDebugAndroidTest` / `make test-device`
        //   run by DEFAULT — the project deliberately does NOT hide it, so a broken
        //   capture flow is caught by the normal test gate.
        //
        //   To EXCLUDE it from a regular instrumented-test run, pass the Gradle
        //   property `-PexcludeScreenshotTests` (or set it in gradle.properties):
        //
        //       ./gradlew connectedDebugAndroidTest -PexcludeScreenshotTests
        //
        //   The android/Makefile surfaces the same switch ergonomically as:
        //
        //       make test-device EXCLUDE_SCREENSHOTS=1
        //
        //   When the property is present, the JUnit `notAnnotation` instrumentation
        //   argument is registered so AndroidX Test skips every test annotated with
        //   @ScreenshotOnly. The `make screenshots` flow is unaffected: screengrab
        //   targets the screenshot package directly (Screengrabfile
        //   `use_tests_in_packages`) instead of relying on this annotation.
        if (project.hasProperty("excludeScreenshotTests")) {
            testInstrumentationRunnerArguments["notAnnotation"] =
                "de.godisch.potillus.screenshot.ScreenshotOnly"
        }

        // KSP argument for Room:
        // Room writes the database schema as JSON into this folder.
        // Useful for tracking migrations (version 1 → 2 etc.)
        ksp {
            arg("room.schemaLocation", "$projectDir/schemas")
        }
    }

    // ── Release signing (OPTIONAL — absent by default) ────────────────────────
    //
    // WHY THIS IS CONDITIONAL:
    //   F-Droid builds the app from source and signs the resulting APK with ITS
    //   OWN key, so the source tree must keep building an UNSIGNED artifact when
    //   no developer key is configured. At the same time, a Google-Play release
    //   needs a signed APK/AAB. This block satisfies both: it declares a
    //   "release" signing config but only POPULATES it when key material is
    //   actually available. If nothing is found, the config stays empty and the
    //   release build below leaves `signingConfig` unset → `assembleRelease`
    //   produces `app-release-unsigned.apk`, exactly as before this change.
    //
    // TWO EQUALLY SUPPORTED WAYS TO SUPPLY THE KEY (see keystore.properties.example):
    //   (a) a local, git-ignored `android/keystore.properties` file, or
    //   (b) environment variables (handy for CI), which OVERRIDE the file.
    // Neither the keystore nor the passwords are ever committed: both the
    // properties file and the Play service-account JSON are listed in .gitignore.
    signingConfigs {
        create("release") {
            // rootProject is the `android/` directory (single-module build, see
            // settings.gradle.kts), so this resolves to android/keystore.properties.
            val keystorePropsFile = rootProject.file("keystore.properties")
            val props = Properties().apply {
                if (keystorePropsFile.exists()) {
                    keystorePropsFile.inputStream().use { load(it) }
                }
            }

            // Environment variable wins over the file entry; returns null if neither
            // is set, which is the signal further down to stay unsigned.
            fun value(propKey: String, envKey: String): String? = System.getenv(envKey) ?: props.getProperty(propKey)

            val storePath = value("storeFile", "POTILLUS_KEYSTORE_FILE")
            val storePass = value("storePassword", "POTILLUS_KEYSTORE_PASSWORD")
            val alias = value("keyAlias", "POTILLUS_KEY_ALIAS")
            val keyPass = value("keyPassword", "POTILLUS_KEY_PASSWORD")

            // Populate the config ONLY when all four values are present. A partial
            // configuration would fail the build, so it is treated as "no key".
            if (storePath != null && storePass != null && alias != null && keyPass != null) {
                storeFile = rootProject.file(storePath)
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
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
            isMinifyEnabled = true

            // isShrinkResources: removes unused resources (images, strings).
            // Only works when isMinifyEnabled = true.
            isShrinkResources = true

            // ProGuard rules: specify what R8 must NOT remove or rename.
            // Important for reflection-based libraries such as Room and Biometric.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Apply the release signing config ONLY if it was populated in the
            // signingConfigs block above (i.e. key material was found). When it
            // was not, `storeFile` is null and we leave `signingConfig` unset, so
            // the build stays unsigned — the configuration F-Droid relies on. With
            // a key configured, both `assembleRelease` (APK) and `bundleRelease`
            // (AAB) are signed for Google Play.
            //
            // Use findByName (nullable) rather than getByName (throws): F-Droid's
            // build strips the whole `signingConfigs { release { … } }` block out
            // of build.gradle.kts before building, because it signs APKs itself.
            // After that removal the "release" config no longer exists, so
            // getByName("release") would fail the build with
            // "SigningConfig with name 'release' not found". findByName returns
            // null in that case and the null-safe check below simply leaves the
            // build unsigned — exactly what F-Droid expects.
            val releaseSigningConfig = signingConfigs.findByName("release")
            if (releaseSigningConfig?.storeFile != null) {
                signingConfig = releaseSigningConfig
            }
        }

        // Debug build: for development and ADB installation
        debug {
            isMinifyEnabled = false // no R8 → faster builds

            // Suffix prevents conflicts: debug and release APK
            // can be installed side-by-side on the same device.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    // Dependency metadata block (privacy / transparency):
    // By default the Android Gradle Plugin embeds a block of dependency metadata
    // into the APK's signing block (and into the AAB), encrypted with a Google
    // public key and readable only by Google Play. For an offline, network-free
    // FOSS app this is both pointless and opaque, and F-Droid prefers it gone.
    // Disabling it also removes one non-transparent, non-deterministic-leaning
    // artefact from the output, which helps reproducible-build verification.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    // App Bundle configuration (Google Play AAB only; F-Droid APKs are never
    // split and are unaffected by this block):
    //
    // WHY LANGUAGE SPLITS MUST BE OFF:
    //   By default Google Play splits an AAB by language and installs only the
    //   device's languages. This app, however, offers an IN-APP language
    //   switcher (SettingsScreen → AppCompatDelegate.setApplicationLocales,
    //   plus perAppLocalizedContext() in l10n/LocaleSupport.kt for
    //   Application-context lookups): the user can select any of the 21
    //   supported languages at runtime, so ALL locale resources must already
    //   be on the device — with the default splits, a switched-to language
    //   would simply have no strings installed. The supported configurations
    //   are either the Play Core on-demand language download (a Play-services
    //   dependency this offline app deliberately avoids) or disabling the
    //   language split, chosen here. Cost: the AAB carries all 21 locales'
    //   STRING resources — negligible bytes for a text-only translation set.
    //
    // LINT: the AppBundleLocaleChanges check watches for dynamic locale calls
    //   (it pattern-matches Configuration.setLocales in perAppLocalizedContext;
    //   AppCompatDelegate alone never triggered it) and verifies exactly this
    //   `language.enableSplit = false` setting — the latent mismatch existed
    //   ever since the in-app switcher shipped, lint only gained a call site
    //   it recognises. With warningsAsErrors this block is what keeps
    //   `lintDebug` green.
    bundle {
        language {
            enableSplit = false
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
            // Several artifacts on the runtime classpath (notably the
            // kotlinx-coroutines JARs) each ship the SAME pair of licence-notice
            // files, META-INF/AL2.0 and META-INF/LGPL2.1; merging them verbatim
            // would fail with a duplicate-resource error, so the standard Compose
            // template excludes them. LICENCE-COMPLIANCE NOTE: this removes only
            // duplicated NOTICE-style text files, never code — no LGPL-licensed
            // code is compiled into this app (the LGPL2.1 file accompanies
            // coroutines' dual-licensed tooling heritage) — and the Apache-2.0
            // licence text itself IS delivered to users through the in-app
            // copyright document (res/raw/copyright.md, which bundles
            // LICENSE.Apache-2.0.md; see generateCopyrightDocument below).
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }

        // ── Native-library symbol stripping ───────────────────────────────────
        //   AGP's `stripDebugDebugSymbols` task runs the NDK `strip` tool over the
        //   bundled .so files to shrink them. When no NDK toolchain is present in
        //   the build environment (the common case here, and in the F-Droid build
        //   image — this app ships NO native code of its own, only a few transitive
        //   prebuilt .so), `strip` cannot run and AGP prints, for every affected
        //   library:
        //       Unable to strip the following libraries, packaging them as they
        //       are: libandroidx.graphics.path.so, libdatastore_shared_counter.so
        //   The libraries are then packaged unstripped anyway, so the message is
        //   purely cosmetic — but with `org.gradle.warning.mode=all` (set in
        //   gradle.properties) it surfaces on every build.
        //
        //   Listing those libraries here marks them as "intentionally kept
        //   unstripped", so AGP excludes them from the strip set and no longer
        //   attempts (and fails) to strip them — the warning disappears. The
        //   PACKAGED OUTPUT IS UNCHANGED: they were already shipped unstripped via
        //   the "packaging them as they are" fallback, so there is no size or
        //   behaviour difference, only a quieter, deterministic build. The two
        //   names are listed explicitly (rather than a blanket `**/*.so`) so that
        //   any NEW unstrippable library introduced by a future dependency update
        //   re-surfaces the warning and prompts a conscious decision — matching the
        //   project's "explicit policy, not blanket suppression" lint stance above.
        jniLibs {
            keepDebugSymbols += setOf(
                "**/libandroidx.graphics.path.so",
                "**/libdatastore_shared_counter.so",
            )
        }
    }

    // MIGRATION TESTING (room-testing / MigrationTestHelper):
    //   MigrationTestHelper reads the exported schema JSONs (app/schemas/) from
    //   the test APK's assets at runtime. Exposing the schema directory as an
    //   androidTest asset source makes createDatabase(name, version) able to find
    //   the historical schema for each version. Without this, the migration test
    //   fails with "Cannot find the schema file in the assets folder".
    sourceSets {
        // THE REPORT TEMPLATE LIVES ABOVE BOTH PLATFORMS.
        //   report/report_template.html is read by Android's PdfReportBuilder and,
        //   once the port lands, by the iOS report renderer. It defines the PDF's
        //   layout: its placeholders and repeat blocks are the contract between
        //   the two. Keeping one copy means a layout fix is made once, and the
        //   two platforms cannot silently drift apart.
        //
        //   Registering it as an assets directory leaves the runtime lookup
        //   unchanged: the merged asset root still contains report_template.html,
        //   so `context.assets.open("report_template.html")` needs no edit.
        //
        //   $projectDir is android/app, so the repository root is two levels up.
        getByName("main") {
            assets.directories += "$projectDir/../../report"
        }

        getByName("androidTest") {
            // AGP 9 deprecates AndroidSourceSet.srcDirs(...) in favour of the
            // `directories` mutable set, to which you append String paths with
            // `+=` (instead of passing a FileCollection via files(...)). The
            // resolved location is identical — app/schemas exposed as androidTest
            // assets — only the DSL changed.
            assets.directories += "$projectDir/schemas"

            // SCREENSHOT DEMO-DATA FIXTURE (single source of truth):
            //   ScreenshotTest seeds the app database from the Play-Store demo
            //   data in ../fastlane/demo-backup.json. That file is the canonical
            //   fixture (it lives next to the report PDFs and the store metadata),
            //   so instead of duplicating it under app/src/androidTest/assets we
            //   COPY it into a generated androidTest assets directory at build
            //   time (see the `copyDemoBackupFixture` task below) and expose that
            //   directory here. The test then opens "demo-backup.json" through the
            //   instrumentation AssetManager while the repository keeps exactly one
            //   copy of the data.
            assets.directories +=
                layout.buildDirectory.dir("generated/screenshotAssets").get().asFile.path
        }
    }

    // =========================================================================
    // LINT CONFIGURATION
    // =========================================================================
    //   The build runs `./gradlew lintDebug` as a quality gate. Lint aborts the
    //   build on ERRORS only (warnings are advisory). All genuine code/resource
    //   findings are fixed in the sources; the checks disabled below are advisory
    //   ones the project deliberately does NOT enforce. This is an explicit,
    //   reviewable POLICY — not a lint-baseline. A baseline silently records the
    //   current set of violations and lets new ones of the same kind slip in
    //   later; disabling a check states plainly that the project opts out of that
    //   category, with the reason documented right here.
    lint {
        // STRICT GATE: fail the build on any reported issue, warnings included.
        //   abortOnError (default true) stops the build on ERROR-severity issues.
        //   warningsAsErrors promotes every reported WARNING to error severity, so
        //   `./gradlew lintDebug` also fails on warnings — the project treats a
        //   clean lint report as a release invariant.
        //   The checks in `disable` below never report at all, so they can never
        //   trip this gate; only genuinely new warnings will. Note the trade-off:
        //   a future AGP/Lint upgrade or an updated dependency can introduce new
        //   warnings that then break the build until they are fixed or, if truly
        //   advisory, added to `disable` with a documented rationale.
        abortOnError = true
        warningsAsErrors = true
        // Each id below is opted out for the stated reason; re-enable any of them
        // if the project's policy changes.
        disable += setOf(
            // ── Dependency / toolchain version nags ──────────────────────────
            // These only report that a newer version exists. Upgrading a
            // dependency, the Android Gradle Plugin, the Gradle wrapper or the
            // compile/target SDK is a deliberate, separately-tested change, never
            // an automatic lint fix. NewerVersionAvailable additionally hits the
            // network on every run. Updates are tracked out-of-band.
            "GradleDependency",
            "NewerVersionAvailable",
            "AndroidGradlePluginVersion",
            // targetSdk is pinned to a level the app has actually been tested
            // against; bumping it pulls in behavioural changes and is a conscious,
            // tested step rather than a lint cleanup.
            "OldTargetApi",
            // ── Launcher-icon design hints ───────────────────────────────────
            // The launcher icon is a deliberate, simple mark; "fills the square"
            // and "round icon equals the square icon" are intentional design
            // choices, not accidental duplicates.
            "IconLauncherShape",
            "IconDuplicates",
        )
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

        // Treat every Kotlin compiler warning as a build-breaking error. The
        // project keeps its sources warning-free (the QA passes documented in
        // CHANGELOG.md and the checks in tools/release-check.sh assume this), so
        // promoting warnings to errors makes any regression — an unused import or
        // symbol, a deprecated API call, an always-true `is` check — fail the
        // build immediately instead of silently accumulating.
        //
        // Scope: this affects the KOTLIN compiler only, across every Kotlin
        // compilation (main, unit-test and androidTest source sets, all build
        // types). It deliberately does NOT touch Gradle-level deprecation
        // warnings — e.g. AGP's internal "Using a Project object as a dependency
        // notation" notice emitted from VariantManager.createTestComponents while
        // wiring the test variant — because those originate in Gradle's
        // configuration phase, not in kotlinc, and are outside this build's
        // control (they will be resolved by a future AGP release).
        allWarningsAsErrors.set(true)
    }
}

// ── 2c. Screenshot demo-data fixture wiring ───────────────────────────────────
// The screenshot suite (app/src/androidTest/.../screenshot/ScreenshotTest.kt)
// seeds the app database from the canonical Play-Store demo data file
// ../fastlane/demo-backup.json. To avoid keeping a second copy of that JSON under
// the androidTest source set, this task copies the single source-of-truth file
// into a generated androidTest assets directory that is registered on the
// androidTest source set in the `sourceSets { }` block above.
//
// `rootProject.file("../fastlane/...")`: this is a single-module Gradle build
// whose root project IS the android/ directory (see settings.gradle.kts). The
// fastlane tree now lives at the repository root (a sibling of android/, so that
// F-Droid auto-discovers the store metadata), hence the `../fastlane` prefix —
// the path resolves to <repo>/fastlane/demo-backup.json.
//
// The copy is made a dependency of the androidTest asset-merge task so it always
// runs before the test APK is packaged. `configureEach` covers whatever the
// concrete merge task is named for the test build type (mergeDebugAndroidTestAssets).
val copyDemoBackupFixture = tasks.register<Copy>("copyDemoBackupFixture") {
    description = "Copy ../fastlane/demo-backup.json into the androidTest assets for the screenshot suite."
    from(rootProject.file("../fastlane/demo-backup.json"))
    into(layout.buildDirectory.dir("generated/screenshotAssets"))
}
tasks.matching { it.name == "mergeDebugAndroidTestAssets" }.configureEach {
    dependsOn(copyDemoBackupFixture)
}

// ── Generated guide & copyright resources (build prerequisites) ────────────────
//
// The in-app documents under res/raw[-xx]/ are GENERATED, not committed (they are
// listed in .gitignore). Historically only the Makefile produced them, so a bare
// `./gradlew assembleRelease` — a fresh clone, CI, or an F-Droid build that does
// not go through `make` — failed because R.raw.usersguide / R.raw.copyright had no
// backing files. These two tasks reproduce the Makefile's generation inside Gradle
// and are wired into `preBuild`, so EVERY Gradle build is self-contained.

// Renders app/src/main/res/raw[-xx]/usersguide.md from the docs/guide templates.
// render-guide.py is idempotent (it no-ops when the outputs are already current),
// so re-running it on every build is cheap. Requires python3 on PATH — the same
// prerequisite the Makefile already documents, and present in the F-Droid build
// environment.
val generateUserGuides = tasks.register<Exec>("generateUserGuides") {
    description = "Render the localized in-app user guides from docs/guide templates."
    workingDir = rootProject.projectDir
    // workingDir is the android/ Gradle root; the tooling now lives in tools/ at
    // the repository root, i.e. one level up.
    commandLine("python3", "../tools/render-guide.py")
}

// Builds res/raw/copyright.md (COPYING.md + the full GPL text + the full
// Apache-2.0 text) via tools/render-copyright.py — the SAME generator the
// Makefile rule and its check-guides verification use, so the two build paths
// cannot disagree about the generated bytes. The Apache-2.0 text ships in-app
// because Apache-2.0 §4(a) requires giving recipients a copy of the licence for
// the Apache-licensed runtime libraries compiled into the APK (see COPYING.md,
// "Third-Party Software"). Declares inputs/outputs so Gradle can skip it when
// nothing changed.
val generateCopyrightDocument = tasks.register<Exec>("generateCopyrightDocument") {
    description = "Build res/raw/copyright.md from COPYING.md + LICENSE.md + LICENSE.Apache-2.0.md via tools/render-copyright.py."
    // workingDir is the android/ Gradle root; the tooling and the licence
    // sources live one level up, at the repository root.
    workingDir = rootProject.projectDir
    val root = rootProject.projectDir.parentFile
    val output = layout.projectDirectory.file("src/main/res/raw/copyright.md")
    inputs.files(
        root.resolve("tools/render-copyright.py"),
        root.resolve("COPYING.md"),
        root.resolve("LICENSE.md"),
        root.resolve("LICENSE.Apache-2.0.md"),
    )
    outputs.file(output)
    commandLine(
        "python3",
        "../tools/render-copyright.py",
        output.asFile.absolutePath,
        "../COPYING.md",
        "../LICENSE.md",
        "../LICENSE.Apache-2.0.md",
    )
}

// preBuild is the earliest per-variant anchor; wiring the generators here makes
// them run before resource merging and R-class generation for every variant.
tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(generateUserGuides, generateCopyrightDocument)
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
    // Add the BOM first – it pins the versions of all compose-* modules
    implementation(platform(libs.compose.bom))

    // Then the individual modules without an explicit version (the BOM sets them):
    implementation(libs.compose.ui) // Core UI primitives
    implementation(libs.compose.ui.graphics) // Canvas, colours, graphics
    implementation(libs.compose.ui.tooling.preview) // @Preview
    implementation(libs.compose.material3) // Material Design 3 Widgets
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
    // The database is NOT encrypted at the application level: it is a plain Room/
    // SQLite file protected at rest by Android's file-based storage encryption and
    // the per-app sandbox. SQLCipher (net.zetetic:sqlcipher-android) was removed in
    // v0.73.0 — see AppDatabase.kt for the one-shot clean-up of the former
    // encrypted database, and the CHANGELOG for the rationale.
    //
    // androidx.sqlite is intentionally NOT declared explicitly: Room pulls in the
    // small SDK surface it needs (SupportSQLiteDatabase, used by the migration and
    // the pre-population callback) transitively via room-runtime.
    //
    // NOTE: androidx.security:security-crypto is intentionally not used (Google
    //   deprecated it in April 2025 in favour of using the Android Keystore
    //   directly). The app seals its remaining small secret — the user-preferences
    //   DataStore — with its own KeystoreSecretStore (de.godisch.potillus.data.security).

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
    androidTestImplementation(libs.androidx.test.ext.junit) // AndroidJUnit4
    androidTestImplementation(libs.compose.ui.test.junit4) // createComposeRule, finders, actions

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

    // ── Play-Store screenshot capture (androidTest) ────────────────────────────
    // uiautomator: provides the full-screen capture used by ScreenshotTest via
    // screengrab's UiAutomatorScreenshotStrategy, so the cleaned Android-Demo-Mode
    // status bar (clock 10:00, full battery/Wi-Fi, no notifications) is part of the
    // saved PNG. The Compose in-process DecorView strategy would crop the system
    // bars out, so uiautomator is required, not optional.
    androidTestImplementation(libs.androidx.uiautomator)
    // screengrab: Screengrab.screenshot(name), UiAutomatorScreenshotStrategy and
    // LocaleTestRule. Used only by the screenshot suite; the `fastlane screengrab`
    // CLI (see ../fastlane/Screengrabfile) drives the per-locale run and pulls the
    // images into the fastlane metadata tree.
    androidTestImplementation(libs.screengrab)

    // room-testing: MigrationTestHelper validates each Room Migration against the
    // committed schema JSONs (app/schemas/), so a broken migration fails the test
    // suite instead of crashing a user's app on first launch after an update.
    androidTestImplementation(libs.room.testing)

    // ui-test-manifest provides the empty Activity that createComposeRule()
    // launches. It MUST be a debugImplementation (not androidTestImplementation)
    // because it has to be merged into the debug app manifest the tests run against.
    debugImplementation(libs.compose.ui.test.manifest)
}

// ── 4. Software Bill of Materials (SBOM) ──────────────────────────────────────
// Generates a standardized CycloneDX 1.6 JSON SBOM that lists exactly the
// third-party components which end up in the RELEASE APK. Produce it via
// `make sbom` (or as part of `make release`); that target also strips the
// volatile metadata timestamp for reproducible output (see android/Makefile).
//
// WHY cyclonedxDirectBom (not cyclonedxBom): this is a single-module build, so
// the per-project task is the correct one. cyclonedxBom is the multi-project
// AGGREGATOR and would only wrap this one module in an empty aggregation layer.
//
// ANDROID SCOPING (important): left to discover configurations on its own, the
// plugin fails on Android projects with "cannot choose between the following
// variants of project :app" — Android exposes many build-type/test variants and
// the resolver cannot pick one. Naming a single, already-resolved configuration
// (releaseRuntimeClasspath) removes the ambiguity and yields precisely the
// components shipped in the release build.
tasks.cyclonedxDirectBom {
    // metadata.component — the application this SBOM describes.
    projectType = Component.Type.APPLICATION
    componentName = "Libellus Potionis"
    // Keep the SBOM component version in lock-step with the app's versionName
    // (single source of truth: the android { } block above) rather than
    // repeating the literal here.
    componentVersion = android.defaultConfig.versionName ?: project.version.toString()

    // Pin to CycloneDX 1.6 (the latest stable schema version).
    schemaVersion = Version.VERSION_16

    // Resolve ONLY the release runtime classpath (see ANDROID SCOPING above) so
    // the SBOM mirrors what is actually packaged in app-release. Because this is
    // a single concrete, resolvable configuration, no skipConfigs filtering of
    // the debug/test classpaths is needed.
    includeConfigs = listOf("releaseRuntimeClasspath")

    // ── Reproducible builds ───────────────────────────────────────────────────
    // The random urn:uuid serial number is the main run-to-run churn; disable
    // it. The metadata timestamp is the other volatile field, and the Gradle
    // plugin (unlike the Maven one) exposes no outputTimestamp option, so the
    // `make sbom` target strips metadata.timestamp after generation. Together
    // these make the SBOM byte-stable across identical builds.
    includeBomSerialNumber = false

    // JSON only: CycloneDX JSON is the de-facto interchange format. The plugin
    // emits both JSON and XML by default; unsetting the XML output's convention
    // suppresses the XML file entirely.
    xmlOutput.unsetConvention()
    jsonOutput.set(
        layout.buildDirectory.file("outputs/sbom/libellus-potionis-sbom.json"),
    )
}

// ---------------------------------------------------------------------------
// Kover — test coverage configuration
// ---------------------------------------------------------------------------
// Kover measures how much of the code is exercised by the JVM unit-test suite
// (`./gradlew :app:test`). It reports two OpenSSF-relevant figures: statement
// coverage (silver target 80%, gold target 90%) and branch coverage (gold
// target 80%). Generate a report with, e.g.:
//
//     ./gradlew :app:koverHtmlReport   # HTML, under app/build/reports/kover
//     ./gradlew :app:koverXmlReport    # machine-readable XML
//     ./gradlew :app:koverLog          # prints total coverage to the console
//
// Scope / methodology: coverage is measured over the *unit-testable* code — the
// domain, l10n, and repository layers, the pure util helpers, and the screen
// ViewModels. Code that requires the Android runtime is excluded below, because
// it is verified by the instrumented tests in src/androidTest (Room migrations,
// Compose UI, on-device locale formatting, report export) rather than by JVM
// unit tests, and Kover only observes the JVM test task: the Compose UI, the
// Room database/DAO layer, the DataStore preferences, the Keystore access, and
// the PDF/WebView renderers. The exclusions are limited to non-JVM-testable and
// generated code so the reported figure honestly reflects coverage of the code
// the unit tests are responsible for.
//
// This block configures reporting, filtering AND the build-breaking
// verification thresholds: the `verify { }` rules below enforce ≥ 90 % LINE and
// ≥ 75 % BRANCH coverage of the filtered class set whenever `:app:koverVerify`
// runs — locally, via `make cover-check`, and in the release gate's opt-in
// coverage mode (`tools/release-check.sh --coverage`). The thresholds are a
// ratchet against regressions, not a target to chase: raise them as real
// coverage grows (see docs/ROADMAP.md for the branch-coverage goal).
kover {
    reports {
        filters {
            excludes {
                // Android-generated classes (R, BuildConfig, Manifest, ...).
                androidGeneratedClasses()

                // Compose UI that is not JVM-unit-testable: the theme, the
                // reusable UI components, and the navigation graph together with
                // its @Serializable routes. The screen ViewModels also live under
                // ui (in ui.screen) but are deliberately NOT excluded — they are
                // JVM-unit-tested; only the @Composable screen bodies are dropped,
                // by the annotation filter below.
                packages(
                    "de.godisch.potillus.ui.theme",
                    "de.godisch.potillus.ui.component",
                    "de.godisch.potillus.ui.nav",
                )

                // All @Composable functions (screen bodies etc.): verified by the
                // instrumented Compose UI tests, not by JVM unit tests.
                annotatedBy("androidx.compose.runtime.Composable")

                // Compose-generated lambda holders for @Composable functions
                // (ComposableSingletons$...ScreenKt): generated code, not testable.
                classes("*ComposableSingletons*")

                // Framework entry points and the manual DI factory (which
                // instantiates Android-scoped ViewModels from PotillusApp) — no
                // JVM-unit-testable logic. The trailing "*" also drops their
                // generated nested classes (lambdas, SAM conversions).
                classes(
                    "de.godisch.potillus.MainActivity*",
                    "de.godisch.potillus.PotillusApp*",
                    "de.godisch.potillus.AppViewModelFactory",
                )

                // Android-runtime-bound layers, verified by the instrumented
                // tests (MigrationTest, BackupRepositoryInstrumentedTest,
                // ReportExportTest) rather than by JVM unit tests. Note: the plain
                // @Entity data classes in data.db.entity stay IN scope (they are
                // JVM-unit-tested by EntityMappingTest); only the Room database,
                // the DAOs, and the generated *_Impl classes are excluded.
                packages(
                    "de.godisch.potillus.data.db.dao",
                    "de.godisch.potillus.data.prefs",
                    "de.godisch.potillus.data.security",
                )
                classes(
                    "de.godisch.potillus.data.db.AppDatabase*",
                    "*_Impl*",
                )

                // Room-transaction-bound repository: BackupRepository uses
                // db.withTransaction, which needs a real Room database, so it is
                // verified by BackupRepositoryInstrumentedTest rather than by JVM
                // unit tests. The other repositories only delegate to DAO methods
                // and ARE JVM-unit-tested (with fake DAOs), so they stay in scope.
                classes("de.godisch.potillus.data.repository.BackupRepository*")

                // Android PDF / WebView renderers (android.print / android.graphics
                // / WebView): exercised by the instrumented ReportExportTest. The
                // trailing "*" also drops their generated nested classes.
                classes(
                    "de.godisch.potillus.util.PdfReportBuilder*",
                    "de.godisch.potillus.util.WebViewPdfPrinter*",
                )

                // Android-runtime-bound declarations marked @AndroidIoBound
                // (MediaStore export/import, print-request DTO): verified by the
                // instrumented ReportExportTest, not by JVM unit tests.
                annotatedBy("de.godisch.potillus.util.AndroidIoBound")

                // Context-bound per-app locale helpers (top-level Context extensions).
                classes("de.godisch.potillus.l10n.LocaleSupportKt")

                // The coroutine bodies of the @AndroidIoBound ViewModel export/import
                // actions compile to separate continuation classes that the
                // annotation filter above does not reach, so they are excluded by
                // name (they call the excluded MediaStore/PDF code).
                classes(
                    "de.godisch.potillus.ui.screen.SettingsViewModel\$exportBackup*",
                    "de.godisch.potillus.ui.screen.SettingsViewModel\$importBackup*",
                    "de.godisch.potillus.ui.screen.StatsViewModel\$exportCsv*",
                    "de.godisch.potillus.ui.screen.StatsViewModel\$exportPdf*",
                )
            }
        }

        // ── Coverage verification (task: koverVerify) ──────────────────────
        // Build-breaking regression floors over the JVM-unit-testable scope
        // defined by the report filters above (verification shares them).
        // These are guard rails, not the OpenSSF gold branch threshold
        // (test_branch_coverage80, still a roadmap goal):
        //   • LINE   >= 90  locks in the achieved gold statement coverage
        //                   (test_statement_coverage90, and silver _80).
        //   • BRANCH >= 75  guards the current branch coverage (~80%) against
        //                   regression without demanding the gold 80% here.
        // Enforced at release time by `tools/release-check.sh --coverage`
        // (and, going forward, by the CI pipeline).
        verify {
            rule {
                minBound(90, CoverageUnit.LINE)
            }
            rule {
                minBound(75, CoverageUnit.BRANCH)
            }
        }
    }
}
