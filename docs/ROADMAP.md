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

# Roadmap

This roadmap describes both the intended direction of Libellus Potionis and the
concrete open tasks currently on the table, so it doubles as the project's task
list. It is a statement of intent, not a promise: priorities may shift, and items
may be reordered, deferred, or dropped.

Two areas are tracked in their own documents, because both are long enough to
crowd out everything else and both are read on their own: accessibility and the
OpenSSF badges. The sections below name them and link to them.

## Accessibility

**No WCAG level is claimed, and none of the W3C WCAG conformance logos is used.**
The app follows accessibility best practices, but a conformance logo is a formal
claim that every success criterion of the chosen level is met, backed by a
thorough human evaluation — W3C states explicitly that no automated or tool check
suffices — and no such evaluation has been performed. There are also verified
unmet Level AA criteria, and the logos are web-page scoped (WCAG = *Web Content*
Accessibility Guidelines), which does not map onto a native mobile app.

What the app supports today is a capability list, not a conformance claim:
screen-reader names on all interactive controls, a one-line summary on each drawn
chart — apart from the iOS category ring, which is silent because the legend
beneath it states every slice in full — a per-app language selector with RTL
support, `sp`-based text that honours the system font scale, and an
under/over-limit palette that is blue versus red rather than a red/green pair.
Where a measurement or a criterion decided the shape of the code, the reasoning
sits beside that code, in `ui/theme/Color.kt` and in the views it applies to.
A regression guard exists in `tools/release-check.sh` §13, which fails the build
if any `Icon` inside an `IconButton` is left with `contentDescription = null`. It
is a labelling invariant only and deliberately asserts no WCAG conformance, which
a static check cannot.

Two things are open:

- **Contrast on iOS is unmeasured.** Android's status palette carries a measured
  ratio beside every colour; iOS takes the same states from the system palette
  (`.secondary`, `.orange`, `.red`), where no value has been read in either
  appearance.
- **No evaluation has been run on device.** Text at 200 %, reflow at the largest
  display size, focus order with a keyboard, and a right-to-left pass are
  untested on both platforms.

## OpenSSF badges

The project holds the OpenSSF Best Practices passing badge and OSPS Baseline
Levels 1 and 2. Seven criteria across silver, gold and Level 3 are open; each
carries its status and its reasoning in
[../.bestpractices.json](../.bestpractices.json), which `make bestpractices`
compares against the badge site. Four of the seven — `access_continuity`,
`bus_factor`, `contributors_unassociated` and `two_person_review`, the last of
which reappears as `OSPS-QA-07.01` — need a second person rather than a change to
the software.

## Longer-term direction (~12 months)

Forward-looking directions, roughly in priority order:

- **Split the CHANGELOG archive** (repository hygiene). `CHANGELOG.md` has grown
  past 6,600 lines; every review diff and several release gates read the whole
  file on each run. Move the older, released entries into a
  `docs/CHANGELOG-archive.md` and keep only the current and recent versions in
  the top-level file. This is deferred rather than done because three gates bind
  the file's structure and must move with it, not break: `md-syntax.py` requires
  every `## vX.Y.Z` heading to run STRICTLY newest-to-oldest across the whole
  file (a split would leave each file internally descending, but the archive
  boundary and the check's per-file scope need adjusting together), while
  `version-consistency.sh` and `changelog.sh` read the TOP entry and the body
  beneath it — both must keep resolving to the live file. The archive split is
  therefore a small, careful change (move entries, retune the monotonicity
  check's scope, keep the version anchor in the live file) rather than a pure
  cut, and it earns its keep only once the file is large enough that the read
  cost bites — which it now is.
- **Stay current and maintained.** Keep the dependency stack up to date — Android
  Gradle Plugin, Gradle, the Kotlin toolchain, and the AndroidX/Jetpack and
  Compose libraries — and track new stable Android API levels, without
  compromising the minimal-permission, offline-first design.
- **Improve the translations.** English and German are hand-authored; all other
  locales are machine-generated. Improve those locales as native-speaker
  corrections arrive (see the translation workflow in
  [../CONTRIBUTING.md](../CONTRIBUTING.md)) and keep every locale complete.
- **Small, in-scope UX and feature refinements.** Incremental improvements to the
  existing screens and reports that stay within the app's purpose, without
  expanding its scope or permissions.
- **Android's colour design on iOS, as an opt-in.** iOS currently draws the
  status colours from the system semantic palette — `Color.red` and `Color.green`
  on the Statistics screen, `.green` / `.orange` / `.red` in `TrafficLightDot` —
  where Android uses hand-tuned hexes picked for WCAG contrast against each theme
  background, `successColor()` and `warningColor()` in `ui/theme/Color.kt`. The
  two therefore agree on meaning and differ in shade. This item would carry
  Android's palette to iOS and put it behind a switch in the Settings screen's
  Appearance section, so a user who runs both platforms can make them match. Note
  that this revisits a documented decision rather than filling a gap: the porting
  stance recorded in `StatsScreen.swift` is that a native app should read the
  native palette. The scope is a colour source indirection plus one new setting,
  which brings the settings model, its sanitizer, the backup format's settings
  block and the shared `backup-settings.json` vector with it.
- **A guided tour on first launch, and from the help menu.** A short walkthrough
  of the main screens shown once after installation, and reachable afterwards
  from the overflow menu's "Help" entry — which today opens the user's guide and
  nothing else — so the tour can be replayed rather than only dismissed. The cost
  sits less in the walkthrough than in its text: every step is user-facing prose
  in 21 languages, in both string catalogues, and the guide itself would need to
  stay in step with it.
- **Hebrew, and with it the first right-to-left language.** Hebrew is the
  candidate that would take the app past its Latin/Cyrillic/CJK set: both stores
  carry it, as `iw-IL` on Play and `he` on the App Store, and
  `android:supportsRtl="true"` has been set all along. Layout mirroring in
  Compose and SwiftUI comes free, but three places do not follow: the charts in
  `ChartComponents.kt` are drawn on a `Canvas` from x coordinates the code
  computes itself, `report/report_template.html` carries no `dir` attribute, and
  six Compose call sites pin an explicit alignment. Hebrew also brings the plural
  category `two`, which no shipped language needs today and which
  `plural-days.json` and both vector suites would have to learn. One further
  point wants a device rather than a decision: this file's tag maps to the
  resource qualifier unchanged, so `he` would give `values-he`, while Android has
  carried Hebrew under the legacy code `iw` — which of `values-he`, `values-iw`
  and `values-b+he` actually resolves has to be tried, because the wrong one
  falls back to English in silence.
- **Plausibility guards for the shell gates' own extractions.** Several checks in
  `tools/release-checks/` derive a set from a source file with a grep pipeline —
  `locale-consistency.sh`, for one, builds its locale tags from
  `grep 'Locale("' … | grep -oE … | sort`. Nothing then asks whether the result
  is the size it should be. Should such a pipeline ever come back short, the
  check does not report an unreadable input; it reports a content mismatch, and
  the message actively misleads: one seen in the field claimed a store locale
  mapped to no shipped translation while the very next line asserted the same
  translation existed. A single comparison of the extracted count against the
  number of source lines would turn that class of confusion into a plain "input
  not read completely". Cheap, and it makes every future failure of these gates
  mean what it says.
- **Gradle dependency verification, if it is worth its upkeep.** The build pins
  every dependency by VERSION, not by content: nothing checks that the artifact
  a repository serves is the one the catalogue names. Gradle answers that with
  `gradle/verification-metadata.xml`, and the project carried such a file
  briefly before it was taken out again. What that attempt established, so the
  next attempt does not rediscover it:

  The file was generated in the most maintenance-heavy configuration Gradle
  offers — `verify-metadata` on, `verify-signatures` off, so every artifact is
  covered by a per-version checksum. In that shape EVERY dependency bump
  invalidates the file, and regenerating it correctly is harder than it looks:
  a task Gradle reports as up to date resolves nothing and therefore records
  nothing, KSP pulls its processor and coroutines through a detached
  configuration at task-execution time, the CycloneDX plugin cannot run in the
  same invocation as the assemble tasks, and an artifact already in the local
  cache is reused without being read and so goes unrecorded. Four regeneration
  attempts each failed on a different one of these, the last of them in CI,
  where a fresh runner needs exactly what a developer machine had not fetched.

  The way out is not a better regeneration command. It is the configuration:
  prefer `<trusted-key>` entries over checksums wherever an artifact is signed,
  because one key covers every release signed with it and a version bump then
  leaves the file untouched — the trade being that a key entry trusts the key
  rather than the bytes, so a malicious release signed with a stolen key would
  pass where a checksum would not. Checksums stay for what is unsigned, in
  practice mostly Gradle Plugin Portal artifacts. Automated upkeep exists too:
  Renovate maintains the file when it finds one, which Dependabot (what the
  project runs today, for advisories only) does not.

  Deferred rather than dropped: the protection is real, and F-Droid rebuilding
  the published APK from this repository is a good reason to want it. But it is
  a security decision about whom to trust, not a build chore, and it should be
  taken deliberately — decide the trust model first, then let the file follow
  from it.
- **Run the test and lint suites in the canonical pipeline.** The GitLab pipeline
  runs the device-free checks and a lockfile SCA scan on a small `python:3-slim`
  image. What it does not run are the TEST and LINT suites: `./gradlew
  testDebugUnitTest` and `lintDebug` (Android Lint is enforced locally by the
  `abortOnError` build gate today), and ideally `swift test` for the Swift package.
  GitLab's instance runners are a metered allowance, so the question is whether a
  heavier image fits the monthly compute quota rather than whether it is an
  imposition. In rising order of cost:
  1. **A scheduled pipeline** (Build > Pipeline schedules, free plan) would run the
     existing checks nightly without adding a megabyte.
  2. **An Android SDK image** would carry `./gradlew testDebugUnitTest`, `lintDebug`
     and the Kover coverage run. UNIT tests need the SDK but NOT an emulator, so
     this is a container job, not a virtualisation problem. Pin the image to a
     version matching the local toolchain to avoid CI-vs-local drift.
  3. **`make check-reuse` as its own job.** Its exclusion from `check-static` is
     self-imposed — the aggregate is kept pip-free so the small image needs no
     install step. A separate job may `pip install reuse`.
  What stays out of reach, so it is not re-investigated: the Swift suite cannot run
  on Linux, because PotillusKit's sources import `CryptoKit` and `Security`, and
  porting the crypto layer to swift-crypto is a change to shipping code for a CI
  convenience. Instrumented tests need an emulator and thus nested virtualisation,
  which instance runners do not offer.
  Note what none of this buys: no badge tier changes. The open badge criteria are
  people, not pipelines (see "OpenSSF badges" above). The widening is worth doing
  for the tighter net it gives the maintainer.
- **Unify VEX with the scanner, and publish it as a feed.** The project records
  non-exploitable advisories in a machine-readable VEX document,
  [../openvex.json](../openvex.json) (OpenVEX), kept in step with the scanner's
  `osv-scanner.toml` triage by `tools/check-vex.py` (see
  [../SECURITY.md](../SECURITY.md), "Dependency monitoring"). Two improvements
  remain, both blocked on upstream rather than on effort here. First, osv-scanner
  does not yet consume VEX; once it does, the VEX document can drive suppression
  directly and the parallel `osv-scanner.toml` ignores — and `check-vex.py` — can
  be retired. Second, the in-repo document could be published as a release asset
  alongside the SBOM, so downstream consumers can fetch it. Neither is pressing
  while the dependency set is clean and the VEX document therefore empty.
- **iOS PDF report rendering (footer and layout parity).** A conscious omission,
  not an oversight, and no blocker for the port. The two-page report is rendered
  by the app itself and rasterized into store screenshots 07–08 by
  `make screenshots-ios`, fully non-interactively (unlike Android's semi-manual
  `report-pdfs`). The WebKit-printed iOS output does not yet match Android's
  layout exactly — the footer placement in particular is still off — and this
  imperfection is knowingly accepted as VISIBLE in the 07–08 screenshots for now.
  Bringing the iOS `ReportRenderer` output into full parity with Android (footer
  position, the `min-height: 267mm` sheet, and the two-page split) is a
  template/renderer tweak; the capture pipeline already produces the pages, so
  this is polish.
- **Independent iOS reproducibility verification** (`build_repeatable`,
  `build_reproducible`). `make release-ios` already rebuilds the archive twice on
  the pinned Xcode and refuses to stage unless the two unsigned `Potillus.app`
  payloads are byte-for-byte identical, so the iOS build is self-verified
  reproducible. What Android gets from F-Droid but the App Store cannot provide is
  an *independent* rebuilder; a cross-machine or third-party reproduction check
  would raise this from self-attested to externally verified.
- **Re-visit explicit iOS App Transport Security.** ATS is currently left at its
  strict Xcode default, which is correct: the app makes no network connections at
  all, so there is nothing for an explicit declaration to harden, and the only way
  to state one (a nested Info.plist dictionary) would trade a working
  `GENERATE_INFOPLIST_FILE` setup for either an `info:`/`properties:` block or a
  PlistBuddy build step, all for zero behavioural change. If a future auditor or a
  store reviewer wants an explicit `NSAllowsArbitraryLoads = false` on record as a
  visible commitment, revisit this and add it deliberately, verifying the
  Info.plist generation stays intact.
- **iOS branch coverage (parity with Android).** The new iOS `cover-check` enforces
  a LINE floor of 90 (matching Android's Kover LINE bound -- the gold
  `test_statement_coverage90` level) over PotillusKit, which clears it with
  headroom (`make -C ios cover-check` prints the current figure). It is
  line-only: Android's Kover also enforces `BRANCH >= 80`, but the
  `swift test`/llvm-cov path yields no branch data (the branch column comes back
  empty). Closing that parity gap -- toward the gold `test_branch_coverage80` on both
  ports -- needs a toolchain path that emits Swift branch coverage.
- **UI / instrumented-test coverage on both platforms** (developer tooling). The
  coverage gates measure UNIT-test coverage only: Android's Kover over the JVM unit
  tests (the Compose UI layer and framework entry points are deliberately excluded),
  and the iOS `cover-check` over PotillusKit via `swift test`. Neither measures the
  UI/instrumented layer. Enriching both symmetrically -- Android via Kover's
  `androidTest`/instrumented-coverage integration (un-excluding the UI classes;
  device-bound) and iOS via `xcodebuild test -enableCodeCoverage` + `xccov`
  (simulator-bound) -- would give a "coverage incl. UI" figure on each. It is a
  larger, device-bound change on both sides and buys nothing for the OpenSSF badge
  (silver is line-only and already met; branch is unobtainable from these paths), so
  it is deferred rather than folded into the unit-coverage gates.
- **iOS on-simulator tests** (`device-tests-ios`; developer tooling). The
  app-target XCTests (`PotillusTests`, `PotillusUITests`) run today only as a side
  effect of the screenshot capture; no target runs them for their own sake. `make
  device-tests-android` already runs the Android on-device tests — the iOS
  counterpart (`xcodebuild test -scheme Potillus -destination 'platform=iOS
  Simulator,name=$(IOS_SIM_DEVICE)'`, Mac + simulator) should join it so both
  platforms have a device-test target driven from the root the same way.
- **iPad / universal app.** The iOS layouts are written adaptively, so a
  universal iPhone-and-iPad build can be added later without a rewrite. It is not
  planned for the first release; the port targets iPhone only for now.
- **Mac-independent Swift syntax pre-check (developer tooling).** A lightweight
  brace/delimiter-balance check under `tools/`, run from `gmake ios` beside the
  existing `check-swift-symbols.py`/`check-swift-tests.py` guards. None of the
  container checks verifies delimiter balance today, so the one mechanical fault
  that reached the `ios` branch — an orphaned code fragment leaving two unbalanced
  `}` in an app file (change-log patch -93) — passed every container check and was
  caught only by the Mac `xcodebuild`. A pre-check would catch that narrow class
  where the code is written, one machine and several steps earlier. Low priority:
  the full Xcode build stays the real syntax gate, so this only shortens the
  edit→Linux→Mac round-trip for typo-class errors and adds code to maintain.
- **Surface load failures on Calendar, Statistics and Drinks.** On iOS the
  `failure` field of `CalendarModel`, `StatsModel` and `DrinksModel` is recorded
  and never rendered: a failed load leaves the screen on its last good snapshot
  without telling the user, and `CalendarScreen` reads the field only as a
  success predicate after an edit. Today is the exception and shows the shape a
  fix would take — an alert whose OK button calls `clearFailure()`. Android
  arrives at the same user-visible outcome from the other direction:
  `CalendarViewModel` and `StatsViewModel` carry no failure field at all, so
  there is nothing to show. Whether these screens should gain Today's alert is a
  product decision, and it belongs to both ports at once; adding it on one side
  only is exactly the drift the shared vectors exist to prevent. Low priority
  because every one of these reads runs against a database that has already
  opened successfully, which makes the realistic trigger narrow — but the KDoc
  on `CalendarModel.failure` points here, so the decision is recorded rather
  than implied.
- **Gradle 10 readiness (build tooling).** Configuring `:app` under Gradle 9.6
  raises four deprecation warnings for passing a `Project` object as a dependency
  notation, the form Gradle 10 will reject. None of them originates in this
  repository's build scripts. Gradle's problems report
  (`android/build/reports/problems/problems-report.html`, written by any build)
  attributes one to the Kover plugin — which the 0.9.9 upgrade in this cycle
  settles — and three to AGP's own `com.android.internal.application`. Nothing
  here can silence those three, and no AGP release is known to have addressed
  them yet; re-read the problems report when raising AGP, and again before
  moving the wrapper to Gradle 10.
  Raising AGP by a minor version is not the remedy, and it is worth knowing why
  before spending a cycle on it. The deprecation arrived with Gradle 9.6 and is
  hitting the plugin ecosystem broadly — Kover and the GraalVM native-build-tools
  filed the identical warning in May 2026 — and on the native-build-tools issue
  the Gradle team's answer was that the only way to remove it is a change inside
  the plugin. So this one clears when Google ships the fix in AGP, on Google's
  schedule, and until then the warning is a status report rather than a task.
- **AGP 10 readiness (checked, nothing to do).** A more consequential date than
  the deprecation above: AGP 9.0 deprecated the previous DSL, and per its release
  notes the ability to opt out of the new one goes away in AGP 10.0, expected
  mid-2026. This project is already clear of that migration, verified rather than
  assumed: `gradle.properties` sets no `newDsl` opt-out (it carries only
  `android.useAndroidX`), and no build script references the old variant API
  (`applicationVariants`, `libraryVariants`, `BaseVariant` or a variant's
  `outputs`). The residual risk is not the project's own scripts but its
  third-party plugins — cyclonedx, ktlint, kover, ksp — any of which may still
  reach for interfaces AGP 10 no longer exposes. Re-check their release notes
  when AGP 10 lands rather than upgrading blind.
- **The OpenSSF Scorecard badge.** Scorecard analyses a single repository on
  GitHub or GitLab and publishes a signed result from a CI job, which the move of
  the canonical repository to GitLab makes possible. Two things are missing: a
  job that runs the analysis and pushes the result, and a re-registration of the
  bestpractices.dev entry, which still names the old canonical URL. A trial run
  against the mirror scored 5.2/10, almost entirely a measurement artifact of the
  mirror topology — the host-dependent checks (Code-Review, CI-Tests,
  Contributors, Branch-Protection, Signed-Releases) were reading a repository on
  which nothing happens, while the substantive ones already scored 10. Publishing
  a score that understates the project would be worse than publishing none.

## User suggestions

Ideas raised by testers and QA reports, recorded here for consideration. Being
listed here is not a commitment to implement -- it is a place to keep external
input so it is not lost.

- **Search and category filtering for the drink library.** The library is a long
  scrolling list; a search field plus category and Favorites filters would speed
  up both entry creation and library maintenance. (QA report #4294, S-01.)
- **Optional standard-drink equivalent for gram totals.** Grams stay the primary
  unit, but an optional standard-drink equivalent could be shown alongside them,
  with a short note on the regional definition in use, so users can interpret a
  total without losing the app's precise gram-based calculation. (QA report #4294,
  S-02.)

## Explicitly out of scope (what the project will not do)

These non-goals follow directly from the project's privacy-first philosophy and
are not expected to change:

- **No network access.** The app will not request the network permission, and
  will not add cloud sync, remote backends, or any feature that transmits user
  data off the device.
- **No accounts or login.** No user accounts, no sign-in, no server-side
  identity.
- **No analytics, telemetry, crash reporting, or advertising.** Nothing that
  tracks users or monetizes their data.
- **No monetization.** The app will stay free and open source: no paid tiers,
  in-app purchases, subscriptions, paywalled features, or sale of user data.
- **No expansion of the permission profile.** The app will not add camera,
  microphone, location, contacts, or runtime storage permissions.
- **No scope creep beyond alcohol tracking.** The app will stay focused on its
  purpose rather than growing into a general health or lifestyle suite.
