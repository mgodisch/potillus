<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
=============================================================================

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.

=============================================================================
-->

# Libellus Potionis – Changelog

<!-- Add new entries on top! -->
<!-- HEADING CONVENTION: directly below each "## vX.Y.Z" header, write a one-line
     summary formatted as a git commit subject — imperative mood, capitalized, no
     trailing period, at most 50 characters. Leave a blank line, then the detailed
     notes. This makes the entry's first line directly reusable as the subject of
     the release commit/tag (git's recommended ≤50-char subject limit). -->
<!-- RELEASE REMINDER: on every version bump, also add a localized store note
     android/fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt for
     EVERY locale, keeping the set identical across locales. release-check.sh §1
     enforces both that the current versionCode's note exists in each locale and
     that all locales carry the same set of changelog files. -->

---

## v0.78.0

Add Play Store onboarding; move tooling to tools/

Google Play onboarding, an F-Droid badge in the feature graphic, a relocation of
the build tooling, and one small user-facing export fix. Apart from that fix,
this release is documentation, store assets and build/release tooling only.

User-facing:
- CSV/PDF export: when the chosen date range contains no entries, show a short,
  self-dismissing Toast ("No entries available.") instead of doing nothing
  visible. Previously this was only a faint inline notice inside the scrollable
  statistics list, so it was easily missed. A successful export is still
  signalled only by the share sheet (CSV) or the system print dialog (PDF).

New documentation:
- `PRIVACY.md`: the privacy policy required by the Play "App content" section,
  linked from `README.md`. It states the app's actual behaviour — no data
  collection, no network access, on-device storage protected at rest by device
  encryption and the sandbox, and an optional biometric lock handled by Android —
  using the corrected data-at-rest wording (no database-level-encryption
  over-claim; the JSON backup is described plainly).
- `docs/PLAY_STORE.md`: a repeatable runbook for publishing to Google Play
  alongside F-Droid with a single signing identity (own app signing key via PEPK;
  a separate upload key), package-name registration, Play App Signing enrolment,
  the App-content declarations, the closed-testing gate, and versionCode
  discipline.

Feature graphic (`tools/render-feature-graphic.py`):
- Embed the per-locale "Get it on F-Droid" badge (`fdroid/get-it-on-de.svg` and
  `fdroid/get-it-on-en.svg`, both new in this release) in the bottom-LEFT corner
  and the GPLv3 logo in the bottom-RIGHT, with mirrored 48 px margins, a shared
  baseline and a shared visible height. The bottom-right logo is drawn after the
  report "paper" so it sits in front of the tilted PDF screenshot.
- Factored SVG parsing into `_svg_box_and_inner`; added a colour-preserving
  `_badge_nested` (F-Droid brand colours are kept, unlike the recoloured logo)
  and `_svg_ink_bbox`. The badge canvas carries a ~43 px transparent margin, so
  the badge is cropped to its ink box before scaling — otherwise its visible
  height would not match the logo. The shared mark size is kept reduced
  (`logo_w` 96).
- Also render a 4x high-resolution companion (`featureGraphic-hq.png`,
  4096x2000) next to each 1024x500 store graphic, for press/web/print; fastlane
  supply does not upload it, and the `README.md` header embeds this high-res
  version.

Badge fonts (build tooling; not shipped in the app package):
- Bundle the two fonts the badge text needs under `tools/fonts/`: DejaVu Sans
  (DejaVu Fonts license) for "GET IT ON" and Rokkitt (SIL Open Font License 1.1)
  for the "F-Droid" wordmark; both are documented in `COPYING.md`. The static
  Rokkitt Bold is instanced from the checked-in upstream variable font via the
  new `make rokkitt-bold`; the variable source lives outside the pinned font dir
  (`tools/fonts-src/`) so it never competes with the static instance during the
  deterministic render.

Release-check tooling (`tools/release-check.sh`):
- Section 9 (markdown syntax) now also validates `PRIVACY.md`.
- Section 1 (version consistency) no longer verifies the F-Droid reference
  recipe: the recipe cross-check and its path variable are removed, and the
  recipe (`fdroid/de.godisch.potillus.yml`) is kept only as a static,
  non-maintained backup (a banner in the file states this).

Build tooling relocation:
- Move the build/packaging tooling from `android/tools/` to a repo-root `tools/`
  directory (a sibling of `android/`, `fastlane/`, `fdroid/`, `docs/`), since
  these scripts serve the build/release process rather than the app. Re-anchor
  `release-check.sh` (it now cd's to the sibling `android/`),
  `render-feature-graphic.py` and `render-guide.py`, and update the invocations
  in `android/Makefile` and `app/build.gradle.kts` to `../tools/...`. Historical
  CHANGELOG entries are intentionally left referring to `android/tools/`.
- Move the `screenshots` and `feature-graphics` targets (with their screenshot
  helper targets and variables) from `android/Makefile` to the root `Makefile`,
  since they orchestrate repo-wide assets rather than the app build; the Gradle
  build stays in android/ via a new `screenshot-apks` target invoked with
  `$(MAKE) -C android`. `crop-screenshots.py` and `validate-screenshots.py` are
  made cwd-independent (`__file__`-anchored) so they run from the repository root.

Release packaging (`Makefile`):
- Exclude `keystore.properties` and `play-store-credentials.json` from the
  release tarball, and drop the `distclean` dependency of the `tgz` target.

Fastlane (`fastlane/Fastfile`):
- The `deploy` lane now defaults to the `internal` track instead of `production`;
  reaching production requires passing `track:production` explicitly. Removed a
  stale reference to a no-longer-existing `PLACEHOLDERS.txt`.

Versioning:
- `versionCode` 88 → 89 and `versionName` 0.77.4 → 0.78.0 in `build.gradle.kts`
  and the `README.md` title; localized store notes in `changelogs/89.txt` for all
  21 listing locales now describe the export fix above (en-US and de-DE are
  localized; the remaining locales carry the English wording pending translation).
  The F-Droid recipe is intentionally NOT updated — it is a static backup.

---

## v0.77.4

Drop in-APK SBOM for reproducible builds

Reproducible builds:
- The release APK no longer embeds the CycloneDX SBOM under `assets/sbom/`.
  F-Droid's from-source rebuild of 0.77.3 verified the signature but failed the
  byte-for-byte reproducibility comparison, and the *only* differences were in
  the packaged SBOM. Its CycloneDX metadata captures the build environment and
  therefore differs between the developer's machine and F-Droid's CI:
  `metadata.timestamp` (dropped locally when `SOURCE_DATE_EPOCH` is unset, but
  pinned to it in CI), an auto-injected `build-system` entry carrying the GitLab
  CI job URL, and the VCS URL recorded as `ssh://…` locally vs `https://…` in
  CI. None of these can be reconciled across environments, so the robust fix is
  to stop shipping the SBOM *inside* the APK.
- `build.gradle.kts`: removed section 5 (`GenerateSbomAsset` and its
  `androidComponents` asset wiring) together with the imports it alone used
  (`java.io.File`, `javax.inject.Inject`, `ExecOperations`). Section 4
  (`cyclonedxDirectBom`) is unchanged, so `make sbom` / `make release` still
  produce the standalone `build/outputs/sbom/libellus-potionis-sbom.json`, which
  can be published as a separate release asset alongside the APK.
- The in-APK SBOM was never read at runtime and is not checked by
  `release-check.sh`, so nothing else depends on it; the APK is otherwise
  byte-identical to 0.77.3.

Release-check tooling (`tools/release-check.sh`):
- New §11 (REPRODUCIBLE-BUILD HYGIENE) fails the release if `build.gradle.kts`
  reintroduces an in-APK SBOM task (`GenerateSbomAsset`), so this regression
  cannot silently return. Sections renumbered from "/ 10" to "/ 11".

F-Droid recipe:
- `AutoName: Libellus Potionis` added to the reference recipe so it stays in
  sync with the fdroiddata copy (where `fdroid checkupdates` populates it) and
  no longer disappears from the recipe diff.

Versioning:
- `versionCode` 87 → 88 and `versionName` 0.77.3 → 0.77.4 across
  `build.gradle.kts`, `README.md` and the F-Droid recipe; localized store notes
  added as `changelogs/88.txt` for all 21 locales. No user-facing or functional
  change — this is a build-reproducibility fix.

---

## v0.77.3

Refine translations and data-security wording

Localization QA:
- A localization quality-assurance pass reviewed the in-app UI strings and
  several user-guide translations for terminology, grammar and typography:
  - `res/values/strings.xml` (base/English): added a structured translator and
    reviewer context block plus a per-entry `<!-- … -->` note for every string —
    where it appears in the UI, what each `%1$s`/`{name}` placeholder means, and
    the typographic-quote convention. These comments are documentation-only and
    do not affect the build. Stray German-style quote escapes in a couple of
    English strings were normalized to standard curly quotes.
  - In-app UI strings across the base locale and all 21 translations
    (`res/values*/strings.xml`): terminology, grammar and quote-consistency
    fixes (e.g. aligning the PDF-report field labels).
  - 12 localized user-guide templates (cs, da, es, fr, it, nb, nl, pl, pt,
    pt-BR, ru, sv): wording and grammar refinements.
  - The Romanian store summary was shortened to 77 characters to meet the
    80-character store limit: "Jurnal de alcool axat pe confidențialitate:
    limite, alcoolemie, rapoarte PDF."
  - Build fix: the Ukrainian `import_merge` value ("Об'єднати") introduced by
    the pass had its apostrophe escaped (`\'`) so the Android resource compiler
    (aapt2) accepts the string.

Documentation accuracy (data-at-rest wording):
- After the earlier removal of SQLCipher, the Room database is no longer
  encrypted at the application level — it is protected at rest only by Android's
  file-based storage encryption and the per-app sandbox. A few texts still
  carried the old "everything is encrypted" claim and were corrected so the
  project no longer overstates its guarantees:
  - `README.md`: the "Privacy & Security Architecture" section no longer says
    security is enforced "through fully encrypted data storage via hardware-backed
    cryptography". It now states that data rests in the app's private, sandboxed
    storage, protected at rest by Android's device storage encryption, with an
    optional biometric fingerprint lock.
  - In-app User's Guide (`docs/guide/usersguide.md.in` and all 21 localized
    `usersguide.<locale>.md.in` templates): the clause "All data is stored in
    encrypted form" was replaced by an accurate wording ("your data stays in the
    app's private storage on your device, protected by your device's
    encryption"), translated per locale.
  - Fastlane full descriptions (all 21 locales): dropped the now-superfluous
    half-sentence stating the preferences are "additionally sealed with a
    hardware-backed Android Keystore key", leaving the accurate device-encryption
    + sandbox statement.
- No source-code comments needed changes: `AppPreferences.kt` still correctly
  documents the app-encrypted preferences DataStore (AES-256-GCM, Keystore-backed
  — unchanged and accurate), and `AppDatabase.kt` only references the *legacy*
  SQLCipher artefacts that `purgeLegacyEncryptedDatabase()` deletes.

Release-check tooling (`tools/release-check.sh`):
- §1 (VERSION CONSISTENCY) no longer cross-checks a version comment in
  `proguard-rules.pro`. That header line merely duplicated `versionName` for no
  functional benefit — R8 ignores `#` comments — yet had to be re-synced on
  every release. The `# Version:` line was removed from `proguard-rules.pro`,
  and the corresponding check (together with the file's pre-flight existence
  entry and the doc references) was dropped from the script, removing one manual
  sync point per release. The README title version stays enforced because it is
  user-facing.
- §2 (CHANGELOG ENTRY) now also verifies the entry's first line — reused verbatim
  as the git commit subject — is ≤ 50 characters (git's subject-length
  convention).
- New §10 (STORE METADATA LENGTH LIMITS) checks every locale's
  `short_description.txt` (≤ 80), `full_description.txt` (≤ 4000) and
  `changelogs/*.txt` (≤ 500), counted in CHARACTERS (not bytes) so Greek,
  Cyrillic and CJK are measured the way the stores do. Existing sections were
  renumbered from "/ 9" to "/ 10".

F-Droid reproducible build:
- The reference recipe (`fdroid/de.godisch.potillus.yml`) now declares `Binaries`
  (the Codeberg release-asset URL, `de.godisch.potillus_%c.apk`) and
  `AllowedAPKSigningKeys`, enabling F-Droid to verify its own from-source build
  against the developer-signed APK published on Codeberg. The published release
  asset must be named for its versionCode (`de.godisch.potillus_87.apk`).

Versioning:
- `versionCode` 86 → 87 and `versionName` 0.77.2 → 0.77.3 across
  `build.gradle.kts`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/87.txt` for all 21 locales (the
  listing-only locales drop the previous `86.txt`). Documentation and metadata
  only — the APK is functionally identical to 0.77.2.

---

## v0.77.2

Fix SBOM normalizer path in release build

Bug fix:
- The `generateSbomAsset` task resolved its `sbom-normalize.py` helper with
  `layout.projectDirectory.file("tools/sbom-normalize.py")`.
  `layout.projectDirectory` is the `:app` module directory (`android/app/`), so
  this pointed at a non-existent `android/app/tools/sbom-normalize.py`; the
  script actually lives at the Gradle root, `android/tools/sbom-normalize.py`.
  The path now resolves via `rootProject.file("tools/sbom-normalize.py")`,
  matching the idiom already used elsewhere in this file. The full release
  build, including SBOM generation, R8 and resource shrinking, now completes.

Versioning:
- `versionCode` 85 → 86 and `versionName` 0.77.1 → 0.77.2 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe
  (`commit: v0.77.2`); localized store notes added as `changelogs/86.txt` for
  all 21 locales (the listing-only locales drop the previous `85.txt`). No
  functional change to the app.

---

## v0.77.1

Fix F-Droid release build signing config

Bug fix:
- The `release` build type looked up its signing config with
  `signingConfigs.getByName("release")`. Before building, F-Droid strips the
  whole `signingConfigs { … }` block out of `build.gradle.kts` (it signs APKs
  itself), after which the named config no longer exists and `getByName` aborts
  the build with "SigningConfig with name 'release' not found". As a result the
  F-Droid build of 0.77.0 failed at `assembleRelease`. The lookup now uses the
  nullable `findByName("release")` with a null-safe check, so when the block has
  been removed the release build simply stays unsigned and F-Droid signs it.
  Local behaviour is unchanged: with a keystore the build is signed, without one
  it stays unsigned, exactly as before.

Versioning:
- `versionCode` 84 → 85 and `versionName` 0.77.0 → 0.77.1 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe
  (`commit: v0.77.1`); localized store notes added as `changelogs/85.txt` for
  all 21 locales (the listing-only locales drop the previous `84.txt`). No
  functional change to the app; this is the first version that builds on F-Droid.

---

## v0.77.0

Rework feature-graphic copy; drop fdroid README

Store assets:
- Reworked the feature-graphic bullet copy in both locales. The privacy bullet
  now spells out the concrete guarantees instead of a generic label — en-US
  "100 % Privacy: App Lock & Offline-only", de-DE "100 % Privacy: App-Sperre,
  kein Netzwerk" — the limits bullet is title-cased on en-US ("Set & Maintain
  Limits"), and the final bullet now also advertises "Open Source". Both
  `featureGraphic.png` were regenerated from the updated copy.
- `README.md` now shows the en-US feature graphic at the top.

Build wiring:
- `Makefile`: `make screenshots` now also runs `make feature-graphics`, so the
  store graphics are regenerated together with the screenshots instead of as a
  separate manual step.

F-Droid:
- Removed the maintainer reference-copy comment header from
  `fdroid/de.godisch.potillus.yml` (it is plain metadata now) and deleted
  `fdroid/README.md`; the recipe no longer references it, and `release-check.sh`
  still keeps the reference copy's version in sync with `build.gradle.kts`.

Versioning:
- `versionCode` 83 → 84 and `versionName` 0.76.0 → 0.77.0 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/84.txt` for all 21 locales (the
  listing-only locales drop the previous `83.txt`). Store-asset/tooling change
  only — the APK is functionally identical to 0.76.0.

---

## v0.76.0

Add a deterministic feature-graphic generator

Replace the two AI-generated Play-Store feature graphics with a deterministic,
re-localizable generator. This is a store-listing change only: the APK is
functionally identical to v0.75.0, and the versionCode is bumped purely so the
refreshed listing ships under its own code (same approach as v0.74.0).

Feature-graphic generator:
- New `android/tools/render-feature-graphic.py` composes the 1024x500 graphic
  (the exact Google Play feature-graphic size; the previous AI images were
  1488x720) from inputs the project already controls, so the result is
  reproducible and trivially re-localizable: per-locale marketing copy, the REAL
  screenshots from `make screenshots` (`01_today` as the phone, `07_report_page_1`
  as the report page) and the app's launcher icon. It emits SVG and renders with
  `rsvg-convert`; the phone is built and perspective-warped with Pillow (turned
  slightly about its vertical axis, left edge receding) and given a perspective
  depth edge on its near side, since SVG's affine transforms cannot do perspective. The old
  images baked in AI-hallucinated text (e.g. a garbled report page); the embedded
  shots are now the genuine, localized captures.
- Determinism: text is rendered with a PINNED bundled font (see below), selected
  via a throwaway fontconfig that exposes only `android/tools/fonts/`, so output
  never depends on the fonts installed on the build host. Repeated renders are
  byte-identical.
- Runtime dependencies are deliberately small: the python3 standard library,
  `rsvg-convert` (Debian `librsvg2-bin`), Pillow (already a project prerequisite)
  and the bundled fonts. Marketing copy
  lives in `fastlane/metadata/android/<locale>/feature-graphic.txt`; tagline line
  breaks are computed by the tool, so editors change words, not layout.

Bundled font:
- `android/tools/fonts/Inter/` adds static Inter instances (Regular/SemiBold/Bold,
  SIL OFL 1.1) used ONLY by the generator. They are build tooling and are NOT
  shipped in the APK. Credited in `COPYING.md`.

GPLv3 logo:
- `fastlane/gpl-v3-logo.svg` adds the GPLv3 "Free as in Freedom" logo, embedded
  (recoloured white) as a small license badge in the bottom-left of the graphic. It
  is one of the
  official GNU license logos by José Obed and is in the public domain; sourced from
  <https://www.gnu.org/graphics/license-logos> and credited in `COPYING.md`.

Copy / design tweaks (both locales unless noted):
- de-DE now addresses the reader informally ("Dein …" rather than "Ihr …").
- "100 %" is written with a space (was "100%").
- The "limits" bullet icon is a bar chart beneath a DOWNWARD trend arrow (the goal
  of keeping limits is to bring consumption down).
- The free/ad-free bullet leads with "free" (de "Kostenlos & Werbefrei",
  en "Free & Ad-free").

Build wiring:
- `android/Makefile`: new `feature-graphics` target renders the graphic for the
  screenshot locales, with an `rsvg-convert` pre-flight check mirroring the
  pdftoppm / Pillow checks; added to `.PHONY` and `make help`. It reuses the
  captures from `make screenshots` and does not capture anything itself.

Versioning:
- `versionCode` 82 → 83 and `versionName` 0.75.0 → 0.76.0 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/83.txt` for all 21 locales.

Also in this release (unrelated tooling fixes):
- `android/tools/validate-screenshots.py` still pointed at the pre-move metadata
  path (`fastlane/metadata/android`), so `make screenshots` failed its final
  Google Play validation step even though capture, crop and PDF rendering had all
  succeeded. It now uses `../fastlane/metadata/android`, matching
  `crop-screenshots.py`.
- `ScreenshotTest` read screengrab's locale from the `testlocale` instrumentation
  argument, but screengrab passes it as `testLocale` (camelCase). Argument keys
  are case-sensitive, so the lookup returned null and every locale run fell back
  to the device language — both stores' captures came out identical (the device
  language). It now reads `testLocale` (with a lowercase fallback), so each
  locale renders in its own language again. Test-only; not in the release APK.
- Follow-up to the above: on API 33+ the per-app locale
  (`AppCompatDelegate.setApplicationLocales`) is applied ASYNCHRONOUSLY, so seeding
  it before launching the Activity left the first captured frame in the device
  language and the English run timed out. The locale is now applied AFTER each
  Activity launch, with the Activity foregrounded (mirroring the in-app language
  picker, the one path that switches reliably on the capture device). Test-only.

---

## v0.75.0

Disable embedded Google dependency blob, ship SBOM inside the APK

Privacy / transparency:
- `android/app/build.gradle.kts` (`android { dependenciesInfo { } }`): disabled
  the dependency-metadata block that the Android Gradle Plugin embeds by default
  into the APK signing block (`includeInApk = false`) and the App Bundle
  (`includeInBundle = false`). That block is encrypted with a Google public key
  and readable only by Google Play; for an offline, network-free FOSS app it
  serves no purpose and is opaque to users. Dropping it also removes one
  non-transparent artefact from the output, which is friendlier to
  reproducible-build verification.

Reproducible builds / SBOM packaging:
- `android/app/build.gradle.kts` (new section 5: `GenerateSbomAsset` +
  `androidComponents`): the CycloneDX SBOM is now packaged INSIDE the release APK
  under `assets/sbom/libellus-potionis-sbom.json`, so the bill of materials ships
  with the artefact it describes. The standalone copy under `build/outputs/sbom/`
  (used by `make sbom`) is unchanged.
- The packaged copy is kept reproducible: the raw CycloneDX output carries a
  wall-clock `metadata.timestamp`, so a generated-assets task normalises it with
  the same `tools/sbom-normalize.py` used by `make sbom` (`SOURCE_DATE_EPOCH`-aware;
  strips the timestamp otherwise) BEFORE the asset merge. The task is wired via
  `addGeneratedSourceDirectory`, so it runs as part of `mergeReleaseAssets` with no
  manual task dependencies. `python3` is already a build prerequisite (see the
  `Makefile`), so no new toolchain requirement is introduced.

Store screenshots (`make screenshots`):
- Fixed four defects in the automated Play-Store screenshot capture
  (`android/app/src/androidTest/kotlin/de/godisch/potillus/screenshot/ScreenshotTest.kt`)
  plus two build-tooling diagnostics (`android/Makefile`). All app-facing fixes are
  test-only; no production code changed.
- `03_statistics` showed a single bar (the capture day) instead of the whole
  month: `AppSettings.statsFromDate` falls back to the APK install date when unset
  (`AppPreferences.installDate`); screengrab reinstalls the app per locale, so that
  default is the capture day, and `StatsViewModel` clamps the period start to it —
  collapsing the chart and the period totals to one day. The Calendar (which does
  not clamp) still showed the full month, which is why the two screens disagreed.
  `setUp()` now clears the floor (`setStatsFromDate("")`) so the statistics period
  spans the full demo history again.
- `04_drinks` was intermittently empty (blank in one locale run, populated in the
  other — the signature of a race). `DrinksViewModel.uiState` starts from an empty
  `DrinksUiState()` that is filled by a Room `Flow` via `stateIn(...)`; the bare
  `composeRule.waitForIdle()` returns before that first database emission arrives.
  A new `waitUntilDrinksLoaded()` gate waits until the empty-state label
  (`R.string.no_drinks`) has disappeared before capturing.
- The `en-US` screenshots rendered in German: the app drives its UI language via
  its own per-app locale (`AppCompatDelegate.setApplicationLocales`), so relying on
  screengrab's `LocaleTestRule` system-locale switch had no effect on the rendered
  language and both locale runs came out in the device language. `setUp()` now
  resolves the requested `testlocale` to a supported language tag (reusing the
  production `LocaleDetector.detect` against `SupportedLocales.TAGS`) and sets BOTH
  the `language` preference and the live per-app locale to it. This is the last
  setup step, so it reliably wins over the asynchronous first-launch language
  detection in `PotillusApp.applyLanguageOnFirstLaunch`.
- Duplicate preset drinks appeared on the Drinks screen: the preset prepopulation
  runs asynchronously (`AppDatabase.PrepopulateCallback` launches it on the
  application scope when the database is first created), and the screenshot run's
  first database access is the import itself, so seeding and import raced and both
  inserted the presets. `setUp()` now awaits the presets (by collecting the drinks
  `Flow` until they are present) before `importReplace`, so the import's name-based
  deduplication matches and reuses them. (This race is effectively unreachable
  through the normal UI, where an import happens seconds after first launch.)
- `android/Makefile` (`screenshots`): the device date pin (`adb shell date`)
  silently no-ops on non-rooted physical devices, leaving the date-relative screens
  (Today / Calendar / Statistics) on the real device date instead of
  `SCREENSHOT_DATE`. The recipe now reads the device date back and prints a
  non-fatal WARNING when it differs from `SCREENSHOT_DATE`, so the condition is no
  longer silent; run on an emulator or rooted device to pin the date.
- `android/Makefile` (`screenshots`): added a fast-failing pre-flight check for the
  bundled fastlane. The fastlane tree moved to the repository root, so a vendored
  bundle installed under the old `android/fastlane/.vendor` no longer applies; the
  capture step then failed late (after a full build and after toggling Demo Mode)
  with the cryptic `bundler: command not found: fastlane` (Error 127). The recipe
  now runs `bundle check` in `../fastlane` up front and, if the bundle is missing,
  aborts immediately with an actionable message (`cd fastlane && bundle install`),
  mirroring the existing Pillow / pdftoppm pre-flight checks.

Version:
- Bumped to `0.75.0` / versionCode `82` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and the F-Droid recipe
  (`fdroid/de.godisch.potillus.yml`: `Builds` seed entry and
  `CurrentVersion`/`CurrentVersionCode`); added the per-locale fastlane `82.txt`
  store-changelog notes.

---

## v0.74.0

Prepare F-Droid packaging, localize store listing

This is a packaging, tooling and store-metadata release. It contains **no
changes to the app's runtime behaviour**: no source file under `src/main/kotlin`
was touched, the database schema is unchanged, and the set of shipped UI string
resources is identical to v0.73.4. The version is bumped purely so the new store
listings ship under their own `versionCode`.

Packaging (F-Droid):
- `fdroid/de.godisch.potillus.yml`: the reference build recipe lagged the source
  tree (it still pinned `versionName 0.73.0` / `versionCode 76`). Its single
  `Builds:` block and the `CurrentVersion` / `CurrentVersionCode` fields are now
  synced to the current release (`0.74.0` / `81`, `commit: v0.74.0`). A new
  release-check invariant (see Tooling) keeps them in lock-step from now on, so
  this class of drift cannot silently reappear.
- `fdroid/README.md`: added a step-by-step **fdroiddata submission checklist**
  (fork, copy recipe, local `fdroid lint` / `fdroid build -l`, open the merge
  request, address CI) and recorded the project decision that the FIRST
  F-Droid-published version will be cut as `1.0.0`. The reference recipe
  deliberately tracks the latest real release until that `1.0.0` tag exists.

Changed (build configuration):
- `android/settings.gradle.kts`: removed the `foojay-resolver-convention`
  plugin. It can fetch a JDK over the network when a Java toolchain is requested
  that is not installed locally — undesirable in F-Droid's network-restricted
  build. The project declares no `toolchain {}` / `jvmToolchain(...)`, so the
  plugin was never actually triggered (Gradle uses the build environment's JDK
  21); removing it deletes a latent network path and a future foot-gun with no
  change to how any build resolves Java.
- `android/app/build.gradle.kts`: enabled `allWarningsAsErrors` in the Kotlin
  `compilerOptions` block. The sources are warning-free, so every future Kotlin
  compiler warning (unused import/symbol, deprecated API, always-true `is`
  check, …) now fails the build instead of accumulating silently. Scope is the
  Kotlin compiler only (all source sets and build types); it does not affect
  Gradle-level deprecation notices (see "Known upstream issue" below).
- `gradle/libs.versions.toml` + `android/app/build.gradle.kts` (`lint { }`):
  bumped `navigation-compose` 2.8.9 → 2.9.7 and re-enabled the three navigation
  lint checks that had been disabled as tooling-bug workarounds
  (`WrongStartDestinationType`, `ComposableDestinationInComposeScope`,
  `ComposableNavGraphInComposeScope`). navigation-compose 2.8.9 shipped lint
  detectors compiled against older Compose lint utilities, which under AGP 9.2 /
  `compose-bom` 2026.06.00 threw `NoClassDefFoundError`
  (`androidx/navigation/lint/UtilKt`, `androidx/compose/lint/PsiUtilsKt`) and
  aborted the whole lint task while analysing `AppNav.kt`. 2.9.7 ships detectors
  built against the current Compose lint API, so the checks run instead of
  crashing — making the previous `disable` workarounds unnecessary. `AppNav.kt`
  is a single flat `NavHost` with top-level type-safe `composable<…>`
  destinations and a `@Serializable` start destination, so the re-enabled checks
  report no findings, and the type-safe-route API is unchanged between 2.8 and
  2.9 (no source edits required).

Store metadata (L10N):
- Added fastlane store listings (`title`, `short_description`, `full_description`
  and the `versionCode 81` changelog note) for the **19 app languages that had
  no store listing yet**: `cs`, `da`, `el`, `es`, `fr`, `it`, `ja`, `ko`, `nb`,
  `nl`, `pl`, `pt`, `pt-BR`, `ro`, `ru`, `sv`, `uk`, `zh-CN`, `zh-TW`. The store
  listing now covers all 21 shipped app languages (`en` and `de` already
  existed). Screenshots are intentionally NOT duplicated per locale — F-Droid
  falls back to the `en-US` images — so only text was added.
- Added the `versionCode 81` changelog note (`changelogs/81.txt`) to the
  existing `en-US` and `de-DE` listings as well, as required by the release
  gate.

Tooling (`android/tools/release-check.sh`):
- SECTION 1 now cross-checks the F-Droid reference recipe: the recipe's
  `CurrentVersion` / `CurrentVersionCode` and its latest `Builds:` block must
  equal the `build.gradle.kts` `versionName` / `versionCode` (which SECTION 1
  already ties to the top CHANGELOG entry). This is the enforcing half of the
  recipe-sync fix above.
- SECTION 1 fastlane **locale-parity** rule relaxed: full changelog *history*
  parity is now required only among the history-bearing locales (`en-US`,
  `de-DE`); every other listing locale must carry only the CURRENT
  `versionCode` note. Without this, adding 19 listing locales would have
  demanded ~320 back-dated changelog files for `versionCode`s those locales
  never shipped under. The current-version coverage check (every locale must
  have `<versionCode>.txt`) is unchanged.

Tests (warning cleanup, required by `allWarningsAsErrors` above):
- `AppViewModelFactoryTest`: removed five `assertTrue(vm is …)` assertions (and
  the now-unused `assertTrue` import). Each `vm` is already statically typed by
  its constructor's return type, so the runtime `is` check is always true and
  the Kotlin compiler flagged it as "Check for instance is always 'true'". The
  meaningful guarantee — that each ViewModel's constructor signature stays
  callable with the injected types — is enforced at compile time (the test would
  not compile otherwise) and the retained `assertNotNull(vm)` covers successful
  construction.
- `LocaleDetectorTest`: replaced the deprecated single-argument
  `java.util.Locale("…")` constructor (deprecated since JDK 19) with the
  equivalent `Locale.of("…")` at the three remaining call sites. Behaviour is
  identical; the file already used `Locale.of` / `Locale.forLanguageTag`
  elsewhere. (The many `Locale("xx", "Autonym")` calls in
  `l10n/SupportedLocales.kt` are unaffected: they construct the app's own
  `data class Locale(tag, autonym)`, not `java.util.Locale`.)

Localization (plurals) and re-enabled lint check:
- Converted `import_success_replace` ("%1$d entries imported.") and
  `import_success_merge` ("%1$d entries imported, %2$d skipped.") from flat
  `<string>`s into `<plurals>` across all 21 locales, and re-enabled the
  `PluralsCandidate` lint check that previously masked them (removed from the
  `lint { disable }` set). `SettingsViewModel` now resolves them via a new
  `quantityStr` helper (`resources.getQuantityString`, selecting on the imported
  count). Per-locale plural forms mirror the CLDR category set and morphology of
  each locale's existing `<plurals name="days">` (the flat translation becomes the
  high-count form; singular/few/many forms derived accordingly). The merge message
  is pluralized on the FIRST count only — the second number's word is invariant in
  the en/de sources (an invariant past participle), so a single `<plurals>` is
  correct there; in several locales (e.g. `cs`, `pl`, `ru`, `uk`) both clauses are
  impersonal and do not inflect, so their categories carry identical text.
- The remaining `%d`-bearing strings are NOT pluralizable nouns —
  `import_error_version_too_high` (a backup version number),
  `import_error_file_too_large` (`%d MB`, an invariant unit) and
  `pdf_kpi_over_drink_days` (`%d/7`, a ratio) — so each is annotated
  `tools:ignore="PluralsCandidate"` (with `xmlns:tools` added to the base
  `values/strings.xml`) rather than forced into a meaningless plural.

Known upstream issue (documented, not fixed here):
- The Android Gradle Plugin emits "Using a Project object as a dependency
  notation has been deprecated" during configuration. A deprecation trace places
  it inside AGP itself
  (`com.android.build.gradle.internal.dependency.VariantDependenciesBuilder`,
  reached from `VariantManager.createTestComponents`) while it wires the tested
  project as a dependency of the test variant — not in this project's build
  scripts, and not in any applied third-party plugin (CycloneDX 3.2.4, the
  latest, was ruled out). It is harmless on the current Gradle 9.6.1 and will
  only become an error on Gradle 10, so the fix must come from a future AGP
  release. `allWarningsAsErrors` does not promote it, as it is a Gradle
  configuration-phase notice rather than a Kotlin compiler warning.

---

## v0.73.4

Fix QA findings: locale-aware numbers, backup robustness, docs

Fixed:
- L10N: user-visible numbers (grams, BAC, percentages, gram limits) were
  formatted with `String.format` / `"%.1f".format`, which follow
  `Locale.getDefault()` (the system locale) instead of the per-app locale set
  via `AppCompatDelegate.setApplicationLocales`. On a device whose system
  language differed from the in-app language this printed a wrong decimal
  separator next to correctly localized month/weekday names (e.g. "Juni 2026"
  beside "19.6 g"). A new `l10n/NumberFormat.kt` adds locale-aware `fmt0` /
  `fmt1` / `fmt2` helpers, and every read-only display on the Today, Statistics,
  Calendar and Drinks screens, the shared chart and list components, and the PDF
  report now passes the per-app locale (`Context.formattingLocale()`). CSV
  export and the round-trip-parsed numeric input field keep `Locale.ROOT` on
  purpose (machine-readable / `String.toDouble()`-parseable); the latter also
  fixes a latent bug where the grams input dialog opened in an error state on a
  comma-decimal system locale (F-1).
- Backup: `BackupRepository.importMerge` now reads the existing drink
  name-to-id snapshot INSIDE its database transaction, mirroring
  `importReplace`, closing a read-outside-write (TOCTOU) gap (F-5).
- Backup: `buildIdMap` now indexes freshly inserted drinks by name within the
  same import, so a backup containing two identically named new drinks no longer
  creates duplicate drink rows (F-6).
- `StatsViewModel.uiState` now seeds its initial value with the actual default
  period (`MONTH`) instead of `WEEK`, so the period selector no longer flashes a
  one-frame `WEEK` selection before the first emission (F-7).

Changed:
- Removed the unused `IEntryRepository.isDuplicate` and its `EntryRepository` /
  `FakeEntryRepository` implementations: the only MERGE de-duplication path
  calls `entryDao.countByTimestampAndDrink` directly, so the method was dead
  code (F-2).

Docs:
- `AlcoholCalculator.roundTo2Decimals` KDoc corrected: it rounds the BAC value
  to two decimals, not gram values (which use `roundTo1Decimal`) (F-4).
- `EntryRepository.addFromDrink` KDoc no longer mentions the removed gender
  setting (F-3).

L10N (comprehensive translation QA against `en` + `de` as the authoritative
sources; key parity, apostrophe escaping, format placeholders, plural CLDR
categories, brand/URL invariants and newline parity all verified clean):
- `values-zh-rCN`: `drink_delete_blocked` started with a stray `%` and wrapped
  the drink name in ASCII straight quotes (`"…"`). Android treats `"` as a
  verbatim delimiter and strips it, so the user saw `%<name>有 …` with the
  quotes gone and a leftover percent sign. Replaced with the same
  `\u201c…\u201d` curly quotes the `en` source uses, dropping the stray `%`
  (L-1). The string is filled via `String.replace("{name}"/"{count}")`, not
  `String.format`, so there was never a crash — only wrong on-screen text.
- CSV header `csv_col_alcohol_pct` is now spelled out in every locale to match
  the `en`/`de` `Word_Word` style (e.g. `Alcohol_Percent` / `Alkohol_Prozent`)
  instead of a literal `%` (e.g. `Alcool_%` → `Alcool_pourcentage`,
  `酒精_%` → `酒精_百分比`). Purely a header-naming consistency change; the value
  carries no format arguments, so behaviour is unchanged.

Tests:
- Added `NumberFormatTest` (JVM) pinning the decimal separator to the passed
  locale (en-US "." vs de-DE ",").
- `LimitBarUiTest` now pins the Compose **Context configuration** locale to US
  (via a `createConfigurationContext` Context provided through `LocalContext`),
  not just `Locale.getDefault()`. Since `LimitBar` now formats grams for the
  per-app locale through `Context.formattingLocale()` — which is decoupled from
  the JVM default — the previous `Locale.setDefault(US)` alone no longer made the
  expected "20.0 g" deterministic on a comma-decimal device.

---

## v0.73.3

Fix QA findings: orphaned directory, German comments, docs, header style

Changed:
- `app/src/main/res/raw-la/` — removed the empty, orphaned directory left
  behind when Latin (`la`) was dropped from the supported-locale set in
  v0.63.0. The directory had no content and served no purpose, but its
  presence could mislead `render-guide.py` if it ever changed to scan
  output directories instead of template files (B-01).
- `AndroidManifest.xml` — translated the only remaining German inline comment
  (`<!-- CSV-Export in Downloads-Ordner … -->`) to English, consistent with
  CONTRIBUTING.md §3 and `release-check.sh` §7 (D-01).
- `ui/component/AppOverflowMenu.kt`, `ui/component/MarkdownText.kt` — unified
  the vim modeline and file-header comment style with the rest of the codebase:
  `// vim: set et ts=4 sw=4:` / `// =====` block replaced by the project-standard
  `/* vim: set et ts=4: */` / `/* * ===== */` block (D-04).
- `data/repository/EntryRepository.kt` — added the missing KDoc block to
  `mostRecentEntry()`, making it consistent with the other `override` functions
  in the same file that all carry explanatory KDoc (D-02).
- `gradle.properties` — added `org.gradle.warning.mode=all` so that the
  per-deprecation detail Gradle previously suppressed behind the summary line
  *"Deprecated Gradle features were used … use `--warning-mode all`"* is
  printed on every build run. The property is the canonical project-wide way
  to set the flag (rather than a per-invocation CLI argument) and ensures the
  warnings surface in CI, `make` runs, and Android Studio alike.
- `gradle.properties` — translated the three remaining German inline comments
  (`# AndroidX aktivieren …`, `# Gradle-Daemon und Parallelbuilds`,
  `# Kotlin-Code-Style`) to English, consistent with CONTRIBUTING.md §3 (D-01).
- `data/prefs/AppPreferences.kt` — made the encrypted DataStore flow resilient
  to a transient read `IOException`. `settingsFlow` previously mapped
  `dataStore.data` directly, so a plain `IOException` raised on
  the read path (which the `ReplaceFileCorruptionHandler` does NOT cover — it
  only handles `CorruptionException` from the serializer) would propagate to
  every collector, including the start-up reads in `MainActivity.onCreate` and
  `PotillusApp.onCreate`, and crash the app. It is now routed through a
  new, unit-tested `recoverIoAsEmpty(...)` helper that emits `emptyPreferences()`
  on an `IOException` (downstream `map` then falls back to the documented
  defaults) and rethrows any non-IO error. This is the Jetpack DataStore
  guidance and matches the app's existing "degrade, never crash" policy.
  Covered by the new `AppPreferencesIoSafetyTest` (R-01).
- `app/build.gradle.kts` — silenced the cosmetic `stripDebugDebugSymbols`
  build warning *"Unable to strip the following libraries, packaging them as
  they are: `libandroidx.graphics.path.so`, `libdatastore_shared_counter.so`"*.
  The app ships no native code of its own; these two transitive prebuilt `.so`
  files cannot be stripped when no NDK toolchain is present (as in the F-Droid
  build image) and are then packaged unstripped anyway, so the message is purely
  cosmetic — but it became visible on every build once
  `org.gradle.warning.mode=all` was enabled in v0.73.3. They are now listed under
  `packaging.jniLibs.keepDebugSymbols`, which removes them from the strip set so
  AGP no longer attempts (and fails) to strip them. The packaged output is
  unchanged. The two names are listed explicitly rather than a blanket `**/*.so`
  so a future unstrippable library re-surfaces the warning for a conscious
  decision (B-02).
- `util/GplNotice.kt` — converted the file header from the `//` line-comment
  form to the project-standard `/* … */` block header used by the other Kotlin
  files, completing the header-style unification this release already applied to
  `AppOverflowMenu.kt` and `MarkdownText.kt` (F2).
- `ui/component/MarkdownText.kt` — promoted the pure helpers `decodeHtmlEntities`
  and `parseOrderedList` (and the `ORDERED_ITEM_RE` pattern) from `private` to
  `internal` + `@VisibleForTesting`, so the renderer's parsing logic is unit
  testable on the JVM without a device. No behavioural change (F3).
- Documentation accuracy: corrected five stale comments left by the earlier
  C-01 refactor (which moved `toDomain`/`toEntity` to `EntityMapping.kt` as
  `internal`). `BackupRepository.kt` and `DrinkRepository.kt` no longer claim the
  mappers are file-private and re-declared per repository; `Models.kt`,
  `DrinkEntity.kt` and `EntryEntity.kt` now point readers to the `internal`
  extensions in `EntityMapping.kt` instead of the (no-longer-correct) repository
  classes. Comments only — no code or behaviour change (G1).

Added:
- `app/src/test/kotlin/.../data/repository/EntityMappingTest.kt` — JVM unit
  tests for the shared entity ↔ domain conversions: `toDomain`/`toEntity` round
  trips and the unknown-category → `OTHER` fallback, the only non-trivial logic
  in the otherwise pass-through repositories (F3).
- `app/src/test/kotlin/.../ui/component/MarkdownTextTest.kt` — JVM unit tests for
  the in-app Markdown renderer's pure helpers: HTML-entity decoding, the
  ordered-item match boundary (a wrapped decimal is not a new item), and
  continuation-line reflow (F3).

Removed:
- The annual info dialog (the one-shot dialog shown on December 27th) and every
  artefact that existed only to support it (F1). Removed: `PotillusApp`'s
  `infoDialog`/`_infoDialog` state, `dismissInfoDialog()` and
  `checkAnnualInfoDialog()` (plus the now-unused `MutableStateFlow`/`StateFlow`/
  `asStateFlow`/`LocalDate` imports); the `AlertDialog` block and its
  `AlertDialog`/`Text`/`TextButton`/`stringResource` imports in `MainActivity`;
  the `info_dialog_title` / `info_dialog_body` / `info_dialog_ok` strings in
  `values/strings.xml` and all 20 `values-*/strings.xml` (per-locale key count
  170, still in sync); the `infoDialogShownYear` / `setInfoDialogShownYear`
  members of `IAppPreferences`, `AppPreferences` (`KEY_INFO_YEAR`,
  `info_dialog_shown_year`) and `FakeAppPreferences`; and the now-obsolete
  suppression call and notes in `ScreenshotTest`. A leftover
  `info_dialog_shown_year` value in an existing DataStore file is simply ignored.
  The two "translate all N keys" comments (`AndroidManifest.xml`,
  `app/build.gradle.kts`) were updated 173 → 170.
- `ui/screen/Screens.kt` — deleted the content-free documentation placeholder.
  The `Screen` sealed interface and all navigation routes live in
  `ui/nav/AppNav.kt`, which is already self-documenting. The placeholder added
  no information and could confuse readers expecting a `Screens` class (D-03).

---

## v0.73.2

Move fastlane metadata to repo root for F-Droid

Changed (project layout):
- Moved the fastlane tree from `android/fastlane/` to the repository root
  (`fastlane/`, a sibling of `android/`) so F-Droid auto-discovers the store
  listing, per-version changelogs and screenshots from the source repo (F-Droid
  does not look inside the Gradle module tree). The directory move itself is a
  `git mv`; this entry accompanies the path updates that follow from it. fastlane
  re-anchors to the new parent (the repo root), so paths into the Gradle build
  outputs in `Fastfile`/`Screengrabfile` gain an `android/` prefix, while the
  metadata output stays under `fastlane/`. The `android/`-side references
  (`Makefile`, `app/build.gradle.kts`, `tools/release-check.sh`,
  `tools/crop-screenshots.py`, `libs.versions.toml`, the screenshot test and
  `.gitignore`) now point at `../fastlane/`. No functional change to the app.

---

## v0.73.1

Fix QA findings: locale, DRY mapping, docs, tests

Changed:
- `TodayViewModel`: replace `Locale.getDefault()` with a locale derived from
  `AppSettings.language` (BCP-47 tag) for the monthly-average label on the Today
  card. On devices where the system language differs from the in-app language the
  month name now matches the rest of the UI rather than the OS locale (A-01).
- `DrinkRepository`, `EntryRepository`, `BackupRepository`: the four entity ↔
  domain conversion helpers (`toDomain` / `toEntity`) are now defined once as
  `internal` extension functions in the new `EntityMapping.kt` file instead of
  being duplicated across three files (C-01 DRY fix). The behaviour is unchanged.
- `PotillusApp.applyLanguageOnFirstLaunch`: the pure locale-detection logic is
  delegated to the new `LocaleDetector.detect()` function so it is unit-testable
  without an Android runtime (T-03).
- `DrinksScreen`, `TodayScreen`, `StatsScreen`, `CalendarScreen`: added missing
  `@param` KDoc entries for `onOpenHelp`, `onOpenCopyright`, and `onLockApp` (D-02).
- `Screens.kt`: added the missing `package de.godisch.potillus.ui.screen` declaration;
  without it the file resided in the default package, inconsistent with every other
  source file in the project (D-01 / S-01).

Added:
- `EntityMapping.kt` (`data/repository`): single source of truth for the four
  entity ↔ domain conversion helpers, replacing the previously scattered private
  and class-private copies (C-01).
- `LocaleDetector.kt` (`domain`): pure, Android-free singleton that implements the
  three-step BCP-47 matching strategy (full tag → base language → "en") extracted
  from `PotillusApp` (T-03).
- `LocaleDetectorTest.kt`: 10 JVM unit tests for `LocaleDetector.detect` covering
  all three matching steps, region variants (zh-CN/zh-TW, pt-BR), unsupported
  locales, empty sets, and case-insensitivity (T-03).
- `AppViewModelFactoryTest.kt`: unit tests that verify each registered ViewModel
  can be constructed with its injected dependency types, and that the factory's
  `else` guard throws `IllegalArgumentException` for unregistered classes (T-02).

---

## v0.73.0

Remove SQLCipher; add signing and Play tooling

Added:
- Conditional release code-signing in `android/app/build.gradle.kts`. A new
  `signingConfigs { create("release") }` block reads the key material either from
  a git-ignored `android/keystore.properties` file or from environment variables
  (the latter take precedence, which is convenient for CI). The release build
  type applies the config ONLY when the material is present, so the default
  source build — and F-Droid, which signs the APK itself — keeps producing the
  unsigned `app-release-unsigned.apk` with no key configured.
- `android/keystore.properties.example`: a documented template listing the four
  keys (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) and their
  environment-variable equivalents (`POTILLUS_KEYSTORE_FILE` etc.). The real
  `keystore.properties` and the Play service-account JSON are now git-ignored.
- `make bundle` (`android/Makefile`): builds the Android App Bundle
  (`bundleRelease`) that Google Play requires for new apps, alongside the
  existing `make release` APK target; both also generate the SBOM.
- `make deploy` plus a fastlane `deploy` lane (`android/fastlane/Fastfile`) and
  `android/fastlane/Appfile`: upload the signed AAB and the existing store
  metadata to Google Play via `upload_to_play_store`. The Play track and release
  status are overridable (defaults: `production` / `draft`, i.e. staged for
  manual publish) and the service-account key path is read from the
  `SUPPLY_JSON_KEY` environment variable (falling back to
  `fastlane/play-store-credentials.json`).
- Per-locale Play/F-Droid release notes `…/changelogs/76.txt` (de-DE, en-US) for
  the new versionCode.

Changed:
- `make release` is now a phony target that always invokes `assembleRelease` and
  prints the produced artifact path, instead of hard-coding the
  `app-release-unsigned.apk` filename (which becomes `app-release.apk` once a
  signing key is configured).
- Bumped versionName 0.72.0 → 0.73.0 and versionCode 75 → 76, with the matching
  README, `proguard-rules.pro` and fastlane changelog updates that
  `tools/release-check.sh` couples to the version.

Removed:
- **SQLCipher** (`net.zetetic:sqlcipher-android`) and the explicit
  `androidx.sqlite` pin are gone, together with all passphrase machinery
  (`getOrCreatePassphrase` / `hasSealedPassphrase` / `canOpenSealedPassphrase`
  and the `KeystoreSecretStore`-sealed passphrase in `AppDatabase.kt`), the
  `-keep class net.sqlcipher.**` ProGuard rules, and the `SupportOpenHelperFactory`
  usage in `MigrationTest`. The database is now a plain Room/SQLite file, relying
  on Android's file-based storage encryption and the per-app sandbox at rest.
- The **device-transfer "Settings not restored?" warning** (its detection,
  `PotillusApp` state/flow, the `MainActivity` dialog, the
  `device_transfer_warning_title`/`_body` strings in all 21 locales, and the
  `PotillusAppHeuristicTest`). The warning existed only to diagnose a failed
  SQLCipher-passphrase migration, which can no longer occur.

Changed (data & security):
- `data_extraction_rules.xml` now **excludes** the database and the preferences
  DataStore from both cloud-backup and device-transfer (and no longer references
  the obsolete passphrase file). With `allowBackup="false"` these rules stay
  inert, but they now state the intent plainly: personal data never leaves the
  device automatically. The **only** supported way to move data between devices
  is the user-initiated JSON backup (Settings → Backup → Export / Import).
- The user's guide **Backup** section was rewritten to explain, emphatically,
  why export/import is the sole transfer path and how to perform it, and was
  translated into all 21 supported languages.

Security:
- **Clean break, no data migration.** A plaintext SQLite engine cannot open the
  former SQLCipher file, so on the first launch after upgrading, `AppDatabase`
  runs a one-shot `purgeLegacyEncryptedDatabase()`: keyed on the legacy
  passphrase SharedPreferences marker, it deletes the old encrypted database, the
  passphrase file, and the now-unused Keystore key, then lets Room create a fresh,
  empty database. The routine is idempotent and a no-op on clean installs. Users
  upgrading from an encrypted build must re-import their JSON backup.

Fixed:
- The release `signingConfigs` block in `android/app/build.gradle.kts` failed to
  compile, breaking every Gradle task at configuration time (`Unresolved reference
  'util'`). Inside that block the bare identifier `java` resolves to Gradle's
  Java-plugin extension accessor, so the fully-qualified `java.util.Properties()`
  was misparsed. Added an explicit `import java.util.Properties` and now reference
  it as `Properties()`.
- Lint (run with `warningsAsErrors = true`) aborted the build on the legacy-database
  cleanup in `AppDatabase.kt`: `legacyPrefs.edit().clear().commit()` tripped both
  `ApplySharedPref` (prefer `apply()` over `commit()`) and `UseKtx` (prefer the
  `SharedPreferences.edit` KTX extension). The call was redundant — the following
  `deleteSharedPreferences()` already removes the file and its in-memory state — so
  the line was dropped entirely.
- The in-app guide viewer (`MarkdownText`) now renders `**bold**` inline spans.
  The rewritten Backup section uses bold for emphasis; previously the renderer
  handled only headings, paragraphs and `[text](url)` links, so the `**` markers
  would have appeared literally. Bold is now parsed alongside links in
  `renderInline` via a combined regex and a `FontWeight.Bold` span.
- The guide viewer now also renders ordered lists (`1.`, `2.`, …) as separate,
  hanging-indented items instead of collapsing them into a single paragraph, so
  the rewritten Backup section's device-transfer steps display as a proper
  numbered list with inline bold preserved per item.
- Migrated the screenshot test off the deprecated `createEmptyComposeRule` (the
  Compose UI-test rule) to its `…junit4.v2` replacement. The v2 rule uses a
  StandardTestDispatcher; the test is unaffected because it already synchronizes
  explicitly via `waitUntil`/`waitForIdle` and drives a real Activity rather than
  relying on immediate composition.
- Worked around a crash in the bundled navigation lint detector
  (`WrongStartDestinationType` / `BaseWrongStartDestinationTypeDetector`), which
  throws `NoClassDefFoundError: androidx/navigation/lint/UtilKt` under the lint
  shipped with AGP 9.2 and aborts `lintAnalyzeDebug` (the project runs lint with
  `abortOnError`/`warningsAsErrors`). The check is disabled in the `lint {}` block
  with a documented rationale; it is a tooling bug, not a finding in the app's
  navigation graph. The crash only surfaced once a source change invalidated the
  previously cached lint result.
- Migrated the three build-script tasks (`copyDemoBackupFixture`,
  `generateUserGuides`, `generateCopyrightDocument`) off the `val name by
  tasks.registering { }` Kotlin-DSL property-delegate syntax, which Gradle 9.6
  deprecated (scheduled for removal in Gradle 10), to the equivalent
  `tasks.register<Type>("name") { }` form. Task names and wiring are unchanged.
  (One remaining Gradle 10 deprecation — "Using a Project object as a dependency
  notation" — originates inside the Android Gradle Plugin, not this build script,
  and will clear with a future AGP release.)

Cleanup:
- Removed 13 unused imports across the UI and test sources, and corrected two
  stale KDoc/comment references in `AppPreferences.kt` that still mentioned the
  former SQLCipher "DB passphrase key alias" (which no longer exists). The
  preferences DataStore key is now the only persistent Keystore key the app uses.

Changed (build and distribution):
- **Guide and copyright resources are now generated by Gradle.** Two tasks
  (`generateUserGuides`, `generateCopyrightDocument`) render
  `res/raw[-xx]/usersguide.md` and `res/raw/copyright.md` and are wired into
  `preBuild`, so a bare `./gradlew assembleRelease` (a fresh clone, CI, or an
  F-Droid build that does not go through `make`) no longer fails on the missing,
  git-ignored `R.raw.*` backing files — previously only the Makefile produced them.
- **Added the F-Droid build recipe** at `fdroid/de.godisch.potillus.yml` (a
  reference copy of the fdroiddata metadata) with `fdroid/README.md`. Because the
  generation is wired into Gradle, the recipe is a plain `gradle: [yes]` build;
  the release stays unsigned when no keystore is configured, so F-Droid signs it.
  Auto-updates track v-prefixed semver tags.

Changed (store metadata):
- Corrected the store texts that the SQLCipher removal had made inaccurate. The
  long description no longer claims data is "stored fully encrypted using
  hardware-backed cryptography" (true only of the former SQLCipher layer); it now
  describes the actual model — on-device private storage under Android's storage
  encryption and the app sandbox, with the preferences additionally sealed by a
  hardware-backed Keystore key. The versionCode 76 store note
  (`changelogs/76.txt`, de + en), previously "developer tooling only", now states
  the real user-facing change and warns that data from earlier versions is not
  migrated automatically.

Changed (dependencies):
- Bumped the Jetpack Compose BOM from 2026.04.01 to 2026.06.00 (core Compose
  modules 1.11.0 → 1.11.3, bug-fix only). The Compose compiler stays paired with
  the Kotlin plugin, and the v2 UI-test rule adopted earlier is unaffected.
- Bumped the Gradle wrapper from 9.4.1 to 9.6.1 (`gradle-wrapper.properties`).
  9.6.1 is a patch release of the 9.6 line and stays well within AGP 9.2's Gradle
  requirement. Only `distributionUrl` is changed; the bundled wrapper JAR boots
  any 9.x distribution, so it needs no regeneration.
- Bumped Kotlin from 2.3.21 to 2.4.0. Because AGP 9's built-in Kotlin is pinned on
  the buildscript classpath, this touches two coupled spots that must stay in
  sync: the `kotlin` catalog key and the hard-coded `kotlin-gradle-plugin`
  classpath literal in the root `build.gradle.kts`. The Compose compiler and the
  serialization compiler plugin follow the `kotlin` key automatically. KSP is
  moved 2.3.7 → 2.3.9 (the release the Kotlin 2.4.0 notes pair with). The
  kotlinx-serialization runtime stays at 1.11.0; it must satisfy the
  forward-compatibility rule under the 2.4.0 compiler — if a build reports a
  serialization version mismatch, that runtime needs bumping too.

Note:
- The Google Play *feature graphic* (1024×500 px) is a design asset and cannot
  be generated here; the placeholder description in
  `android/fastlane/metadata/android/en-US/images/PLACEHOLDERS.txt` still
  applies. The F-Droid build-recipe metadata (for the fdroiddata repository) is
  intentionally NOT included yet — it needs the agreed tag/versioning convention.
  (With SQLCipher removed, the build no longer ships any prebuilt native binary,
  so the earlier prebuilt-binary concern no longer applies.)

---

## v0.72.0

Automate Play-Store screenshots via screengrab

Added:
- Fully automated Play-Store screenshot pipeline, runnable as `make screenshots`
  (root) which delegates to `make -C android screenshots`. It captures the six
  in-app phone screenshots in both store locales (`de-DE`, `en-US`) via Fastlane
  `screengrab` plus an Espresso/Compose UI test, then renders the two pages of
  the localized PDF report as screenshots 7 and 8, placing all eight assets per
  locale straight into `fastlane/metadata/android/<locale>/images/phoneScreenshots/`.
- `app/src/androidTest/.../screenshot/ScreenshotTest.kt`: the capture suite. It
  seeds the database from the canonical demo fixture (`fastlane/demo-backup.json`,
  copied into the androidTest assets at build time by the new
  `copyDemoBackupFixture` Gradle task), fixes the theme per phase (screenshots
  1–3 in light mode, 4–6 in dark mode), and navigates Today → Calendar →
  Statistics → Drinks → Add-drink dialog → Settings. It selects navigation
  targets by their localized label text plus a click action (the production UI
  has no test tags) so it works unchanged in both locales.
- `app/src/androidTest/.../screenshot/ScreenshotOnly.kt`: a runtime annotation
  tagging the suite so it can be excluded from an ordinary device-test run via
  the documented switch `make test-device EXCLUDE_SCREENSHOTS=1`
  (`-PexcludeScreenshotTests`). By default the suite still runs as part of
  `connectedDebugAndroidTest`, so a broken capture flow is caught by the normal
  gate.
- `tools/validate-screenshots.py`: a pure-stdlib gate that fails the run unless
  every captured asset meets Google Play's phone-screenshot requirements (PNG,
  each side 320–3840 px, aspect ratio ≤ 2:1, exactly eight per locale).
- Fastlane Ruby configuration: `fastlane/Fastfile` (lane `screenshots`),
  `fastlane/Screengrabfile` (locales, packages, output dir), `fastlane/Gemfile`
  (declares the fastlane gem) and the resolved `fastlane/Gemfile.lock` that pins
  the exact gem versions for the mandatory `bundle exec` run.

Changed:
- Status-bar hygiene during capture uses the Android Demo Mode API, driven from
  the `screenshots` Makefile target via adb: clock 10:00, 100 % battery, full
  Wi-Fi and no notifications. A bash `EXIT` trap guarantees Demo Mode is disabled
  again afterwards (`screenshots-demo-off`), even if the run fails. The device
  date is pinned to 2026-06-30 so the date-relative Today screen shows the demo
  period (best-effort; needs an emulator/rooted build).
- `app/build.gradle.kts` / `gradle/libs.versions.toml`: added the
  `tools.fastlane:screengrab` and `androidx.test.uiautomator` androidTest
  dependencies. The UiAutomator full-screen capture strategy is required so the
  cleaned Demo-Mode status bar is part of the saved image. `FLAG_SECURE` is cleared
  for the run by enabling the existing `allowScreenshots` preference from the
  test — no production code change.
- Screenshot filenames are stable across runs: screengrab's timestamp suffix is
  disabled (`use_timestamp_suffix(false)`), so capture overwrites
  `01_today.png` … `06_settings.png` in place instead of emitting a new
  timestamped file every run. The committed store screenshots can therefore be
  re-generated and checked in without churn or duplicates.
- The six in-app screenshots are bottom-cropped to at most a 2:1 aspect ratio
  (`tools/crop-screenshots.py`, Make step `screenshots-crop`). This removes the
  Android navigation bar at the bottom and satisfies Google Play's max-2:1 rule
  even when captured on a tall phone/emulator (e.g. 19.5:9). The PDF report pages
  (07/08) keep their A4 ratio and are never cropped.

Release process:
- versionName 0.71.1 → 0.72.0, versionCode 74 → 75 (anchor v0.70.0 = 72 plus
  three releases since). README title and `proguard-rules.pro` header updated to
  v0.72.0.
- Added fastlane store notes `changelogs/75.txt` in both locales (covers 0.72.0).

---

## v0.71.1

Fix Today-screen trend-arrow baseline

Fixed:
- Today screen, second row: the month-trend arrow (↑/↓) next to the per-day
  average was rendered in `titleMedium` while the adjacent "g/day" label uses
  `bodyMedium`. Because `Alignment.Bottom` aligns text bounding boxes rather
  than baselines, the larger style left the arrow sitting off the "g/day"
  baseline. The arrow now uses `bodyMedium` (bold), so it shares the label's
  baseline and size.

Release process:
- New rule, enforced by `release-check.sh` (SECTION 1): every `## vX.Y.Z`
  heading added to this changelog must be accompanied by exactly one increment
  of `versionCode`. The check derives the expected `versionCode` from a fixed
  reference point in `android/version-anchor` (anchored at v0.70.0 = 72) plus
  the number of changelog entries above it. versionName 0.71.0 → 0.71.1,
  versionCode 72 → 74 (0.71.0 = 73, 0.71.1 = 74).
- Added fastlane store notes for the new versionCodes in both locales:
  `changelogs/73.txt` (covers 0.71.0) and `changelogs/74.txt` (covers 0.71.1).

---

## v0.71.0

Reorder PDF KPIs; show longest abstinence streak

Changed:
- PDF report, KPI section: reordered tiles so that `abstinent days` and
  `longest abstinence phase` appear together in the first row, followed by
  `drinking days` and `total alcohol`. The consumption-peak and average/median
  rows are regrouped accordingly. (Patch `reorder.diff`.)

Added:
- PDF report, KPI section: the previously empty tile next to `abstinent days`
  now shows the longest continuous abstinence streak (in days) within the
  report period, using the already-computed `PdfReportData.longestAbstinence`
  field and the existing `pdf_meta_longest_abstinence` string resource
  (available in all 21 locales).
- PDF report, KPI section: `max per day` and `max per 7 days` tiles are now
  highlighted in red (warn flag) when their value exceeds the corresponding
  configured limit (`LimitInfo.limitGrams` and `LimitInfo.weeklyLimitGrams`
  respectively), consistent with the existing colouring of the
  `days > g/day` and `days > g/7 days` violation tiles.
- Statistics screen: initial period on first app start changed from `WEEK` to
  `MONTH` (`StatsViewModel._period` default).
- Document viewer: HTML character entities (`&copy;`, `&amp;`, `&lt;`,
  `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, `&reg;`, `&trade;`) are now decoded
  to their Unicode equivalents before rendering, so e.g. `&copy;` in
  `LICENSE.md` appears as `©` instead of literal markup
  (`MarkdownText.decodeHtmlEntities`).
- Settings screen, Appearance section: new "Allow Screenshots" toggle.
  When off (default) `FLAG_SECURE` blocks screenshots and screen recordings
  to protect health-sensitive data. When on, the flag is cleared reactively
  via the `settingsFlow` collector in `MainActivity` without requiring a
  restart (`AppSettings.allowScreenshots`, `KEY_ALLOW_SCREENSHOTS`,
  `IAppPreferences.setAllowScreenshots`, `SettingsViewModel.setAllowScreenshots`).
  String resources added in all 21 locales.
- Today screen, second row: the left column now shows today's own total in
  grams (e.g. `0.0 g`) styled like the right column's headline figure, instead
  of the static word "Alcohol". The month-trend arrow (↑/↓) on the right is now
  rendered in bold.
- Settings screen: the access-lock and screenshot toggles moved out of the
  "Appearance" section into a new "Security" section placed above it, so
  "Appearance" now precedes the colour-scheme (theme) and language controls
  only. New `security` string resource added in all 21 locales.
- PDF report, page 1 long-term trend chart: corrected the section heading unit
  from "Ø Grams/Month" to "Ø Grams/Day" in all 21 locales — the bars (and the
  dashed reference line) have always been per-day averages against the daily
  limit, independent of the span-derived bucket width. Each bar now also carries
  its per-day average on top (one decimal, blank for abstinent buckets),
  matching the page-2 hour/weekday charts (`BAR_VALUE`).

---

## v0.70.0

Add monthly trend arrow; fair per-day trend

Added:
- Today screen, monthly trend arrow. Next to the month's per-day average a small
  arrow now shows how it compares with the baseline period — the per-day average
  over the whole time from the configured statistics start date up to the day
  before this month: a green ↓ when this month is averaging fewer grams of
  alcohol per day than that baseline, a red ↑ when it is more, and nothing (no
  arrow, no extra space) when the two are equal at 0.1 g precision or there is no
  baseline yet (statistics started this month). Backed by a new shared domain
  type Trend (Trend.of(currentAvg, prevAvg)) and a monthTrend field on
  TodayUiState; the baseline is read by widening the monthly daily-summary query
  to start at the statistics start date.
- Release gate now checks Markdown syntax. A new check (`release-check.sh`
  section 9, backed by `tools/md-syntax.py`, standard library only) verifies that
  `CHANGELOG.md`, `README.md`, `CONTRIBUTING.md` and the per-language guides
  rendered from `*.md.in` are well formed: inline-code backticks and `*` emphasis
  balanced, and code-looking tokens (`snake_case`, glob `*`) wrapped in backticks
  so a stray marker cannot turn into accidental emphasis in the in-app renderer.
  `CHANGELOG.md` headings must additionally read `## vMAJOR.MINOR.PATCH` in
  descending order. The verbatim GPL texts (`LICENSE.md`, `COPYING.md`,
  `copyright.md`) are excluded.

Changed:
- Statistics trend is now computed on a per-day-AVERAGE basis instead of period
  totals, and its arrow uses the same shared Trend rule as the Today card. This
  makes an in-progress period compare fairly with the previous one: the current
  period is divided by its effective days (today counts only once it is a drink
  day) and the previous, complete period by its full day count. As a result a
  part-month no longer looks artificially lower than a full previous month, and
  the two screens always agree. The "trend vs. previous" percentage is now the
  change in the per-day averages; equal-at-0.1 g shows "–" (no arrow). The 7-day
  view is unaffected in practice (two equal-length windows).

Fixed:
- PDF report, page-1 trend chart: the x-axis labels are now drawn in a separate
  row BELOW the baseline, matching the page-2 hour/weekday charts (previously they
  sat above the axis, inside the plot area). The trend chart was switched to the
  same .barchart layout (a .bars plot area plus a .axis label row), so a label is
  never overlapped by its bar and both pages are laid out consistently.
- English PDF report capitalization. Report labels now use sentence case
  (lowercase except the first word and proper nouns) instead of Title Case —
  e.g. "Total alcohol", "Ø per day", "Longest abstinence phase", "Binge days",
  "Drinking days" — and units after a slash are lowercase ("g/day", "g/7 days",
  "Ø g/day", "… days/month"). Document title and section headings keep their
  Title-Case / all-caps styling. Only the report-only (`pdf_*`) English strings
  were touched; localized values are unchanged (e.g. German "g/Tag" stays
  capitalized, since "Tag" is a noun).
- Day counts are now correctly pluralized. The abstinence values in the PDF
  report (e.g. "Longest abstinence: 1 day", "Current: 0 days") and the streak
  values on the Statistics screen previously always used the plural form ("1
  Days"). They now use a shared `days` plural resource with the correct forms for
  every locale (including the multi-form Slavic plurals: cs/pl/ru/uk and ro).
  The now-unused `pdf_days_suffix` and `days_count` strings were removed.
- CHANGELOG escaping. Several code identifiers in recent entries were written
  without backticks; their `_` and `*` characters could render as unintended
  emphasis in a Markdown viewer. They are now wrapped in backticks (along with a
  stray `2.2.*` version glob), matching the file's convention. The new section-9
  check above guards against regressions.

Release housekeeping:
- versionName 0.69.0 → 0.70.0 (minor bump), versionCode 71 → 72.
- Synced proguard-rules.pro and the README title line; added Fastlane store
  notes 72.txt for de-DE and en-US.

---

## v0.69.0

Label chart bars; add monthly per-day average

Added:
- Statistics chart, per-bar value labels. On the two sparse axes each bar is now
  annotated with its grams of alcohol per day, commercially rounded to a whole
  number and printed without a unit to stay compact: the 7-day view labels each
  daily bar with that day's grams, and the year view labels each monthly bar
  with the month's grams averaged over its calendar days. The dense ~30-bar
  month view is left unlabelled to avoid clutter.
- Today screen, monthly per-day average. The summary card's right-hand column
  now shows the current month's average grams per day: a caption "Ø <month>"
  (the full localized month name) above the figure "<x> g/day". The left column
  keeps the "Today's Total" caption but no longer repeats today's gram figure —
  that number already appears on the daily-limit bar just below, so the card
  shows only the label "Alcohol" there. The per-day average uses the same rule
  as the chart and the statistics summary (see Fixed). Backed by new
  monthlyAvgPerDay and currentMonthLabel fields on TodayUiState.
- New/renamed string resources, translated into all 20 locales: `avg_of_month`
  ("Ø %1$s" format), `alcohol` and `grams_per_day`; the now-unused `grams_alcohol` was
  removed.

Changed:
- Statistics chart, year view: the dashed daily-limit line and the over-limit
  red colouring are no longer drawn, because a month's per-day average is not
  compared against a daily limit. Bar heights remain the per-day average (the
  same scale as the 7-day and month views), so a bar's height matches its label.
  The 7-day and month views keep the daily-limit line unchanged.

Fixed:
- Per-day averages now agree across the app. The Today card's monthly average,
  the Statistics summary's "average per day" and the year-view chart bar for the
  current month previously used different denominators (the chart and Today
  counted the in-progress day; the summary did not), so the same month could
  read as e.g. 18.8 vs 19.6. They now share one rule, centralised in
  DayResolver.effectivePeriodDays: the current day counts only once a drink has
  been logged on it (otherwise the unfinished day is left out of the average).
  bucketize gained an optional inProgressDay parameter for this; the PDF export
  passes none and is unchanged.

Release housekeeping:
- versionName 0.68.2 → 0.69.0 (minor bump), versionCode 70 → 71.
- Synced proguard-rules.pro and the README title line; added Fastlane store
  notes 71.txt for de-DE and en-US.

---

## v0.68.2

Rename app, fix year chart, add SBOM tooling

Fixed:
- Statistics screen, YEAR view: the consumption chart aggregated by ISO week
  (~52 bars) while labelling each weekly bar with its month name, so a single
  month could appear as several identically-named bars (e.g. three "Jun" bars
  for entries spread across June). The on-screen YEAR view now aggregates by
  calendar month (≤ 12 bars, exactly one bar per month). Implemented by
  selecting `ChartGranularity.MONTHLY` instead of `WEEKLY` for the YEAR period
  in StatsViewModel; the existing month-name axis label is the natural label for
  a monthly bucket. The PDF export is deliberately unchanged — it derives its
  granularity from the chosen span via `ChartBucketing.granularityForSpan()`, so
  a one-year report still shows ~52 weekly bars.

Changed:
- The user-visible application name is now simply "Libellus Potionis"; the
  informal "Potillus" nickname has been dropped. This affects the `app_name`
  string in the base locale and every translated `values-<code>/strings.xml`,
  the README/CONTRIBUTING/COPYING/CHANGELOG titles, all source- and build-file
  header comments, `GplNotice.HEADER_LINES` (the header reproduced in exported
  reports and JSON backups), the rendered User's Guide titles, and the Fastlane
  store descriptions (de-DE, en-US).
- Technical identifiers are intentionally left unchanged: the application id and
  Kotlin package (`de.godisch.potillus`), the canonical repository URL
  (`codeberg.org/godisch/potillus`) and the source tarball name stay "potillus",
  so the update channel, signing identity and existing installations are
  unaffected.

Added:
- Standardized SBOM generation. The CycloneDX Gradle plugin (org.cyclonedx.bom
  3.2.4, the Gradle-9-compatible line) is wired into the build to emit a
  CycloneDX 1.6 JSON Software Bill of Materials for the release runtime
  classpath, i.e. exactly the third-party components packaged in app-release.
  No SBOM file is committed to source; the SBOM is generated on demand via the
  new `make sbom` target and is also produced as part of `make release`,
  landing next to the APK at app/build/outputs/sbom/. The plugin is build-time
  only, so the APK and versionCode are unchanged.
  - Android scoping: generation is pinned to the resolved `releaseRuntimeClasspath`
    configuration, which avoids the well-known "cannot choose between the
    following variants of project :app" resolution error.
  - Reproducible builds: the random serial number is disabled
    (`includeBomSerialNumber = false`) and the volatile `metadata.timestamp` is
    normalized by the new tools/sbom-normalize.py post-step (honoring
    SOURCE\_DATE\_EPOCH when set, otherwise dropping the timestamp), so the SBOM
    is byte-stable across identical builds. python3 was already a build
    prerequisite, so no new tooling dependency is introduced.

Release housekeeping:
- versionName 0.68.1 → 0.68.2, versionCode 69 → 70.
- Kept the version string in `proguard-rules.pro` and the README title line in
  sync (release-check.sh §1).
- Added Fastlane store notes `70.txt` for de-DE and en-US (release-check.sh §1
  requires the changelog-file set to be identical across all locales).

---

## v0.68.1

Fix lock bypass on warm start; add manual lock

Fixed (security):
- The biometric app lock could be bypassed after a "warm start". When Android
  destroyed the Activity but kept the process cached (common after the phone has
  been locked or used for other things for hours), reopening the app sometimes
  revealed it WITHOUT a prompt. Cause: the inactivity timestamp `backgroundedAt`
  was a per-Activity-instance field (reset to 0 on the recreated Activity), while
  `isAuthenticatedThisSession` is process-global (still true) — so onCreate's gate,
  which only checked the boolean, skipped the prompt, and onStart saw `backgroundedAt
  == 0` and also skipped. `backgroundedAt` is now process-global (companion object)
  and the staleness check runs in onCreate as well as onStart, so re-authentication
  is required once the threshold has elapsed regardless of whether the Activity was
  recreated. The timestamp is consumed on a valid foreground return, so a later
  configuration change (which skips onStop) cannot re-prompt spuriously.
  Reproducible deterministically with Developer Options → "Don't keep activities".

Added:
- "Lock app" entry in the shared overflow menu, for locking the app on demand. It
  clears the authenticated state and shows the prompt immediately. Variant A: it
  works regardless of the auto-lock setting, as long as a biometric or device
  credential is available; the entry is hidden when no authenticator is enrolled,
  so it can never strand the user. MainActivity exposes `lockNow()`, threaded
  through AppNavigation to the four main screens' `AppOverflowMenu`. New string
  `lock_app` added to all 21 locales (per-locale key count 172 → 173).

---

## v0.68.0

Add biometric toggle auth; fix bugs and lint

Quality-assurance release plus one small feature: two functional bugfixes, a
security-feature responsiveness fix, biometric authorisation for the lock toggle,
resource-handling hardening, additional tests, and documentation corrections. No
schema change, no UI redesign.

Added:
- Toggling the biometric app lock now requires biometric (or device-credential)
  authorisation in BOTH directions: enabling AND disabling the lock prompts, and
  the switch only changes when authentication succeeds. Cancelling leaves the
  setting unchanged (the switch is bound to the stored value and snaps back).
  MainActivity exposes a dedicated `authenticateForToggle()` that — unlike the
  app-start gate — never finishes the Activity on cancel; the capability is threaded
  through AppNavigation to the Settings switch. It reuses the existing biometric
  prompt strings, so no new translations are needed. If no authenticator is
  enrolled, the toggle is left unchanged (the lock could not be satisfied anyway).

Fixed (functional):
- CSV export now formats the grams column with a locale-independent dot decimal
  separator (Locale.ROOT). Previously the default-locale formatter produced a
  comma on comma-decimal locales (e.g. de, fr, es), and that unquoted comma split
  the grams value across two columns, misaligning every following column in the
  exported file. The localised column headers are now also escaped, so a comma in
  a translated caption can no longer add a stray column.
- Importing a JSON backup now runs the file read and JSON parse on Dispatchers.IO
  instead of the main thread, removing an ANR risk on large backups. This matches
  the export path, which already moved its I/O off the main thread.

Fixed (security / behaviour):
- The biometric app lock now reflects the live preference: enabling it during a
  running session arms the inactivity re-authentication immediately, rather than
  only after the next cold start. MainActivity keeps its cached flag in sync via a
  repeatOnLifecycle collector.

Hardened:
- WebViewPdfPrinter now creates its off-screen WebView from the application
  context (not the Activity context) and abandons any still-pending previous
  WebView before starting a new print job, preventing an Activity context leak if
  the page-finished callback never fires.
- DocumentViewerScreen reads its bundled raw resource on Dispatchers.IO via
  produceState instead of synchronously during composition, keeping all disk I/O
  off the UI thread.

Tests:
- Added ChartBucketingTest (JVM) for gap filling, per-day averaging, period
  clamping and calendar-month snapping.
- Added CsvExporterBuildTest (JVM, run under Locale.GERMANY) covering the new
  Locale.ROOT grams formatting, the eight-column invariant and header escaping.
  CsvExporter's CSV assembly was extracted into an internal, Context-free
  buildCsv() to make this testable without an Android Context.
- Added LimitBarUiTest (instrumented Compose UI) and LocaleFormattingInstrumented-
  Test (instrumented) for Context.formattingLocale().

Fixed (lint / backup-rule correctness):
- `res/xml/data_extraction_rules.xml` used `domain="datastore"`, which is not a
  valid data-extraction domain. Android Lint rejected it as a `FullBackupContent`
  error (build-blocking once Lint runs), and the rule would have silently matched
  nothing if `android:allowBackup` were ever turned on, defeating the intended
  exclusion of the encrypted preferences file from cloud backup and its inclusion
  in a device transfer. Both rules now use `domain="file"` with the real on-disk
  path `datastore/potillus_settings.preferences_pb` (the `file` domain is rooted
  at `getFilesDir()`, where DataStore stores its file). No runtime behaviour
  changes while `allowBackup` stays `false`.

Lint cleanup (warnings driven to zero):
- Fixed in the sources: launcher/limit/chart composables now declare `modifier`
  as the first optional parameter (ModifierParameter); DocumentViewerScreen reads
  the user guide via `LocalResources.current` so a configuration change
  re-invalidates it (LocalContextResourcesRead); the passphrase write uses the KTX
  `SharedPreferences.edit(commit = true) { … }` form, keeping the deliberate
  synchronous commit (UseKtx, ApplySharedPref); the adaptive-icon XMLs moved from
  `mipmap-anydpi-v26` to `mipmap-anydpi` since minSdk 30 makes the `-v26` qualifier
  redundant (ObsoleteSdkInt), and the legacy pre-API-26 density launcher bitmaps
  (`mipmap-*dpi/ic_launcher*.png`) were deleted — at minSdk 30 the adaptive icon is
  always used, so they were dead fallbacks whose continued presence alongside the
  unqualified `mipmap-anydpi` XML triggered an IconXmlAndPng error; the
  `localeConfig` attribute is annotated
  `tools:targetApi="33"` and the backup-rules advisory is suppressed with
  `tools:ignore="DataExtractionRules"` (allowBackup is off, so a legacy
  full-backup-content file would be dead config); the WebViewPdfPrinter singleton
  carries a documented `@SuppressLint("StaticFieldLeak")` on its object declaration
  (it holds only the application context and is cleared after use — see its KDoc); and
  five genuinely unused strings (`stats_from_section`, `bac_section`, `bac_desc`,
  `biometric`, `pdf_months_truncated`) were removed from all 21 locales
  (UnusedResources), lowering the per-locale key count from 177 to 172.
- Opted out by explicit policy in a documented `lint { }` block (NOT a baseline):
  the dependency/AGP/Gradle/targetSdk version-update nags (GradleDependency,
  NewerVersionAvailable, AndroidGradlePluginVersion, OldTargetApi), the launcher-
  icon design hints (IconLauncherShape, IconDuplicates), and PluralsCandidate.
  Each carries a rationale in build.gradle.kts; dependency upgrades and a proper
  plural conversion across 21 locales are tracked as separate, tested changes.
- Made the lint check a strict gate: `lint { warningsAsErrors = true }` (with the
  default `abortOnError = true`) so `./gradlew lintDebug` now fails on warnings,
  not just errors. The disabled checks above never report, so only genuinely new
  warnings can break the build.

Documentation:
- Corrected the stale "181 string keys" comment to 177 in AndroidManifest.xml and
  app/build.gradle.kts (LocaleSyncTest remains the authoritative source).
- Corrected the "minSdk 35" remark in the AndroidManifest biometric comment to the
  actual minSdk 30.
- Translated the remaining German inline comments in AndroidManifest.xml and
  app/build.gradle.kts to English, matching the project's English-documentation
  convention.

---

## v0.67.2

Bugfix: locale-sensitive text (month names, weekday names, long dates) now follows
the in-app language instead of the system language. Previously, with the app set
to English, the PDF report still printed German month names next to its English
"Export Date" and "Period" labels.

### Fixed

- **PDF report dates follow the in-app language.** `PdfReportBuilder` formatted
  dates and month labels with `Locale.getDefault()`, which reflects the *system*
  locale and is unaffected by the in-app language picker
  (`AppCompatDelegate.setApplicationLocales` only re-configures the Context, not
  the JVM default). Labels (drawn from string resources via the Context) were
  therefore localized while the adjacent month names were not. The two
  locale-sensitive formatters are now built per report from the Context's locale,
  and the weekday/month axis labels use the same locale. The formatters were also
  `object`-level `val`s frozen at class-load time, so this additionally removes a
  stale-locale hazard.
- **Calendar and statistics screens follow the in-app language.** The same
  `Locale.getDefault()` mismatch was present on screen: `CalendarScreen` (long
  dates, the "MMMM yyyy" month header and weekday header), `StatsScreen` (the
  week/year chart axis and the weekday-chart labels) and `SettingsScreen` (the
  statistics from/to date). All now format with the per-app locale, taken from the
  Compose `LocalContext`.

### Added

- **`Context.formattingLocale()` helper** (`l10n/LocaleSupport.kt`) — a single,
  documented source for "the locale to format user-visible values in", resolved
  from the Context configuration so it always agrees with the localized string
  resources. All formatting code now goes through it instead of
  `Locale.getDefault()`.

### Changed

- **Version bump** to `0.67.2` / `versionCode 67` across `build.gradle.kts`,
  `README.md` and `proguard-rules.pro`, with matching localized store changelog
  notes (`fastlane/.../changelogs/67.txt`) for de-DE and en-US.

---

## v0.67.1

Bugfix: the in-app Markdown viewer (Copyright and Help) now resolves HTML/Markdown
character entities such as `&copy;`, which were previously shown verbatim.

### Fixed

- **`MarkdownText` resolves character entities.** The viewer now decodes
  HTML/Markdown character entities — named (`&copy;` → `©`, `&amp;`, `&mdash;`,
  …) and numeric (`&#169;`, `&#xA9;`) — in headings and visible text, never in
  URLs. Unknown names and out-of-range numeric values are left verbatim. Stray
  ampersands without a trailing `;` (e.g. "AT&T") are untouched.

### Changed

- **Fastlane changelog sync check.** `release-check.sh` §1 now additionally
  verifies LOCALE PARITY: all `fastlane/metadata/android/<locale>/changelogs/`
  directories must carry the same set of `<versionCode>.txt` notes, so a release
  note added to one language but forgotten in another is caught before release
  (previously only the current versionCode's presence per locale was checked). A
  maintainer reminder was added at the top of this CHANGELOG.
- **Version bump** to `0.67.1` / `versionCode 66` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and this CHANGELOG, with new
  fastlane `changelogs/66.txt` notes for `en-US` and `de-DE`.

---

## v0.67.0

Renamed the overflow-menu **License** entry to **Copyright** and broadened the
document it shows: the viewer now displays the project's `COPYING.md` notice and
the full `LICENSE.md` GPL text, joined at build time and separated by a single
blank line, still untranslated. Added a README section describing the project's
textbook-grade source documentation, introduced a fastlane store-metadata tree
for Google Play and F-Droid (English and German), and hardened the build: the
release gate now runs on every build and its fastlane release notes are tied to
the `versionCode`.

### Added

- **Fastlane store metadata.** New `android/fastlane/metadata/android/` tree with
  `en-US` and `de-DE` listings, each providing `title.txt` (≤30 chars),
  `short_description.txt` (≤80), `full_description.txt` (≤4000) and a
  `changelogs/<versionCode>.txt` release note (≤500, F-Droid's limit). Texts are
  derived from `README.md`; titles and descriptions deliberately omit the version
  to avoid churn. An `images/` folder per locale carries the launcher icon and
  documented placeholders for the feature graphic and screenshots (the binary
  assets must be supplied before publishing). Layout follows the conventions both
  `fastlane supply` and F-Droid consume.
- **README documentation section.** New *Source Code Documentation* subsection
  under *Technical Aspects*, explaining the literate, KDoc-everywhere style, how
  `release-check.sh` enforces it, and the benefits for newcomers, reviewers and
  long-term maintenance.

### Changed

- **"License" → "Copyright" in the overflow menu.** The string key `license` was
  renamed to `copyright` in all 21 locales with the (intentionally untranslated)
  value `Copyright`. The navigation route `Screen.License`, the callback
  `onOpenLicense`, and the raw resource `R.raw.license` were renamed to
  `Screen.Copyright`, `onOpenCopyright` and `R.raw.copyright` so no identifier
  still calls the feature "license". KDoc/comments in `AppNav.kt`,
  `AppOverflowMenu.kt` and `DocumentViewerScreen.kt` were updated to describe the
  combined document accurately (and to correct a stale note that claimed the text
  was rendered as plain, non-Markdown monospace).
- **Build-time copyright document.** The Makefile rule that copied
  `../LICENSE.md` to `raw/license.md` now concatenates `../COPYING.md`, a blank
  line, and `../LICENSE.md` into `raw/copyright.md`. `check-guides`, `.gitignore`,
  `distclean` and the `prereq` prerequisite list were updated accordingly.
- **`MarkdownText` h1 top spacing.** Level-1 (`#`) headings gained a top inset
  (20.dp, larger than the `##` heading's 16.dp). Previously an h1 had no top
  inset, so the `# GNU GENERAL PUBLIC LICENSE` heading at the COPYING/LICENSE
  seam sat closer to the text above it than the `## Preamble` heading below —
  now its gap is at least as large.
- **`release-check.sh` moved to `android/tools/`** and re-anchored to `android/`
  (one line: `cd "$SCRIPT_DIR/.."`); all other relative paths are unchanged. A
  new Makefile `release-check` target runs it, and it was added to `prereq`, so
  the full read-only release gate now runs on **every** build and aborts on any
  hard failure.
- **`release-check.sh --Werror`.** New switch that treats warnings as errors
  (non-zero exit on any warning). The Makefile `release-check` target passes it,
  so warnings can no longer slip silently into a build. Without the flag warnings
  remain advisory (exit 0); an invalid option exits 2; `--help` is supported.
- **Sharper §5 documentation heuristic.** The KDoc look-behind now skips
  multi-line annotation arguments (e.g. `@Query("""…""")`) so KDoc placed above
  the annotation is found, and it excludes local (nested) functions the same way
  it already excludes private ones. This removes two false positives
  (`EntryDao.getDailySummaries`, `PdfReportBuilder`'s local `svg`) so the gate is
  clean under `--Werror`.
- **Version coupling for fastlane.** `release-check.sh` §1 verifies that every
  fastlane locale directory ships a `changelogs/<versionCode>.txt` note matching
  the current `versionCode`, alongside the existing version-string consistency
  check across `build.gradle.kts`, the CHANGELOG, `README.md` and
  `proguard-rules.pro`.
- **Removed the Makefile `version-check` target.** Its checks are fully covered
  by `release-check.sh` §1, which already runs in `prereq`; keeping a separate
  Make target would only duplicate that logic. The target and its entry in
  `prereq`/`.PHONY` were dropped, and the documentation that pointed at it now
  points at the script.
- **Version bump** to `0.67.0` / `versionCode 65` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and this CHANGELOG.

---

## v0.66.0

PDF-report improvements: the time-of-day chart now labels every hour beneath the
axis, the weekday profile is shown as a bar chart, the category breakdown is a
half-width table paired with a colour-matched donut, and two peak-consumption KPIs
(max per day, max per 7 days) were added. Follow-up changes: a donut rendering fix,
average-grams bar labels, red limit lines, an eight-bucket on-screen time-of-day
chart, an annual info dialog, and integer-only body weight.

### Added

- **Annual info dialog.** A once-per-year dialog ("Do you like this App?") shown
  only when the app is opened on December 27th (device-local date); if that day is
  missed it is not caught up later. `PotillusApp` decides this once per process
  start (`checkAnnualInfoDialog()`) and `MainActivity` renders it over the content,
  mirroring the existing device-transfer dialog. The "last shown year" is persisted
  through `IAppPreferences.infoDialogShownYear` (new DataStore key
  `info_dialog_shown_year`; `FakeAppPreferences` updated). New strings
  `info_dialog_title` / `info_dialog_body` (placeholder) / `info_dialog_ok` in all
  21 locales, with title and OK localised per language.
- **Bar value labels.** PDF time-of-day bars and the on-screen `ValueBarChart`
  (time-of-day + weekday) now print the average grams above each bar
  (`ValueBarChart` gains a `showValues` flag; bars reserve headroom so labels are
  not clipped).
- **Peak-consumption KPIs.** `util/PdfReportData.kt` gains `maxPerDay` (heaviest
  single calendar day) and `maxPer7Days` (heaviest *rolling* 7-consecutive-day
  window; the whole-period total when the period is shorter than 7 days).
  `util/PdfReportBuilder.kt` shows them as two new KPI tiles. New strings
  `pdf_kpi_max_day`, `pdf_kpi_max_7days` translated into **all 21 locales**.
- **Category donut in the PDF.** Beside the (now half-width) category table the
  report draws an SVG donut matching the on-screen chart, using the same per-category
  colours (`util/PdfReportBuilder.kt` `categoryColor()`, mirroring
  `ui/component/categoryColors`). The ring is built with the stroke-dasharray
  technique (`PIE_SLICES` block: `PIE_FILL`, `PIE_DASH`, `PIE_GAP`, `PIE_OFFSET`) so
  it needs no raster image and survives SimpleTemplate's HTML-escaping. Each table
  row gets a matching colour swatch (`C_COLOR`) as an inline legend.

### Fixed

- **Donut rendered every slice as a full ring.** The SVG dash values were formatted
  with the default locale, so on a comma-decimal device `stroke-dasharray="40,00
  60,00"` was parsed by SVG as four numbers (`40 0 60 0`) — a zero gap that paints
  the whole circle. The pie geometry is now formatted with `Locale.ROOT`
  (`util/PdfReportBuilder.kt`).

### Changed

- **On-screen time-of-day chart → eight 3-hour buckets.** The Statistics screen now
  shows eight buckets (0–3, 3–6 … 21–24), each the **average grams per day** in the
  period (`StatsViewModel`: `hourBucketAverages` replaces the 24 hourly sums in
  `StatsUiState`; the divisor is the same `effectivePeriodDays` used for the per-day
  rate). The PDF time-of-day chart keeps all 24 hourly bars, each labelled with its
  average grams per day.
- **Limit lines are now red dashed** (were amber/orange) in both the PDF
  (`.chart .limit` → `#c83232`) and the app (`AlcoholBarChart` limit line →
  `dangerRedColor()`), matching the over-limit cue colour.
- **Body weight is integer-only.** Settings accepts whole numbers only
  (`GramsInputDialog(allowDecimal = false)`) and displays an integer; the PDF shows
  the weight as an integer (`roundToInt()`).
- **Time-of-day chart: all hours labelled, below the axis.**
  `assets/report_template.html` + `util/PdfReportBuilder.kt`: the chart is split into
  a bars row (`HBARS`) and a separate axis row (`HLABELS`) rendered *beneath* the
  baseline, and every hour 0..23 is labelled (previously only every third hour, and
  the labels sat inside the plot area where tall bars overlapped them). New CSS
  `.barchart` family; the obsolete `.chart.hours` variant was removed.
- **Weekday profile is now a bar chart.** Replaces the former one-row table with a
  bar chart analogous to the hour chart: bars (`WDBARS`) with the average value
  printed above each bar and the weekday names on the axis row (`WDLABELS`). Bar
  heights leave 15 % headroom so the value label above the tallest bar still fits.
- **Category breakdown layout.** The table is now half width (`.cat-row` /
  `.cat-table`, ~48 %) with the donut occupying the right half.

### Tests

- `test/.../util/PdfReportDataTest.kt`: added a test for `maxPerDay` / `maxPer7Days`.
- `PdfTemplatePlaceholderTest` continues to guard the template ⇄ builder placeholder
  contract; it automatically covers the new `HBARS`/`HLABELS`/`WDBARS`/`WDLABELS`/
  `PIE_SLICES`/`C_COLOR`/`H_VALUE` placeholders and the removal of the old
  `HOURS`/`WEEKDAY_*` blocks.

---

## v0.65.0

Feature release. Adds two new charts to the Statistics screen, reworks the PDF
report's time-of-day section into a 24-hour chart, adds median KPIs alongside the
existing means, fixes the per-day average of partial (started) months, shows the
running Android version in the PDF footer, makes the light-mode "caution" colour
clearly yellow, and adds a build-time guard that every PDF template placeholder is
initialised. The PDF layout/design in `assets/report_template.html` was also
updated (visual styling), independently of the structural edits listed here.

### Added

- **`ui/component/ChartComponents.kt` – `ValueBarChart`.** A small, reusable
  vertical bar chart (no time axis, no limit line, no abstinence ticks) used by the
  Statistics screen for the new hour-of-day and weekday charts. A bar of value ≤ 0
  is drawn as an empty slot, which is how "no data for this slot" is shown.
- **Statistics screen: hour-of-day and weekday charts.** Above the category donut
  the screen now shows, in order, a **24-hour** chart (grams per clock hour) and a
  **weekday** chart (average grams per weekday, rotated to the locale's first
  weekday). Each card is hidden when it has no data.
  - `ui/screen/StatsViewModel.kt`: `StatsUiState` gains `hourlyGrams` (24 buckets),
    `weekdayOrder` (ISO 1..7, rotated) and `weekdayAverages` (null = weekday never a
    drink day); all computed in the existing `combine`.
  - `ui/screen/StatsScreen.kt`: renders the two new cards; weekday labels use the
    locale's short `DayOfWeek` names.
- **PDF report: median KPIs.** Beside the mean tiles the report now prints
  **Median per Day**, **Median per Drinking Day**, **Ø Drinking Days/Month** and
  **Median Drinking Days/Month**. Medians are robust to the occasional very heavy
  day that can inflate a plain average.
  - `util/PdfReportData.kt`: adds `medianPerDay`, `medianPerDrinkDay`,
    `avgDrinkDaysPerMonth`, `medianDrinkDaysPerMonth`, plus a private `median()`
    helper (even count → mean of the two central values).
  - `util/PdfReportBuilder.kt`: emits the four extra KPI tiles.
  - `res/values*/strings.xml`: new keys `pdf_kpi_median_day`,
    `pdf_kpi_median_drink_day`, `pdf_kpi_avg_drink_days_month`,
    `pdf_kpi_median_drink_days_month` – translated into **all 21 locales**.
- **PDF report: 24-hour time-of-day chart.** The former "Ø first/last drink" and
  "share before/after 17:00" figures are replaced by a 24-bar chart of **grams of
  pure alcohol per clock hour** (0..23), mirroring the on-screen chart.
  - `util/PdfReportData.kt`: adds `hourlyGrams: List<Double>` (24 buckets).
  - `util/PdfReportBuilder.kt`: fills the new `HOURS` repeat block (height = grams
    relative to the busiest hour; axis thinned to every third hour plus hour 23).
  - `assets/report_template.html`: new `.chart.hours` CSS variant and `HOURS`
    repeat block; the old before/after meta table is removed.
  - `res/values*/strings.xml`: new screen titles `stats_time_of_day`,
    `stats_weekday` – translated into **all 21 locales**.
- **`test/.../util/PdfTemplatePlaceholderTest.kt` (new).** A pure-JVM guard that
  reads `report_template.html` and `PdfReportBuilder.kt` as source, then fails the
  build if any `{{PLACEHOLDER}}` used in the template is never initialised in the
  builder (which would otherwise print as a raw `{{…}}` in the PDF). Comments are
  stripped before scanning, and a second test asserts a few structural placeholders
  are seen so a broken scan cannot pass vacuously.

### Changed

- **Light-mode "caution" colour is now clearly yellow.** `ui/theme/Color.kt`: the
  light-theme `warningColor()` changed from amber-700 `#B45309` to gold `#A67C00`.
  The previous amber still read as orange-red on the small dot (its red channel
  dominated its green), sitting too close to the danger red. `#A67C00` shifts the
  hue towards gold while staying compliant: **3.35:1** vs the light background
  (≥ 3:1 required for a non-text indicator; 3.82:1 vs a white card) and **2.38:1**
  vs the danger red `#960018`. Dark mode (`#E8A020`) is unchanged.
- **PDF footer 2 carries the running Android version.** `util/PdfReportBuilder.kt`:
  the line now reads *"… on Android &lt;release&gt;, …"* using
  `Build.VERSION.RELEASE` (falling back to the numeric API level when blank),
  replacing the static *"for Android"*.
- **`assets/report_template.html` – heavier documentation (teaching detail).**
  Added a top-of-body **placeholder & block inventory** and richer per-section
  comments. (Separately, the file's visual design was updated manually by the
  author; see the note at the top of this entry.)

### Fixed

- **Partial-month g/day no longer diluted by not-yet-recorded days.**
  `util/PdfReportData.kt`: the monthly **Ø g/day** now divides each month's grams by
  the number of that month's calendar days that actually fall inside the report
  period `[firstDate, lastDate]` (via `ChronoUnit.DAYS.between(…)`), not by the full
  calendar-month length. Previously a started first/last month counted its
  remaining, unrecorded days as abstinent and deflated the figure.

### Localisation

- **`res/values*/strings.xml`**: removed the four now-unused keys
  `pdf_meta_first_drink`, `pdf_meta_last_drink`, `pdf_meta_before_18`,
  `pdf_meta_after_18`; added the six new keys above, translated into every locale.
  Net change is uniform across all 21 files (`168 → 172` strings), so
  `LocaleSyncTest` stays green.

### Tests

- `test/.../util/PdfReportDataTest.kt`: removed the obsolete *"time-of-day
  percentages are complementary"* test (the fields no longer exist); added tests
  for the 24-bucket hourly histogram (sums to the total), the new medians/means,
  and the partial-month g/day fix.
- Added `PdfTemplatePlaceholderTest` (see *Added*).
- `test/.../ui/screen/StatsViewModelTest.kt`: hardened the three data-bearing tests
  (`single over-limit day`, `drink today extends the effective period`,
  `categoryBreakdown sums grams`) against two pre-existing, time/scheduling-dependent
  fragilities (no production behaviour changed):
  - They dated their entry with `LocalDate.now()` (the real calendar date) while the
    ViewModel derives its period from the LOGICAL day (shifted by `dayChangeHour`,
    `4` in these tests). Run between midnight and 04:00 the entry fell one calendar
    day outside the period, so the computed state had no data and the assertions saw
    zeros. They now date the entry with `DayResolver.today(4, 0)`, matching the
    period — which was the tests' own documented intent ("use today's date as the
    logical date").
  - They assumed the first Turbine emission is already the computed state rather than
    the `stateIn(WhileSubscribed)` seed. A small `awaitComputed()` helper now skips
    any leading seed emission.

---

## v0.64.0

Feature release. Reworks the consumption chart (Statistics screen **and** PDF
report) into a real, gap-free time axis that also shows abstinent days,
overhauls the PDF footers, and fixes a colour bug that made the traffic-light
"caution" state look like "danger" in light mode.

### Added

- **`domain/ChartBucketing.kt`** – a small, Android-free helper shared by the
  Statistics screen and the PDF export. It expands the sparse per-day summaries
  (which only contain days *with* entries) into a continuous, gap-free series of
  buckets covering every day in the period, so abstinent days become explicit
  zero buckets on a proper time axis. A bucket may be a day, a week or a month;
  its value is the **mean grams of pure alcohol per calendar day** inside the
  bucket. Using a per-day average (rather than a per-bucket total) keeps the
  dashed **daily-limit** reference line directly comparable across all
  granularities. The object is pure `java.time` + plain data, hence JVM
  unit-testable.

### Changed

- **Statistics chart now uses a real time axis incl. abstinent days.** WEEK and
  MONTH render one bar per day; YEAR aggregates into weekly buckets (≈ 52 bars)
  spanning `max(1 Jan, statsFrom) … today`. Days/weeks with zero consumption are
  no longer omitted: they are drawn as a small **green tick** at the baseline, so
  "recorded, nothing consumed" is visually distinct from a tiny bar. Axis labels
  are **thinned** for dense charts (≤ 12 buckets → one aligned label per bar;
  more → a handful of evenly spaced labels for context).
  - `ui/component/ChartComponents.kt`: `AlcoholBarChart` now takes a
    `List<ChartBucket>` and a `(ChartBucket) -> String` label function instead of
    a `List<DaySummary>`; renders the abstinence tick and the thinned labels.
  - `ui/screen/StatsViewModel.kt`: builds the bucket series (`chartBuckets`,
    `chartGranularity`) in the same `combine` that produces the rest of the UI
    state. The legacy `dataPoints` field is retained unchanged.
  - `ui/screen/StatsScreen.kt`: feeds `chartBuckets` to the chart and formats the
    label per period (weekday / day-of-month / month name).
- **PDF report: the monthly-average trend chart is replaced by the same
  time-axis chart and is now shown unconditionally** (previously hidden when
  there were fewer than two months of data). The export picks a granularity from
  the recorded span (`≤ 35 days` daily, `≤ 366 days` weekly, else monthly).
  Abstinent buckets are drawn as a green tick, matching the on-screen chart.
  - `util/PdfReportData.kt`: adds `chartBuckets` + `chartGranularity` (the
    existing `months` list is kept for the monthly *table*).
  - `util/PdfReportBuilder.kt`: emits the bucket bars with per-bucket tick
    visibility and thinned labels.
  - `assets/report_template.html`: adds the green-tick markup/CSS to the chart.
- **PDF footers overhauled.**
  - **Footer 1** (medical disclaimer) is now translated and present in **all 21
    locales** (`pdf_footer1`), with new wording: *"Estimates – not a medical
    diagnosis. Not for fitness-to-drive assessment or diagnostic purposes."*
  - **Footer 2** is **English-only and never translated**: it is built in code
    (no longer a string resource) and reads *"Created with Libellus Potionis
    v&lt;version&gt;, free software under the GNU GPL v3, WITHOUT ANY WARRANTY."*
    The version is **shortened** to `MAJOR.MINOR.PATCH` via
    `BuildConfig.VERSION_NAME.substringBefore("-")`, so the debug build's
    `-debug` suffix is stripped from the printed line.
  - The separate **running GPL footer was removed**; its GPL / no-warranty notice
    is folded into Footer 2.
  - Both footers are now **pinned to the bottom of their page** (page 1 / page 2)
    regardless of how much content precedes them, via per-page flex `.sheet`
    wrappers in the template.
- **Traffic-light "caution" colour fixed in light mode.** `ui/theme/Color.kt`:
  the light-theme `warningColor()` changed from amber-800 `#92400E` to amber-700
  `#B45309`. On a 12 dp dot the very dark amber-800 was almost indistinguishable
  from the danger red `#960018` (same red channel, little green), so the YELLOW
  state read as RED in light mode. amber-700 keeps a clearly amber hue and still
  clears the ≥ 3:1 contrast a non-text indicator needs (4.40:1 on the light
  background). Dark mode was already fine and is unchanged.
- **`res/values*/strings.xml`**: `pdf_footer1` updated/translated in all locales;
  `pdf_footer2` removed from all locales (key count drops uniformly 171 → 170, so
  `LocaleSyncTest` stays green).

### Assumptions

- **Per-day average.** Weekly/monthly bars show the bucket's mean grams per day
  (not the bucket total), so the daily-limit line stays meaningful at every
  granularity. A daily bar therefore equals that day's own total, unchanged.
- **Abstinent = zero in the period, including today.** The current (in-progress)
  day's empty bucket is also shown as a green tick.
- **Footer pinning is best-effort and tuned for A4** (`.sheet { min-height:
  267mm }` = A4 height minus the existing 14/16 mm `@page` margins). On US Letter
  the printable height differs; per-page footer placement should be verified by
  exporting a PDF and the `min-height` adjusted if needed.

### Known follow-ups

- The 19 non-German/English `pdf_footer1` translations are **best-effort and
  should be reviewed by native speakers** before release (consistent with the
  project's translation-quality policy).
- The PDF chart heading string `pdf_section_trend` ("…avg g/month") was left
  untouched to avoid a 21-locale translation churn; its unit wording is now
  slightly imprecise for daily/weekly charts and is a candidate for a future
  copy pass.

---

## v0.63.1

Bug-fix release. Resolves a runtime crash when switching between the bottom-bar
main screens, and hardens the app against a whole class of `java.time`
availability problems by enabling **core library desugaring**.

### Rationale

The app crashed with `java.lang.NoSuchMethodError: No virtual method
datesUntil(...)` shortly after a non-Today main screen was shown. The trigger is
`java.time.LocalDate.datesUntil(...)`, a Java 9 API used by `StatsViewModel`,
`DayResolver` and `PdfReportData`.

On Android, `java.time` is provided by the *updatable* ART mainline module
(`/apex/com.android.art/.../core-oj.jar`). `datesUntil()` was backported into a
later ART revision, so at one and the same API level a device whose module has
been updated (e.g. via Google Play system updates) exposes the method, while an
older emulator system image does not. This is exactly why the crash reproduced
on an API 30 emulator yet not on physical API 29/30 devices: identical API
level, different ART module version. Relying on the platform's `java.time` for
Java 9+ methods is therefore fragile across runtimes.

Core library desugaring removes this dependency on the device's module version:
D8/R8 rewrites the affected `java.*` calls to resolve against the bundled
`desugar_jdk_libs` implementation, which is shipped inside the APK and available
uniformly down to `minSdk`. This fixes the crashing call site **and** every
other `datesUntil()` (and future Java 9+ `java.time`) usage at once, with no
changes to the Kotlin sources.

### Fixed

- **App no longer crashes when switching main screens.** Enabling core library
  desugaring makes `LocalDate.datesUntil(...)` resolve on all supported
  runtimes, eliminating the `NoSuchMethodError` raised from
  `StatsViewModel.uiState` (and latent in `DayResolver` and `PdfReportData`).

### Changed

- **`app/build.gradle.kts`**: set `isCoreLibraryDesugaringEnabled = true` in
  `compileOptions` and added the `coreLibraryDesugaring(libs.desugar.jdk.libs)`
  dependency.
- **`gradle/libs.versions.toml`**: added the `desugar-jdk-libs` version
  (`2.1.5`, 2.x requires AGP 7.4.0+ — satisfied by AGP 9.2.0) and the matching
  `com.android.tools:desugar_jdk_libs` library coordinate.
- **Version bump to 0.63.1**: `versionName` (`app/build.gradle.kts`) and the
  version strings in the README title and the `proguard-rules.pro` header
  brought in sync with this CHANGELOG (enforced by the `version-check` build
  step); `versionCode` advanced `60 → 61` for the published APK.

### Notes

- Side effects of desugaring are limited to a small APK-size increase (only the
  used classes survive R8 shrinking in release builds) and an additional L8 dex
  step at build time. The supported device range is **unchanged**: desugaring
  does not raise `minSdk` (it works down to API 21, well below the project's
  `minSdk = 30`).

---

## v0.63.0

Localisation-scope release. Reduces the shipped languages to the set whose
translations can be quality-assured against the German/English originals for
**both** the UI strings and the in-app user guide, and adds a build-time guard
that keeps the two language sets identical from now on.

### Rationale

Previously the app shipped 51 translated locales, but only a subset could be
reviewed to a level the project is willing to vouch for across *both* surfaces
(strings and the long-form guide). Shipping a translation that cannot be
quality-assured is worse than not shipping it. This release keeps only the
languages that clear that bar for both surfaces, and writes the missing guides
for the kept languages so that every shipped language now has a guide.

### Changed

- **Supported languages reduced to 21** (20 locales + the English base):
  `cs da de el en es fr it ja ko nb nl pl pt pt-BR ro ru sv uk zh-CN zh-TW`.
- **Seven new user-guide translations** authored from the German source
  (`usersguide.de.md.in`), token placeholders preserved:
  `el ja ko ro uk zh-CN zh-TW`. Every kept language now ships a guide.
- `locale_config.xml` and `SupportedLocales.kt` trimmed to the kept set. The
  English base stays listed as `en` (no `values-en/`; it resolves to the base
  `values/`), which remains best practice for the per-app language picker.

### Removed

- **31 languages** dropped from `values-XX/`, `locale_config.xml` and
  `SupportedLocales.kt` (including Latin, whose guide template and rendered
  guide were removed too):
  `ar bg bn cy et fi fo ga ha he hi hr hu id is la lb lt lv mr ms mt sk sl sw ta te th tr vi yo`.

### Added

- **Build-time language-parity guard.** The guide-template language set and the
  string-resource language set must now be identical (both counting the base as
  English). Enforced on two layers: `render-guide.py` aborts the build (write
  and `--check` modes) with a precise diff, and a new `LocaleSyncTest` case does
  the same on the Gradle/CI path.

### Release bookkeeping

- `versionName` → `0.63.0`, `versionCode` → `60`; README title and
  `proguard-rules.pro` header updated to match (release-check.sh §1 /
  `make version-check`).

---

## v0.62.1

Maintenance release. Small UI consistency fixes, a clearer PDF export file name,
a menu-icon refresh, and refreshed German localisation.

### Fixed

- **PDF export file name now carries the `.pdf` extension.** The system "Save as
  PDF" dialog derives its default file name from the print-job name, which
  previously lacked an extension (e.g. `potillus_report_20260603_1430`).
  `PdfReportBuilder.jobName()` now appends `.pdf`, so the dialog pre-fills a
  complete file name.

### Changed

- **Unified the "danger" red across the Statistics screen.** The over-limit
  chart bars and the over-limit statistics (e.g. *Days over daily limit*,
  *over weekly limit*, *over drink-day limit*) and the rising-trend percentage
  now use `dangerRedColor()` — the same saturated red already used by the delete
  trash icons, traffic-light bullets and calendar over-limit dots — instead of
  the softer Material `error` colour. Export-error text still uses `errorColor()`,
  as it denotes a genuine error state rather than a statistic.
- **Overflow-menu icons refreshed.** The *License* entry now uses the open-book
  glyph (`MenuBook`), and the *Help* entry uses a medical-cross glyph
  (`LocalHospital`). The cross inherits the menu's content colour (it is not
  drawn red), so it blends with the active theme.
- **German localisation updated.** The German user's guide and
  `values-de/strings.xml` were revised (provided by the maintainer).

### Release bookkeeping

- `versionName` bumped to `0.62.1`, `versionCode` to `59`; README title and
  `proguard-rules.pro` header updated to match (release-check.sh §1).

---

## v0.62.0

Feature release. Replaces the fixed, configurable calendar week with a gliding
**7-day window** throughout the app, and removes the *"Week starts on …"* setting.

### Rationale

The weekly gram limit and the maximum-drink-days limit were previously evaluated
per calendar week, resetting on a user-chosen weekday. A fixed reset is easy to
game (heavy drinking split across the Sunday/Monday boundary landed in two
separate buckets) and does not reflect continuous health risk. A trailing 7-day
window — every day judged against itself plus the previous six days — never
resets, is stricter, and matches how low-risk-drinking guidance is generally
framed. Removing the setting also simplifies the Settings screen.

### Changed

- **All consumption metrics now use a trailing 7-day window** (today + the
  previous six calendar days), evaluated continuously:
  - *Today screen* — the "this week" gram total, drink-day count and the range
    label now cover the last seven days instead of the current calendar week.
  - *Statistics screen* — the **WEEK** period is now the rolling last-7-days
    window (its previous period, used for the trend %, is the seven days before
    that); MONTH and YEAR are unchanged. The period chip is relabelled **"7 days"**.
  - *Limits* — the traffic light and the "days over limit" statistics/PDF figures
    use the rolling window. `AlcoholCalculator.countLimitViolations` was rewritten
    from a per-calendar-week grouping into an O(n) two-pointer sliding window and
    no longer takes a `weekStartDay` parameter.
- **Calendar grid and PDF weekday profile** keep a fixed first weekday for *layout
  only*; it now follows the **device locale** (via the new
  `DayResolver.firstDayOfWeekIso()`) instead of the removed setting.
- User-facing strings reworded from "week" to "7 days" in the English base, German
  and — best-effort — all other bundled locales:
  `weekly_limit_grams`, `drink_days_setting`, `drink_days_label`,
  `limit_caption_week`, `days_over_weekly_limit`, `pdf_unit_g_per_week`,
  `pdf_kpi_over_weekly`, and the stats period label `week`.

### Removed

- The **"Week starts on <weekday>"** setting and its entire plumbing:
  `AppSettings.weekStartDay`, `IAppPreferences.setWeekStartDay`,
  `AppPreferences` key `week_start_day` (its stored value is now ignored — no
  migration needed; no DB schema change), `SettingsViewModel.setWeekStartDay`,
  and the Settings UI control.
- The obsolete `week_starts_on` string was deleted from the base locale **and all
  51 translations** so the `LocaleSyncTest` key-count/key-set checks stay green.

### Fixed

- Nothing was found broken during the accompanying review pass; see *Notes* for a
  pre-existing observation that was left as-is to keep this change focused.

### Tests

- `AlcoholCalculatorTest`: the `countLimitViolations` suite was rewritten for the
  rolling window, adding cases for window-boundary inclusivity (a 6-day gap shares
  a window, a 7-day gap does not), no gram carry-over beyond the window, and the
  drink-day count not resetting across a weekday boundary. Expected values were
  cross-checked against an independent reference implementation.
- `PdfReportDataTest`: the weekday-order test is now locale-deterministic (asserts
  against `DayResolver.firstDayOfWeekIso()` instead of a hard-coded Monday), so it
  passes regardless of the JVM default locale on the build machine.

### Notes / follow-ups

- **Translations:** the reworded limit strings were translated (best-effort) for
  every bundled locale, preserving each language's existing terminology and only
  swapping the period token to "7 days". Placeholders (`%1$s`) and locale key sets
  are unchanged, so the format-arg and `LocaleSyncTest` checks stay green. Two areas
  intentionally keep their English fallback for now, by agreement: the in-app
  user's guide (`usersguide*.md`) and the "crypto key unavailable" startup message.
- **Build not run in this environment.** The change was made and statically
  reviewed without executing the Android/Gradle toolchain (unavailable in the
  authoring sandbox). Please run `./gradlew testDebugUnitTest lint` before release.
- **Pre-existing observation (not changed):** `TodayViewModel` and `StatsViewModel`
  each retain a `java.time.LocalDate` import that already appeared unused before
  this change. Left untouched to avoid widening the diff; safe to drop later.

---

## v0.61.3

Bug-fix release. Fixes the PDF export (broken on every device since v0.61.0), the
limit progress bars turning red one step too early, a self-terminating comment in
the report template, and two build-tooling paths missed when the code base moved
into `android/`.

### Fixed

- **PDF export failed on every device** ("Export fehlgeschlagen"). The placeholder
  regex in `SimpleTemplate` left its closing braces unescaped (`\{\{(\w+)}}`). The
  desktop JVM regex engine — which local unit tests and `make test` run against —
  accepts a bare `}`, but the stricter ICU engine on Android devices
  (`com.android.icu.util.regex`) rejects it with `PatternSyntaxException`. That
  threw inside `SimpleTemplate`'s static initialiser, failed every
  `PdfReportBuilder.buildHtml` call, and the exception was swallowed by
  `runCatching`, surfacing only as a brief "export failed" banner. All braces are
  now escaped (`\{\{(\w+)\}\}`), which is valid under both engines.
- **Progress bars turned red when a limit was exactly *reached*** rather than
  exceeded. `LimitBar` (daily and weekly gram limits) and `DrinkDaysBar` coloured
  the bar red at `fraction >= 1.0`. Red now means *strictly over* the limit
  (`totalGrams > limitGrams` / `drinkDays > maxDrinkDays`), matching
  `AlcoholCalculator.countLimitViolations` and the calendar/chart over-limit
  markers. Reaching the limit exactly stays amber.
- **Self-terminating comment in `report_template.html`.** The documentation block
  at the top contained a literal `repeat:NAME` / `end:NAME` example written with
  real HTML-comment delimiters, whose first close sequence ended the doc comment
  early and leaked explanatory prose into the rendered page. The example is now
  described without literal delimiters. (This was previously masked by the PDF
  export crashing before it could render.)

### Fixed (build tooling, after the move into `android/`)

- `release-check.sh` looked for `CHANGELOG.md` / `README.md` in its own directory
  (`android/`), but they live at the repository root; it now reads `../CHANGELOG.md`
  and `../README.md`, matching the `version-check` Make target.
- The root `Makefile` `install` target referenced the pre-move APK path
  `potillus/app/build/...`; corrected to `android/app/build/...`.

### Added

- `SimpleTemplateInstrumentedTest` (androidTest) exercises `SimpleTemplate.render`
  on-device, so the JVM-vs-ICU regex divergence that caused the PDF crash is caught
  by `make test`'s `test-device` phase in future — the JVM unit test cannot detect
  it.

### Notes

- Root cause of the PDF regression was confirmed from an on-device logcat stack
  trace (`PatternSyntaxException` in `SimpleTemplate.<clinit>`); the pure pipeline
  (`PdfReportData`, template fill) was never at fault.
- The WebView + system-print path itself still warrants the usual on-device check
  now that the report can be generated again: trigger the PDF export, confirm the
  system print dialog opens, A4 pagination looks right, and "Save as PDF" works.

---

## v0.61.2

- Moved Android code base into subdirectory android/.

## v0.61.1

Bug-fix release: corrected off-by-one errors in the abstinence and average
calculations so that the **abstinent-days KPI**, the **average per day**, and the
**current / longest abstinence streaks** all agree and follow a single, consistent
rule for how the in-progress current day is treated:

- A day counts as a **drink day** the moment its first drink is logged. At that
  point today joins the observable period (with the amount consumed so far), so
  the period is one day longer than the completed days.
- A day counts as an **abstinent day** only once it has *finished* alcohol-free,
  i.e. it has reached the next day-change time without any consumption.
- While today has no drink yet it is undetermined (it may still become either a
  drink or an abstinent day) and stays out of the period entirely until it finishes.

Formally the period length is `effectivePeriodDays = completedDays + (today is a
drink day ? 1 : 0)`, and every rate / count is derived from it.

### Fixed

- **Current / longest abstinence over-counted by one day.** `DayResolver`'s
  tail-gap calculation (last drink day → today) counted the span *including* the
  last drink day. Since the last drink day is itself a drink day (and today is
  still in progress), both endpoints must be excluded; the gap now subtracts the
  drink day (`− 1`, floored at 0), matching the inter-drink-gap convention that
  already did this. Example: last drink two days ago, none since → current
  abstinence is now `1` (the single completed dry day), previously `2`.
- **Abstinent-days KPI and average-per-day were inconsistent with the
  drink-today case.** The Statistics view divided by / subtracted from a period
  that excluded the in-progress day, while `totalGrams` and `drinkDays` already
  *included* a drink logged today. Both are now derived from one explicit
  `effectivePeriodDays = completedDays + (today is a drink day ? 1 : 0)`:
  - `avgPerDay = totalGrams / effectivePeriodDays` — previously divided by the
    completed days only, so logging a drink today divided today's grams over a
    period that did not include today, overstating the daily average (and showing
    `0` when the period was just today). Now today extends the period exactly when
    it is a drink day.
  - `abstinentDays = effectivePeriodDays − drinkDays` (= completed dry days) — the
    in-progress day is never counted as abstinent. Per-drink-day averaging still
    includes today, as intended.

### Changed (documentation / tests)

- Clarified the `DayResolver` KDoc for both abstinence functions to state
  explicitly that the last drink day and the in-progress current day are both
  excluded, and rewrote the `StatsViewModel` comment around the previously
  misleading `coerceAtLeast(0)` note to document the single `effectivePeriodDays`
  model from which the average and the abstinent-day count are derived.
- Updated four `DayResolverTest` expectations to the completed-day semantics
  (last-drink-3-days-ago 3→2, drank-yesterday 1→0, statsFrom-ignored 3→2,
  tail-gap-included 9→8) and added regression tests for the reported scenario
  (drink on T−2, today T → current and longest tail = 1) plus a `StatsViewModelTest`
  case asserting that a drink logged today extends the period for `avgPerDay`.

### Notes

- Behaviour intentionally differs from a naive "days since last drink": the day
  immediately after a drink day shows `0` and becomes `1` only once the following
  day has also finished dry. This is the rule that makes the KPI and the streaks
  consistent.
- A drink logged before the day-change time on the "statistics start" date falls
  on the previous logical day and is correctly excluded from the period — this was
  already handled by the logical-date model and needed no change.

---

## v0.61.0

Reworked the PDF report so its **layout can be edited by hand** without touching
report code. The report is now authored as an HTML/CSS template under
`app/src/main/assets/`; computed numbers and localised labels are injected into
it at runtime, and the result is turned into a PDF through the **Android system
print dialog**. No third-party PDF library and no extra permission were added,
preserving the app's no-network, minimal-permission design.

### Changed (PDF export architecture)

- **Hand-editable template.** `app/src/main/assets/report_template.html` defines
  the two-page A4 report's structure and styling (fonts, colours, spacing, column
  widths, section order, page breaks). It uses `{{PLACEHOLDER}}` tokens and
  `<!-- repeat:NAME -->…<!-- end:NAME -->` row blocks; the contract is documented
  in the file header. Editing it requires only a rebuild, not code changes.
- **System print dialog instead of silent file write.** The PDF is produced by
  loading the report HTML into an off-screen `WebView` and calling
  `PrintManager.print(...)` (`WebViewPdfPrinter`). The user picks *Save as PDF*
  (or a printer) and the destination in the system UI.
- **Behaviour preserved.** All figures are computed by the new pure
  `PdfReportData` layer, which reuses `AlcoholCalculator` and `DayResolver`, so
  the PDF and the on-screen statistics still agree exactly.

### Added

- `util/PdfReportData.kt` – Context-free computation of every report figure
  (KPIs, monthly aggregates, category shares, time-of-day, weekday profile,
  streaks). Unit-tested on the JVM (`PdfReportDataTest`).
- `util/SimpleTemplate.kt` – a tiny, dependency-free HTML templating engine
  (scalar placeholders + repeat blocks, with HTML escaping). Unit-tested
  (`SimpleTemplateTest`).
- `util/PdfReportBuilder.kt` – resolves localised labels, formats numbers and
  fills the template; replaces the old canvas-drawing `PdfExporter`.
- `util/WebViewPdfPrinter.kt` – renders the report HTML via the system print
  dialog.

### Removed

- `util/PdfExporter.kt` – the previous `android.graphics.Canvas`/`PdfDocument`
  exporter that hard-coded the layout in Kotlin and drew each element by pixel
  coordinate.

### UX / behavioural notes

- The PDF export no longer writes a file straight to *Downloads* and no longer
  opens a share sheet; saving/sharing happen inside the system print dialog. CSV
  export is unchanged (still writes to Downloads and offers a share sheet).
- Long monthly tables are no longer truncated to a fixed row budget: the HTML
  report paginates automatically across pages. The `pdf_months_truncated` string
  is consequently no longer referenced (left in place; harmless).
- Per-page footers use the running GPL notice (fixed at the page foot) plus a
  trailing per-page disclaimer; this is a minor cosmetic change from the old
  absolute pixel placement and can be restyled in the template.

### Fixed / cleanup

- Removed the now-unreachable PDF branch from the Statistics share effect (PDF no
  longer flows through `shareTarget`).
- Updated stale KDoc in `ExportResult.kt` and `GplNotice.kt` that referenced the
  deleted `PdfExporter`.

### Known limitation (needs on-device QA)

- The `WebView` + `PrintManager` path is runtime-only and **cannot be exercised
  in unit tests or in this build environment**; it requires verification on a
  physical device / emulator (report renders, A4 pagination, "Save as PDF"). The
  pure pieces (`PdfReportData`, `SimpleTemplate`) are covered by JVM unit tests.

### Observation (not changed)

- `SettingsScreen` still contains a dead `application/pdf` branch in its share
  effect; Settings only exports JSON backups, so it never fires. Left untouched
  to keep this change scoped to the Statistics PDF export.

---

## v0.60.1

Lowered the minimum supported Android version from 15 to 11 to make the app
installable on a much larger share of devices, with no functional code changes —
every version-sensitive API the app uses is already available at the new floor.

### Changed (minimum supported Android version)

- **`minSdk` lowered from 35 (Android 15) to 30 (Android 11)** in
  `app/build.gradle.kts`. This roughly doubles the reachable worldwide install
  base (≈41% → ≈87%, per apilevels.com / Statcounter, April 2026 data) while
  `targetSdk` stays at 36. The previous floor was a policy choice (GrapheneOS
  Pixel devices), not a technical requirement: the codebase contains no
  `Build.VERSION.SDK_INT`, `@RequiresApi`, or `@TargetApi` usage, and every
  version-sensitive API it relies on is available at API 30 or lower
  (MediaStore Downloads + `RELATIVE_PATH` — API 29; Android Keystore AES-256-GCM
  — API 23; `androidx.biometric` — API 23; `WindowCompat` edge-to-edge insets —
  all levels; `AppCompatDelegate` locale switching — back-ported). API 30 is a
  *principled* floor rather than the lowest possible one: API 29 is the level at
  which the exporters can write to the public Downloads folder via `MediaStore`
  **without** any storage permission, so going lower would force a storage
  permission and break the app's minimal-permission design.
- **Bumped `versionCode` 53 → 54 and `versionName` 0.60.0 → 0.60.1**, kept in
  lock-step with the `proguard-rules.pro` header and the `README.md` title
  (enforced by `release-check.sh §1` / the `version-check` Make target).

### Changed (documentation)

- **Rewrote the `minSdk` rationale comment in `app/build.gradle.kts`** to a
  teaching-grade explanation: it now enumerates each version-sensitive API with
  its availability level, explains why no `SDK_INT` branches are needed, and
  documents the two graceful-degradation cases on API 30–32 (see below).
- **Added a "Supported Android versions" section to `README.md`** stating the
  Android 11+ requirement and the reason API 30 is the floor.
- **Added an API-level note in `AndroidManifest.xml`** explaining that
  `android:dataExtractionRules` is honoured only on API 31+ and is silently
  ignored on API 30, which is harmless because `android:allowBackup="false"`
  disables backup on every supported version.

### Notes (graceful degradation on API 30–32, no code change required)

- The **system per-app language picker** (`android:localeConfig`) is an API 33+
  feature. On Android 11–12 it is absent, but the in-app language selector in
  `SettingsScreen` (via `AppCompatDelegate`) works on every supported version.
- **Cloud/device-transfer backup** is disabled on all versions
  (`allowBackup="false"`), so the API-31+ `dataExtractionRules` being ignored on
  API 30 has no security or privacy impact.

### Follow-up (recommended before release)

- Run the unit **and** instrumented test suites (`MigrationTest`,
  `BackupRepositoryInstrumentedTest`, `EntryListItemUiTest`) on emulators for API
  30, 31/32, 33, and 34, plus a manual smoke test of CSV/PDF/backup export,
  biometric unlock, database encryption, and runtime language switching. This QA
  pass — not code changes — is the main remaining effort of the version drop.

---

## v0.60.0

A round of fixes and refinements: localized the device-transfer warning, a daily
limit rounding fix, build-tooling and in-app guide-viewer improvements, and
overflow-menu icons.

### Changed (version metadata)

- **Corrected the version strings, which had drifted.** `versionName` was still
  `0.58.0` (a leftover) and is set to `0.60.0`; `versionCode` is bumped 51 → 53;
  the `app/proguard-rules.pro` header is synced from `v0.56.0` to `v0.60.0`. These
  must stay in lock-step with the top CHANGELOG entry (enforced by
  `release-check.sh §1`).
- **Added the app version to `README.md`** (`v0.60.0` under the title), which had
  carried no version string at all.
- **New `version-check` target in the `Makefile`, wired into `prereq`.** It reads
  the version from the top-most `## vX.Y.Z` CHANGELOG entry and fails the build if
  `build.gradle.kts` (versionName), the `proguard-rules.pro` header, or the
  `README.md` title disagree — so version drift is caught on every local build,
  not just at the release gate.

### Changed (in-app guide viewer)

- **Paragraphs in the Markdown guide viewer now have a clear blank-line gap.**
  `MarkdownText` separated paragraphs with only 8.dp, which read as cramped; the
  inter-paragraph spacing is now 12.dp, matching the blank lines that separate
  paragraphs in the guide source.

### Changed (overflow menu)

- **Leading icons added to the overflow menu items:** a gear before Settings
  (`Icons.Filled.Settings`), a book before Help (`Icons.AutoMirrored.Filled.MenuBook`)
  and a gavel before License (`Icons.Filled.Gavel`). The icons are decorative
  (`contentDescription = null`) since each sits next to its text label. All three
  come from the already-included `material-icons-extended`.

### Fixed (invisible daily-limit exceedance from rounding)

- **Alcohol grams are now computed at 0.1 g precision instead of 0.01 g.**
  `AlcoholCalculator.calculateGrams` rounded to two decimals, so e.g. 188 ml at
  13.5 % stored 20.02 g. The UI displays one decimal ("20.0 g"), but the daily
  limit and binge checks compared the stored 20.02 g, so a 20 g limit showed as
  exceeded while the screen still read "20.0 g" — an exceedance the user could not
  see. `calculateGrams` now rounds to 0.1 g (new `roundTo1Decimal`), so the
  displayed value and every comparison use the same number. BAC keeps its 0.01 ‰
  precision (`roundTo2Decimals` is unchanged for `calculateBAC`).
- **No data migration.** Only newly logged entries are stored at 0.1 g; existing
  entries are left as-is (to be adjusted manually via a backup edit if desired),
  per request — no migration code was added.
- Unit tests in `AlcoholCalculatorTest` updated to the 0.1 g precision, including
  a regression test for the 188 ml / 13.5 % → 20.0 g case.

### Changed (guide build tooling)

- **`tools/render-guide.py` now discovers languages automatically** from the
  `docs/guide/usersguide*.md.in` templates instead of a hard-coded list, so
  adding a language (e.g. the new Latin guide) needs no script edit. The English
  default template is now the code-less `docs/guide/usersguide.md.in` (renamed
  from `usersguide.en.md.in`), mapping to the unqualified `values`/`raw`; a tag
  maps to `values-<q>`/`raw-<q>` with the Android region form (`pt-BR` →
  `pt-rBR`).
- **Outputs are regenerated on a timestamp basis:** an in-app `usersguide.md` is
  rewritten only when its template **or** the matching `strings.xml` is newer
  than the existing file. `--check` still compares content (for CI).
- Dropped the dead code for the former root-level `USERSGUIDE.md` /
  `USERSGUIDE-de.md` copies (those outputs were already removed) and updated the
  `Makefile` `guides` comment accordingly.

### Changed (localized device-transfer warning)

- **Translated the device-transfer warning** (`device_transfer_warning_title` /
  `device_transfer_warning_body`), which had been English in every locale, into
  the major languages: de, fr, es, it, nl, pt, pt-BR, ru, pl, sv, da, nb, cs, fi,
  el, tr, uk, hu, ro, sk, ja, ko, zh-rCN, zh-rTW, ar, id (26 locales). The
  remaining locales keep the English text for now. The wording uses the app's
  neutral/impersonal register (no informal/formal pronoun, matching the existing
  strings), and the "Settings → …" breadcrumb uses each locale's actual
  `settings` label so it matches what the app shows.

---

## v0.59.0

Toolchain modernisation for 2026, delivered as a sequence of incremental,
build-on-each-other steps under one version:

  - **Part 1:** raise the Kotlin compiler, KSP, the Compose BOM
    and the Kotlin-coupled test libraries, and adapt the instrumented UI tests
    to the Compose v2 testing APIs. The build system (AGP 8.13.2, Gradle
    8.14.5) is deliberately left untouched.
  - **Part 2:** Gradle 8.14.5 → 9.4.1 + AGP 8.13.2 → 9.2.0
    together (lock-step major upgrade), removing the now-redundant
    `kotlin-android` plugin and adopting AGP 9 built-in Kotlin, with the Kotlin
    compiler version pinned to 2.3.21 via a buildscript override; plus the AGP 9
    `srcDirs` → `directories` source-set fix.
  - **SQLCipher migration (this change):** move off the deprecated, EOL
    `android-database-sqlcipher` to the maintained `sqlcipher-android` for
    16 KB page-size compliance.
  - **Part 3 — hygiene (this change):** consolidate the inline-pinned
    dependency versions into the version catalog and drop the obsolete
    `suppressUnsupportedCompileSdk` flag. (Enabling the Gradle configuration
    cache is kept as a separate, optional follow-up.)
  - **Dependency freshening:** raise the explicitly-versioned
    AndroidX core libraries (core-ktx, activity-compose, lifecycle) to current
    stable. (navigation-compose stays at 2.8.9 — androidx.navigation 2.9 is still
    in alpha, so 2.8.9 is the current stable.)
  - **SQLCipher / SQLite / Room currency (this change):** raise the database
    stack to the current coordinated set — sqlcipher-android 4.15.0,
    androidx.sqlite 2.6.2 and Room 2.8.4 — and drop the merged room-ktx artifact.

### Changed

- **Kotlin 2.0.21 → 2.3.21.** Current patch of the Kotlin 2.3 line. Because the
  Compose compiler plugin and the serialization plugin are versioned via the
  same catalog key, this also moves the Compose compiler to 2.3.21, which is the
  compiler that pairs with the Compose 1.11 runtime (see below).
- **KSP 2.0.21-1.0.28 → 2.3.7.** Adopts KSP's new, Kotlin-decoupled version
  scheme (since KSP 2.3.0 a single release supports Kotlin `2.2.*` and newer), so
  the version no longer mirrors the compiler version.
- **Compose BOM 2025.05.01 → 2026.04.01.** Pins the core Compose modules to
  1.11.0.

### Fixed

- **Serialization runtime incompatible with the new compiler.**
  `kotlinx-serialization-core` was pinned to 1.7.3 (built against Kotlin 2.0).
  Kotlin's forward-compatibility rule (a runtime built with 2.Y supports 2.(Y+1)
  but not 2.(Y+2)) makes 1.7.3 invalid under the 2.3.21 compiler. Bumped to
  1.11.0 (built against Kotlin 2.2.x).
- **Coroutines test runtime incompatible with the new compiler.**
  `kotlinx-coroutines-test` 1.9.0 (Kotlin 2.0) falls under the same rule; bumped
  to 1.11.0. Dispatcher semantics are unchanged, so the JVM unit tests behave
  identically.
- **`kotlin-test` version drift.** The literal `2.0.21` test dependency was
  updated to `2.3.21` to match the compiler and avoid a metadata mismatch.
- **Build script: removed `kotlinOptions` String setter.** The Kotlin 2.3
  Gradle plugin turns `android { kotlinOptions { jvmTarget = "21" } }` from a
  deprecation warning into a hard script-compilation error. Migrated to the
  type-safe `compilerOptions` DSL in a new top-level `kotlin { }` block
  (`jvmTarget.set(JvmTarget.JVM_21)`), with the matching
  `org.jetbrains.kotlin.gradle.dsl.JvmTarget` import. This DSL migration was
  originally earmarked for part 3 but is mandatory here because the 2.3 compiler
  makes the old form non-compiling.
- **Instrumented UI tests under the Compose v2 testing APIs.** BOM 2026.04.01
  enables the v2 testing APIs by default, switching the Compose test
  dispatcher from `UnconfinedTestDispatcher` (eager) to `StandardTestDispatcher`
  (queued). In `EntryListItemUiTest`, the two click tests asserted on a plain
  counter immediately after `performClick()`; that read could now race the
  queued click. The assertions are wrapped in `composeTestRule.runOnIdle { }`,
  which drains the queue before reading. Node-based assertions
  (`assertIsDisplayed()`) were left unchanged because finders synchronise
  implicitly.
- **Stale documentation.** The `libs.versions.toml` comment claiming KSP must
  use the `<kotlin-version>-<ksp-patch>` format and "must exactly match the
  Kotlin version" was corrected to describe the decoupled scheme.

### Notes

- Building part 1 on AGP 8.13.2 emits a deprecation warning about the
  `org.jetbrains.kotlin.android` plugin: from Kotlin 2.3.0 onward the plugin is
  redundant on AGP versions that ship built-in Kotlin. This is expected and is
  resolved in part 2; it is a warning, not an error, on AGP 8.x.
- Room (2.7.1) and SQLite (2.4.0) are unchanged and run on KSP 2.3.7. A full
  compile + `connectedDebugAndroidTest` on the target toolchain is the
  authoritative verification step for this part.

### Changed (part 2 — build system)

- **Gradle 8.14.5 → 9.4.1.** Mandatory lock-step partner for AGP 9: moving from
  AGP 8.x to 9.x requires a Gradle 8.x → 9.x major upgrade that cannot be
  bypassed. 9.4.1 is the version Google's current AGP setup guide recommends.
- **AGP 8.13.2 → 9.2.0.** Major upgrade. JDK 17+ (we use 21) and compileSdk up
  to API 36.1 (we use 36) are satisfied.
- **Adopted AGP 9 built-in Kotlin; removed the `kotlin-android` plugin.** AGP 9
  compiles Kotlin itself, so `org.jetbrains.kotlin.android` is no longer applied
  (app and root) nor declared in the version catalog. Keeping it under AGP 9
  would be a hard error (duplicate `kotlin` extension), not just a warning —
  this resolves the deprecation warning noted for part 1.
- **Pinned the built-in Kotlin compiler to 2.3.21 via a buildscript override.**
  AGP 9 bundles KGP 2.2.10 as a floor. To keep the 2.3.21 compiler established
  in part 1 (the Compose/serialization plugins and test libraries are aligned to
  it), the root `build.gradle.kts` adds the officially documented override
  `buildscript { dependencies { classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.21") } }`.
  The Compose, serialization and KSP plugins continue to be applied via the
  version catalog and are unchanged.
- **Fixed AGP 9 source-set deprecation.** The first green AGP 9 build emitted
  `'fun srcDirs(...)' is deprecated. Use 'directories' mutable set instead`.
  The androidTest schema-assets line was migrated from
  `assets.srcDirs(files("$projectDir/schemas"))` to
  `assets.directories += "$projectDir/schemas"`. Same resolved location, AGP 9
  DSL. (The build also logs an informational note that `libsqlcipher.so` and two
  other prebuilt native libraries cannot be stripped of debug symbols; that is
  expected and requires no change.)

### Notes (part 2)

- The buildscript Kotlin pin is a hard-coded literal because a Gradle
  `buildscript` block cannot read the version catalog. It must be kept in sync
  with `kotlin` in `libs.versions.toml` on every future Kotlin bump; both spots
  carry a comment to that effect.
- KGP 2.3.21 is officially fully tested with Gradle only up to 9.3.0, so on
  9.4.1 benign Kotlin deprecation warnings are possible. Dropping the wrapper to
  9.3.0 would avoid them if AGP 9.2 accepts it; 9.4.1 was chosen to match
  Google's recommendation.
- KSP (2.3.7) is applied via the plugins block as before. Because 2.3.7 is above
  AGP's built-in KSP floor it is not force-upgraded; if a build ever reports a
  KGP/KSP mismatch, add the commented KSP `classpath(...)` line provided in the
  root `build.gradle.kts`.
- `android.builtInKotlin=false` is deliberately NOT set: built-in Kotlin is
  adopted, not opted out of (the opt-out is removed in AGP 10, mid-2026).
- No use of the removed AGP 9 variant APIs (`applicationVariants`, etc.) was
  found, so no DSL changes were required to configure under AGP 9. As always, a
  full compile + `connectedDebugAndroidTest` on the target toolchain is the
  authoritative verification step.

### Changed (SQLCipher migration — 16 KB page-size compliance)

- **`net.zetetic:android-database-sqlcipher:4.5.4` → `net.zetetic:sqlcipher-android:4.10.0`.**
  The old artifact was deprecated in 2022 and reached end-of-life in 2023; its
  native libraries are not built for 16 KB memory pages. Android 15+ devices can
  run with 16 KB pages and Google Play requires 16 KB support for apps targeting
  Android 15+, so the unaligned `libsqlcipher.so` (flagged by the strip step in
  the build log) is a real runtime/release risk. The maintained replacement
  `sqlcipher-android` ships 16 KB-aligned libraries (since 4.6.1).
- **`AppDatabase.kt` adapted to the new API.** The package moved from
  `net.sqlcipher.database` to `net.zetetic.database.sqlcipher`, and the Room
  integration class changed from `SupportFactory` to `SupportOpenHelperFactory`
  (same constructor: a passphrase `ByteArray`, zeroed immediately after). The
  new library also requires the native library to be loaded explicitly, so
  `System.loadLibrary("sqlcipher")` is called once before the factory is built.
  No schema, passphrase, or Keystore logic changed, so existing encrypted
  databases open unchanged.
- **Instrumented test (`MigrationTest.kt`) migrated too.** It also used the old
  `net.sqlcipher.database.SupportFactory`. Switched to `SupportOpenHelperFactory`
  with `System.loadLibrary("sqlcipher")` in the companion `init`. IMPORTANT
  semantic change: the old `SupportFactory(passphrase, hook, clearPassphrase)`
  third argument was `clearPassphrase` (the test passed `false` to keep the
  passphrase reusable across multiple opens); the new
  `SupportOpenHelperFactory(passphrase, hook, enableWriteAheadLogging)` third
  argument is unrelated (WAL). The new library has no passphrase-clearing toggle
  and does not zero the passphrase, so the single-argument constructor is now
  used and is safe across the test's repeated opens.

### Notes (SQLCipher migration)

- `androidx.sqlite` is deliberately left at 2.4.0 to keep this step a focused
  artifact swap. Newer `sqlcipher-android` releases (4.15.0) are paired with
  `androidx.sqlite` 2.6.2; raising both together is deferred to the optional
  dependency-freshening step. If the build reports a `SupportSQLiteOpenHelper`
  API mismatch, bump `sqlite` alongside.
- If Gradle fails to resolve the native AAR, append `@aar` to the `sqlcipher`
  library coordinate (a comment in `libs.versions.toml` notes this).
- Verification is necessarily on-device: a `connectedDebugAndroidTest` run
  (which exercises the encrypted Room database and the migration test) confirms
  the native library loads and decryption still works.

### Changed (part 3 — hygiene)

- **Consolidated inline-pinned dependency versions into the version catalog.**
  Eight dependencies were previously declared as string literals in
  `app/build.gradle.kts` (`androidx.tracing`, `junit`, `kotlin-test`,
  `kotlinx-coroutines-test`, `turbine`, `org.json`, `androidx.test:runner`,
  `espresso-core`). They now live in `gradle/libs.versions.toml` and are
  referenced via `libs.*` accessors. Resolved versions are unchanged, so this is
  behaviour-neutral; the per-dependency rationale comments stay at the usage
  site. `kotlin-test` now references the `kotlin` version (`version.ref`), so it
  can no longer drift from the compiler version.
- **Removed the obsolete `android.suppressUnsupportedCompileSdk=36` flag.** It
  silenced an "untested compileSdk" warning that no longer applies: AGP 9.2
  officially supports compileSdk up to API 36.1, and the project uses 36.

### Notes (part 3)

- This step touches only `gradle.properties`, the version catalog and dependency
  declarations; no source code changes. It is behaviour-neutral and should not
  alter the build graph beyond removing the (now unnecessary) warning
  suppression.
- The Gradle configuration cache (suggested by the build output) is intentionally
  not enabled here. It can surface incompatibilities (e.g. with the buildscript
  Kotlin override, KSP, or Room) and is best introduced as its own isolated,
  separately-tested change.

### Changed (dependency freshening — AndroidX core)

- **core-ktx 1.13.1 → 1.18.0**, **activity-compose 1.9.0 → 1.12.3**,
  **lifecycle 2.8.2 → 2.10.0** (current stable as of mid-2026). These were a year
  or more behind the SDK-36 / Kotlin-2.3 / Compose-1.11 baseline. Verified against
  the official AndroidX release notes; pre-release versions were deliberately
  avoided (core 1.19, lifecycle 2.11 are still rc/beta).
- **navigation-compose kept at 2.8.9.** androidx.navigation 2.9.x is still in
  alpha, so 2.8.9 is the current stable — no bump warranted. (Not to be confused
  with the JetBrains `org.jetbrains.androidx.navigation` 2.9.x KMP fork, which is
  a different artifact.)

### Notes (dependency freshening)

- This is a pure version bump in the catalog; no source changes. Still, it crosses
  real minor versions (notably lifecycle 2.9's Kotlin-Multiplatform repackaging),
  so it must be built and instrument-tested. The APIs this app uses
  (`collectAsStateWithLifecycle`, `viewModel()`, `setContent`) are unchanged.
- activity-compose and lifecycle were bumped together on purpose: activity 1.12
  depends transitively on a recent lifecycle, so pinning lifecycle to 2.10.0 keeps
  the catalog's declared version aligned with what actually resolves.
- Other explicitly-versioned libraries were left as-is: appcompat 1.7.0 and
  biometric 1.1.0 are the current stables; Room 2.7.1, DataStore 1.1.1 and the
  SQLCipher/SQLite pair are working and were out of scope here. Raising the
  SQLCipher/SQLite pair to the very latest (`sqlcipher-android` 4.15.0 +
  `androidx.sqlite` 2.6.2) remains available as a separate, coordinated change.

### Changed (SQLCipher / SQLite / Room currency)

- **sqlcipher-android 4.10.0 → 4.15.0**, **androidx.sqlite 2.4.0 → 2.6.2**,
  **Room 2.7.1 → 2.8.4** — bumped together as one coordinated set. 2.6.2 is the
  androidx.sqlite version Google documents for Room 2.8.4 and Zetetic documents
  for sqlcipher-android 4.15.0, so the three move in lockstep to avoid a
  Room ↔ androidx.sqlite binary-compatibility skew.
- **Removed the `room-ktx` dependency and catalog entry.** As of Room 2.8 the
  room-ktx APIs (coroutine/Flow support, suspend DAOs) are merged into
  room-runtime and the standalone artifact is empty. No code change is needed —
  the same APIs now resolve from room-runtime.
- **Corrected a stale comment** in `app/build.gradle.kts` that still referred to
  the old `SupportFactory` and an `@aar` classifier; it now describes
  `SupportOpenHelperFactory` and the explicit `System.loadLibrary` step.

### Notes (SQLCipher / SQLite / Room currency)

- Room 2.8.x is the final Room 2.x line (maintenance mode); Room 3.0 is a
  separate package (`androidx.room3`) and is deliberately not adopted. 2.8.x
  retains the SupportSQLite APIs, so the SQLCipher `SupportOpenHelperFactory`
  integration in `AppDatabase` and `MigrationTest` works unchanged.
- This crosses a Room minor version and the androidx.sqlite 2.5→2.6 line, so it
  must be built and instrument-tested. The migration test (which opens the
  encrypted DB through SQLCipher and validates the Room schema migration) is the
  key check. No schema, DAO, entity, passphrase or Keystore code changed.
- Verified against the official Room and sqlcipher-android documentation; no
  pre-release versions were used.

### Changed (Compose v2 test rule)

- **`EntryListItemUiTest` now uses the v2 `createAndroidComposeRule`.** Since
  Compose 1.11 (Compose BOM 2026.04.01, adopted in part 1) the v1 test
  environment factories are deprecated in favour of the
  `androidx.compose.ui.test.junit4.v2` package. Only the import changed: the v2
  factories are the sole part of the testing surface that moved, while the
  finders, actions, `setContent` and `runOnIdle` stay on their existing APIs. The
  v2 environment runs composition on a StandardTestDispatcher; the
  recomposition-dependent assertions were already wrapped in `runOnIdle {}` in
  part 1, so no test logic needed to change.

### Fixed (false "Settings not restored?" on first install)

- **The device-transfer warning no longer fires on a genuine first install.**
  Previously the warning was driven by a heuristic — install younger than 15
  minutes AND `language` empty AND `weightKg == 0.0` — and a fresh install
  satisfies all three, so every first launch showed "Settings not restored?".
  The check now uses an authoritative signal instead: a sealed passphrase
  envelope is *present* in storage (restored from an Android backup) but cannot
  be *decrypted* with this device's Keystore key — the actual signature of a
  transfer where the hardware-bound key did not migrate. A first install has no
  envelope at all, so the warning stays silent.
- **Implementation.** `AppDatabase` gains two read-only probes,
  `hasSealedPassphrase()` and `canOpenSealedPassphrase()` (the latter attempts
  `KeystoreSecretStore.open` and returns false on `GeneralSecurityException` /
  malformed blob, zeroing the plaintext). `PotillusApp.checkForDeviceTransferFailure()`
  consumes them; the pure decision `shouldWarnDeviceTransfer(present, decryptable)`
  is `present && !decryptable`. The install-recency window (`INSTALL_RECENCY_MS`)
  and the settings-based heuristic are removed, and `onCreate` no longer needs the
  pre-write settings snapshot for this check.
- **Tests.** `PotillusAppHeuristicTest` was rewritten to lock in the new truth
  table (present+undecryptable → warn; absent → silent; present+decryptable →
  silent). It remains a pure JVM test.
- **Display language unchanged but worth noting:** the dialog is shown via
  `stringResource`, i.e. resolved against the system/configuration locale. That is
  the correct behaviour here, because in the failure scenario the user's stored
  language preference lives in the encrypted store that cannot be read. The
  message strings are currently English in every locale (translation is tracked
  separately).

### Added

- **`docs/guide/usersguide.la.md.in` — a Latin translation of the user guide.**
  The build-time renderer (`tools/render-guide.py`) now emits the Latin guide to
  `res/raw-la/usersguide.md` (with `values-la` for the on-screen labels), so the
  app shows it for users whose per-app language is Latin.

---

## v0.58.0

Added a localized, build-time-templated in-app user guide system and an
in-app viewer for it; replaced the per-screen settings gear with a single
overflow (burger) menu that also opens the guide and the license; embedded a
GPLv3 notice in the JSON and PDF exports; and fixed a text bug in the English
source guide.

### Added

- **In-app user guides under `res/raw`.** The user guide now ships as a raw
  resource (`R.raw.usersguide`) so it can be displayed inside the app later. As
  with `strings.xml`, the file is locale-qualified: the English guide lives in
  `res/raw/usersguide.md` (the resource default) and each translated guide in
  `res/raw-<locale>/usersguide.md`. Because the app sets a per-app locale via
  `AppCompatDelegate.setApplicationLocales`, Android resolves the matching
  `raw-xx` directory automatically — exactly the mechanism already used for
  strings.
- **Single-source guide templates** in `docs/guide/usersguide.<lang>.md.in`.
  Every on-screen name (screen titles, settings-section headers) is written as a
  `{{key}}` token instead of a hard-coded word, so a guide can never drift away
  from the label the app actually shows.
- **Build-time renderer `tools/render-guide.py`.** It resolves each `{{key}}`
  against the *matching* locale's `strings.xml`, undoes Android's string
  escaping (e.g. French `Aujourd\'hui` → `Aujourd'hui`), and fails loudly on an
  unknown key. It writes the in-app `res/raw[-xx]/usersguide.md` copies (license
  header stripped for clean on-device rendering) and regenerates the
  repository-facing `USERSGUIDE.md` / `USERSGUIDE-de.md` (header kept, plus a
  "generated — do not edit" banner). Writes are content-diffed (no needless
  touches) and a `--check` mode lets CI verify the committed guides are in sync.
- **Curated 14-language core set** with real translations: English (base), plus
  German, French, Spanish, Italian, Dutch, Portuguese, Brazilian Portuguese,
  Russian, Polish, Swedish, Danish, Norwegian Bokmål and Czech. Every other
  supported language deliberately has no `raw-xx`, so the app falls back to the
  English guide via normal resource resolution rather than showing
  machine-quality text.
- **Makefile integration.** A new `guides` target regenerates the guides and is
  now a prerequisite of every build, so the shipped guides are always in sync;
  `check-guides` runs the renderer in verification mode for CI. Help text and
  `.PHONY` updated accordingly.
- **Overflow menu (`AppOverflowMenu`).** The four main screens previously each
  carried an identical settings gear in their top bar. They now share one
  composable that shows a burger icon (`Icons.Default.Menu`) opening a dropdown
  with three entries: **Settings**, **Help** and **License**. The menu holds no
  navigation logic of its own — it invokes callbacks supplied by
  `AppNavigation` — so the four screens stay free of navigation dependencies.
- **In-app guide & license viewer (`DocumentViewerScreen`).** A single,
  reusable read-only screen backs both new menu entries. *Help* renders the
  locale-resolved `R.raw.usersguide` as Markdown; *License* shows
  `R.raw.license` as plain monospaced text. Both are pushed on top of Home with
  an Up arrow, mirroring Settings, and are wired as two new type-safe routes
  (`Screen.Help`, `Screen.License`).
- **Minimal Markdown renderer (`MarkdownText`).** A small, dependency-free
  composable renders exactly the Markdown subset the guides use (ATX headings,
  reflowed paragraphs, `[text](url)` links). Adding no third-party library keeps
  the app dependency-light, in line with its privacy-minimal design; the
  unsupported-syntax boundary is documented in the file.
- **Bundled license (`res/raw/license.md`).** A verbatim copy of the
  project-root `LICENSE.md`, produced by a `cp` step in the Makefile's `guides`
  target. It is intentionally **not** translated or locale-qualified, so
  `R.raw.license` always resolves to the original (English) GPLv3 text;
  `check-guides` now also fails if the copy drifts from the root file.
- **GPLv3 notice in exports (`GplNotice`).** Exports now carry the project's
  GPLv3 header as a non-evaluated notice. The **JSON backup** gains a top-level
  `_comment` array (JSON has no comment syntax, and the importer already ignores
  unknown keys, so this round-trips safely). The **PDF report** gains a small
  one-line notice in the footer of every page (`FOOTER_RESERVE` raised from 30
  to 42 pt to make room). The **CSV export deliberately carries no notice**, as
  CSV has no portable comment convention and a leading line would surface as a
  spurious data row in spreadsheet importers.
- **Three new UI strings** (`menu`, `help`, `license`) added across all 52
  locales (the base plus 51 translations), so per-locale `strings.xml` parity is
  preserved (now 172 strings each, up from 169).

### Changed

- **Settings is now reached via the overflow menu**, not a dedicated gear icon.
  The gear `IconButton` was removed from all four main screens; `StatsScreen`'s
  now-unused icon imports were dropped.
- **Guide wording updated to match the new menu.** Every guide template's
  "gear/cog icon" phrasing was replaced with "menu icon (☰)" and the guides
  regenerated, so the shipped text describes the actual UI.

- **English source guide had stray heading echoes.** Several paragraphs ended
  with a duplicated fragment of the following heading (e.g. "… functions of the
  app. Highlights", "… on a Fairphone 4. \"Today\" Screen", "… the Widmark
  formula. Limits"). These were removed while templating; the German guide was
  already clean.

### Notes

- The in-app Markdown *viewer* deferred when the guide files were first added
  is now implemented (see `DocumentViewerScreen` / `MarkdownText` above), so the
  guide is readable directly inside the app rather than only via
  `resources.openRawResource`.
- This version *does* change `strings.xml`: three UI strings were added to every
  locale, raising the `LocaleSyncTest`-checked parity from 169 to 172 strings.
  `res/raw` (the guide and license copies) remains outside that test.
- The GPLv3 notice embedded in exports is kept in English on purpose — it is a
  legal notice rather than UI chrome, so it lives in code (`GplNotice`), not in
  the translatable `strings.xml`.

---

## v0.57.0

Replaced the gender + guideline-mode limit system with three always-active,
user-defined limits.

### Changed

- **Limits are now three independent values that always apply together:** a
  daily limit (g), a weekly limit (g) and a maximum number of drink days per
  week. Defaults are 20 g / 100 g / 5 days. The previous WHO / DHS / custom
  *limit mode* selector and the separate daily-vs-weekly *gram mode* toggle have
  been removed; all three limits are always evaluated at once.
- **Biological sex is no longer stored or used.** The Widmark BAC estimate now
  uses a fixed, conservative distribution coefficient r = 0.6 (the smaller of
  the two classic coefficients), which yields the higher — i.e. worst-case —
  blood-alcohol estimate. Body weight is still used.
- **Binge threshold** is now the sex-independent constant 48 g
  (`AlcoholCalculator.BINGE_THRESHOLD`), replacing the former per-sex values.
- **Today screen** now shows three progress bars (daily grams, weekly grams,
  drink days) instead of one gram bar plus the drink-days bar.
- **Traffic-light capacity dots** consider all three limits. Free servings are
  the minimum of the daily and weekly gram headroom; the drink-day limit acts as
  a gate that forces red once the week's drink-day budget is used up. The gate
  fires both when today is not yet a drink day and the week already holds the
  maximum number of drink days, and when today *is* a drink day but the maximum
  had already been reached on earlier days.
- **Statistics screen** replaces the single "days over limit" row with three
  rows: days over the daily limit, days over the weekly limit, and days over the
  drink-day limit (see the new `AlcoholCalculator.countLimitViolations`).
- **PDF report** drops the "Sex" metadata row and the guideline-mode line; the
  limit line now reads "X g/day · Y g/week · N drink days/wk", the KPI grid shows
  the three violation counts plus the (fixed-threshold) binge count, and the
  monthly table's over-limit column and the trend sparkline reference line now
  use the daily limit.
- **Settings screen** "Personal data" now contains only body weight; the new
  "Limits" section offers three numeric inputs (daily / weekly / drink days).

### Added

- `AlcoholCalculator.countLimitViolations(...)` — shared, unit-tested helper that
  counts the three violation kinds over a list of day summaries, grouping weeks
  by the configured week-start day. Used by both the Statistics screen and the
  PDF export so they always report identical figures.
- `LimitViolations` domain model holding the three counts.
- New, fully translated string resources across all 51 locales:
  `limits`, `daily_limit_grams`, `limit_caption_day`, `limit_caption_week`,
  `days_over_daily_limit`, `days_over_weekly_limit`, `days_over_drink_day_limit`,
  `pdf_unit_g_per_week`, `pdf_meta_drink_days_suffix`, `pdf_kpi_over_daily`,
  `pdf_kpi_over_weekly`, `pdf_kpi_over_drink_days`, `pdf_col_over_daily`.

### Removed

- Domain enums `Gender` and `LimitMode`; `AppSettings.gender`,
  `AppSettings.limitMode`, `AppSettings.weeklyGramMode`; the WHO/DHS limit
  constants and per-sex binge/Widmark constants; the `LimitMode` label
  extensions; the `DrinkCapacity.weeklyGramMode` field and its `effective*`
  helpers; and the now-orphaned `unit_g_per_day` plus all WHO/DHS/gender/
  weekly-mode string resources (24 keys).
- The corresponding `IAppPreferences` setters (`setGender`, `setLimitMode`,
  `setCustomLimit`, `setCustomMaxDrinkDays`, `setWeeklyGramMode`) were replaced
  by `setDailyLimit`, `setWeeklyLimit` and `setMaxDrinkDaysPerWeek`. The DataStore
  keys for the daily limit and drink-day count are reused under their historical
  names so existing values survive; obsolete keys are ignored.

### Documentation

- Updated `README.md`, `CONTRIBUTING.md` and the in-code KDoc to reflect the new
  model. The user guides already described the three-limit design.

### Notes / known issues

- A static **dead-code review** found two pre-existing functions in
  `AlcoholCalculator` that are referenced only by tests and never in production:
  `soberByMillis` and `limitPercent`. They predate this change and were left in
  place (public, tested domain API); removal is recommended if they are not
  intended for upcoming features. (`MILLIS_PER_HOUR`, by contrast, is live.) A
  handful of string resources (`bac_section`, `bac_desc`, `biometric`,
  `stats_from_section`) also appear unused; these are pre-existing and were not
  touched.
- The domain layer (`Models.kt`, `AlcoholCalculator.kt`) was compiled and its
  unit tests (39 cases, including the new BAC, limit, traffic-light and
  violation-counting tests) were executed and pass. The Android/Compose layers
  could not be compiled in this environment (no Android SDK); they were reviewed
  statically for signature and resource consistency.
- The new locale strings were translated on a best-effort basis for the less
  common languages; native review is recommended.

---

## v0.56.0

First sanitized, public baseline.

This is the starting point of the public, forward-only changelog. The internal
development history that preceded it has been removed — it is not part of the
published source — and the knowledge it carried, in particular the *reasons*
behind design decisions, now lives in the source code itself, in the KDoc and
comments next to the code each decision affects.

What was done to produce this baseline:

- **Source documentation sanitized.** All references to concrete past app
  versions and to internal review issue codes were removed from comments, KDoc,
  file headers, the README, CONTRIBUTING, the build script, the ProGuard rules,
  the localization resources and `release-check.sh`. Functional version tokens
  are intentionally kept because they are data contracts, not release history:
  the Room schema version (`@Database(version = 2)`, `MIGRATION_1_2`, the
  committed `app/schemas/*.json`) and the backup-format version
  (`BACKUP_VERSION`).
- **Design rationale folded into the code.** Explanations that previously lived
  only in the changelog (or were referenced indirectly through an issue code)
  were rewritten in present tense as self-contained rationale at the relevant
  code site, so the code explains itself without this file.
- **Three-part versioning.** The version string is now `MAJOR.MINOR.PATCH`,
  starting at `0.56.0` (`versionCode` 49). Going forward, routine changes bump
  PATCH and larger feature sets bump MINOR; `versionName`, this changelog's top
  entry, the README title and the ProGuard header stay in lock-step (CONTRIBUTING
  §6).

### Notes

- No application behaviour changed in this baseline: the edits are limited to
  documentation/comments, the version strings, and the version-format check.
- Not built or tested in this environment (no Android SDK). Run `make test` and
  `make test-device` before tagging.
