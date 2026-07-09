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

1. **SQLite schema.** Both platforms use the same tables and columns so the
   domain logic maps one-to-one and a power user could, in principle, copy the
   database file across platforms. Current shape (schema version 2):
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
  OFL). GRDB.swift, for example, is MIT.
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
2. **Domain port + parity (in progress).** `AlcoholCalculator` and `DayResolver`
   are ported, with both suites green against the shared vectors — including
   `isOverLimit`'s floating-point tolerance, and the timezone- and DST-safe
   calendar arithmetic the logical day and the seven-day window depend on. Still
   to port: chart bucketing and trend. Not ported by design: the `clockOverride`
   screenshot seam and the locale-driven `firstDayOfWeekIso`, which are platform
   concerns and return with the iOS UI.
3. **Data layer.** SQLite schema (identical), repositories, JSON backup v3
   reader/writer, CSV export — verified byte-compatible with Android output.
4. **UI.** SwiftUI screens to feature parity (Today, Calendar, Statistics,
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
