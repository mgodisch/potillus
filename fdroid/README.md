<!--
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
=============================================================================
-->

# F-Droid packaging

`de.godisch.potillus.yml` in this directory is a **reference copy** of the build
recipe that F-Droid uses to build and publish the app. F-Droid does **not** read
it from this repository — the authoritative file lives in the F-Droid data repo at
`metadata/de.godisch.potillus.yml`. This copy exists so the recipe is versioned
alongside the source and reviewed together with the changes that affect it.

## How F-Droid builds this app

F-Droid runs a clean-room `./gradlew assembleRelease` (no flavour, `gradle: [yes]`)
from the build commit. A few project specifics make that work:

- **Generated resources.** `res/raw[-xx]/usersguide.md` and `res/raw/copyright.md`
  are generated and git-ignored. They are produced by Gradle itself — the
  `generateUserGuides` and `generateCopyrightDocument` tasks are wired into
  `preBuild` (see `android/app/build.gradle.kts`) — so no `prebuild:` step is
  needed in the recipe. `generateUserGuides` invokes `python3 tools/render-guide.py`;
  `python3` is present in the F-Droid build environment.
- **Unsigned release.** The release `signingConfig` only activates when a keystore
  is supplied via `android/keystore.properties` or the `POTILLUS_KEYSTORE_*`
  environment variables. F-Droid supplies neither, so the build stays unsigned and
  F-Droid signs the APK with its own key — no recipe workaround required.
- **Build root.** The Gradle root is `android/` (its `settings.gradle.kts` and
  `gradlew`); the application module is `android/app`, hence `subdir: android/app`.

## Updating the recipe

`AutoUpdateMode: Version` + `UpdateCheckMode: Tags ^v([0-9]+\.){2}[0-9]+$` lets
F-Droid pick up new releases automatically from **v-prefixed semver tags**
(`v0.73.0`, `v0.74.0`, …). On each release: bump `versionName`/`versionCode`, push
the matching `vX.Y.Z` tag, and F-Droid opens a merge request that adds the new
build block. Keep this reference copy and the fdroiddata file in sync.

## Caveats to verify on first submission

- **`subdir` / wrapper discovery.** Because the Gradle wrapper is under `android/`
  (not the repository root), confirm fdroidserver locates it from
  `subdir: android/app`. If the fdroiddata CI cannot find `gradlew`, adjust the
  recipe (e.g. point `subdir` at the Gradle root) per the CI feedback.
- **The `v0.73.0` tag must exist** in the source repository before F-Droid can
  build it; F-Droid only builds tagged commits.
