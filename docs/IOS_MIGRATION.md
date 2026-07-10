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

In addition, as permitted by section 7 of the GNU General Public License,
this program may carry additional permissions; any such permissions that
apply to it are stated in the accompanying COPYING.md file.

=============================================================================
-->

# iOS Migration

This document is the working plan for bringing Libellus Potionis to Apple
devices as a **native Swift / SwiftUI** application that lives in the **same
repository** as the existing Android app, alongside `android/`. It records the
decisions the maintainer and the assistant agreed on, maps the current Android
architecture onto its iOS counterparts, and lists the challenges, risks, and
open actions so that future work (and future chat sessions) has a single,
authoritative reference.

It is a companion to [ROADMAP.md](ROADMAP.md), which keeps the high-level
project direction; the detail lives here so the roadmap stays lean.

> Status: **strategy agreed, implementation not started.** All migration work
> happens on the `ios` branch and is merged to `main` only when ready; the
> human-readable release version is therefore not yet fixed (see
> [Versioning](#6-versioning-and-release-synchronization)).


## 1. Agreed decisions

These are settled and should not be reopened without a note here explaining
why. Each line is the outcome of an explicit maintainer decision.

1. **Approach: native Swift / SwiftUI.** No Kotlin Multiplatform (KMP) and no
   Compose Multiplatform for now. The iOS app is a standalone Swift codebase.
   The pure-Kotlin domain logic is *ported* to Swift and *cross-checked* against
   the Android implementation (see
   [Correctness parity](#7-correctness-parity-strategy)); it is not shared as a
   binary module. KMP remains a possible *later* consolidation because the
   Android `domain/` layer is already pure Kotlin, but it is out of scope now.
2. **One repository, two targets.** `ios/` is a sibling of `android/`;
   `appstore/` is a sibling of `fdroid/`. Root documents (`CHANGELOG.md`,
   `README.md`, `LICENSE*`, `PRIVACY.md`, `ROADMAP.md`, this file) are shared and
   phrased platform-neutrally.
3. **"Shared data" means a shared interchange *format*, never live sync.** The
   two platforms interoperate through byte-compatible files a user moves by
   hand — the existing JSON backup (schema v3), the CSV export, and an identical
   SQLite schema. There is **no** cross-device synchronisation, **no** cloud,
   and specifically **no iCloud sync**, because any of those would be network
   activity and would break the project's offline-only, no-network promise (see
   [ROADMAP.md](ROADMAP.md), "Explicitly out of scope"). Each platform stores its
   data locally in its own app sandbox.
4. **License: App Store distribution exception to the GPLv3 (in place).** As the
   sole copyright holder, the maintainer grants an additional permission under
   section 7 allowing distribution through app stores whose terms are
   incompatible with the GPL, so the well-known GPLv3 / App Store incompatibility
   does not block release. Dual licensing was considered and rejected (it would
   either dissolve the copyleft or add a contributor-agreement burden, and there
   is no monetisation goal to justify it). The exception text is now in
   `COPYING.md`; only a final wording review remains (see
   [Licensing](#8-licensing-gplv3-on-the-app-store)).
5. **Single source of truth for the human-readable version.** The marketing
   version (e.g. `0.79.0`) is factored out of `android/app/build.gradle.kts`
   into a shared repository-root file that both the Gradle build and the Xcode
   build read. Per-store build numbers stay independent (Android `versionCode`
   vs. iOS `CFBundleVersion`). Details in
   [Versioning](#6-versioning-and-release-synchronization).
6. **Minimum iOS version: iOS 17.** Chosen over iOS 16 because the pre-iOS-17
   installed base is a small, shrinking tail while iOS 17 unlocks the Observation
   framework (`@Observable`), giving a fresh SwiftUI app a state model close in
   spirit to the existing Compose `ViewModel` / `StateFlow` design. Swift Charts
   (iOS 16+) is available regardless. Hardware floor: iPhone XS (2018) and later.
7. **Device scope and tooling placement.** iOS store-listing assets live under
   `appstore/` (mirroring the role of `fdroid/`); iOS delivery/screenshot
   automation is added as new lanes in the existing `fastlane/` setup and runs on
   the maintainer's Apple-silicon Mac. Device scope is **iPhone-only for the
   first release** (adaptive layouts leave iPad open for later); see
   [Scaffolding decisions](#11-scaffolding-decisions).
8. **Branch and versioning workflow.** Migration proceeds on the `ios` branch.
   `CHANGELOG.md` is **not** touched on the branch, because the repository's own
   tooling (`tools/md-syntax.py`, `tools/release-check.sh`, and the `Makefile`'s
   `VERSION` derivation) requires the top changelog heading to be an exact,
   numeric, descending `## vMAJOR.MINOR.PATCH` that equals the built
   `versionName`. A placeholder there would break those checks. Instead, per-task
   progress is logged in this file under
   [Change log (ios branch, pre-merge)](#12-change-log-ios-branch-pre-merge) with
   a placeholder version, and is collapsed into a single real `## vX.Y.Z`
   changelog entry at merge time, when the release version is known.


## 2. Inherited scope and non-goals

The iOS app is bound by the same principles as the Android app. Restating them
here so no iOS-specific convenience quietly violates them:

- **No network.** No sync, no telemetry, no crash reporting, no remote backend,
  no ad SDKs. This rules out CloudKit/iCloud sync, Firebase, and the like.
- **No accounts / no login.** Local-only, single-user, on-device.
- **No monetisation.** Free and open source; no in-app purchases or paywalls.
- **Minimal permissions.** Only what a feature strictly needs (e.g. Face ID via
  the local-authentication API for the optional app lock). No location, camera,
  microphone, contacts, or background networking.
- **No scope creep.** Alcohol tracking only; not a general health suite.


## 3. Target repository layout

The intended top-level shape once the iOS side exists (only the iOS-relevant
additions are annotated; the Android tree is unchanged):

```
potillus/
├── android/                     # unchanged Android (Kotlin/Compose) app
├── ios/                         # NEW: native Swift/SwiftUI app + Xcode project
│   ├── Potillus/                #   app sources (SwiftUI views, view models)
│   ├── PotillusKit/             #   ported domain math + data layer (Swift pkg)
│   ├── PotillusTests/           #   XCTest unit tests (incl. shared vectors)
│   ├── project.yml              #   XcodeGen spec (reviewable source of truth)
│   └── Potillus.xcodeproj/      #   generated by XcodeGen, git-ignored
├── appstore/                    # NEW: App Store listing assets (mirrors fdroid/)
├── fdroid/                      # unchanged F-Droid recipe/badges snapshot
├── fastlane/                    # extended: existing android lanes + NEW ios lanes
│   └── metadata/
│       ├── android/             #   unchanged
│       └── ios/                 #   NEW: App Store metadata per locale
├── test-vectors/               # NEW: language-neutral golden I/O for parity
├── tools/                       # shared tooling (release-check.sh extended)
├── docs/
│   ├── ROADMAP.md               # links here
│   └── IOS_MIGRATION.md         # this file
├── VERSION                      # NEW: single source of the marketing version
├── CHANGELOG.md                 # shared, one entry per release
└── ...                          # other shared root docs
```

The iOS project uses a Swift package (`PotillusKit`) for the ported domain/data
layer plus an XcodeGen-generated app shell: the YAML spec is the reviewable
source of truth and the `.pbxproj` is git-ignored, which suits a source-first,
review-friendly project. (A checked-in `.xcodeproj` is an acceptable beginner
starting point, switchable to XcodeGen later.)


## 4. Architecture mapping (Android to iOS)

The Android app is clean MVVM in four layers (`data`, `domain`, `ui`, `util`).
Each has a native iOS counterpart:

| Android (current)                             | iOS (planned)                                             | Notes |
|-----------------------------------------------|-----------------------------------------------------------|-------|
| Jetpack Compose + Material 3                  | SwiftUI                                                   | Full UI re-implementation; layouts re-authored, not shared. |
| `ViewModel` + `StateFlow` / `collectAsState`  | `@Observable` model objects + SwiftUI bindings           | iOS 17 Observation framework; one model per screen, as today. |
| Navigation-Compose                            | `NavigationStack` / `NavigationSplitView`                | Same screen set: Today, Calendar, Statistics, Drinks, Add-drink, Settings, Document viewer. |
| Room (SQLite), plaintext since v0.73.0        | GRDB.swift over SQLite (or SQLite.swift)                  | **Identical schema** (tables `drinks`, `entries`; same columns, keys, indices). |
| Room DAOs + repositories (`I*` interfaces)    | Swift repository protocols + implementations             | Mirror the existing interface seams so tests can use fakes, as on Android. |
| DataStore Preferences                         | `UserDefaults` (small, non-secret settings)              | Same setting keys/semantics. |
| Android Keystore (AES-256-GCM envelope)       | Keychain (+ Secure Enclave where applicable)             | Platform-specific; not shared. Only guards the optional lock secret. |
| BiometricPrompt (app lock)                    | `LocalAuthentication` (Face ID / Touch ID)               | Requires `NSFaceIDUsageDescription` in Info.plist. |
| PDF report: HTML template + WebView print     | Same `report_template.html` via `WKWebView` -> PDF       | The HTML template and bundled fonts are reusable; only the print/host code differs. |
| CSV export                                     | Same CSV columns                                          | Byte-compatible with the Android export. |
| JSON backup (schema v3, version-gated)        | Same JSON schema v3 (same reader/writer contract)        | The interchange cornerstone; see below. |
| MediaStore "Downloads" export                 | `UIDocumentPicker` / share sheet                         | iOS has no shared Downloads folder; export UX differs by necessity. |
| Charts via custom Compose `Canvas`            | Swift Charts (and SwiftUI `Canvas` for the year heatmap) | Re-drawn; visual parity is a design goal, not automatic. |
| `res/values-*/strings.xml` (21 locales)       | String Catalog (`.xcstrings`) / `.strings`               | Strings re-keyed; the machine-translation workflow is extended to iOS. |
| `l10n/` date & number formatting              | `Foundation` `DateFormatter` / `NumberFormatter`         | Much of the custom logic maps to Foundation; formats must be matched for parity. |
| Gradle + version catalog, ktlint, kover       | Swift Package Manager, SwiftFormat/SwiftLint, coverage    | Separate toolchains; both gated in the (planned) CI. |
| Fastlane screengrab (screenshots)             | Fastlane `snapshot` (UI-test driven, per device class)   | Separate automation effort; App Store screenshot sizes differ. |


## 5. Shared data contract

Three artefacts define interoperability. They are treated as a versioned
contract; any change to them is a coordinated, cross-platform change.

1. **SQLite schema.** Both platforms use the same tables and columns, so the
   domain logic maps one-to-one and the backup JSON maps cleanly onto rows. The
   shape is pinned by `test-vectors/db-schema.json`, generated from Room's
   authoritative export; Android asserts its export still matches it, and iOS
   introspects the database GRDB actually builds (`PRAGMA table_info`,
   `index_list`, `foreign_key_list`) against the same file.

   **Correction to an earlier assumption:** a database *file* is NOT an
   interchange format between the platforms. Room keeps its own bookkeeping (a
   `room_master_table` holding an identity hash, plus `user_version`), and GRDB
   keeps a `grdb_migrations` table instead; neither would open the other's file.
   Only the JSON backup is a supported interchange path. What "shared schema"
   buys is that the tables mean the same thing on both sides.

   Current shape (schema version 2):
   - `drinks(id, name, volumeMl, alcoholPercent, isPreset, isFavorite,
     category)`
   - `entries(id, drinkId FK, drinkName, volumeMl, alcoholPercent, gramsAlcohol,
     timestampMillis, logicalDate, note)` with indices on `drinkId` and
     `logicalDate`, and an `ON DELETE RESTRICT` foreign key.
2. **JSON backup, schema v3.** Already self-describing and version-gated (the
   importer rejects a `version` greater than it understands). The iOS app reads
   and writes byte-compatible files. This is the primary, privacy-preserving way
   a user carries data between an Android phone and an iPhone. The format also
   tolerates optional fields, so a setting added on one platform restores with a
   default on the other rather than failing.
3. **CSV export.** Same column order and formatting, so a spreadsheet exported on
   one platform reads identically on the other.

Explicitly **not** shared: the Keystore/Keychain-sealed lock secret and the
biometric configuration (re-created per platform). Because the database is
plaintext since v0.73.0, there is no cross-platform database-key problem.


## 6. Versioning and release synchronization

**Goal:** the human-readable version (e.g. `0.79.0`) is identical on both
platforms; the opaque per-store build counters are independent.

- **Marketing version — one source.** Factor the string out of
  `android/app/build.gradle.kts` into a bare-line root file `VERSION` (contents
  e.g. `0.79.0`). Gradle and the `Makefile` read it directly for `versionName`;
  the iOS build reads it via a generated `Version.xcconfig` (`MARKETING_VERSION`)
  for `CFBundleShortVersionString`.
- **Build numbers — independent and monotonic per store.** Android keeps
  `versionCode` (governed by the existing `version-anchor` rule: `versionCode ==
  ANCHOR + releases-after-anchor`). iOS keeps `CFBundleVersion` as its own
  monotonic integer. These are *expected* to diverge; that is normal and
  correct.
- **Changelog — one shared file.** `CHANGELOG.md` remains the single source of
  the `## vX.Y.Z` history for both platforms. Per-store *listing* notes still
  differ (Android's `fastlane/metadata/android/*/changelogs/<versionCode>.txt`
  vs. App Store release notes), and those mirror, not replace, the shared
  changelog.
- **Enforcement.** `tools/release-check.sh` is extended to also assert that the
  iOS `CFBundleShortVersionString` equals the shared `VERSION` and that
  `CFBundleVersion` is monotonic — the iOS analogue of the checks it already runs
  for Android.

**Branch caveat (important).** As noted in decision 8, `CHANGELOG.md` is not
edited on the `ios` branch. The version a merge will carry is unknown until the
merge, so pre-merge work is logged in this file with a placeholder and reconciled
into one real changelog entry at merge time.


## 7. Correctness parity strategy

The health-relevant maths (Widmark BAC, ethanol density 0.789, binge threshold,
daily/weekly/drink-day limits, the traffic-light logic, the rolling seven-day
window, and — critically — the `DayResolver`'s configurable "logical day"
boundary and its timezone handling) must produce **identical** results on both
platforms. A backup exported on Android and imported on iOS has to compute the
same `logicalDate` and the same gram totals, or the shared data contract is
silently broken.

Because the approach is "port, don't share", the guard against drift is a
language-neutral fixture:

- **`test-vectors/`** holds golden input -> expected-output cases as plain data
  (JSON), covering the calculator, bucketing, day resolution across timezones and
  DST edges, and limit-violation counting.
- Vectors are *harvested from the authoritative Android tests*, not invented. A
  vector therefore encodes current behaviour, which is a hazard as well as a
  guarantee: if the Android code has a bug, the vector enshrines it. When Android
  fixes a bug, the vectors must be regenerated and the Swift port re-checked.
  Regression vectors for fixed bugs are added deliberately — see the
  floating-point drift case in `alcohol-calculator.json`, which a strict `>`
  comparison fails and `isOverLimit`'s tolerance passes.
- The Android JVM unit tests and the iOS `XCTest` suite both load these vectors
  and assert against them. Neither platform can change a formula without either
  updating the shared vectors (a visible, reviewable change) or turning its own
  suite red.
- The existing Android domain tests are the natural seed for the vector set.


## 8. Licensing: GPLv3 on the App Store

The GPLv3 has historically been treated as incompatible with the Apple App
Store's terms (the VLC / GNU Go precedent, where the FSF had apps removed): the
store imposes usage and DRM conditions the GPL does not permit a downstream
distributor to add, and GPLv3's anti-Tivoization clause conflicts with a device
that runs only Apple-signed binaries. This is an **Apple-specific** problem:
Google Play and F-Droid do not have it, because Android lets a user install a
self-built, self-signed, modified copy, which satisfies the freedom GPLv3
insists on. The exception below is therefore needed for the App Store **only**;
it is harmless to, and need not be applied for, the Android channels.

### Why an exception, not dual licensing

Since the maintainer is the **sole copyright holder**, the clean, well-trodden
fix is to grant an **additional permission** under GPLv3 section 7 (an "App
Store distribution exception") alongside the GPLv3. Dual licensing (offering the
program under "GPLv3 OR some other licence") was considered and rejected:

- A permissive second arm would let anyone strip the copyleft entirely —
  contrary to the project's deliberate use of GPLv3.
- A proprietary second arm would mean writing and maintaining a whole second
  licence and, because you may only relicense code you wholly own, would force a
  Contributor Licence Agreement / copyright assignment on any outside
  contributor, closing the door to casual GPL patches.
- Dual licensing's real purpose is commercial (selling proprietary licences, or
  embedding as a library in closed products). The project has an explicit
  no-monetisation non-goal and ships an end-user app, not a library, so that
  purpose does not apply.

The additional permission is surgical: it changes exactly one thing (the App
Store distribution channel) and leaves GPLv3-or-later and full copyleft intact
everywhere else. It is the FSF's intended mechanism for exactly this case, and
contributors can simply contribute under "GPLv3 + the same exception" with no
CLA. Lock the exception in **before** accepting third-party contributions;
afterwards, uncovered contributions would constrain the options.

### Where the exception lives (file headers)

A single clear grant by the sole copyright holder binds the work, so the
exception does not strictly need repeating per file. But GPLv3 section 7 lets a
downstream distributor *remove* additional permissions per-copy or per-file, and
a reader who extracts one file should still see that a permission may exist. The
robust convention (as used by the GCC Runtime Library Exception and the OpenJDK
Classpath Exception) is therefore two-fold, and this is what the project does:

1. The **authoritative** exception text lives once in `COPYING.md` (section "App
   Store Distribution Exception"), whence it flows into the generated in-app
   copyright document. There is no separate `LICENSE.exception.md`.
2. Every existing project source header carries a **generic section 7 pointer**
   to it — not the exception text itself, but a forward reference that holds true
   whether or not an exception exists (and one does). It was added uniformly
   across the whole repository (197 files, all four comment styles), so the
   header is identical everywhere and future files — including the iOS Swift
   sources — simply carry the same canonical header. Verbatim/third-party files
   (`LICENSE.md`, `LICENSE.Apache-2.0.md`, `COPYING.md` itself,
   `CODE_OF_CONDUCT.md`, fonts and badges) and the two JSON files (which cannot
   carry a comment header) are excluded. The `.kt` header check still passes: it
   only requires the string "GNU General Public License", which remains present.
   The generic pointer is stripped from the rendered in-app user guide (the
   `.md.in` templates carry it as source, but `render-guide.py` drops the header
   when generating the clean guide text).

### Adopted wording (from the Feeel project, AGPL adapted to GPL)

We adopt the established "app store exception" popularised by the Feeel project
(and used by others, e.g. wger; documented at
`github.com/wger-project/flutter` issue #10), adapting "AGPL" to "GPL". It was
chosen over a bespoke draft because it is community-vetted and carries a
free-channel proviso that keeps the copyleft intact (the source must stay
available under the GPL through a channel without the store's restrictive
terms). The authoritative text lives in `COPYING.md` (section "App Store
Distribution Exception"); there is **no** separate `LICENSE.exception.md`.

The operative grant is:

```
As an additional permission under section 7 of the GNU General Public License,
version 3, you are allowed to distribute the software through an app store, even
if that store has restrictive terms and conditions that are incompatible with
the GPL, provided that the source is also available under the GPL with or
without this permission through a channel without those restrictive terms and
conditions.
```

The **generic pointer** added to every project header (after the "If not, see
<gnu.org/licenses>" paragraph of the standard GPL notice, wrapped to match the
existing header) reads:

```
In addition, as permitted by section 7 of the GNU General Public License,
this program may carry additional permissions; any such permissions that
apply to it are stated in the accompanying COPYING.md file.
```

### iOS dependency licence policy

The exception covers the maintainer's *own* GPLv3 code; it cannot cover
third-party copyleft, which the maintainer has no authority to re-permit. So the
binary shipped on the App Store must contain no foreign copyleft:

- Prefer permissive licences for iOS dependencies (MIT / BSD / Apache-2.0 / SIL
  OFL). GRDB.swift — the project's first and so far only iOS dependency — is MIT,
  has no transitive dependencies, performs no network access, and ships no
  telemetry. It must be added to `COPYING.md` before the first App Store
  submission.
- **No GPL/AGPL** in the shipped iOS binary.
- **Avoid LGPL too**, not just GPL: LGPL requires that the end user be able to
  relink/replace the library, which iOS's static, signed, sandboxed model
  effectively prevents — the classic "LGPL on iOS" trap. Permissive licences
  sidestep the question entirely.
- Fonts bundled into the binary (e.g. for the PDF report) under SIL OFL 1.1 or
  Apache-2.0 (Roboto) explicitly permit embedding — fine.

For reference, the current **Android** inventory (`COPYING.md`) is already
App-Store-clean on its merits: everything compiled into the APK is Apache-2.0
except `desugar_jdk_libs`, which is GPL-2.0 **with the Classpath Exception** that
defuses the copyleft — and none of it ships in the iOS binary anyway. The one
non-free licence present (the "JSON License" on `org.json`) is build/test-only
and never redistributed.

**Done.** The exception text is in `COPYING.md`, and the generic section 7
pointer is in every project header (197 files). **Remaining before the first App
Store submission:** a final review of the exact exception wording; the iOS Swift
sources will inherit the same canonical header as they are created.


## 9. Anticipated challenges and risks

- **Signing single-point-of-failure.** The maintainer already self-signs for
  F-Droid (reproducible build; F-Droid verifies and ships the maintainer's
  signature), so a single signing key is *already* a continuity risk. The App
  Store adds a second, Apple-account-bound distribution certificate. Neither
  offers F-Droid-style reproducible re-signing. This intersects the roadmap's
  `access_continuity` / bus-factor items and should be reflected in
  `docs/GOVERNANCE.md`.
- **Maintenance surface doubles the platform work.** A second platform roughly
  doubles UI, localisation, screenshot, and release effort for a single
  maintainer — a real bus-factor concern already flagged in the roadmap.
- **Feature-parity effort concentrated in a few places:** the year heatmap and
  charts (re-drawn in Swift Charts / `Canvas`), the localisation re-keying across
  21 locales plus extending the translation workflow, and the export UX (no
  shared Downloads on iOS).
- **Timezone / logical-day correctness** is the subtlest data-integrity trap;
  it is the first and most important target for the shared test vectors.
- **App Store review specifics.** Even a free, offline app must complete the
  paid/free agreements, export-compliance (encryption) questionnaire — the app
  uses only standard platform crypto (Keychain), which normally qualifies for the
  exemption but must still be declared — and the privacy "nutrition label"
  (expected: "Data Not Collected", matching PRIVACY.md).
- **Screenshot automation** on iOS is a separate build-out (fastlane `snapshot`
  on simulators, fixed device sizes) rather than a reuse of the Android
  screengrab pipeline.


## 10. Phased roadmap (milestones)

Indicative ordering; refined as work starts.

1. **Scaffolding (done).** `ios/` project (XcodeGen app shell + `PotillusKit`
   Swift package with a runnable placeholder SwiftUI screen), `test-vectors/` and
   `appstore/` stubs. Verified on macOS: the app runs in the simulator and
   `swift test` runs the package suite natively. Still to add: a CI skeleton for
   the Swift toolchain.
2. **Domain port + parity (done).** `AlcoholCalculator`, `DayResolver`,
   `ChartBucketing` and `Trend` are ported, with both suites green against the
   shared vectors — including `isOverLimit`'s floating-point tolerance, and the
   timezone- and DST-safe calendar arithmetic the logical day, the seven-day
   window and the chart buckets depend on. Not ported by design: the
   `clockOverride` screenshot seam and the locale-driven `firstDayOfWeekIso`,
   which are platform concerns and return with the iOS UI.
3. **Data layer (done).** The schema, the GRDB record types, the repositories
   behind protocol seams, the JSON backup v3 reader/writer, the CSV export, the
   encrypted preferences store and the backup importer are all in place, with both
   platforms asserting against shared vectors. Compatibility is demonstrated, not
   asserted: the iOS suite parses AND imports `fastlane/demo-backup.json`, a
   genuine Android-written backup already in the repository, and gets back its 15
   drinks and 85 entries with no orphans. Nothing is deferred any more.
4. **UI (in progress).** The app shell — composition root, tab bar, theming,
   startup-failure path — is in place, with placeholder screens. SwiftUI screens to feature parity (Today, Calendar, Statistics,
   Drinks, Add-drink, Settings, Document viewer), app lock via
   `LocalAuthentication`, PDF report via `WKWebView` reusing the HTML template.
5. **Localisation.** Port 21 locales to String Catalogs; extend the translation
   workflow; match date/number formatting for parity.
6. **Versioning + release plumbing.** Shared `VERSION`, `release-check.sh`
   extension, `appstore/` metadata, fastlane iOS lanes, screenshots.
7. **Licensing + store prep.** App Store distribution exception; privacy label;
   export-compliance; TestFlight.
8. **Merge to `main`.** Assign the real release version, write the single
   `CHANGELOG.md` entry, submit to the App Store.


## 11. Scaffolding decisions

These were the open questions before scaffolding; all are now resolved:

- **Device scope: iPhone-only for the first release.** The SwiftUI views are
  written adaptively so iPad (universal) can be added later without a rewrite.
  This keeps the initial layout, testing, and screenshot surface minimal.
- **Project generation: a Swift package (`PotillusKit`) for the ported
  domain/data layer, plus an XcodeGen-generated app shell.** The YAML spec is the
  reviewable source of truth and the `.pbxproj` is git-ignored. A checked-in
  `.xcodeproj` is an acceptable beginner starting point, switchable to XcodeGen
  later. (Tuist was considered but is heavier and cloud/caching-oriented —
  overkill here.)
- **SQLite library: GRDB.swift** (MIT, actively maintained, Room-like
  `DatabaseMigrator`, `Codable` records, and change observation). It lets both
  platforms share the identical SQLite schema; Core Data / SwiftData were
  rejected because their opaque store cannot guarantee that shared schema.
- **Version single-source: a bare-line root `VERSION` file** (contents e.g.
  `0.79.0`). Gradle and the `Makefile` read it directly; the iOS build generates
  a `Version.xcconfig` (`MARKETING_VERSION`) from it; `release-check.sh` asserts
  `VERSION` equals the top `CHANGELOG.md` heading, the Android `versionName`, and
  the iOS marketing version. Per-store build numbers (`versionCode` /
  `CFBundleVersion`) stay independent.


## 12. Change log (ios branch, pre-merge)

Per-task work log for the `ios` branch. The version is a **placeholder** until
the branch is merged to `main`; at merge these entries collapse into a single
real `## vX.Y.Z` entry in the root `CHANGELOG.md`. Entries are newest-first;
each keeps the imperative subject line of its patch.

The series was rebased onto the 0.81.0 development tree after the branch's
0.79.0 base went stale; the archived pre-rebase work is equivalent in content.

### vX.Y.Z-ios (unreleased placeholder)

#### Port the template engine, pinned by shared vectors  (patch -51)

First piece of the PDF report. `Template` is the Swift counterpart of Android's
`SimpleTemplate`: scalar `{{KEY}}` placeholders and `<!-- repeat:NAME -->` blocks,
nothing more. Both fill `report/report_template.html`, so both must agree
character for character.

- Add `test-vectors/template-render.json`, 20 cases, read by BOTH suites — Swift's
  `TemplateTests` and Kotlin's new `TemplateVectorTest`. Until now the Kotlin
  engine had no vector test at all; its behaviour was whatever it happened to do.
- Two subtleties the vectors pin, because both are easy to get wrong and neither
  is obvious from the code:
  - The document pass runs over the WHOLE expanded text, so a `{{Y}}` that arrives
    as a ROW VALUE is itself substituted if `scalars` knows `Y`. The first draft of
    the vectors claimed the opposite; the reference implementation caught it.
  - A row value shadows a document scalar of the same name, but only inside its
    block.
- `\w` MEANS DIFFERENT THINGS. Kotlin's `\w` on the JVM is ASCII `[a-zA-Z0-9_]`;
  `NSRegularExpression` follows ICU, where `\w` matches `Ö` as well. Left as `\w`
  on both sides, `{{TÖTAL}}` would be substituted on iOS and left verbatim on
  Android. `Template` writes the class out. This cannot be a shared vector —
  Android's own two regex engines disagree, JVM in unit tests and ICU on a device
  — so a Swift test states it instead.
- `replaceMatches` is written by hand rather than with
  `stringByReplacingMatches(in:withTemplate:)`, which reads `$1` in the REPLACEMENT
  as a back-reference. A drink named `$1` would interpolate itself. Kotlin's
  replacement lambda does no such thing, so neither may this; two tests hold it
  there.
- The result is built forward, slice by slice, not by mutating the input. A
  `String.Index` belongs to the string it came from, and carrying indices of the
  original into a partially rewritten copy is reading a map of a city that has
  since been rebuilt. The first draft did exactly that.
- Two tests read the REAL template: one asserts that every repeat block collapses
  to nothing when handed no rows (or the PDF would show an HTML comment), and one
  asserts that the template declares exactly the ten blocks the renderer knows —
  so a new block cannot be added without someone noticing.

Both linters ran before delivery: ktlint over the new Kotlin test, SwiftLint
`--strict` over the Swift.

#### Lint the Swift the way ktlint lints the Kotlin  (patch -50)

SwiftLint ships a portable Linux binary that needs no Swift toolchain, so Swift
style is checkable wherever the Swift is written — not only on a Mac. Out of the
box it found 110 things and was wrong about most of them.

- Add `ios/.swiftlint.yml`, the counterpart to `android/.editorconfig`. Every rule
  switched off carries its reason, because an unexplained exception is not a
  decision, it is a problem in hiding:
  - `static_over_final_class` — all seven hits are `override class func setUp()`,
    XCTestCase's own signature. `static` means `final class` and cannot be
    overridden. The rule does not recognise `override`.
  - `trailing_comma` — house style, as on the Kotlin side: adding an element
    touches one line, not two.
  - `function_parameter_count` — `calculateBAC` takes seven parameters because
    Android's does. Packing them into a struct for a lint rule would break the
    correspondence the port exists to preserve.
  - `identifier_name` excludes `db`, `to`, `up`, `id`. 42 of the 58 hits were
    `db`, which is GRDB's own idiom, and 15 were the `to:` of `inRange(from:to:)`.
  - `file_length` ignores comment-only lines. These files are mostly prose
    explaining the arithmetic; counting it against a budget rewards deleting it.
- Fix the ten findings that survived, all of them real:
  - `Data("[1,2,3]".utf8)` rather than `try XCTUnwrap(...data(using: .utf8))`. The
    conversion cannot fail, so there was never anything to unwrap.
  - Two 175- and 129-character strings in `SettingsScreen` split across lines,
    then verified by concatenation that not one character of the sentences moved.
  - A doubled blank line, a 122-character filter, and four closure parameters
    that belonged on the brace line.
- Run it from `make ios` as `check-swiftlint`, PINNED to 0.65.0 and `--strict`.
  SwiftLint changes rules between releases, and the Kotlin side gets version
  pinning free through its Gradle plugin; Swift has no such mechanism, so the
  Makefile checks. `--strict` because a warning nobody must act on is a warning
  nobody reads. Required rather than optional, because a target that skips itself
  when its tool is missing reports success for work it never did.
- Install with `brew install swiftlint`.

#### Format the Kotlin tests as ktlint demands  (patch -49)

- 36 `argument-list-wrapping` violations across the five Kotlin vector tests, plus
  2 `spacing-between-declarations-with-comments` from the comment block patch -48
  added. Once an argument list is multi-line, ktlint wants EVERY argument on its
  own line; the vector tests packed two or three per line and had done so since the
  day they were written. Nothing had ever checked them.
- Corrected with `ktlint --format` at the version the project pins, then verified
  by hand: every string literal survived byte for byte, and each file holds exactly
  as many non-whitespace characters as before. A formatter may change style; it may
  never change meaning.
- The whole Android module is now silent under ktlint, main and test alike.

NOTE FOR FUTURE SESSIONS: ktlint runs perfectly well without Gradle and without a
build — a single self-contained jar and a JVM. It reproduced the failure exactly,
36 + 2, before a line was changed. Kotlin style is therefore checkable in the same
place the Kotlin is written, and there is no excuse for shipping it unchecked.

#### Lift the report template above both platforms  (patch -48)

Groundwork for the PDF export. The report's layout is about to become a contract
between two platforms, so it stops belonging to one of them.

- Move `android/app/src/main/assets/report_template.html` to
  `report/report_template.html`. Its placeholders and repeat blocks are what the
  Android builder and the coming iOS renderer must agree on; one copy means a
  layout fix is made once, and the two cannot silently drift apart.
- Register the directory as a MAIN assets source in `app/build.gradle.kts`, using
  the `assets.directories` DSL already used for the androidTest schemas. The
  merged asset root is unchanged, so `context.assets.open("report_template.html")`
  needs no edit — the runtime lookup does not know the file moved.
- Point `PdfTemplatePlaceholderTest` and `PdfReportLangTest` at the new path. Both
  read the template as a FILE rather than an asset, so both had to follow it.
- Fix the comments in `SimpleTemplate` and `PdfReportBuilder` that named the old
  location. A comment that describes a path the file no longer occupies is not
  stale documentation, it is a false statement.

`report/` sits beside `test-vectors/`, and for the same reason: what both
platforms must agree on belongs to neither of them.

#### Give xcodebuild a destination  (patch -47)

- `make ios` invoked `xcodebuild -target Potillus -sdk iphonesimulator`, which
  names no destination. xcodebuild could not compute an active architecture, so it
  honoured `ARCHS` in full and built arm64 AND x86_64 — while the Swift package's
  GRDB module was resolved for one slice only. The build died with

      error: Unable to resolve module dependency: 'GRDB'

  which reads like a missing dependency and is really a missing destination. The
  `ONLY_ACTIVE_ARCH=YES ... no active architecture could be computed` warning
  standing above it was the actual diagnosis.
- Build `-scheme Potillus -destination 'generic/platform=iOS Simulator'` instead.
  The generic destination fixes one architecture without naming a simulator
  device, so the build does not depend on which runtimes are installed. The
  `Potillus` scheme was already declared in `ios/project.yml`; nothing was added
  to it.

#### Stop a bare `cd` from leaking through the ios recipe  (patch -46)

- `make ios` ran `cd ios/PotillusKit && swift test` and then invoked `xcodebuild`
  with a path relative to the repository root. Under `.ONESHELL` the whole recipe
  is ONE shell, so the `cd` moved every line below it: 256 tests passed, and then
  xcodebuild reported that `ios/Potillus.xcodeproj` does not exist — a working
  directory error wearing the costume of a missing file. Wrapped in a subshell.
- The `screenshots` target already knew this and says so beside its own
  `cd fastlane`. The knowledge was in the file; the discipline was missing. So it
  is now a check rather than a comment.
- Add `tools/check-makefile.py`: under `.ONESHELL`, a recipe line starting with
  `cd ` must be the last line of its recipe or be wrapped in parentheses. Recipes
  end at target boundaries — make starts a fresh shell per target — so a trailing
  `cd` cannot leak, and `ios-project` was never affected. Verified by
  reintroducing the fault, watching it fire, and removing it again.

#### Stop SettingsModel lying about its own state  (patch -45)

- `SettingsModel.update` wrote to the store and left its own `settings` stale.
  The field was refreshed ONLY by the observation loop, so between a write and the
  store's next emission the model reported the value the caller ASKED for rather
  than the one that was kept: a weight of 9999 kg read as set while the store held
  500, and a stepper could bounce back under the user's thumb. A model that never
  called `start()` — a test, or a screen not yet visible — would never learn the
  truth at all.
- `update` now reads the value back. `settings` therefore means "what is stored",
  which is the only definition the sanitiser leaves room for: the store may
  legitimately keep something other than what was asked for.
- Found by two failing tests, and the tests were right. They asserted `hasWeight`
  and `hasStatsFloor` after a write without starting observation — exactly the
  state that exposed the defect. The regression test now says so in its name and
  omits `start()` deliberately, because observation would mask it.
- Checked the other models for the same gap. `TodayModel` and `CalendarModel`
  reload after every write; `DrinksModel` leans on GRDB's database observation,
  which emits on commit. The defect was unique to the one model whose store is a
  file rather than a database.

#### Catch by machine what review kept missing  (patch -44)

Three compile errors reached the repository in four patches, all from the same
root: Swift is written here on a machine that cannot build it. All three are
mechanical, and none needed a Mac to find.

- Add `tools/check-swift-symbols.py`, checking two things it can be RIGHT about:
  - A NEAR-MISS TYPE. `Backup.parse` where no `Backup` exists but `BackupReader`,
    `BackupWriter` and `BackupFile` do. Shortening a real family of types into one
    that never existed is what memory does to a name.
  - A MISSING IMPORT. `UTType` without UniformTypeIdentifiers, `BarMark` without
    Charts, `@Observable` without Observation.
- The first attempt at the symbol check verified that `Type.member` named a
  declared member. It was worthless twice over: it MISSED the very bug it was
  written for, because `Backup` is not a declared type and undeclared types were
  exactly what it skipped; and it raised twenty false alarms, because
  `Drink.filter` and `Entry.order` come from GRDB's protocols and `allCases` from
  CaseIterable. A linter that misses the real fault and cries wolf about the rest
  gets switched off, and then finds nothing ever again. The rule was inverted.
- The near-miss rule then assumed no Apple type could be a prefix of one of ours.
  `Calendar` and `CalendarModel` disproved that within a minute. The exceptions
  are named in `EXTERNAL_TYPES`, where a missing entry costs a false alarm rather
  than a missed bug — the failure mode points the right way.
- Make `check-swift-tests.py` walk the FILE SYSTEM instead of `git ls-files`. It
  passed silently over untracked files, which is the state every new file is in
  while it is being written, and is how patch -39 shipped uncompilable tests.
- Run both from `make ios`, before `xcodegen` and long before `swift test`. A grep
  costs milliseconds; the build costs minutes.

Each check was validated by reintroducing the real bug it exists for and watching
it fire, then removing it and watching the tree fall silent. A linter nobody has
seen fail is a linter nobody has tested.

#### Fix an invented type name shipped in patch -40  (patch -43)

- `BackupExporter`, its tests, and `SettingsScreen` called `Backup.parse` and
  `Backup.makeJSON`. No type `Backup` exists: the file declares `BackupReader` and
  `BackupWriter`, and every older caller spells them correctly. Nine call sites in
  three files, all from patch -40, all written from memory of a file that had been
  read weeks earlier.
- Cross-checked afterwards that every kit symbol the new app and exporter code
  names does exist and is public. It does — this was the only invention.

#### Add CSV export, and fix a missing import from patch -40  (patch -42)

- Wire `CsvExporter` — long since ported and tested — to a button in the
  Statistics toolbar. It exports the VISIBLE period, so what the user gets is what
  the screen shows.
- Filter the range in SQLite, over the index on `logicalDate`, rather than loading
  the whole log and filtering in memory. The same choice Android's `exportCsv`
  makes, for the same reason.
- Refuse an empty export, as Android does. A file containing nothing but a header
  looks like a broken export, not an empty period.
- Copy Android's file name, `potillus_export_yyyyMMdd_HHmm.csv`, and its column
  captions, underscores included, so a spreadsheet built against one platform's
  export opens against the other's.
- Name the captions `englishHeaderCells` rather than `headerCells`. Android
  localises them and iOS has no string catalogue yet; the English set is the
  CURRENT truth, not a placeholder to be quietly forgotten. `buildCsv` keeps taking
  them as a parameter, so localisation will not touch the exporter.
- `SettingsScreen` used `.json` as a `UTType` without importing
  `UniformTypeIdentifiers`, which does not compile. Shipped in patch -40 and found
  by auditing every file that names a content type, rather than only the one being
  written.

#### Give the root Makefile a per-platform entry point  (patch -41)

- Add `make ios`, the counterpart of `make android`. It depends on `ios-project`,
  so the Xcode project is REGENERATED before anything compiles. `project.yml`
  collects the app's sources with a directory glob that XcodeGen resolves once and
  freezes into the `.xcodeproj`; a file added afterwards is invisible to the app
  target, and the build fails with "Cannot find X in scope" — a compile error that
  looks like a code error and is not one. Making it a prerequisite means it cannot
  recur. `ios/PotillusKit/` never had the problem, because SwiftPM rereads its
  directory every build, which is why the mistake only ever surfaced in the app.
- Run the cheap checks first: `check-headers` and `check-swift-tests` cost
  milliseconds and should not wait behind a Swift build that costs minutes.
- Rename `debug` to `android`. In a repository that builds two platforms, `make
  debug` no longer says which one. `debug` survives as a shim that prints the new
  name and forwards, rather than greeting years of muscle memory with "No rule to
  make target".
- Make `help` the default goal, and let it print nothing but the target list. A
  bare `make` should not silently pick one of two platforms.
- Generate that help from the "TARGETS AT A GLANCE" comment block at the top of
  the file, by stripping the leading `#`. A help text kept separately from the
  comment it paraphrases will one day describe a target that no longer exists.
- Note in `check-swift-tests`'s comment that it walks `git ls-files`, so untracked
  files are skipped. That gap is what let patch -39 ship uncompilable tests.

#### Add backup export and import  (patch -40)

- Add `BackupExporter`, the missing half of the backup path: `Backup.makeJSON`
  could already write a `BackupFile`, and nothing assembled one from the live
  stores. The test that matters is the round trip — what the exporter writes, the
  importer reads back into an identical database.
- Export the PRESETS too. The importer recreates them, so omitting them looks
  harmless, until a user has renamed or re-categorised one and the edit is lost.
- Omit the `settings` KEY entirely when the user excludes settings, rather than
  emitting defaults. An absent key means "leave mine alone"; a defaulted one would
  overwrite the recipient's with someone else's. A test checks the key is absent,
  not null, and that a recipient keeps their own body weight.
- Copy Android's file name exactly — `potillus_backup_yyyyMMdd_HHmm.json`,
  underscores and all — so a user with both phones finds their backups sorted
  together. The stamp is LOCAL time, while `exportedAt` inside the file is UTC;
  that is Android's split, and it is right: the file lives among the user's
  documents, and they look for "the backup from Friday evening".
- Present the system document browser through `.fileExporter` / `.fileImporter`.
  The app never touches the file system, asks for no permissions, and the user
  decides where their data goes — or that it goes nowhere.
- Open the imported URL inside `startAccessingSecurityScopedResource`. It comes
  from outside the sandbox; forgetting this is the classic import that works in
  the simulator and fails on a device.
- Ask whether to merge or replace AFTER the file is chosen and BEFORE anything is
  written, and say plainly what replacing deletes.
- Assemble the export before presenting the browser, so a failure is an alert
  rather than an empty file the user has already saved.

#### Fix uncompilable assertions shipped in patch -39  (patch -40)

- `SettingsModelTests` awaited inside `XCTAssert` autoclosures in seven places,
  which does not compile. `tools/check-swift-tests.py` exists to catch exactly
  this and reported nothing, because it walks `git ls-files`: a `git apply`
  without `--index` leaves new files untracked, and untracked files were silently
  skipped. The verification, not only the test, was at fault. Awaited values are
  now bound to a `let` first.

#### Add the Settings screen  (patch -39)

- Add `SettingsModel` and `SettingsScreen`: limits, day-change time, body weight,
  statistics floor, theme, language, alternative status symbols. Reached from a
  gear in the Today toolbar, as on Android, where settings sit above the tabs.
- Make the `SettingsSanitizer` bounds PUBLIC, and drive every control from them.
  A stepper offering 1…600 while the sanitiser clamps at 500 would let the user
  set a value the app silently discards — the same divergence that made Android's
  Save button lie until v0.81.0.
- Add `sanitize(AppSettings)` beside `sanitize(BackupSettings)`. A settings screen
  can hand over an out-of-range number as easily as a backup can. The two
  overloads share every clamping helper and repeat only a field list; a test
  asserts they agree on every field, and a second that sanitising is idempotent.
- Route every control through `SettingsModel.update`, which sanitises the WHOLE
  value before it reaches the store. Clamping is defined over the value, and a
  caller cannot know which other field a change invalidates. The store's invariant
  then holds for any future writer, not just for today's views.
- Offer absence as absence. A missing body weight is a button, not a stepper
  showing `0.0 kg`, and clearing it is its own operation, so no view has to know
  that a magic zero means "not set".
- Reload the Today screen when the settings sheet closes: the day-change hour
  decides which day is "today", and the screen would otherwise show yesterday.
- Do NOT offer `biometricEnabled` or `allowScreenshots`. Both are stored and
  ported, and nothing reads them yet. A switch that promises a lock which does not
  exist is worse than a missing switch.
- Label the language picker with each locale's autonym: someone who needs the list
  cannot necessarily read the current interface language.

#### Add the Statistics screen  (patch -38)

- Add `StatsScreen`: period picker, consumption chart, limit violations, streaks,
  category breakdown, time-of-day and weekday profiles. Every number arrives from
  `StatsModel`; the view computes nothing.
- Respect three absences rather than flattening them to zero:
  - `hasBaseline == false` hides the trend row. The stats floor cut into the
    current period, so there is nothing to compare against, and "0 %" would claim
    there was.
  - A weekday whose average is nil is OMITTED from its chart. That weekday never
    fell in the period, which is not a dry weekday.
  - An empty category breakdown draws no section, rather than an empty pie.
- Colour an abstinent chart bucket green. Its bar has zero height and would
  otherwise be indistinguishable from missing data.
- Colour a rising trend RED and a falling one green. Down is the good direction
  here, and the default green-for-up would congratulate the user for drinking
  more.
- Use named `Identifiable` structs for the chart points instead of tuples: `Chart`
  and `ForEach` want identity, and a key path into a tuple element is not a
  promise worth leaning on.
- Delete `PlaceholderScreen`. Every tab is now a real screen, and dead scaffolding
  outlives its usefulness quickly.

#### Fix two wrong expectations in the statistics tests  (patch -37)

- The suite's `log()` helper built its timestamp by adding `hour` to
  `DayResolver.parseDate(date)`, which anchors a day at NOON rather than midnight
  — deliberately, so that adding whole days survives a DST transition. A "20:00"
  entry therefore landed at 08:00 the next morning, and the time-of-day histogram
  reported an empty bucket. The model was right; the helper subtracts the twelve
  hours now, and a comment says why they are there.
- `testTheFloorAlsoAppliesToStreaks` expected fifteen dry days between 1 and 15
  January. `computeCurrentAbstinence` excludes TODAY, because the day is not over
  and a drink may still be logged: fourteen COMPLETED dry days. The vectors and
  Android agree; the expectation was wrong.

#### Add the statistics model  (patch -36)

- Add `StatsWindows`, the period arithmetic, as a pure type. Week is a rolling
  seven days against the seven before; month and year run from their first day and
  compare against the WHOLE previous month or year. The lengths differ on purpose:
  the trend compares grams per day, so a half-finished January is still comparable
  to a complete December. Boundaries — the first of a month, 1 January, a leap
  February — are tested against independently computed dates.
- Model the `statsFromDate` floor as raising the start of BOTH windows, and make
  its third case explicit. A floor inside the CURRENT period leaves the baseline
  inverted, which means "there is no comparable history", not "the baseline was
  zero". `StatsState.hasBaseline` carries that distinction to the view, so a
  trend of 0 % is never mistaken for "no change".
- Compare the floor by STRING. That works only because `yyyy-MM-dd` sorts
  chronologically, which is why the schema stores dates that way; a test says so.
- Add `StatsModel`, which computes nothing. The window comes from `StatsWindows`,
  the aggregations from `StatsAggregator`, the violations from `AlcoholCalculator`,
  the streaks from `DayResolver`, the chart from `ChartBucketing`. It fetches,
  delegates, and assembles — which is all a view model should do, and is exactly
  what Android's `StatsViewModel` does not.
- Compute the streaks over the whole history above the floor, not over the period:
  a dry streak that began in December is still a streak in January.
- Add a one-shot `allDates()` to the entry repository, sharing the query of
  `observeAllDates` so a streak cannot be computed over a different set of days
  than the chart draws.
- Leave the CSV and PDF exports for their own patches.

#### Fix the calendar tests, and test what caught them  (patch -35)

- `CalendarModelTests` inserted entries with a hard-coded `drinkId` of 1 and never
  created that drink, so seven tests failed on the foreign key. The constraint was
  right and the test was wrong: every entry references a drink. The suite now adds
  a real drink in `setUp` and uses its row id.
- Add the test that would have caught this: an entry referencing a drink that does
  not exist must be REFUSED, and nothing may be stored. Only the other direction
  of the same foreign key was covered — deleting a referenced drink — so the
  insert side went unguarded until a broken test discovered it.

#### Port the statistics aggregations  (patch -34)

- Add `StatsAggregator`: the category breakdown, the time-of-day histogram, the
  weekday profile, and the trend percentage. On Android these live inside
  `StatsViewModel`, where nothing tests them. Ported as pure functions, for the
  reason the drink-day gate was extracted: an unnamed calculation buried in a view
  model is one nobody can check and everybody will copy.
- Bucket the histogram by WALL-CLOCK hour while the day totals follow the LOGICAL
  date. A drink at 01:00 counts towards the previous day and still happened at one
  in the morning; the histogram answers "when do I drink", not "on which day does
  it count". The two clocks are deliberate and now carry a test.
- Divide each of the eight buckets by the period's length, not by the days it
  appears on, so the bars sum to the overall average grams per day. A bucket that
  is empty on most days should look small.
- Average the weekday profile over DAILY SUMMARIES rather than entries: a day with
  six beers counts once, as a day. Android's PDF does the same, and screen and
  report must not disagree.
- Keep a weekday column with no days at all `nil`, not `0.0`. "No Tuesdays in this
  period" and "Tuesdays were dry" are different statements, and a bar chart must
  draw both.
- Mirror an asymmetry rather than smooth it over: `trendPercent` compares the RAW
  averages, while `Trend.of` rounds both to one decimal first. A rise from 10.00
  to 10.04 g/day therefore reports +0.4 % beside a FLAT arrow. Android behaves
  identically; the arrow is meant to be less twitchy than the number. A test pins
  it, because it reads like a bug.
- Assert that `StatsAggregator.weekdayOrder` equals `MonthGrid`'s, across all seven
  first-days. If they ever drift, the calendar and the profile label different
  columns.

#### Add the Calendar screen  (patch -33)

- Add `MonthGrid`, the calendar's arithmetic, as a pure tested type rather than a
  view helper. This is where calendars go wrong: a leading-blank count off by one
  puts every date under the wrong weekday, nothing crashes, and the bug is
  invisible in any month that happens to begin in the first column. Tested against
  months chosen for their first weekday, in Monday-first and Sunday-first locales.
- Add `DayResolver.firstDayOfWeekIso()`, the counterpart of Kotlin's
  `WeekFields.of(locale).firstDayOfWeek.value`. Two numbering schemes meet here:
  `Calendar.firstWeekday` counts 1 = SUNDAY, ISO counts 1 = MONDAY. Sunday is 1 in
  one and 7 in the other, and every other day is off by one. The conversion is the
  reason the function exists instead of a bare `Calendar.current.firstWeekday` at
  the call site.
- Navigate months with INTEGER arithmetic, never dates: December to January cannot
  then go wrong, and no DST transition can shift the grid relative to the entries
  it displays. A cell is a logical day — the string the entries carry.
- Keep a day with no entries ABSENT from the summary map rather than present with
  zero, so the view can distinguish "nothing logged" from "logged nothing". The
  cell shows no dot at all.
- Clear the selection when navigating away: a selection belongs to the month it
  was made in, or January's entries appear under a February heading.
- Defer the YEAR view. It is a second layout over the same summaries, and it
  belongs with the Statistics screen, which already owns per-month aggregation.

#### Make it possible to log a drink  (patch -32)

- Patch -31 shipped a Drinks screen on which a row tap opened the EDITOR, and a
  Today screen with no way to add anything. Both were wrong. Tapping a drink now
  LOGS it — the action a user performs several times a day — and a pencil opens
  the editor, which is the rare one. Android splits them the same way.
- Add the Today screen's primary action. Android uses a floating action button;
  iOS puts the primary action in the toolbar. Same action, native placement.
- Add `EntryLogger`, so both screens produce identical entries. `gramsAlcohol` and
  `logicalDate` are DERIVED there and can never be supplied by a view: a view that
  could pass its own would eventually pass a wrong one, and a drink logged at
  02:00 would stop counting towards the evening it belongs to.
- Pre-select the drink of the most recent entry, as Android does. People repeat
  what they just had, not what they had most often. This needed a one-shot
  `lastEntry()` on the entry repository.
- Reuse `DrinkValidator.volumeMlRange` for the entry's volume: the serving size an
  entry may record is the serving size a drink may have, and a fifth copy of
  "1...5000" would be a fifth chance to disagree.
- Make `DrinkDefinition` `Hashable`, which SwiftUI's `Picker` needs to tag its
  options by value. Every stored property already is, so it is synthesised.

#### Add the Drinks screen  (patch -31)

- Add `DrinksModel` and `DrinksScreen`: the catalogue, a favourite toggle, an
  add/edit sheet, and swipe-to-delete.
- Let the Save button ask `DrinkValidator` the same question the model will ask,
  so it cannot offer to save what the model then rejects. The editor NAMES the
  offending field rather than greying out Save in silence, and the sheet stays
  open when a write is refused.
- Guard deletion instead of attempting it. `entries.drinkId` references
  `drinks.id` with ON DELETE RESTRICT, so deleting a used drink fails at the
  database; relying on that would show a SQLite error code. The model counts the
  entries first and reports "Pils is used by 23 entries". The constraint remains
  the real guarantee — between the count and the delete an entry could still be
  logged, and then the database refuses. The guard improves the message, it does
  not replace the constraint.
- Validate `update` and the favourite toggle, both of which take the same path as
  `add`. Android's `updateDrink` trusted its caller until v0.81.0, while the
  favourite toggle was already a second caller.
- Store the trimmed name via `DrinkValidator.canonicalName`, the helper that
  measured it. Validating one string and persisting another is how a
  101-character name reaches the table.
- Omit `deinit` on the `@MainActor` model. A `deinit` is nonisolated, and reaching
  into isolated state from there is a rule that has shifted between Swift
  versions; the observation task holds `self` weakly and the view calls `stop()`.
- Restore the newest-first order of this list: patch -30's entry was filed below
  patch -29's.

#### Correct the whitespace claim the vectors refuted  (patch -30)

- Patch -29 asserted that Kotlin's `trim()` keeps the non-breaking spaces,
  because Java's `Character.isWhitespace` excludes them, and "corrected" the Swift
  port to match. The shared vectors then failed on the JVM, which is what they are
  for. Kotlin's `Char.isWhitespace()` is
  `Character.isWhitespace(c) || Character.isSpaceChar(c)`, and `isSpaceChar`
  covers the whole Zs category — so U+00A0 IS trimmed, exactly as Swift's
  `.whitespacesAndNewlines` trims it. The custom trimming set is removed.
- Keep the UTF-16 length correction from -29: that divergence is real, and the
  emoji vector passed on both sides.
- Regenerate the vectors and turn both suites' assertions around, so the file now
  records what the platforms do rather than what the author believed.
- Check finiteness BEFORE the range test, as Kotlin does. `(0.0...100.0).contains(.nan)`
  is false and happens to reject it, but a hand-written `!(percent > 100)` would
  not, and a NaN reaching `SUM(gramsAlcohol)` poisons every total after it.

#### Port the drink validator, with shared bounds  (patch -29)

- Port `DrinkValidator`, added to Android in v0.81.0 after its rules were found
  to exist twice with two different answers. Add
  `test-vectors/drink-validation.json`, whose `bounds` block is GENERATED from the
  Kotlin source and asserted by both suites: a fourth copy of these numbers
  cannot now drift unnoticed.
- Correct two string semantics that look identical across the languages and are
  not. Kotlin is the authority, because a drink Android accepts must be accepted
  here:
  - `String.length` counts UTF-16 CODE UNITS; Swift's `String.count` counts
    grapheme clusters. A name of 51 beer emojis is 102 units (rejected) and 51
    characters (accepted). The Swift port measures `utf16.count`.
  Pinned by vectors and by tests on each side, since it would never surface as a
  bug report — the user would simply find a name rejected on one of their devices.

#### Silence a real warning, not the compiler  (patch -28)

- `TodayModel.addEntry` fed `entries.add`, which returns the new row id, into a
  `Void` closure and dropped the value. Discard it explicitly with `_ =` rather
  than annotating the protocol with `@discardableResult`: the row id is real
  information, and a caller that does not want it should have to say so.
- Drop the pointless `_ =` in `perform`, whose closure returns `Void`.

#### Add the limit bars to the Today screen  (patch -27)

- Add `LimitGauge` in the kit: the rules a progress bar needs, extracted so they
  can be tested. The SwiftUI `LimitBar` maps `Emphasis` onto a colour and does
  nothing else — a colour chosen in a view would be a rule nobody could test.
- Separate the two fractions. The bar's FILL is clamped to `0...1`, or a 130 %
  day would draw past its track; the COLOUR comes from the UNCLAMPED value, so
  the overflow still reads as red. Conflating them either breaks the layout or
  hides the violation.
- Colour the drink-day bar by the same gate `AlcoholCalculator.trafficLight`
  already uses, rather than the simpler `days > max`:

      pastDrinkDays = drinkDaysThisWeek - (todayIsDrinkDay ? 1 : 0)
      if pastDrinkDays >= maxDrinkDaysPerWeek -> red

  Both the bar and the dot answer "may I drink now?", and a full drink-day bar
  does not settle it. At 5/5 with today already a drink day, another drink adds
  no further day: amber. At 5/5 with today still dry, the first drink spends a
  day the user does not have: red. The bar looks identical; the answer does not.
- A test walks the whole `days x maxDays x todayIsDrinkDay` grid asserting the bar
  and the dot agree, so the two cannot drift apart.

#### Add the Today screen  (patch -26)

- Add `Clock`, so "now" is injected rather than read from a global. The Today
  screen needs the instant twice — to pick the logical day, and to age the
  blood-alcohol estimate — and a test for "the day flips at 04:00" cannot wait
  until 4am. This is also where Android's `clockOverride` screenshot seam will
  land, as another `Clock` at the composition root, with no mutable global.
- Add `TodayModel` in the KIT, not the app target: that is where the arithmetic
  is, and the app target is not covered by `swift test`. `TodayScreen` decides
  where things sit and computes nothing.
- Keep `bacPermille` OPTIONAL, and render it as absent rather than zero. Nil
  means "we cannot know" — no body weight, or nothing alcoholic logged. Showing
  0.00 permille would assert a sobriety the app cannot vouch for.
- Derive an entry's grams and logical date inside the model. A view that could
  pass its own would eventually pass a wrong one, and a drink logged at 02:00
  would stop counting towards the evening it belongs to.
- Add one-shot `dailySummaries(from:to:)` and `allOnce()` to the repositories,
  each sharing the query of its observing twin. The summary SQL now exists once:
  two copies would eventually disagree about what a day's total is. `allOnce()`
  repeats the stream's ordering (favourites first, then name) so a screen cannot
  reshuffle its list by switching between snapshot and stream.
- Defer `monthlyAvgPerDay`, `monthTrend`, `weeklyRangeLabel` and
  `currentMonthLabel`. Each is a formatted, locale-dependent string or a statistic
  the Statistics screen owns; porting them now would mean inventing a date format
  before the String Catalogs exist, and inventing it twice.

#### Use a calendar symbol for the Today tab  (patch -25)

- Replace `sun.max` with `calendar.badge.clock`. The sun was wrong: in Apple's
  own apps that symbol means weather or screen brightness, so in a tab bar it
  reads as a different feature. A tab symbol depicts the content, not a mood.
- Android pairs `Today` (a calendar sheet with the day marked) against
  `CalendarMonth` (a month grid) — the two differ by day versus month, not by
  metaphor. SF Symbols has no sheet with an inner day marker, because Apple
  places badges outside the glyph, so `calendar.badge.clock` is the closest
  reading: the same family as its neighbour, with the "now" sense, still legible
  at tab-bar size.
- Record why no `.fill` variant is named: SwiftUI picks the filled form for tab
  items on iOS and the outlined one on macOS on its own.

#### Lint for await inside XCTAssert autoclosures  (patch -24)

- Fix a third `await`-in-autoclosure compile error, in `AppEnvironmentTests`.
  The same mistake was made in patch -20, fixed in -21, and made again in -23.
- Add `tools/check-swift-tests.py` and `make check-swift-tests` rather than
  resolving to remember. `XCTAssert*` takes autoclosures, which are synchronous,
  so an awaited value must be bound to a `let` first; a grep catches that in a
  second, while the compiler only reports it after a full build — on a Mac, which
  is not always to hand. Comment text mentioning `await` is not a false positive.

#### Add the SwiftUI app shell  (patch -23)

- Add `AppEnvironment`, the composition root: one place that chooses the concrete
  database, repositories and preferences store, and hands protocols to everything
  downstream. It lives in the kit, not the app target, because the app target is
  not covered by `swift test` — the wiring itself is worth testing, and an
  ephemeral variant (in-memory database, temporary preferences file, ephemeral
  key) serves previews and screenshot runs without touching the file system.
- Add `AppDatabase.makeDefault()` alongside the existing preferences one, placing
  the database in Application Support rather than Documents: it is app-managed
  state, not a user-visible document. The user's export path is the JSON backup.
- Add the app shell: a `TabView` over the same four sections Android has, in the
  same order — Today, Calendar, Statistics, Drinks. The information architecture
  is shared; the presentation is not. Compose puts labelled icons in a bottom
  NavigationBar, SwiftUI uses a tab bar. Porting Material 3 onto iOS would make
  the app feel foreign to its users and conspicuous to App Review. The rule for
  the rest of this port: identical behaviour, native idiom.
- Apply `themeMode` through `preferredColorScheme`, with `.system` mapped to
  `nil` — SwiftUI's "do not override". Reading the device setting directly would
  ignore the user's in-app choice, the exact trap Android's `Color.kt` documents.
  The setting is observed, so a change applies without a restart.
- Handle a failed launch honestly. Opening the database runs migrations and the
  Keychain can refuse; a crash at launch is the worst possible bug report ("it
  just closes"). The failure is caught and displayed with a selectable error the
  user can quote. The app does NOT delete and recreate the database: that trades
  a visible failure for silent data loss.
- Use `.tabItem` rather than the `Tab { }` builder, which is iOS 18 while this app
  supports iOS 17. They render identically here.

#### Apply a restored backup, settings included  (patch -22)

- Add `BackupImporter`, the counterpart to Android's
  `BackupRepository.importReplace/importMerge`, and close the gap left open in
  patch -12: the `settings` block is now applied, not merely carried through.
- Remap drink ids rather than trust them. A backup's `drinkId` values are row ids
  from the device that WROTE it; on the importing device they belong to different
  drinks, or none. Copying them across would silently re-attribute history — an
  entry logged as "Pils" reappearing as "Whisky". The join is made on the drink
  NAME, the only identifier that means the same thing on both devices.
- Mirror both modes: REPLACE wipes the log and user-created drinks (presets
  survive, so an old entry can always resolve its drink); MERGE keeps what is
  there and skips entries identified by timestamp plus drink, so importing the
  same file twice cannot double the history.
- Move drinks and entries inside ONE write transaction. A backup whose entry
  references a drink the file never defines is internally inconsistent: the
  import aborts and the transaction rolls back, because a half-imported history
  is worse than none — the user cannot tell which half is missing.
- Sanitise restored settings before storing them, and `replace` rather than merge:
  the file describes a complete settings state, and mixing it with the local one
  would produce a state neither device ever had. Settings are applied outside the
  data transaction, since they live in a different store and a settings failure
  must not roll back a good import.
- End-to-end proof: parse and import the real Android demo backup, and get back
  exactly 15 drinks, 85 entries, and no orphaned rows.

#### Fix two await-in-autoclosure compile errors  (patch -21)

- `XCTAssert*` takes its arguments as autoclosures, which are synchronous, so an
  `await` cannot appear inside one. Two assertions in `PreferencesStoreTests`
  did. Hoist the awaits into named values, which also makes a failure report name
  the case that broke rather than the line.

#### Add the encrypted preferences store  (patch -20)

- Add `PreferencesStore`, the counterpart to Android's encrypted DataStore, and
  refuse the easy option. `UserDefaults` writes a plist that is plain text
  whenever the device is unlocked and is copied into unencrypted Finder backups.
  The app stores body weight and alcohol limits, and PRIVACY.md makes its promise
  without qualifying it by platform: an unencrypted iOS store would have been a
  silent downgrade at the platform boundary.
- Use the same on-disk format as Android: `[12-byte nonce] || [AES-256-GCM
  ciphertext] || [16-byte tag]`, which is exactly CryptoKit's
  `SealedBox.combined`. A fresh nonce per write, and an authentication tag that
  turns a flipped bit into a detected forgery rather than a changed limit.
- Keep the AES key in the Keychain as `WhenUnlockedThisDeviceOnly`: unreadable
  while the phone is locked, and excluded from every backup. The consequence is
  deliberate — restoring a device backup brings the encrypted file but not the
  key — so the store treats an undecryptable file exactly like a missing one and
  returns the canonical defaults. Key loss is a normal event, not a crash; the
  user's real settings travel in the JSON backup, which is the supported path.
- Inject the key behind `SecretKeyProviding`. The Keychain is unreachable from a
  plain `swift test` process, which has no keychain entitlement; injecting the
  key lets the tests exercise the shipping crypto against a temporary file.
- Test what matters rather than what is easy: no field value appears in the bytes
  on disk; two saves of identical settings differ; a tampered tag falls back to
  defaults; a wrong key falls back to defaults; the store still writes afterwards;
  and an atomic write leaves no temporary file behind.
- Expose changes as `AsyncStream`, the shape the repositories already use, so a
  SwiftUI view consumes settings and drinks identically. Registration happens
  inside the actor via `makeStream()`; the older `AsyncStream { ... }` builder
  runs its closure outside actor isolation, and touching the observer table from
  there is a data race the Swift 6 mode rejects.

#### Port the backup settings sanitiser  (patch -19)

- Extend the Swift `AppSettings` from the calculator's three-field slice to the
  full twelve-field model, and add `ThemeMode` and `SupportedLocales`.
- Add `test-vectors/backup-settings.json`: 24 clamping cases harvested from
  `BackupManager.parseSettings`, plus the 21-tag locale catalogue GENERATED from
  `l10n/SupportedLocales.kt`. Both suites assert the catalogue, so a language
  added on one platform cannot be quietly forgotten on the other — the failure
  mode would be a restored `language` silently degrading to "follow the system",
  which no user would ever report as a bug.
- Port the clamping. A backup is plain JSON in the user's Files app: editable,
  truncatable, possibly written by a newer app. Its numbers flow straight into
  the alcohol maths, so every value is range-checked at the boundary and each
  screen downstream can treat `AppSettings` as sound.
- Two rules that look like bugs and are not, now documented and tested on both
  sides: `weightKg == 0` is the "not set" SENTINEL and must never be clamped up
  to the 1 kg floor, or a restore invents a one-kilogram body; and
  `statsFromDate` survives only if it round-trips through the canonical
  formatter, so "2026-1-1" and the non-existent "2026-02-30" both become blank
  rather than mis-bucketing every statistic.
- No Android change was needed after all: `parseBackupJson` is already
  `internal` + `@VisibleForTesting`, so the JVM vector test drives the real
  restore path — the reader's defaulting AND the clamping — exactly as iOS does.

#### Check only the files the repository tracks  (patch -18)

- Fix `tools/check-headers.py`, which walked the file system and therefore
  reported on files the project does not own: the vendored Ruby gems under
  `fastlane/.vendor/`, a developer's local `android/keystore.properties`, and
  scratch output — several hundred warnings, and one spurious ERROR for the
  keystore file, which is generated from the tracked `.example` and predates the
  section 7 pointer.
- Take the file list from `git ls-files` instead. "The project owns it" and "the
  repository tracks it" are the same statement, and `.gitignore` already records
  it; reimplementing its matching rules would only let the two disagree.
- Keep a fallback for a tree that is not a git checkout (an exported tarball):
  walk, skipping dot-directories as well as `SKIP_DIRS`. Best effort, and the
  reason the git list is preferred.
- Exempt `fastlane/metadata/android/screenshots.html`, which is tracked but
  written by fastlane screengrab. It surfaced once the directory-pruning of the
  old walk no longer hid it.

#### Add a make target for the Xcode project  (patch -17)

- Add `make ios-project`, which regenerates `Version.xcconfig` and then runs
  `xcodegen generate` in `ios/`. The prerequisite enforces the ordering; getting
  it wrong surfaces only as a wrong version number in a shipped build.
- Fix the build instructions in `ios/README.md`, which put the `cd ios` BEFORE
  `gmake ios-version`. That cannot work: the Makefile lives in the repository
  root, while `xcodegen` resolves `project.yml` relative to the working
  directory. The two commands run from different places.
- Declare the targets added in patches -06, -16 and here in `.PHONY`, where they
  were missing. Without it, a file named `check-headers` or `ios-project` in the
  tree would silently disable the target.
- Document how to VERIFY the version actually took effect: ask
  `xcodebuild -showBuildSettings`, not the Xcode UI, which shows the unexpanded
  `$(MARKETING_VERSION)` placeholder for a generated project and so proves
  nothing either way.

#### Derive the iOS version from the changelog  (patch -16)

- Replace the `0.0.0` placeholder in `ios/project.yml` with a generated
  `Version.xcconfig`: `MARKETING_VERSION` comes from the top `## vX.Y.Z` entry of
  `CHANGELOG.md`, `CURRENT_PROJECT_VERSION` from the Android `versionCode`. Both
  stores then report the same version and the same build number.
- Derive rather than introduce. The earlier plan was a root `VERSION` file that
  the Android build, the Makefile and `release-check.sh` would all read. That
  would have rewritten the one number the release pipeline is built on, for no
  gain on the Android side, where `release-check.sh` SECTION 1 already ties
  `versionName`, README.md and CHANGELOG.md together. The changelog was already
  the single source of truth; iOS now reads it too.
- Keep the generated file git-ignored, so a stale copy can never contradict its
  own sources, and add `make ios-version` / `make ios-version-check` — the second
  suitable as a release gate.
- Note the trap in `project.yml`: a value in `settings` overrides an xcconfig, so
  `MARKETING_VERSION` must NOT be set there or the generator is silently defeated.

#### Record GRDB in COPYING.md  (patch -15)

- Add a "Third-Party Software (bundled in the iOS application)" section to
  `COPYING.md` recording GRDB.swift (MIT, Copyright 2015-2025 Gwendal Roué),
  parallel to the existing APK section rather than hidden inside it. Note that
  MIT is GPL-3.0 compatible, so the combined work stays distributable.
- Note the outstanding obligation: the iOS about screen must reproduce the MIT
  licence text before release, as the Android one already does. Recording the
  dependency in this file is necessary but not sufficient.
- `ios/PotillusKit/Package.resolved` pins the resolved GRDB revision and is
  committed, so a build is reproducible from the repository alone. It was never
  git-ignored; this only makes the intent explicit.

#### Port the CSV export to Swift  (patch -14)

- Add `test-vectors/csv-export.json`: 15 escaping cases and 6 complete CSV
  documents, harvested from `CsvExporterTest.kt` and `CsvExporterBuildTest.kt`.
  The documents carry their CRLF endings, so a divergence in quoting, ordering
  or number formatting turns one side red.
- Port the Android-free core of `CsvExporter`. Byte-identical output requires
  four details to line up: CRLF after every record INCLUDING the last (RFC 4180
  §2); a '.' decimal separator in the grams column, whatever the locale, since a
  comma would split the value across two columns; escaped column headers, because
  a translator's comma would misalign every row; and the OWASP formula-injection
  guard that prefixes `= + - @ TAB CR` with a single quote, since the file exists
  to be shared and the recipient's spreadsheet would be the victim.
- Mirror the asymmetry deliberately: only free text (headers, drink name, note)
  is escaped, while generated cells (dates, times, category, numbers) are not.
  "Escaping everything for safety" would produce a different document.
- Make the time zone an explicit parameter rather than reading a global. Android
  calls `ZoneId.systemDefault()` inside `buildCsv`, so the JVM vector test pins
  the default zone and restores it; the Swift port takes the zone as an argument.
  Same behaviour in the app, but the shared vectors can now assert a clock time —
  the same instant reads 20:14 in Berlin and 14:14 in New York.
- Keep the UTF-8 BOM out of `buildCsv`, as Android does: it is a property of the
  file (so Excel detects the encoding), not of the document.

#### Clear the Swift 6 concurrency warnings  (patch -13)

- Fix six `#SendableClosureCaptures` warnings in `SchemaParityTests`: a `Drink`
  or `Entry` was declared outside the write closure and mutated inside it. GRDB's
  `write` takes a `@Sendable` closure, so that is a data race, and an error in
  the Swift 6 language mode rather than a warning.
- Create and mutate the record inside the closure, returning only the assigned
  row id (or the finished value), so mutable state never crosses the isolation
  boundary. The production repositories already used this shape; only the tests
  had drifted.

#### Port the JSON backup format to Swift  (patch -12)

- Port Android's `BackupManager` reader/writer. This is the project's single
  most important interoperability surface: the JSON backup is the only supported
  way a user carries their history between an Android phone and an iPhone.
- Prove compatibility against the real artefact rather than a hand-written
  sample: the suite parses `fastlane/demo-backup.json`, a genuine format 2
  backup the Android app wrote and the repository already ships as the
  screenshot fixture — 15 drinks, 85 entries, no settings block.
- Mirror the compatibility rules exactly: required fields strict, optional and
  newer fields defaulted (a format 1 drink with no `category` restores as
  OTHER), unknown keys ignored, and a file from a newer app REJECTED rather than
  read with unknown fields silently dropped.
- Restore the numeric leniency `org.json` has and `JSONSerialization` lacks: an
  ABV written as `5` rather than `5.0` must still read as a Double, or a backup
  would fail to cross the platform boundary in one direction.
- Reject a malformed `logicalDate` at the door; it would otherwise silently
  mis-bucket every statistic built on it.
- Write with sorted keys, so an export is deterministic and a diff of two
  backups shows only real changes.
- Carry the `settings` block through unchanged without applying it: on Android
  the settings live in an encrypted DataStore, and iOS has no preferences store
  yet. An iOS export therefore omits the key, exactly as a format 1/2 file does,
  and an Android import leaves the local preferences untouched — the behaviour a
  pre-v3 backup already produces.

#### Declare NOT NULL on the iOS primary keys  (patch -11)

- Fix the schema-parity failure the contract caught on its first real run: Room
  declares `id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL`, while GRDB's
  `autoIncrementedPrimaryKey` omits the `NOT NULL`. Both behave identically — an
  INTEGER PRIMARY KEY is a rowid alias and can never be NULL, and inserting a
  NULL id still lets SQLite assign the next value — but `PRAGMA table_info` only
  reports a column as NOT NULL when the constraint was *declared*. The two
  schemas therefore differed on paper. iOS now declares it too.
- This is exactly what the shared schema contract exists for: a difference that
  no behavioural test would have surfaced, found mechanically on both sides.

#### Add iOS repositories behind protocol seams  (patch -10)

- Port `DrinkDefinition`, `ConsumptionEntry` and `DrinkCategory` to the Swift
  domain, with the same "stored by name, unknown decays to OTHER" rule that
  CONTRIBUTING.md section 4 mandates for enum persistence.
- Add `EntityMapping`, the single place where a persistence detail (an optional
  row id, a category stored as text) becomes a domain value and back, so the
  domain layer never learns that SQLite exists.
- Add `DrinkRepositoryProtocol` / `EntryRepositoryProtocol` and their GRDB
  implementations, mirroring Android's `IDrinkRepository` / `IEntryRepository`
  operation for operation. Each query documents the Room DAO statement it is the
  twin of, including the ordering guarantees callers depend on: favourites first
  then alphabetical; entries oldest-first within a logical day; "most recent"
  ordered by consumption time, not insertion order.
- Bridge GRDB's `ValueObservation` into `AsyncThrowingStream` rather than
  publishing the library type through the protocol. Exposing
  `AsyncValueObservation` would have defeated the seam — every caller would
  import GRDB. The bridging happens in one helper, and cancelling the consuming
  task tears the observation down.
- Test against a real in-memory database rather than a mock: the failures worth
  catching (a wrong `ORDER BY`, an unenforced foreign key) only appear against
  SQLite itself. Covers ordering, inclusive range bounds, the MERGE-import
  de-duplication guard, `ON DELETE RESTRICT`, preset survival, unknown-category
  decay, and that an observation re-emits after a committed write.

#### Add the iOS data layer schema with GRDB  (patch -09)

- Add GRDB (MIT) as the first iOS dependency, the counterpart to Room: typed
  records, a migrator, and change observation over plain SQLite. Chosen over raw
  `SQLite3` because migrations and observation are exactly the infrastructure
  that is dangerous to hand-roll in an app whose database is the user's only
  copy of their history.
- Add `test-vectors/db-schema.json`, generated from Android's authoritative Room
  export, and assert against it from BOTH sides: Android checks its export still
  matches, iOS builds a real in-memory database and introspects it with
  `PRAGMA table_info`, `index_list` and `foreign_key_list`. Introspection rather
  than DDL-string comparison, because Room and GRDB spell the same table
  differently.
- Add `Drink` and `Entry` GRDB records mirroring the Room entities, and
  `AppDatabase` with a migrator that builds the version 2 shape: AUTOINCREMENT
  primary keys, the two `entries` indices, and the `ON DELETE RESTRICT` foreign
  key. Behavioural tests assert the schema actually protects the data — deleting
  a referenced drink is refused, freed row ids are never reused.
- Correct the shared-data-contract section: a database *file* is not an
  interchange format (Room and GRDB keep incompatible bookkeeping tables). The
  JSON backup is. The shared schema means the tables mean the same thing, not
  that the files are swappable.

#### Port ChartBucketing and Trend to Swift  (patch -08)

- Add `test-vectors/chart-bucketing.json`: 27 golden cases harvested from
  `ChartBucketingTest.kt` and `TrendTest.kt`, covering trend classification, the
  granularity thresholds, month-boundary snapping, period clamping, a leap
  February, and both consequences of the in-progress day.
- Port `ChartBucketing` and `Trend` to Swift, completing the domain layer. Month
  buckets snap to the first of the next month, buckets are clamped to the period
  end, and calendar arithmetic runs on a UTC-pinned calendar so a device time
  zone or DST transition can never shift a bar.
- Assert both suites against the vectors, and add structural tests: buckets tile
  the period contiguously without gaps, duplicates, or overlaps at every
  granularity; an inverted range is empty rather than an error; a leap February
  averages over 29 days; and the bucket holding the in-progress day is never
  marked abstinent.

#### Document the GNU Make requirement on macOS  (patch -07)

- Record that the `Makefile` needs GNU Make 4.x: macOS ships 3.81, where a `#`
  ends the line as a comment even inside `$(shell ...)`, so the `VERSION`
  assignment (which greps `CHANGELOG.md` for `'^## v'`) aborts with
  "unterminated call to function `shell'". Use `gmake`. Note that the iOS
  workflow never needs the `Makefile`, and that the checker script runs directly.

#### Add a header checker and licence the WCAG doc  (patch -06)

- Add `tools/check-headers.py`, a dependency-free checker in the style of
  `md-syntax.py`. It fails on a stale header (GPL notice present, section 7
  pointer missing) and warns on a file that carries no header at all, keeping
  the two cases apart because only the first has a mechanical fix. `--fix`
  inserts the pointer after the anchor line, reusing that file's own comment
  leader, so one routine is correct for every comment style; the repair is a
  byte-exact round trip, verified across block, line, hash and HTML comments.
- Wire it up as `make check-headers` / `make fix-headers` and document both in
  CONTRIBUTING.md. This removes the manual step that would otherwise recur every
  time the long-running `ios` branch merges a tree that has grown new files.
- Add the canonical header to `docs/WCAG_LEVEL_A_CHECKLIST.md`, which was
  created without one — the first file the new checker found.
- Fix a dangling reference introduced in patch -01: CONTRIBUTING.md section 2
  pointed at a "file-header convention in Section 4" that had failed to apply
  against the newer tree, so the section itself was missing. It is now present.

#### Port DayResolver to Swift with shared vectors  (patch -05)

- Add `test-vectors/day-resolver.json`: 48 golden cases for the logical-day
  boundary, effective period length, and the abstinence streaks, harvested from
  `DayResolverTest.kt`. The `resolve` cases carry an absolute instant plus an
  IANA zone and cover both DST edges and cross-timezone instants.
- Port `DayResolver` to Swift, mirroring the `assert` postconditions. Document
  why this is the riskiest port: the logical day decides which day every entry
  belongs to, so a one-day divergence would silently corrupt every downstream
  figure. The zone stays an explicit parameter rather than an ambient global,
  wall-clock readings are resolved through the zone so DST is handled by
  Foundation, and date-string arithmetic is pinned to a UTC calendar at noon.
- Pin the date formatter to `en_US_POSIX`, so a device locale can never
  substitute an alternate calendar (a naive formatter prints Buddhist-era years
  on a Thai device, corrupting every stored `logicalDate`).
- Assert both suites against the vectors, and add structural tests for
  round-tripping, malformed input, locale independence, and non-negative streaks.
- Not ported by design: `clockOverride`/`clock()`/`today()` (a screenshot test
  seam) and `firstDayOfWeekIso` (a locale-driven visual detail); both are
  platform concerns that return with the iOS UI.

#### Port AlcoholCalculator to Swift with shared vectors  (patch -04)

- Add `test-vectors/alcohol-calculator.json`: 45 golden input/output cases
  harvested from the authoritative Android `AlcoholCalculatorTest.kt`, covering
  gram conversion, Widmark BAC, limit fractions, `isOverLimit`, the traffic-light
  gate, and the rolling seven-day violation counts.
- Port `AlcoholCalculator` and its domain models to Swift, including
  `isOverLimit`'s 1e-6 tolerance and the `assert` postconditions. Document the
  rounding trap: Kotlin rounds halves toward +infinity, Swift away from zero;
  they coincide here because every rounded value is non-negative.
- Add a regression vector for the floating-point drift the tolerance fixes
  (44.5 + 80.9 + 65.2 sums to 190.60000000000002 against a 190.6 g limit), plus
  explicit tests on both platforms proving a strict `>` would fail it and that
  the tolerance cannot absorb the smallest real (0.1 g) exceedance.
- Add the `TestVectors` loaders and parity suites on both sides — the Swift one
  derives the repository root from `#filePath` (SwiftPM cannot bundle resources
  outside a target), the JVM one reuses the existing `org.json` test dependency
  and the `potillus.project.dir` convention, so no new dependency, no SBOM entry,
  and no change to the reproducible release build. This closes the parity loop:
  a formula changed on one platform alone now turns the other red.

#### Document iOS migration strategy and licence  (patch -01)

- Add `docs/IOS_MIGRATION.md` recording the agreed native-Swift strategy:
  repository layout (`ios/`, `appstore/`), architecture mapping, the shared data
  contract (JSON backup v3, CSV, identical SQLite schema — an interchange format,
  never live sync), version synchronisation, correctness parity via shared test
  vectors, the GPLv3 App Store distribution exception, risks, and a phased
  roadmap. Link it from `docs/ROADMAP.md`.
- Add the "App Store Distribution Exception" to `COPYING.md`, adopting the Feeel
  project's community-vetted wording (AGPL adapted to GPL), whose free-channel
  proviso keeps the copyleft intact. Dual licensing was considered and rejected.
- Document the canonical file header in `CONTRIBUTING.md`, including the generic
  section 7 pointer, and cross-reference it from the licensing checklist.
