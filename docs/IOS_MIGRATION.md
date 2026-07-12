<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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

#### Add screenshots-ios capture recipe  (patch -107)

Replaces the `screenshots-ios` stub (patch -99) with the real recipe, now that the
capture app hooks (-100), the UI-test target (-103), the navigation and appearance
fixes (-104, -105) all run green on the Mac. Run from the repo root on the Mac, it
pre-flights the Homebrew tools (putting them on the minimal PATH a non-interactive
`ssh mini` gets), materializes the git-ignored fastlane SnapshotHelper on first run,
regenerates the Xcode project, drives the `ios screenshots` lane for pages 01–06,
then rasterizes the per-locale PDF report the app wrote during capture into pages
07–08 with pdftoppm — pulled from the simulator's Documents container via
`simctl get_app_container`, exactly as screenshots-pdf-android does. Report pages
carry the same `<device>-` filename prefix fastlane gives 01–06 so they sort after
06. `IOS_SIM_DEVICE` (default "iPhone 17 Pro") must match fastlane/Snapfile.

The whole set is then one command: `ssh mini 'cd … && make screenshots-ios'`.

Makefile only; verified by check-makefile in the container and a full run on the Mac.

#### Split Statistics tab label from heading  (patch -106)

The French Statistics screen showed the heading "Stats". That abbreviation was only
ever meant for the bottom tab bar, where the full "Statistiques" would wrap under the
icon — the iOS port had folded both uses onto a single `Statistics` key, so shortening
the tab shortened the title too. Android already avoids this with two resources
(`statistics` for the title, `nav_statistics` for the tab), which the iOS port had not
replicated; this restores that split.

`Statistics` is now the full word in every language (French corrected to
"Statistiques") and stays on the screen title. A new `nav_statistics` key carries the
tab label, its values mirroring Android's — identical to the full word everywhere
except French "Stats". RootView's tab reads it through a new `Loc.string(key:english:)`
overload, needed because the key (`nav_statistics`) is not its own English text.

Audit: across the four tab words (Today, Calendar, Statistics, Drinks) French
"Stats" was the sole abbreviation on either platform; no other language or tab needed
changing, and Android was already correct and is untouched.

App and localization only; verified by the container l10n checks and a Mac build.

#### Pin status-bar clock, dark-mode shots 3-6  (patch -105)

Two finishes on the now-working capture, both matching the Android set.

CLOCK: `override_status_bar(true)` alone renders the status-bar time from an
ISO-8601 timestamp in the host time zone, so in CET/CEST it reads 10:41/11:41, not
Apple's canonical 9:41. The Snapfile now also sets `override_status_bar_arguments`
with a bare `--time 9:41` (no date, no zone) — the documented, timezone-immune fix —
and restates snapshot's own signal/battery defaults.

DARK MODE: screens 03–06 are now captured in dark mode (01–02 stay light), the same
split as Android. `ScreenshotMode.forcedColorScheme` returns `.dark` when the app is
launched with `-screenshotDark`, and RootView prefers it over the in-app theme; a
normal build passes nil and is unchanged. The UI test shoots 01–02, then relaunches
with `-screenshotDark` (screenshot mode re-seeds identically every launch, so this
stays deterministic) and shoots 03–06.

App and UI-test code, verified only by a full Xcode build + capture run on the Mac.

#### Navigate screenshot tabs by index  (patch -104)

The first `fastlane ios screenshots` run built cleanly and captured `01_today`,
then failed at `tab.calendar`: `No matches found for "tab.calendar" IN
identifiers`. SwiftUI does not forward a view's `accessibilityIdentifier` onto its
tab-bar button, so the `tab.*` identifiers added in patch -100 never reached the
buttons the UI test tapped. The test now addresses the tab bar by position
(`buttons.element(boundBy:)`, order matching RootView's TabView) — locale-
independent and free of the propagation problem. The toolbar buttons keep their
working `nav.settings` / `nav.addDrink` identifiers (those sit on real `Button`s,
which do propagate). The now-unused `tab.*` identifiers are left in place: harmless,
and ready should a future SwiftUI forward them.

#### Add PotillusUITests screenshot target  (patch -103)

The capture half of the automated App Store screenshots — a UI-test target that
drives the app through the six screens, wired into the project. The Makefile recipe
that orchestrates it (report pages 07/08, rasterization) follows in patch -104.

WHAT LANDS:
  - `ios/PotillusUITests/PotillusUITests.swift`: one XCUITest that fastlane snapshot
    runs once per locale. It launches the app in `-screenshotMode` (patch -100),
    hands it the demo fixture as `SCREENSHOT_FIXTURE_JSON` and the store locale as
    `SCREENSHOT_LOCALE`, waits for the seed, and snapshots 01_today … 06_settings —
    navigating by accessibilityIdentifier, never by localized label, and dismissing
    sheets with a swipe, so the one path holds across all 21 store locales.
  - `project.yml`: a `PotillusUITests` UI-testing target (with the demo fixture as a
    bundle resource and `TEST_TARGET_NAME: Potillus`) and the matching
    `PotillusUITests` scheme the Snapfile already names.
  - `fastlane/Snapfile`: the capture device set to the installed `iPhone 17 Pro`.
  - `.gitignore`: fastlane's `SnapshotHelper.swift`, which `make screenshots-ios`
    materializes from the installed fastlane (version-matched, never vendored).

VERIFY ON THE MAC (before the recipe exists): materialize the helper once with
`cd ios/PotillusUITests && fastlane snapshot init && rm -f SnapfileExample Snapfile`,
then `make ios-project` and `cd fastlane && bundle exec fastlane ios screenshots`.
The six PNGs per locale should appear under fastlane/screenshots/ios/<locale>/.

This is UI-test and project code, verified only by a full Xcode build on the Mac.

#### Fix StatsScreen body length after clock arg  (patch -102)

`StatsScreen`'s struct body sat exactly at SwiftLint's `type_body_length` limit of
250 lines, so the single `clock: environment.clock` argument added to the
`StatsModel` construction in patch -100 pushed it to 251 and failed
`swiftlint --strict`. The argument is folded onto the preceding `preferences:` line
— net zero lines, and the same one-line style `CalendarScreen` already uses for its
model construction — restoring the body to 250. No behaviour change.

#### Harden l10n check against missing localizations  (patch -101)

`tools/check-l10n.py` crashed with `KeyError: 'localizations'` on any String
Catalog entry that carries no `localizations` key — a legitimate state Xcode
produces (an entry marked `shouldTranslate: false`, or a freshly harvested key it
has not localized yet). The plural-placeholder check now reads the key defensively
(`entry.get("localizations", {})`) and treats such an entry as "no plurals to
check" instead of aborting the whole `make -C ios` run.

Found while verifying patch -100 on the Mac: the check is run before the build, so
its crash blocked compilation even though it is unrelated to the Swift changes
(the committed catalogue is well-formed; the missing key came from a locally
Xcode-modified catalogue). No translation coverage is hidden — parity is a
separate check, and this one only compares plural placeholders, which an entry
without localizations does not have.

#### Add iOS screenshot-mode app hooks  (patch -100)

The app side of the automated App Store screenshot capture — the deterministic
state a UI test needs, and the report pages it cannot reach through the UI. Split
from the test target and Makefile recipe, which follow in patch -101. Everything
here is gated on the `-screenshotMode` launch argument, so a normal build is
untouched.

WHAT LANDS:
  - `ScreenshotMode` (new, app target): on a `-screenshotMode` launch it builds an
    EPHEMERAL, clock-pinned environment — `AppEnvironment.makeEphemeral` with a
    `FixedClock` frozen at 2026-06-30 (matching the Makefile's SCREENSHOT_DATE and
    the demo fixture's range) — seeds it from the demo backup passed as JSON via
    the `SCREENSHOT_FIXTURE_JSON` environment variable (`BackupReader.parse` +
    `importer.restore(.replace)`), and renders the two report pages 07/08 to a PDF
    programmatically (no "Save as PDF" dialog, unlike the manual Android step),
    writing `screenshot_report_<locale>.pdf` into the app's Documents directory
    for the fastlane recipe to pull out.
  - `AppEnvironment` (kit): gains an injected `clock` (default `SystemClock`), so
    the pin reaches the models through the existing composition root rather than a
    global. The `Clock.swift` seam the domain reserved for exactly this is now used.
  - `TodayScreen`, `StatsScreen`, `CalendarScreen`: pass `environment.clock` into
    their models, so "today" follows the pinned clock in a screenshot run.
  - `RootView` + `TodayScreen`: stable `accessibilityIdentifier`s on the four tabs
    (`tab.today` …) and the Settings and add-drink toolbar buttons (`nav.settings`,
    `nav.addDrink`), so the UI test navigates by identifier, not by localized label
    — a hard requirement across the 21 store locales.

CONTRACT with patch -101 (the UI-test target and recipe):
  `-screenshotMode` launch argument enables the mode; `SCREENSHOT_FIXTURE_JSON`
  carries the demo backup; `SCREENSHOT_LOCALE` names the store locale for the report
  file. The app writes the report PDF; the recipe rasterizes it to pages 07/08.

This is app-target code, verified only by a full Xcode build on the Mac.

#### Split asset make targets by platform  (patch -99)

The root Makefile's store-asset and release targets were named as if the project
had one platform. With the iOS port they now carry a platform suffix, so the two
tracks read unambiguously and an iOS counterpart has a place to live.

RENAMED (all Android-specific, root Makefile only):
  release → release-android, screenshots → screenshots-android,
  feature-graphics → feature-graphics-android, store-assets → store-assets-android,
  and the four helpers they call: screenshots-pdf, screenshots-demo-off,
  feature-graphics-existing and _cascade-feature-graphics (each + "-android").
  Every internal `$(MAKE) …` caller, the `.PHONY` list, the help-text block and the
  diagnostic echo labels were updated to match. The nested `$(MAKE) -C android
  release bundle` was left untouched: those are the android/ sub-Makefile's own
  targets, already namespaced by the sub-directory (decision: root targets only).

ADDED:
  screenshots-ios — the iOS counterpart entry point, driven by the fastlane `ios
  screenshots` lane (fastlane/Snapfile). It is a self-documenting placeholder: it
  cannot capture until a `PotillusUITests` UI-test target (plus the fastlane
  SnapshotHelper) is authored with the app target on the Mac, so the recipe prints
  exactly what is missing and exits non-zero rather than pretending to work. The
  real capture target is a separate, larger follow-up.

DOCS:
  CONTRIBUTING.md and the fastlane Fastfile (source of the generated
  fastlane/README.md, updated in step) now name the -android targets; the ios lane
  description points at `make screenshots-ios`. .bestpractices.json was updated too
  (its `make release` mention), on the understanding that the authoritative badge
  answer is edited on bestpractices.dev and re-synced. Historical CHANGELOG.md
  entries were left as an accurate record. iOS release/feature-graphic instructions
  were deliberately NOT invented: the App Store has no feature graphic, and the iOS
  release/upload flow is still undecided — only the accurate screenshots-ios entry
  point was added. This change is tooling/naming only; no app behaviour changes.

#### Fix stale app name in manifest locale comment  (patch -98)

A developer comment in AndroidManifest.xml described the per-app language picker's
path as "Settings → Apps → Potillus → Language". In that Android system list the app
appears under its launcher label, which is "Libellus Potionis", so the internal
codename was the wrong name to show. Corrected to the label the user actually sees.
Comment-only; no code or build behaviour changes.

#### Use Libellus Potionis in export file names  (patch -97)

The internal codename "Potillus" is meant to stay internal, but it leaked into the
one place a user actually reads a generated name: the suggested file name in the
share/save dialog and the Files app. The three user-facing export names now use the
public product name instead — on BOTH platforms, changed identically so the
cross-platform "same convention, backups sort together" contract still holds:

  - `potillus_backup_…json`  → `libellus_potionis_backup_…json`
  - `potillus_export_…csv`   → `libellus_potionis_export_…csv`
  - `potillus_report_…pdf`   → `libellus_potionis_report_…pdf`

The timestamp also gains seconds: the stamp pattern goes from `yyyyMMdd_HHmm` to
`yyyyMMdd_HHmmss` on both platforms, so two exports within the same minute no longer
collide. iOS: ReportJob/BackupExporter/CsvExporter in PotillusKit and their tests
(ReportJobTests asserts the exact stamped name; the two exporter tests assert only
the prefix/suffix). Android: PdfReportBuilder/BackupManager/CsvExporter and the
ExportResult doc example; no Android test asserted these names, so none changed.

DELIBERATELY LEFT UNCHANGED
  - The Keychain/Keystore secret alias `potillus_prefs_key` (iOS SecretKeyProviding,
    Android AppPreferences). It is never shown to a user, and renaming it would
    orphan data already encrypted under the old alias.
  - The internal screenshot fixtures — the fixed `jobName` in the androidTest
    ReportExportTest and the committed `fastlane/report-pdf/potillus_report_<locale>.pdf`
    inputs — which are tooling artifacts, not user-facing names.
  - Historical CHANGELOG.md and this log's earlier entries, which accurately record
    the prior convention and are left as a faithful history rather than rewritten.

#### Correct stale build-tool versions in README  (patch -96)

The "Build Infrastructure & Tooling" prose in README.md listed several tool versions
that had drifted behind the actual pins. Each figure was re-checked against its
authoritative source and corrected where stale:

  - Gradle 9.4.1 → 9.6.1 (from android/gradle/wrapper/gradle-wrapper.properties).
  - Kotlin 2.3.21 → 2.4.0, KSP 2.3.7 → 2.3.9, Compose BOM 2026.04.01 → 2026.06.00,
    Navigation Compose 2.8.9 → 2.9.7 (all from android/gradle/libs.versions.toml).

Figures already matching the pins were left untouched (AGP 9.2.0, Activity 1.12.3,
Lifecycle 2.10.0, Room 2.8.4, Desugar 2.1.5). Two that are not keyed in the
[versions] table were verified before deciding not to change them: the Compose
runtime 1.11 line is what BOM 2026.06.00 pulls (per the toml's own note), and
kotlinx-serialization-core 1.11.0 matches its inline library pin. This change is
documentation-only; no code or build behaviour changes.

#### Add from-scratch Android and iOS install guides  (patch -95)

Two root-level onboarding documents now take a blank OS to a runnable debug build,
so a new contributor no longer has to reverse-engineer the toolchain from the
Makefiles: INSTALL-ANDROID.md goes from a fresh Debian GNU/Linux stable install to
`android/app/build/outputs/apk/debug/app-debug.apk`, and INSTALL-IOS.md goes from a
fresh macOS install to the app running in the iPhone Simulator.

WHAT THEY COVER
  - INSTALL-ANDROID.md: the apt packages (JDK 21, git/unzip/curl/python3/make), the
    manual Android SDK setup via `sdkmanager` (platform-tools, build-tools,
    platforms;android-35 and android-36, licence acceptance, ANDROID_HOME), and the
    build itself (`make debug` → `./gradlew assembleDebug`). It explains that Gradle
    9.6.1 arrives through the committed wrapper and AGP 9.2.0/Kotlin 2.4.0 through
    Maven, that no NDK is needed, and that compileSdk/targetSdk is 36 with minSdk 30.
  - INSTALL-IOS.md: Xcode 26 (iOS 17 SDK) plus `xcode-select`, Homebrew, and
    `brew install make xcodegen`; project generation with `gmake ios-project`
    (Version.xcconfig then `xcodegen generate`, since Potillus.xcodeproj is generated,
    not committed); the Simulator build as the primary path (Xcode Run, and the
    headless `xcodebuild -destination 'generic/platform=iOS Simulator' ...` with the
    GRDB-arch pitfall explained); GRDB 7.11.1 resolved automatically by SwiftPM via
    PotillusKit; and a physical-device appendix using free personal-team signing.

SCOPE AND CONVENTIONS
  Publishing (F-Droid, Play Store, App Store) is deliberately excluded, matching the
  request. Both files carry the canonical GPL file header and live at the repository
  root beside README.md, which gains a short pointer to them. INSTALL-ANDROID.md is
  Android-scoped, but it is logged here in the ios-branch §12 log because it was
  produced in this working session; at merge these collapse into the root changelog
  as usual. This change is documentation-only; no code or build behaviour changes.

#### Note container syntax check on roadmap  (patch -94)

A Mac-independent brace/delimiter-balance pre-check is recorded as a low-priority
developer-tooling item in docs/ROADMAP.md (Longer-term direction) rather than built
now. It targets exactly the fault class of patch -93: an orphaned fragment that left
two unbalanced `}` in an app file, invisible to every container check and surfaced
only by the full `xcodebuild` on the Mac. The maintainer decided the tool is not
worth the maintained code today — the Xcode build already gates syntax — so only the
intent is captured, keeping the gap a listed decision rather than a silent one. This
change is documentation-only; no code or build behaviour changes.

#### Fix broken importedMergedPlural in Localization.swift  (patch -93)

The first full-app `xcodebuild` (not just `swift test` on the kit) surfaced a syntax
error in `ios/Potillus/Localization.swift`: `importedMergedPlural` ended with its
`String(localized:)` expression but then carried a stray fragment of an older,
manual-interpolation implementation (`} else if let range = interpolation.range(of:
"%1$lld")…`), leaving two extra `}` and a cascade of "Extraneous '}' at top level".

The fragment references an `interpolation` variable that no longer exists; the
function was rewritten to `String(localized:)` (like its siblings `daysPlural` and
`importedPlural`) but the old body was not fully removed. The orphaned lines are
deleted and the function closed cleanly. The catalogue key
`"%lld entries imported, %lld skipped."` is a positional plural (`%1$lld`/`%2$lld`);
`String(localized: "\(imported) … \(skipped) …")` reproduces it and inflects on the
first count, exactly as the doc comment describes, and the one caller
(`SettingsScreen.swift`) is unchanged.

WHY IT SURVIVED THIS LONG
  The defect entered with an early plurals patch (108d46e). `ios/Potillus/` is the
  APP target, compiled only by the full `xcodebuild`; the container linters and
  `swift test` cover the KIT (`ios/PotillusKit/`) only, so a syntax error in an app
  file passes every check until a real device/simulator build runs. No behaviour
  changed — the file never compiled with the fragment present.

#### Record deferred year view and PDF footer on roadmap  (patch -92)

Two Android features are consciously not ported; both are now recorded as possible
future work in `docs/ROADMAP.md` (Longer-term direction) rather than left as silent
gaps, and the iOS-port status line no longer claims unqualified feature-completeness.

  - Calendar year view (Month/Year toggle, 12-month heat-map). Omitted because the
    analytical year overview it duplicates is already covered by the Statistics
    screen's `year` period (`StatsPeriod.year` exists on iOS). Verified scope-local
    on Android: `CalendarViewMode.YEAR` touches only the calendar screen, never the
    PDF date range (the independent `periodEnd`) or the Statistics period.
  - PDF report footer position. Deferred pending on-device verification; the shared
    template's `min-height: 267mm` (A4 minus margins) is arithmetically correct, and
    any correction is a template tweak once observed.

#### Fix locale-vector and stopped-observation test failures  (patch -91)

The first on-device/simulator test run surfaced three failures (all latent, none
from patch -90's build fix):

LOCALE CATALOGUE (SettingsSanitizerTests.testLocaleCatalogueMatchesAndroid)
  The shared `test-vectors/backup-settings.json` is Android-canonical and lists
  Chinese by region (`zh-CN`/`zh-TW`); iOS ships the same languages but keys
  Chinese by script (`zh-Hans`/`zh-Hant`), because iOS String Catalogs do. The test
  compared the two spellings literally and failed. It now maps each Android tag
  through `SupportedLocales.canonicalTag` — the very migration the app runs when
  restoring an Android backup on iOS — so it asserts the language SETS agree AND
  that the real backup-interop path yields exactly the iOS catalogue. The shared
  vector stays Android-canonical, so the Android test is unaffected. Drift is still
  caught: an Android-only language maps to `""` and the lists differ.

STOPPED OBSERVATION (CalendarModelTests / StatsModelTests testStopEndsTheSubscription)
  After `stop()` cancels the observation task, the GRDB-backed `AsyncThrowingStream`
  can still deliver one element before it tears down (cancellation is cooperative
  and asynchronous). The consuming `for try await` loop then wrote state once more —
  "a stopped observation still fired". Each loop now checks `Task.isCancelled`
  before writing. The same latent bug existed in TodayModel and DrinksModel (no test
  exercised it); those were fixed too, so all four presentation models are
  consistent and a future stop-test on Today/Drinks cannot regress.

#### Fix main-actor clock capture in AppLockModelTests  (patch -90)

A real-device/simulator build under stricter Swift concurrency checking rejected
AppLockModelTests: its `clock` was a `@MainActor`-isolated stored property of the
(main-actor) test case, but `AppLockModel.uptime` is `@Sendable`, so the closure
`{ [weak self] in self?.clock ?? 0 }` could not read it ("main actor-isolated
property 'clock' can not be referenced from a Sendable closure").

The clock is now a small `TestClock` reference box (`@unchecked Sendable`, like the
existing `FakeAuthenticator`), captured by value into the closure as `[clock]`. The
tests still advance it after the model is built (`clock.now += …`), because a
reference box shares the mutation with the closure — a plain value copy would not.
No production code changed; the other model tests were already using the by-value
`FixedClock(millis:)` pattern and were unaffected.

#### Add iOS fastlane lanes and App Store metadata  (patch -89)

The App Store delivery path now mirrors the existing Play Store one: the
repository is the single source of truth for the listing, and an upload
overwrites the store texts from the committed metadata tree.

WHAT WAS ADDED
  - fastlane/metadata/ios/ — the App Store listing for 21 locales (deliver's
    format): per-locale name/subtitle/keywords/description/release_notes and the
    support/marketing/privacy URLs, plus global copyright, primary/secondary
    category (HEALTH_AND_FITNESS / FOOD_AND_DRINK) and review_information/
    placeholders. Field limits (name/subtitle ≤30, keywords ≤100, description
    ≤4000) are all respected. Locale codes follow App Store Connect (no, zh-Hans,
    zh-Hant, pt-PT, pt-BR), which differs from Android's.
  - fastlane/Fastfile — a `platform :ios` block with `screenshots` (snapshot),
    `testing` (upload only) and `production` (upload + submit) lanes, authenticated
    with an App Store Connect API key (.p8) via the APP_STORE_CONNECT_API_KEY_*
    environment variables. The Android block is untouched; default_platform stays
    android.
  - fastlane/Snapfile — snapshot configuration for the App Store screenshots,
    deriving its locale set from the metadata tree (as Screengrabfile does).
  - fastlane/Appfile — an app_identifier (de.godisch.potillus) beside the existing
    package_name; the .p8 is git-ignored.
  - appstore/README.md — the end-to-end release procedure (setup, signed .ipa,
    screenshots, upload, console-side answers). Documents that the build is
    reproducible up to upload; Apple re-signs on ingestion, as already noted for
    Play in .bestpractices.json.

PROVENANCE (honesty)
  English and German store texts are the author's wording. The other 19 languages'
  descriptions reuse the existing translator-written Play Store text with only the
  two platform-specific sentences swapped to iOS (iOS 17, iOS Data Protection, Face
  ID / Touch ID); their subtitles and keywords are machine-translated and
  unreviewed. CONTRIBUTING §6 now carries a prominent native-speaker call-to-action
  and §6.2 declares this machine provenance.

#### Document iOS l10n paths for translators  (patch -88)

CONTRIBUTING §6.1 now maps the two iOS localisation files (Localizable.xcstrings
for UI strings, ReportLabelsCatalog.swift for the PDF report labels), explains the
String Catalog format and the Android→iOS format differences (%1$s→%@, %d→%lld),
and states the two-platform parity rule enforced by tools/check-l10n-parity.py.

#### Decouple the iOS build from android/: self-contained l10n  (patch -87)

The iOS localisation is now laid out the way a native iOS app's would be, and the
iOS build no longer depends on android/ for any of its content.

WHAT WAS COUPLED
  Two committed artefacts used to be GENERATED from android/'s strings.xml:
  Localizable.xcstrings (via build-xcstrings.py) and ReportLabelsCatalog.swift (via
  build-report-labels.py). Worse, check-report-labels.py ran the report generator as
  a subprocess DURING `make ios`, so the iOS build read android/ transitively — it
  would break if android/ were absent.

WHAT CHANGED (Variante A — the catalogue IS the truth)
  - Localizable.xcstrings and ReportLabelsCatalog.swift are now the committed,
    hand-maintained source of truth, edited like any native iOS resource. Their
    values were frozen from the last generator run, so nothing changed for users.
  - Removed the android-reading generators and helpers: build-xcstrings.py,
    build-report-labels.py, and the twenty l10n_XX.py translation tables.
  - Removed check-report-labels.py (it regenerated from android/ to compare).
  - The iOS BUILD now reads neither android/ nor any generator for its l10n.

ANTI-DRIFT SAFETY NET (tools/check-l10n-parity.py)
  A single new check keeps the platforms from silently diverging, and by explicit
  design runs in BOTH `make ios` and `make android`. It reads android/ ONLY to
  compare — it never generates iOS content from it. Three checks:
    1. every UI string literal in the views has a key in the catalogue (the
       untranslated-key safety the generator used to provide);
    2. every catalogue translation whose English key equals an Android string is
       IDENTICAL to Android's translation, in all twenty languages;
    3. the report labels match Android's strings.xml for the same keys.
  A mismatch is a hard error: the platforms have diverged and a human must decide
  which wording wins and update the other side. Building the check surfaced that
  several apparent divergences (e.g. French "Stats", Chinese "月") were NOT drift —
  iOS matches a DIFFERENT Android string that shares the English word (nav_statistics
  vs statistics; month vs pdf_col_month), so the check compares against every Android
  string sharing the English value and passes if any matches.

NOTE ON check-headers: it still scans android/ headers in `make ios`, but that is
the repo-wide licence-header lint, not an l10n content dependency; it is unchanged
and out of scope here.

#### Parity P2d: add iOS coverage to .bestpractices.json  (patch -86)

The badge answers described only the Android build, tooling, crypto, and tests. This
adds the iOS counterpart to 21 justifications, appended (never replacing the Android
text), each backed by a checked fact in the tree:

  • Crypto (6): Android's javax.crypto + Keystore has the iOS counterpart CryptoKit
    AES-256-GCM + the Security-framework Keychain — SymmetricKey(size: .bits256), a
    fresh per-seal nonce, only published algorithms, no re-implemented primitives.
  • Build tooling (3): Gradle/Kotlin-DSL/wrapper → the Swift toolchain, Swift Package
    Manager, and XcodeGen, driven by the same Makefile; all FLOSS or free.
  • Testing (3): ./gradlew test → `swift test` for PotillusKit and xcodebuild for the
    app target, sharing golden vectors with Android.
  • Static analysis / style (3): Android Lint / Kotlin conventions → SwiftLint pinned
    to 0.65.0 and run --strict as a release gate, plus the seven project linters.
  • Dependencies (2): AndroidX/Jetpack → the single pinned SwiftPM dependency GRDB.
  • i18n / a11y / versioning (4): String Catalog with the same locale set; VoiceOver
    and Dynamic Type; MARKETING_VERSION from the same CHANGELOG source of truth.

HONESTY NOTE: interfaces_current does NOT claim deprecation-as-error parity, because
iOS has no SWIFT_TREAT_WARNINGS_AS_ERRORS in the project — the addition states plainly
that currency rests on the modern target and review, not a warnings-as-errors flag.
The ~67 justifications that mention Kotlin/Gradle only in passing were left untouched;
adding iOS boilerplate there would be noise. As with -85, .bestpractices.json is a
snapshot of bestpractices.dev and the authoritative answers must be updated there.

#### Parity P2c: correct the reproducibility/signing claims for stores  (patch -85)

The `build_reproducible` and `signed_releases` justifications in .bestpractices.json
stated the reproducible-build and author-signing story as if it were universal. It is
not — it is bound to the productive channels. This corrects them, from official store
documentation:

  • Codeberg release tags and F-Droid (PRODUCTIVE): the maintainer signs, and anyone
    can rebuild from a tag and compare bit-for-bit. Unchanged; still accurate.
  • Google Play (PLANNED): Play App Signing has the developer sign the upload with an
    upload key, and Google re-signs the distributed APK with a Google-held key.
  • Apple App Store (PLANNED): the developer signs with a distribution certificate and
    App Store Connect re-signs with an Apple identity.

So on the store channels the store — not the maintainer — holds the distribution
signing key, and the published binary is not author-reproducible bit-for-bit. That is
a property of those platforms, not a project choice. The iOS build itself is
deterministic from the repository (declarative XcodeGen project, pinned Swift package
for the one dependency), but App Store distribution offers no F-Droid-style
reproducible re-signing.

NOTE FOR THE MAINTAINER: .bestpractices.json is a downloaded SNAPSHOT of the answers
on bestpractices.dev (the Makefile `bestpractices-json` target pulls site → repo; the
reverse is not available). These edits improve the in-repo copy; the authoritative
badge answers on bestpractices.dev must be updated there by hand to match.

#### Parity P2b: document the no-network guarantee; ATS stays default  (patch -84)

The iOS counterpart of Android's "no INTERNET permission". iOS has no install-time
network permission, so the guarantee is stated where it actually lives — the code.
An exhaustive scan confirms the iOS source contains no networking APIs at all: no
URLSession, no Network framework, no sockets, and the one WKWebView (PDF report
layout) loads a local HTML string with baseURL:nil, reaching nothing.

App Transport Security is deliberately LEFT AT ITS STRICT XCODE DEFAULT rather than
declared explicitly. ATS is already at its most restrictive by default, and with no
connections to govern it has nothing to enforce; the only way to state it explicitly
is a nested Info.plist dictionary, which would trade the working
GENERATE_INFOPLIST_FILE setup for an info:/properties: block or a PlistBuddy step —
real risk for zero behavioural change. SECURITY.md now states both the Android and
the iOS form of the guarantee. A roadmap note (SHOULD section) records that an
explicit ATS declaration can be revisited if an auditor or store reviewer ever wants
it on record.

#### Parity P2a: keep the consumption log out of device backups  (patch -83)

Android declares `android:allowBackup="false"`, removing the whole app from Google's
automatic backup. iOS has no blanket switch, so this adds the per-file counterpart:
the database `potillus.sqlite` — which holds the consumption entries — is excluded
from every device backup by default, with a Settings switch to opt in.

DEVICE BACKUP, NOT iCLOUD. The one attribute this uses, `isExcludedFromBackup`, is
defined by Apple as excluding a file from ALL backups of app data — the automatic
iCloud backup AND the local encrypted Finder/iTunes backup over a cable. The switch
is named "Include in device backup" and the docs say "device backup", never "iCloud",
because naming it after iCloud alone would understate the cable path.

WHAT IS PROTECTED. Only the database file, which carries the entries (the sensitive
data) alongside the drinks list. The settings in `prefs.bin` are sealed with a
`ThisDeviceOnly` Keychain key a restored backup cannot decrypt anyway, so they need
no exclusion; the drinks list travelling with the database is not a privacy concern.

WHY A MARKER AND A RE-APPLY. Apple warns that some file writes reset
`isExcludedFromBackup` back to false. The database is written constantly, so a
once-only set would silently decay. So the user's choice lives in a UserDefaults
marker (a plain "include in backup?" boolean — not health data, so UserDefaults is
fine), and `AppDatabase.makeDefault` re-asserts the preference on every launch via
`BackupExclusion.applyPreference`. The marker decouples "what the user wants" from
the attribute, which can be reset out from under us: an opted-in file is never
re-excluded, and an excluded file whose flag got reset is renewed. Ten tests cover
this with a real temp file and an isolated UserDefaults suite.

The switch is iOS-only by design: Android's `allowBackup="false"` is a hard,
absolute manifest guarantee with no per-file granularity and no cloud/device backup
to opt into, so a switch there would only weaken a closed door. Both platforms
protect the data by default; they just use the mechanism each platform offers.

DOCS. SECURITY.md now lists the iOS at-rest, app-lock, app-switcher, and backup
protections next to Android's; PRIVACY.md gains an "Automatic device backups"
section stating both platforms exclude personal data by default.

Also in this patch: "GRDB.swift" is marked source-only in the string catalogue (a
product name, never translated), and the new switch label is translated into all
twenty languages.

#### Parity pass P1: headers, export compliance, iOS in the docs  (patch -82)

First of a prioritised Android/iOS parity sweep. This patch clears the three P1
items — the ones that block a release or misstate the project.

CONTACT ADDRESSES. Every copyright/licence header now carries `martin@godisch.de`,
on both platforms — 349 header lines — because a copyright line names the person, not
a platform. The content contact addresses (security reports, privacy, governance,
code of conduct, feedback, the F-Droid `AuthorEmail`) stay `android@godisch.de`, as
project-wide maintainer contacts that are not iOS-specific. `ios@godisch.de` is
reserved for genuinely iOS-specific content as it appears.

EXPORT COMPLIANCE. `ios/project.yml` now sets
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: "NO"`. App Store Connect blocks every
submission (TestFlight first) until this is answered. The app is fully offline and
uses only the OS's own encryption — Keychain for the app-lock secret, SQLite for the
database — and ships no proprietary cryptography, so it uses no non-exempt encryption
and the honest, binding answer is "NO". This is a regulatory declaration, correct
because the app genuinely has no non-exempt crypto, not a prompt-silencing trick.

iOS IN THE DOCUMENTATION. The port was still written up as a future goal.
- `docs/ROADMAP.md`: the "Port the app to iOS" future item is replaced by a
  "Current state: the iOS port" section stating it exists and is feature-complete;
  only App Store distribution remains, reframed accordingly.
- `README.md`: the intro now says the app runs on Android AND iOS (two native apps,
  one repository, shared backup format); Platform Compatibility gains the iOS floor
  (iOS 17+, iPhone XS and later); Accessibility gains the VoiceOver/Dynamic Type
  counterpart to the Android TalkBack paragraph.

Still to come in this sweep: P2 (security & compatibility docs, best-practices, the
iOS declarative constraints incl. the iCloud-backup switch), P3 (fastlane/store
tooling, reproducibility), P4 (the year calendar view).

#### Add the About screen with the GRDB licence  (patch -81)

COPYING.md required the iOS app to reproduce GRDB's licence in an about screen before
release, as Android already does. This adds it. From Settings, an "About" row opens a
screen with the app's name and version, its own GPL notice, GRDB's MIT licence in
full, and a link into the combined copyright/licence document.

THE GRDB LICENCE, VERBATIM. The text is reproduced exactly from GRDB's own LICENSE
file — copyright line (Copyright (C) 2015-2025 Gwendal Roué), permission grant, and
warranty disclaimer — in AppInfo.grdbLicense. It is folded into source with line
continuations, and six app-target tests guard it: the copyright line, the permission
grant, the disclaimer, no broken joins, plus the version and name. A licence quoted
loosely is not the licence, so the text is pinned by tests, not trust.

THE COMBINED DOCUMENT. The viewer shows copyright.md — COPYING.md, the full GPL, and
the Apache notice, joined by tools/render-copyright.py, the SAME renderer and the SAME
three files Android bundles as raw/copyright.md, so the two platforms show byte-
identical text. It is generated by `make ios-project` and gitignored, like
Version.xcconfig: a copy in the tree would drift from COPYING.md. DocumentViewerScreen
mirrors Android's: read-only, scrolled, with a deliberately small Markdown pass
(headings, rules, inline links) rather than a heavyweight parser on 60 KB — a licence
must never fail to display because a parser choked.

AppInfo now owns the version that StatsScreenExport read for the report footer; both
read one definition. Seven new strings (About, Version, Licence, and so on) are
translated into all twenty languages; "GRDB.swift" is a proper noun on the l10n
allowlist. COPYING.md's wording changes from a future obligation to a statement that
both platforms reproduce the licence.

#### Make the Today screen reactive  (patch -80)

TodayModel was the last snapshot model; the other four already observe the database.
It loaded on appear and after its own writes, which hid the gap: a drink imported or
an entry edited in another tab left the Today screen showing yesterday's numbers until
something made it reload.

Now it observes, in the same shape as StatsModel and CalendarModel. `start()` opens
three subscriptions — entries, drinks, settings — and each carries only the FACT that
something changed; `load()` recomputes the one consistent moment. The streams cannot
each hold their own slice, because all three windows depend on the settings:
`dayChangeHour` moves what "today" is, and "today" moves the trailing weekly window.
Weaving three data streams would redraw the screen into an inconsistent instant; a
single recompute cannot.

The view drops its `.task { load() }` for `.task { start() }` + `.onDisappear {
stop() }`, exactly like the other reactive screens, and loses the reload-on-sheet-
close hack: the settings stream now covers a changed day-change hour, and the entry
and drink streams cover a log or an import from anywhere.

Four tests prove reaction to a change made ELSEWHERE — a repository write not routed
through this model — since a write through the model would reload regardless and prove
nothing. They use the real ephemeral GRDB, so the observation path is the one that
runs in the app.

All five models are reactive now.

#### Localise the PDF report, following the UI language  (patch -79)

The report was the last English-only surface. Now its title, sections, KPI labels,
table headers, category names, and the risk-section closures all follow the UI
language — as Android's report does, where `Context.formattingLocale` drives the
labels, the numbers, and the dates from one per-app locale.

FULLY HARVESTED. Android localised the report completely: 46 `pdf_`/`category_`
strings in all twenty languages, 100% present, nothing missing. So this patch invents
no report text — `tools/build-report-labels.py` reads Android's strings.xml and emits
`ReportLabelsCatalog.swift`, a `ReportLabels(language:)` that carries every label in
every language. `%1$s`/`%1$d` in the harvested closures become Swift `\($0)`.

WHY A GENERATED FILE, EXCLUDED FROM SWIFTLINT. Twenty languages is 800-plus strings
and a 20-way dispatch; the switch's complexity and the file's length are inherent to
that, not signs of messy hand-written code. The file is generated and excluded from
SwiftLint, and `tools/check-report-labels.py` guards it instead: it regenerates and
compares byte for byte (so a hand edit or a changed Android string is caught as
drift), and checks that every language's closures carry the same `\($0)` count as
English (so a dropped placeholder can't crash the report at print time). Both checks
are self-tested.

ReportLabels declares an explicit `init()`, which suppresses the memberwise
initialiser — so the generated code assigns fields on a `var`, it does not call
`init(title:...)`, which would not compile.

REPORT_LANG. The renderer already emitted the BCP-47 tag into `<html lang>`; now it
is the chosen language's tag. That matters beyond text: a WebView picks its CJK glyph
orthography (Simplified vs Traditional Han, Japanese kanji, Korean hanja) from the
document language, so a Japanese report now renders Japanese glyph forms rather than
defaulting to Simplified-Chinese shapes for the code points the scripts share.

Localisation is complete: twenty UI languages, the report, and the plurals. A device
check worth doing: export a report under each script and confirm the glyph forms and
the number/date formats follow the chosen language.

#### Localise the three plurals, in the UI too  (patch -78)

Android has three `<plurals>`: `days` (statistics streaks, and the report), and the
two import-summary messages. iOS handled none of them — the statistics showed a bare
number with no noun, and the import summary always said "entries" even for one. Now
all three inflect, in every language, in the UI.

THE MECHANISM. String Catalogs store plurals under `variations.plural`, a form
(one/few/many/other) per language: two forms for English and German, four for Polish
and Russian, one for Japanese. The runtime picks the form for the count. `Loc` builds
the lookup by interpolating the count as an `Int` into a `String.LocalizationValue` —
`String(localized: "\(count) days")` — which is what makes the key `"%lld days"` AND
lets iOS inflect. Passing the number as a String would defeat both; that subtlety is
the whole reason these are three written-out helpers rather than one format-string
call.

Every form is harvested from Android — 156 forms across twenty languages and three
plurals — none invented, since Android defines them all. Android's `%1$d` becomes
iOS's `%lld` (or positional `%1$lld`/`%2$lld` for the merge message's two counts).

THE GUARD. `check-l10n.py` now reads the built catalogue and fails if any plural form
carries a different number of `%lld` placeholders than its English `other`. A
harvested form with a dropped placeholder would crash or mis-format at runtime, and
only for the language and count that hits that form — the hardest bug to see.
Self-tested: corrupt one Polish form and it fires.

NOTE for device testing: plural selection with an EXPLICIT locale (not the system
one) is the path this app relies on but cannot compile-check here. Worth a look on
device that Polish "2 dni" / "5 dni" / "1 dzień" pick the right forms.

STILL TO DO: the report's own localisation (ReportLabels, REPORT_LANG), which will
reuse the days plural built here.

#### Add the CJK languages, completing the twenty  (patch -77)

Japanese, Korean, Simplified Chinese, Traditional Chinese — the last four, matching
Android's full set. 27 harvested from each `values-XX` (Android's zh-rCN/zh-rTW map
to the catalogue's zh-Hans/zh-Hant, wired in patch -74), 71 translated for this port.

Simplified and Traditional Chinese are kept separate, as Android keeps them: they
differ in script and in wording (导出 vs 匯出 for export, 添加 vs 新增 for add,
数据 vs 資料 for data). The zh-Hans/zh-Hant split here is the payoff of the code
migration in -74 — a stored "zh-CN" now resolves to the zh-Hans catalogue entries.

CJK punctuation follows each language's convention: the ideographic full stop 。in
Japanese and Chinese, the interpunct ・between number and unit in Japanese. The "ml"
and "g" units stay Latin, as Android leaves them, since that is how the units are
written in these locales in practice.

Twenty languages now — the whole of Android's set — 98 keys each, and a check
confirms every placeholder survives every one of the twenty translations. STILL TO
DO: the report's own localisation (ReportLabels, REPORT_LANG), and the three plurals.

#### Add the Slavic and Greek languages  (patch -76)

Five: Czech, Polish, Russian, Ukrainian, Greek. 27 harvested from each `values-XX`,
71 translated for this port, no new machinery.

The action labels follow the register Android already set for these languages — the
imperative-infinitive form for buttons (Exportovat, Eksportuj, Экспортировать,
Експортувати, Εξαγωγή), read from the harvested strings so the port's own verbs match
the harvested ones rather than clashing with them. Cyrillic carries its own unit
tokens: "мл" for millilitres, "г/день" for grams per day, so those strings ARE
translated here where the Latin-script languages left "ml"/"g" untouched.

Every placeholder survives every translation: a check across all sixteen languages
confirms no `%@` or `%lld` was dropped or reordered against the English source. That
matters most for the positional `%1$…`/`%2$…` strings, where a translator moving the
arguments would silently corrupt the format.

Sixteen languages now, 98 keys each. STILL TO DO: CJK (ja, ko, zh-Hans, zh-Hant);
the report's own localisation; the three plurals.

#### Add the Romance languages  (patch -75)

Six: Spanish, French, Italian, European Portuguese, Brazilian Portuguese, Romanian.
Same shape as the Germanic patch — 27 keys harvested from each `values-XX`, 71
translated for this port — and no new machinery; the generator already took a
language list, so this patch is six tables and one line added to it.

European and Brazilian Portuguese are kept as SEPARATE languages, not one with a
region fallback, because they diverge in ordinary vocabulary the app uses:
"Eliminar" vs "Excluir" for delete, "Registos" vs "Registros" for entries,
"definições" vs "configurações" for settings. A Brazilian user given the European
wording would read it as stilted; the split costs one extra table and reads right to
both.

Eleven languages now, 98 keys each. STILL TO DO: Slavic + Greek (cs, pl, ru, uk, el),
CJK (ja, ko, zh-Hans, zh-Hant); the report's own localisation; the three plurals.

#### Add the Germanic languages, migrate the Chinese codes  (patch -74)

Four languages — Danish, Dutch, Norwegian Bokmål, Swedish — the first of four
family-grouped patches that bring the catalogue to Android's twenty. Each language
is one flat table in `tools/l10n_XX.py`, keyed by the English source. Of the 98
translated keys, 27 are harvested verbatim from Android's `values-XX` where the
English matched a string there; the other 71 are this port's own, translated the
same way German was, since Android's own translations were made under the same
conditions.

The generator, German-only until now, took a language list. Harvested Android values
merge UNDER the port's own table, so a hand-written string wins over a harvested one
where a key exists in both — the port's wording is the source of truth for its own
keys.

THE CHINESE MIGRATION. `SupportedLocales` stored `zh-CN`/`zh-TW`; iOS String Catalogs
key Chinese by script, `zh-Hans`/`zh-Hant`. The two now agree — `SupportedLocales`,
`knownRegions`, and the catalogue all use the script tags, and the two sets are byte
-for-byte equal for the first time. But a backup or a stored setting written before
this carries the old region code, and `String(localized:locale:)` with an explicit
locale would not find a script-tagged entry from a region tag. So `canonicalTag`
migrates `zh-CN` → `zh-Hans` and `zh-TW` → `zh-Hant` FIRST, before it validates
against the current list. Every stored language runs through `canonicalTag`, so an
upgrading Simplified-Chinese user keeps their language instead of dropping to System.
Five tests, including a case-insensitive one and the pass-through of the new codes.

STILL TO DO: Romance (es, fr, it, pt, pt-BR, ro), Slavic + Greek (cs, pl, ru, uk,
el), CJK (ja, ko, zh-Hans, zh-Hant); the report's own localisation; the three plurals.

#### Localise every screen, German complete  (patch -73)

Android has an in-app language picker; this port keeps it (same feature, native
idiom). That one decision shapes everything here, because it fights SwiftUI's grain.

THE CONFLICT. `Text("Today")` becomes a `LocalizedStringKey` resolved against the
ENVIRONMENT locale, which follows the SYSTEM language. Setting `.environment(\.locale,
chosen)` moves some views but, by Apple's documentation and wide report, not all of
them reliably. A privacy app that promises a language must not show half its labels
in another.

THE MECHANISM (path A). Every user-facing string goes through `Loc.string(_:locale:)`,
which calls `String(localized:locale:)` — a real API since iOS 16 — with the CHOSEN
locale explicitly. The result is a plain `String`, which is exactly why views must
call it rather than hand a literal to `Text`: `Text(runtimeString)` does not
re-localise. `\.appLocale` carries the choice down from the root, set once from
`settings.language`. The two covers that sit ABOVE the root (they must show before
the tree exists) take the locale as a parameter instead.

THE CATALOGUE. `Localizable.xcstrings`, Apple's String Catalog, keyed by the English
source text. It is not hand-edited: `tools/build-xcstrings.py` regenerates it from
the views and the translation tables, so it cannot silently disagree with the code.
It reads both raw `Text("...")` and converted `Loc.string("...")`, so a key does not
vanish as its screen is converted — a bug that bit once and is now designed out.

GERMAN. 102 keys; 98 translated, 4 language-neutral (`%lld ml`, a bare `%@`), 0
untranslated. Nineteen came verbatim from Android's `values-de` where the English
matched word for word; the rest are this port's own, written into `tools/l10n_de.py`
as ordinary catalogue entries.

PLACEHOLDERS. SwiftUI renders an `Int` interpolation as `%lld` and a `String` as
`%@`; the catalogue key must match what SwiftUI generates or the lookup misses. The
generator infers the specifier from the interpolated expression, and positional
`%1$…`/`%2$…` once there is more than one argument.

WHAT IS NOT LOCALISED, on purpose: the app's proper name; pure number-and-unit
strings; the startup-failure view, which renders before the locale exists and is
meant to be quoted verbatim into a bug report — the same reasoning that keeps the
kit's technical error strings in English. The PDF report (`ReportLabels`,
`REPORT_LANG`) is a SEPARATE localisation axis and stays for its own patch; until
then the report prints English even under a German UI.

THE GUARD. `tools/check-l10n.py`, wired into `make ios`, fails the build on any raw
localizable literal in a view. It understands that a unit suffix after an
interpolation is neutral, so it agrees with the catalogue on which strings need no
lookup. Self-tested: reintroduce a `Text("literal")` and it fires.

The `.xcstrings` builds into the bundle from the scanned source path; `project.yml`
now declares `developmentLanguage: en` and the 21 `knownRegions` matching
`SupportedLocales.all`. A two-versus-four-space indentation error in that file cost
a round to find — the anchor was real, the whitespace was not what it looked like.

STILL TO DO: the other 19 languages (harvested from Android per the agreed plan),
the report's own localisation, and the three Android plurals.

#### Hide the app-switcher preview  (patch -72)

`allowScreenshots` was the last stored-but-unread setting. Android sets FLAG_SECURE,
one flag that blanks the Recents thumbnail AND blocks active screenshots. iOS has no
such flag, and the one setting splits into two problems with very different answers.

DONE: the app-switcher thumbnail. When the app leaves the foreground iOS snapshots
the window; an opaque `PrivacyCover` over the content during `.inactive`/`.background`
means the snapshot is of the cover. Ordinary SwiftUI, no private API. Secure by
default as on Android — the cover shows unless the user allows screenshots.

DELIBERATELY NOT DONE: blocking an ACTIVE screenshot. The only known way is the
`isSecureTextEntry` trick — wrapping the UI in a secure text field. That is
undocumented, fragile across releases, and the wrong thing to ship inside a privacy
app that is meant to contain no such tricks. Android gets active blocking free from
the platform; iOS would charge a hack, and we decline. The toggle is therefore
labelled "Show in app switcher", saying what it does here rather than promising
Android's behaviour.

THE COVER IS INDEPENDENT OF THE APP LOCK. When the lock is on, its cover is already
up on background, so this is redundant then; when the lock is off, this is the only
protection for the thumbnail. Keeping them separate means either can go without
touching the other.

The visibility rule — covered unless active, unless opted out — is a truth table,
and a truth table can be got wrong, so it is a pure `PrivacyCoverDecision.isCovered`
with four tests rather than an inline `&&`. One subtlety it encodes: `.inactive`
counts as not-active, because the switcher snapshot is taken during that transient
phase, and waiting for `.background` would photograph the diary a frame too late.

One SwiftUI timing bug found and fixed on the way: the scene's observation of the
flag was keyed with `.task(id: startup.isReady)`, because a plain `.task` fires once
while startup is still `.loading`, never sees the environment, and would leave the
cover stuck on.

#### Add the biometric app lock  (patch -71)

`biometricEnabled` was stored, ported through backup, and read by nothing. It reads
by something now.

Android gates the app behind a strong-biometric-or-device-credential prompt; unlock
lasts the process session, and after more than 30 seconds in the background it
re-authenticates on return, measured with `elapsedRealtime` so an overnight lock
holds. This reproduces all of that.

THE SPLIT. The decision that matters — has enough background time passed to prompt
again? — is `AppLock.requiresReauth`, pure arithmetic over two monotonic readings,
driven by shared vectors in `app-lock.json` (seven cases, the threshold carried in
the file so a drift on either platform shows up as a mismatch). The state machine is
`AppLockModel`, which talks to the sensor through a `BiometricAuthenticator`
protocol and takes its clock as a closure, so every transition is tested with a fake
and time is advanced by hand — nine tests, no device. Only `DeviceBiometricAuthenticator`,
in the app shell, imports LocalAuthentication.

THE CHOICES, as agreed:
- `.deviceOwnerAuthentication`, not the biometrics-only policy — it accepts Face ID,
  Touch ID, Apple Watch, OR the passcode, matching Android's `BIOMETRIC_STRONG or
  DEVICE_CREDENTIAL`, and it is the only policy a passcode-only device can satisfy.
- A cancelled or failed prompt leaves the cover up with a Retry, never a way past.
- The settings toggle refuses to arm on a device that can neither take a biometric
  nor a passcode: arming there would lock the diary away for good. Android runs the
  same `canAuthenticate` check before showing its switch.
- A fresh `LAContext` per prompt: a reused one that already succeeded passes the
  next `evaluatePolicy` automatically, which is exactly wrong for a re-lock.

`allowScreenshots` and the switcher-thumbnail cover are deliberately still separate;
they are the next patch. The kit found one of its own bugs on the way: `@Observable`
without `import Observation`, caught by `check-swift-symbols` before the compiler.

`.inactive` scene phase is ignored: only `.background` arms the timer and only
`.active` checks it, or the app would prompt every time it briefly lost focus.

#### Make the calendar live  (patch -70)

The last snapshot but one. The calendar loaded on `.task` and never again; a backup
imported while it sat in another tab left the month showing the dots it had before.

It observes the SAME triggers as the statistics screen — the set of logged dates and
the settings — but with a twist the statistics screen does not have: the month
changes underfoot when the user pages. So the stream must not carry a range. It
carries the fact that something changed, and `reloadMonth()` reads whichever month
is on screen when it fires. `observeDailySummaries(from:to:)` would have tied the
subscription to one month and forced a resubscribe on every page turn; `observeAllDates()`
is month-blind and fires on every write, so one subscription stays correct across
paging. A test pages to February and adds an entry there to prove it.

Unlike `StatsModel`, `start()` calls `load()` up front rather than leaning on the
first emission: `load()` seeds `state.year`/`state.month`, which `reloadMonth()`
needs before it can choose a month. The entry stream then drives `reloadMonth()` —
the grid alone — while the settings stream drives `load()`, because a changed
day-boundary moves what today is.

Six tests, written against `makeModel(at:)` and `addEntry(on:grams:at:)` — the
fixture that file actually has, read before writing this time rather than after the
compiler complained.

ONE SNAPSHOT LEFT: `TodayModel`. It reloads when the entry sheet closes, which
hides the gap on its own screen, but an import in another tab still leaves it stale.
Next.

#### Build the statistics tests against the fixture that exists  (patch -69)

Patch -68 wrote `self.model` into `StatsModelTests`. `DrinksModelTests` has a
`model` property; `StatsModelTests` has a `makeModel()` factory and no such field.
Five tests, sixteen compile errors, and the build had to reach the type checker on a
machine that is not this one to say so.

Rule 7 — no identifier without evidence — was applied to the model under test and
not to the test fixture around it. The fixture is code too, and it was two lines
away in the same file.

Each test now takes its own model from the factory, as every other test in that file
already did, and stops it in a `defer`.

A LINTER RULE WAS WRITTEN FOR THIS AND THEN DELETED. It flagged `self.foo` where the
file declares no `foo`, which sounds right and is useless here: `model` IS declared
in that file, as a local binding inside a dozen other tests. Catching this needs
scope analysis, which needs a parser. The rule as drafted also called `self.init` an
error in three source files.

A check that misses the bug it was written for, while inventing three others, gives
false confidence twice over. `swift test` catches this, in one second, and it
already runs in `make ios`.

#### Make the statistics screen live  (patch -68)

Android's `StatsViewModel` combines the period selector, the settings and the set of
logged dates into one Flow and re-runs its queries with `flatMapLatest`. Log a
drink, and the statistics behind it have already changed.

The iOS `StatsModel` was a SNAPSHOT. It loaded on `.task` and on pull-to-refresh,
and nothing else. Import a backup while the statistics sit in another tab, come
back, and the screen shows the numbers from before the import. Add an entry on the
Today screen, and the totals are a drink behind. Neither says so. It was not a
decision; three of five models were written this way and two were not.

`start()` now subscribes to two streams, following the shape `DrinksModel` and
`SettingsModel` already used. They carry no data — `reload()` is the only code that
knows which days the window covers — they carry the fact that something changed.

THE CASE THAT DECIDED THE DESIGN is a second entry logged on a day that already has
one. `observeAllDates()` fetches `SELECT DISTINCT logicalDate`, whose value is then
unchanged. It fires regardless: GRDB's `ValueObservation` notifies on every
transaction touching the tracked region and, by its own documentation, "may notify
consecutive identical values". Duplicates are dropped only when `removeDuplicates()`
is asked for, and it deliberately is not. There is a test that logs exactly that
entry.

The settings stream matters as much: `dayChangeHour` moves what today is, and
`statsFromDate` moves the floor of every window.

Six tests, including one that stops the model and then writes to the database, to
show that a view which has disappeared is not still observing behind it.

STILL SNAPSHOTS: `TodayModel` and `CalendarModel`. Today reloads when the entry
sheet closes, which hides the problem; the calendar has no such trigger and will
show a stale month after an import. Next patches.

#### Ask which days to export  (patch -67)

Android asks before every export, CSV and PDF alike: a date-range picker pre-filled
with the "statistics from" date and today, future days greyed out. The exported
range is INDEPENDENT of the period on screen — you may be looking at this month and
export the whole year.

The iOS port silently exported whatever window the statistics screen happened to
show, and disabled the button when that window was empty. Import a backup of last
spring, open the app in July, and the export button is grey. Nothing is wrong with
the data; the app simply never asked the question.

`ExportRangeSheet` asks it. Two `DatePicker`s rather than a range picker, because
SwiftUI has none — same information architecture, native controls, which is this
port's rule. The upper bound of the second picker is the first, so an inverted range
cannot be expressed; Android greys those days out, this control will not scroll to
them.

The button is now disabled only while a PDF is rendering. An empty range is still
refused, with a sentence, at the moment of export — as on Android, because a file
with no rows looks like a broken export rather than an empty month.

`DayResolver` anchors logical days at 12:00 UTC so they survive time-zone shifts;
`DatePicker` shows a `Date` in the device's zone. Noon-UTC is the same calendar day
from UTC-11 to UTC+12, which is every zone in use, and `formatDate` reads it back in
UTC. The round trip is exact.

#### Known deviation: the report's footer sits higher on iOS

Left as it stands, deliberately, and recorded here so it is not mistaken for an
oversight.

WebKit's print layout inflates absolute CSS lengths in the block flow by a constant
just over 1.2 (measured: 267mm asked, 320.9mm printed; 240mm asked, 288.4mm
printed), and resolves `100vh` against something that is not the page box (596.7mm).
There is therefore no unit in which the template can state "one page tall" and be
believed.

Patch -66 stopped trying: the sheet is as tall as its content, and the disclaimer
follows the content instead of the paper — about 40 pt higher than Android's on
sheet one, 110 pt on sheet two. The report is correct, two pages, and every number
in it is right.

Pinning the footer again needs one number: `267 / 1.2018 = 222.2mm`. That is a
measurement of one WebKit on one iOS, not a derivation, and it would move without
warning. If it is ever adopted it must arrive with the three data points above, a
name that says it was measured, and a test that recomputes it — so that the day it
stops being true, the build says so instead of the report growing by two pages.

#### Stop asking WebKit how tall a page is  (patch -66)

Patch -65 replaced `min-height: 267mm` with `100vh`, on the reasoning that a page
box is one page box by definition. It printed a sheet 1691 pt tall — 2.23 pages —
and the report came out on six.

| `min-height` asked | sheet printed | sheet / page |
| ------------------ | ------------- | ------------ |
| 267 mm             | 320.9 mm      | 1.2018       |
| 240 mm             | 288.4 mm      | 1.0802       |
| 100 vh             | 596.7 mm      | 2.2348       |

Millimetres inflate by a constant just over 1.2, linear through the origin.
Viewport units resolve against something that is not the page. WebKit's print
layout gives the page box no height that CSS can ask for.

SO THE REPORT STOPS ASKING. The sheet is only tall because `margin-top: auto`
needs a tall box to push the disclaimer against its bottom edge. The content fits
with room to spare — sheet one ends 66 pt above the page bottom, sheet two 138 pt.
Drop the height, and `page-break-before: always` between sheets yields exactly two
pages. Nothing in that sentence depends on how a length resolves.

The cost is cosmetic and real: on iOS the disclaimer now sits under the last table
rather than at the foot of the page, about 40 pt higher on sheet one and 110 pt
higher on sheet two. Android's print framework resolves millimetres correctly and
keeps the pinned footer. A report that is right in the wrong place beats a report
on twice the pages.

`margin-top: 18pt` replaces the `auto`, which would otherwise pin the disclaimer to
a bottom edge that is now the content's own and collapse the gap to nothing.

FIVE WRONG DIAGNOSES PRECEDED THIS — invented margins, a formatter assumed to
scale, an inch of insets that was not there, a footer blamed on flexbox, and a
viewport unit that resolves against nothing useful. Every one was argued from the
source. The two that mattered came from measuring the artefact: a constant ratio
across two exports, and a donut that was neither 44 mm nor 1.2018 × 44 mm.

#### Express the sheet height in pages, not millimetres  (patch -65)

Superseded by -66; the reasoning is kept because the measurement in it stands.

Two exported PDFs, measured rather than reasoned about, established that WebKit's
print layout inflates absolute lengths in the block flow by a constant a little over
1.2, and that the donut — `44mm` square in the SVG — comes out 40.1 mm, neither 44
nor 1.2018 × 44. Two length resolutions in one document.

The fix chosen here, `min-height: 100vh`, assumed viewport units would resolve
against the page box. They do not.

#### Let the sheet be shorter than its page  (patch -64)

`check-report-paper.py` demanded that `.sheet`'s min-height EQUAL what the `@page`
margins leave of an A4 sheet, and then described the failure as "a sheet taller than
its page prints on two" — a sentence true of one side of an equality it was testing
as both.

So it rejected a 240 mm sheet: shorter than its page, harmless, and precisely the
experiment meant to diagnose why the report prints on four pages. A check that
blocks a diagnosis is worse than no check.

It is an inequality. A shorter sheet only lifts the pinned footer off the bottom
edge; a taller one prints on two pages. Only the second is a fault.

The failing case was never tested when the check was written — the three tests it
did have were "clean", "template moved", "Swift moved". None of them made the sheet
SHORTER. The test list now covers both directions, which is what the message had
been claiming all along.

#### Take the formatter's inch away  (patch -63)

`UIPrintFormatter.perPageContentInsets` defaults to ONE INCH on every side. Nothing
at the call site says so.

72 pt at the top and 72 at the bottom is 50.8 mm, subtracted from a printable box
that already carries the template's `@page` margins. A 267 mm sheet was handed
216 mm. It printed on two pages, and the report on four — even after `pageZoom`
made every millimetre the right size, which patch -62 confirmed by the donut coming
out at its intended 44 mm.

The same inch on the left and right is the loose end from patch -61: changing the
web view's width moved the line breaks and nothing else, because the formatter had
been re-flowing the text inside its own narrower column the whole time. Both
observations now have one cause.

`tools/check-report-paper.py` fails the build if `perPageContentInsets = .zero`
ever disappears. Nothing in the type system would notice, and the symptom is a
report that is silently one page too long.

MEASUREMENT AND PREDICTION DO NOT QUITE AGREE: 50.8 mm computed against roughly
61 mm measured off a screen. That is within a ruler's slop, but it is not zero. If
a narrow strip still overflows after this patch, the cause is a sheet whose content
is taller than its own `min-height`, which would be a fault in the template rather
than in the printer.

#### Scale the page, not the view  (patch -62)

Third attempt at the same four pages, and the first one aimed at the actual cause.

CSS resolves a millimetre at 96 dpi; `UIPrintPageRenderer` draws at 72. Left alone,
one CSS pixel prints as one point and every millimetre comes out 4/3 too large. A
267 mm sheet then needs 356 mm of a 267 mm page — a third more — and each of the
report's two sheets spills onto a page of its own.

WHAT THE TWO WRONG FIXES ASSUMED. Patch -59 inset the printable box by an invented
24 pt and let the scale fall where it may. Patch -61 assumed
`UIViewPrintFormatter` SCALES the view down to the printable width, and sized the
view in CSS pixels so the scale would land on 0.75. It does not scale. It RE-LAYS-
OUT the content for the page width, so the view's width moved the line breaks and
nothing else.

The evidence that settled it was a measurement, not an argument: the overflow was
"a good third" of a page. 96/72 − 1 is a third. Had the formatter been scaling, the
type would have looked too large, and it never did.

`webView.pageZoom = 0.75` scales the CONTENT, whatever the formatter does with it
afterwards. The view is the printable box in points; the zoom gives the page a
layout viewport of 703 × 1009 CSS px, which is 186 × 267 mm. One CSS millimetre
becomes one printed millimetre. `min-height: 267mm` lands on 756.85 pt, and the
printable height is 756.85 pt.

The reasoning of both failed attempts stays in the source, above the constant that
replaced them. A comment that only records the right answer teaches nobody why the
wrong ones were plausible.

#### Pin the print scale to 72/96  (patch -61)

The report printed on four pages. Each of its two sheets overflowed by a strip.

The template measures in millimetres — `@page { margin: 14mm 12mm 16mm 12mm }` and
`.sheet { min-height: 267mm }`, which is exactly 297 minus the two vertical
margins. CSS resolves a millimetre at 96 dpi; `UIPrintPageRenderer` draws at 72.
The formatter scales the web view's width down to the printable width and applies
that same ratio to the heights.

Patch -59 let the ratio fall where it may. An A4-wide web view printed into a box
inset by an invented 24 pt gives 0.9194. A 267 mm sheet is 1009 CSS px; at 0.9194
it prints 928 pt tall, and 794 pt were printable. Overflow: 134 pt per sheet —
arithmetic that matches the four pages exactly.

The ratio must be 0.75, which is 72/96, and nothing else. Then one CSS millimetre
is one printed millimetre and the sheet ends where the template says. That is
arranged by laying the web view out in the CSS PIXELS of the printable box (its
points times 4/3) and by taking the printable box from the template's own `@page`
margins instead of a number that felt about right.

The type never looked too large, which is what made this hard to see and easy to
mis-diagnose: the width was being scaled correctly all along. Only the heights,
written in absolute millimetres, refused to come along.

TWO TRUTHS ABOUT ONE SHEET OF PAPER NOW EXIST — the template's `@page` and the
printer's `pageMarginsMm` — because `UIViewPrintFormatter` reads no CSS. So
`tools/check-report-paper.py` fails `make ios` if they disagree, and also if
`.sheet`'s min-height stops matching what those margins leave of an A4 page. Tested
four ways: silent when they agree, loud when the template moves, loud when the
Swift moves, loud when the sheet outgrows its page.

#### Close the PDF context before reading its buffer  (patch -60)

The report exported in patch -59 could not be opened. It had a `%PDF-` header, it
had page objects, and it had no ending.

`UIGraphicsEndPDFContext()` is what writes the cross-reference table and the
`%%EOF` marker — the parts that make the bytes a document rather than a heap of
drawing commands. Patch -59 called it from a `defer`, and `defer` runs AFTER the
return value has been evaluated. `output as Data` took the buffer while the
document was still open.

Worse: the draft before -59 had the explicit call AND the `defer`, and I removed
the explicit one as a redundant double-close. It was not redundant. It was the one
that mattered; the `defer` was the safety net for the throwing path. Both are back,
with a flag so the net does not fire twice, and with the reason written down.

`ReportJob.isWellFormed` now checks that the bytes begin `%PDF-` and end `%%EOF`.
It is not a validator and does not pretend to be. It answers the single question
this bug turned on, it is pure, and so it lives in the kit with four tests — one of
which feeds it exactly the truncated buffer that shipped.

The printer refuses to hand such a buffer to `fileExporter`. A report that cannot
be opened should fail at the moment of export, with a sentence, and not three taps
later in Preview.

#### Print the report  (patch -59)

The last step. The Statistics toolbar now exports a PDF as well as a CSV.

- `ReportPdfPrinter` loads the HTML in a `WKWebView` and hands
  `viewPrintFormatter()` to a `UIPrintPageRenderer`, which paginates it. What comes
  out is what Safari would print, which is what Android's print framework produces
  from the same file.
- NOT `WKWebView.createPDF`, though it is the newer API and needs no subclass. It
  captures a rectangle, usually the whole scroll height: one endless sheet. The
  template is two A4 pages with page-break rules and a running footer, and an
  endless sheet would be a different document.
- PAPER SIZE WITHOUT KVC. `paperRect` and `printableRect` are read-only, and every
  recipe on the web writes them with `setValue(_:forKey:)`. They are also `open`, so
  `PaperSizedRenderer` overrides the getters instead: same result, no reflection,
  and the compiler checks it. There is no key-value coding in this app.
- The template is copied into the app bundle by `ios/project.yml`, from
  `report/report_template.html` at the repository root — the same file Android
  registers as an asset. One file, two reports, no chance of drift.
- `ReportJob.fileName` is the only testable part of exporting a PDF, so it lives in
  the kit and is tested there. Its formatter is pinned to `en_US_POSIX`: a
  locale-aware one would name a file after a Japanese era year, and an Arabic one
  would write the digits in Eastern Arabic numerals. Neither sorts.
- The report takes its "today" from `model.state.today` rather than asking a clock
  again. Asking twice could straddle the day-change hour and give the report a
  different today than the screen behind it.

`StatsScreen` split at the seam SwiftLint's body limit exposed: one file shows the
statistics, the other carries them out of the app. Doing so meant widening `model`
and `environment` from `private`, because `private` in Swift is FILE scope — the
same trap the renderer walked into two patches ago, caught this time before the
compiler had to say it.

Rule 7 earned its keep here: `DayResolver.today`, `Bundle.appVersion` and an
unimported `UIDevice` were all written down from memory and all three were wrong.
The grep found them before the compiler did.

`ReportPdfPrinter` has no tests and cannot have any: it needs a screen, a web
engine and a run loop. Everything that could be tested was moved out of it long
before it was written.

#### Stop capturing a key path across an actor boundary  (patch -58)

The compiler warned that `SettingsScreen.bind` captured a
`WritableKeyPath<AppSettings, Value>` in a `@Sendable` closure. It is right, and
under Swift 6 it will refuse rather than warn.

`SettingsModel.update` takes a `@Sendable` transform because the change travels
from the main actor into the store's. A key path handed to that transform is
captured by it, and a `WritableKeyPath` is not `Sendable`.

The write is now a CLOSURE LITERAL at each call site, capturing nothing at all, so
the transform is trivially sendable. The read still uses a key path: it runs on the
main actor and never crosses. The alternative — wrapping the key path in an
unchecked-sendable box — would have silenced the compiler by asserting something
nobody had checked.

THE FIX INTRODUCED A HAZARD, so the fix carries its own guard. `bind` used to take
one key path, which could not disagree with itself; two halves can. A stepper that
reads the body weight and writes the daily limit would look entirely correct on
screen until the moment somebody used it. `check-swift-symbols.py` now flags any
`bind(\.a, set: { $0.b = $1 })` where `a` and `b` differ. Verified both ways:
silent on the seven real call sites, and it names the line the moment one is
crossed.

#### Render the report  (patch -57)

`ReportRenderer` fills the 37 document placeholders and the ten repeat blocks of
`report/report_template.html` from a `ReportData`. `ReportLabels` holds every word
the PDF says.

- NOT YET LOCALISED, and shaped so that becoming localised is a change of one
  initialiser rather than a change of the renderer. The defaults are the English
  strings from `res/values/strings.xml`, read out of the file rather than typed.
  Labels that take a number are closures, because Android writes them as `%1$s`
  and lets each translation put the number where its grammar wants it; the plural
  of "day" is a closure for the same reason, since other languages have up to six
  forms.
- `footer2` — the licence and warranty notice — is English on both platforms, by
  decision. The GPL's disclaimer is quoted, not paraphrased.
- `REPORT_LANG` fills `<html lang="…">`, because a WebView picks its CJK glyph
  orthography from the document language. With no hint it prints Simplified-Chinese
  glyph shapes in a Japanese report. Latin locales are unaffected, which is exactly
  why it is easy to forget.
- THERE IS NO GOLDEN HTML FILE, on purpose. The template exists so that a person
  can rearrange the report by hand without touching code; a golden file would turn
  every such edit into a failing test to re-bless, and the tool would fight the
  thing it was built for. The tests assert PROPERTIES instead: no placeholder is
  left unfilled, the renderer fills exactly the blocks the template declares, the
  charts have as many bars as labels, the KPI grid holds sixteen tiles, a hostile
  category name comes out escaped, and — in a German report — the reader's numbers
  carry a comma while every `stroke-dasharray` still carries a dot.
- Split across two files: `private` in Swift means FILE scope, and SwiftLint's body
  limit was reached at the seam where the type divides anyway — one file decides
  the document's values, the other builds its rows.

Two mistakes caught in my own tests before delivery, both of the kind that pass for
the wrong reason: the fixture had no month inside the daily limit, so the test that
checks a clean month prints an en dash could never have held; and the comment
stripper used `.` without `(?s)`, so the template's multi-line documentation comment
survived and carried its example `{{PLACEHOLDER}}` into the "nothing left behind"
assertion.

Coverage was checked mechanically, not by eye: the placeholders the template wants
and the ones the renderer sets are the same 37, with none left over on either side.

#### Make Swift round a number the way Kotlin does  (patch -56)

Before the report can print a figure, the two platforms have to agree on what the
figure IS. They did not.

`String.format(locale, "%.1f", x)` rounds HALF UP, applied to the shortest decimal
representation of the double. C's `printf` — which is what Swift's
`String(format:)` calls — rounds the exact binary value to nearest, ties to even.
Measured, on OpenJDK 21 and on glibc, not assumed:

| value | Kotlin `%.1f` | printf `%.1f` | Kotlin `%.0f` | printf `%.0f` |
|-------|---------------|---------------|---------------|---------------|
| 0.25  | 0.3           | 0.2           | 0             | 0             |
| 2.5   | 2.5           | 2.5           | 3             | 2             |
| 20.5  | 20.5          | 20.5          | 21            | 20            |
| 12.35 | 12.4          | 12.3          | 12            | 12            |

A daily limit of 20.5 g — a limit a person might actually set — would print as
"21" in the Android report and as "20" in the iOS one, from the same data, on the
same day. Nobody would ever have filed that bug; they would simply have stopped
trusting the app.

`ReportFormatting` therefore does NOT use `String(format:)` for anything a reader
sees. It rounds the shortest decimal representation with `NSDecimalRound(.plain)`
— half away from zero, which is HALF_UP for the non-negative values this app deals
in — and only then asks a locale-aware formatter for the decimal mark. Grouping is
off, because `%.1f` never groups and 1234.5 must not become "1,234.5".

`ReportChart.svgNumber` stays on `String(format:)`, and that is the exception that
shows the rule: it feeds a renderer, not a reader, so it wants POSIX and does not
care which way a tie falls.

New shared vectors, `test-vectors/report-format.json`, 42 cases across three
locales. EVERY EXPECTED STRING WAS PRODUCED BY THE JVM rather than typed by hand:
the file is the JVM's own output, and the Swift implementation reproduces all 84
comparisons. Kotlin's `NumberFormatVectorTest` reads the same file, where it acts
as a guard: if a Kotlin change ever alters how a gram figure is printed, it fails
there first, before the two reports drift apart.

#### Restore the KDoc adjacency broken by patch -54  (patch -55)

`release-check.sh --Werror` refused the tree: `PdfReportBuilder.categoryColor`
appeared to have no KDoc. It has one, and always did. Patch -54 slipped three
`//` lines — the reason the function is `internal` — BETWEEN the KDoc and the
declaration, and the check looks for a KDoc immediately above, skipping only
blank lines and annotations. `pct` and `chartLabelIndices` kept their KDoc
adjacent and were never flagged.

The rationale is not deleted; it belongs to the reader of that function. It is now
a paragraph INSIDE the KDoc, where the tool can see it and a reader still finds it.

Verified by running the check's own heuristic, extracted from the script, rather
than by reasoning about it: silent on the corrected file, and it names
`categoryColor` again the moment a comment is put back between the two.

#### Port the report's presentation arithmetic  (patch -54)

The renderer divides cleanly into arithmetic that decides what the PDF LOOKS like
and text that decides what it SAYS. The arithmetic needs no language, so it is
ported first and pinned by shared vectors; the text waits for localisation.

- `ReportChart` and `ReportPalette`: bar heights, axis-label thinning, donut
  geometry, category colours.
- THE AXIS-LABEL STEP IS A 32-BIT FLOAT. Kotlin writes
  `((n - 1).toFloat() / (target - 1))`, and the truncation that follows lands on
  different indices than the same expression in `Double` — for 16 of the first 400
  series lengths, `n = 32` among them, which is a month of daily buckets. Ported
  as `Double`, iOS would have drawn a different x-axis than Android for the same
  drinking. Swift uses `Float`, a vector pins `n = 32`, and both suites carry a
  test that FAILS if the two ever agree, because agreement would mean the `Float`
  was quietly widened.
- Bar heights: a dry bucket and a bucket that never occurred both draw nothing,
  while a tiny non-zero value keeps a two-percent sliver — one beer in a heavy
  month must not round to abstinence.
- Donut geometry: `stroke-dasharray` on a circle of radius 15.9155, whose
  circumference is very nearly 100, so a slice's dash length IS its percentage.
  Numbers are formatted POSIX: SVG reads `,` as a list separator, so a German
  `40,00 60,00` would become the four values `40 0 60 0` and paint the ring solid.
  Kotlin escapes this with `Locale.ROOT`; Swift's `String(format:)` already does
  it, and the locale is passed anyway — a requirement stated in code outlives one
  stated in a comment.
- `PdfReportBuilder.pct`, `.chartLabelIndices` and `.categoryColor` become
  `internal` so the Kotlin vector test can reach them. The Android renderer is
  otherwise untouched.

New shared vectors, `test-vectors/report-chart.json`, read by `ReportChartTests`
(Swift) and `ReportChartVectorTest` (Kotlin).

Delivered pre-checked: ktlint over the Kotlin, SwiftLint `--strict` over the Swift.

#### Fix two compile errors from patch -52  (patch -53)

- `DayResolver.addingDays` already existed, PRIVATELY, a few lines above where a
  second copy was added. The grep that should have found it asked for `addDays`
  and `nextDay`. Looking with the wrong name is not looking. The duplicate is gone
  and the original is now `public`, carrying the reasoning that was written for
  the copy.
- `categoryStats` chained `map` into an unannotated tuple, into `sorted`, into
  `map(\.stat)`. Swift's type checker gave up: "unable to type-check this
  expression in reasonable time". Rewritten as explicit steps with a named local
  type. The behaviour is unchanged and the vectors still pin it.
- `tools/check-swift-symbols.py` gains a duplicate-declaration check, because the
  first error was mechanical and a grep with the right name would have caught it.
  Its first draft keyed on the function name and argument labels, and promptly
  flagged three LEGAL overloads — `encode(_ value: Double)` beside
  `encode(_ value: String)`. Swift distinguishes overloads by label AND by type,
  so the types are part of the key. Verified three ways: silent on the corrected
  tree, loud on the real duplicate, silent on overloads that differ by label and
  on overloads that differ by type.

The type-checker timeout is not mechanically catchable and remains the compiler's
to find. The redeclaration now is.

#### Port the report's figures  (patch -52)

`ReportData` is the Swift counterpart of Android's `PdfReportData.from`. It
computes and does not format: no locale, no number formatting, no HTML. That is
what makes every figure testable.

- Wherever the Statistics screen already answers a question, the report asks the
  SAME code — `countLimitViolations`, `bucketize`, `weekdayAverages`,
  `computeLongestAbstinence`. A report that disagreed with the screen would be
  worse than none: the user would not know which to believe.
- New here, and nowhere else: medians, binge days, the monthly table, the 24-hour
  profile, the rolling seven-day peak.
- `DayResolver` gains `addingDays` and `inclusiveDates`, because date arithmetic
  belongs in the file that owns the noon-anchor trick. Adding 86400 seconds is not
  adding a day; some days are 23 hours long.
- TIES BETWEEN CATEGORIES ARE BROKEN BY FIRST APPEARANCE. Kotlin accumulates into
  a `linkedMapOf` and `sortedByDescending` is stable, so equal grams keep the order
  the log first mentioned them in. Swift's `Dictionary` has no order and
  `sorted(by:)` is not stable — two equal categories would come out in whichever
  order the hash seed chose that morning. The index is carried explicitly, and a
  vector pins it.
- A partial month divides by ITS DAYS INSIDE THE PERIOD, not by the month's full
  length, or a month begun yesterday would look like a very sober one.
- The abstinence streaks anchor at the day after a historical range ends, not at
  the real today — Android's v0.81.0 lesson, ported with its reasoning. A test
  asserts the impossible thing that bug produced: current abstinence exceeding the
  longest.

Shared vectors, `test-vectors/report-data.json`, read by BOTH suites — Swift's
`ReportDataTests` and Kotlin's new `ReportDataVectorTest`, which is the Kotlin
side's first vector coverage of these figures.

SCOPE, STATED HONESTLY: the vectors pin only what does not depend on the device
time zone, the device locale or the real clock. `PdfReportData.from` reads all
three itself, so its hour-of-day profile, weekday columns and streaks cannot be
driven from a file without reshaping the Kotlin signature. Swift injects all
three, so those fields are covered by Swift tests instead. Where a figure can be
shared, it is shared; where it cannot, the reason is written down rather than the
gap being papered over.

Delivered pre-checked: ktlint over the Kotlin (it caught an import order), and
SwiftLint `--strict` over the Swift.

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
