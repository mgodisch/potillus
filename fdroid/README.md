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

## Store listing metadata (auto-discovered)

The fastlane store metadata (summaries, full descriptions, per-version
changelogs and screenshots) lives at the **repository root** in
`fastlane/metadata/android/<locale>/`. F-Droid auto-discovers fastlane metadata
at the repo root, so the listing, the `<versionCode>.txt` changelogs and the
screenshots are pulled into the F-Droid client automatically — no need to
duplicate them in the fdroiddata merge request. (F-Droid does not find fastlane
metadata placed inside the Gradle module tree, which is why it is kept at the
root rather than under `android/`.)

The listing is translated into all 21 shipped app languages. Only `en-US` and
`de-DE` carry the full per-`versionCode` changelog history; the other locales
ship the listing text plus the CURRENT version's changelog note, and reuse the
`en-US` screenshots via F-Droid's locale fallback. `release-check.sh` SECTION 1
enforces exactly this policy (see "locale-parity" there).

## Caveats to verify on first submission

- **`subdir` / wrapper discovery.** Because the Gradle wrapper is under `android/`
  (not the repository root), confirm fdroidserver locates it from
  `subdir: android/app`. If the fdroiddata CI cannot find `gradlew`, adjust the
  recipe (e.g. point `subdir` at the Gradle root) per the CI feedback.
- **The build-block tag must exist** in the source repository before F-Droid can
  build it; F-Droid only builds tagged commits. The current reference recipe
  points at `v0.74.0`, so that tag must be pushed (see the milestone note below
  for how this relates to the planned `1.0.0` debut).

## First-version milestone (`1.0.0`)

Project decision: the FIRST version actually published on F-Droid will be cut as
**`1.0.0`** (it does not exist yet). Until that tag is created, this reference
recipe deliberately tracks the latest *real* release so that `release-check.sh`
can keep the recipe, `build.gradle.kts` and the top `CHANGELOG.md` entry in
lock-step (the check fails on any drift). When you are ready to debut on F-Droid,
cut `1.0.0` the normal way (bump `versionName`/`versionCode`, add the CHANGELOG
entry and the per-locale `changelogs/<versionCode>.txt`, push the GPG-signed
`v1.0.0` tag); the same machinery then updates this recipe to `1.0.0`, and that
becomes the first `Builds:` block submitted to fdroiddata.

## Submission checklist (fdroiddata merge request)

These steps run entirely on your side; none of them contacts F-Droid until you
deliberately open the merge request in step 6.

1. **Pre-conditions.** The source repo is public over `https://`, builds an
   unsigned release with no developer keystore, and carries a FOSS license
   (`GPL-3.0-or-later`). All already true for this project.
2. **Tag the release.** Push the GPG-signed `vX.Y.Z` tag the recipe's
   `Builds: … commit:` points at (e.g. `v0.74.0`, later `v1.0.0`).
3. **Get fdroidserver.** Install it locally, e.g. `pipx install fdroidserver`
   (Debian/Ubuntu: `apt install fdroidserver`). Linting the recipe needs only
   fdroidserver + Python; a real test build additionally needs the Android SDK
   or the `registry.gitlab.com/fdroid/fdroidserver:buildserver` container image.
4. **Fork & place the recipe.** Fork <https://gitlab.com/fdroid/fdroiddata>,
   then copy this file to `metadata/de.godisch.potillus.yml` in the fork.
5. **Validate locally (offline).** From the fdroiddata checkout run
   `fdroid readmeta` and `fdroid lint de.godisch.potillus`; optionally
   `fdroid build -l de.godisch.potillus` for a full clean-room build test.
   Fix anything they report.
6. **Open the merge request** against fdroiddata. The F-Droid CI builds and
   reviews it; address any CI feedback (the `subdir`/wrapper caveat above is the
   most likely first hurdle).
7. **After merge**, `AutoUpdateMode: Version` picks up later `vX.Y.Z` tags
   automatically and opens follow-up merge requests adding each new build block.
   Keep this reference copy in sync with the fdroiddata file on every release.
