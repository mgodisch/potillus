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
  past 6,600 lines, and every review diff and several release gates read it
  whole. Moving the released entries into a `docs/CHANGELOG-archive.md` is a
  careful change rather than a cut: `md-syntax.py` requires the `## vX.Y.Z`
  headings to descend strictly across the whole file, and `version-consistency.sh`
  and `changelog.sh` read the top entry and the body beneath it. All three have
  to move with the split.
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
- **Android's colour design on iOS, as an opt-in.** iOS draws the status colours
  from the system semantic palette where Android uses hand-tuned hexes picked for
  contrast against each theme background. This item would carry Android's palette
  over and put it behind a switch in the Appearance section, so a user of both
  platforms can make them match. It revisits the porting stance recorded in
  `StatsScreen.swift` — that a native app reads the native palette — and its
  scope is a colour-source indirection plus one setting, which brings the
  settings model, its sanitizer and the backup settings block with it.
- **A guided tour on first launch, and from the help menu.** A short walkthrough
  of the main screens shown once after installation, and reachable afterwards
  from the overflow menu's "Help" entry — which today opens the user's guide and
  nothing else — so the tour can be replayed rather than only dismissed. The cost
  sits less in the walkthrough than in its text: every step is user-facing prose
  in 21 languages, in both string catalogues, and the guide itself would need to
  stay in step with it.
- **Hebrew, and with it the first right-to-left language.** Both stores carry it
  (`iw-IL` on Play, `he` on the App Store) and `android:supportsRtl="true"` has
  been set all along, but three places do not mirror by themselves: the `Canvas`
  charts in `ChartComponents.kt`, the missing `dir` attribute in
  `report/report_template.html`, and six Compose call sites that pin an explicit
  alignment. Hebrew also brings the plural category `two`, which
  `plural-days.json` and both vector suites would have to learn. Which resource
  qualifier actually resolves — `values-he`, `values-iw` or `values-b+he` — has
  to be tried on a device, because the wrong one falls back to English silently.
- **Plausibility guards for the shell gates' own extractions.** Several checks in
  `tools/release-checks/` derive a set from a source file with a grep pipeline,
  and nothing asks whether the result is the size it should be. A pipeline that
  comes back short is reported as a content mismatch rather than as an unreadable
  input, and the message misleads: one seen in the field claimed a store locale
  mapped to no shipped translation while the next line asserted that translation
  existed. Comparing the extracted count against the number of source lines would
  turn that into a plain "input not read completely".
- **Gradle dependency verification, if it is worth its upkeep.** The build pins
  every dependency by version, not by content. Gradle's
  `gradle/verification-metadata.xml` answers that; the project carried one
  briefly and took it out again, and what the attempt established is recorded in
  the header of `android/gradle/libs.versions.toml`. Deferred rather than
  dropped: F-Droid rebuilding the published APK from this repository is a good
  reason to want it, but it is a decision about whom to trust rather than a
  build chore, so decide the trust model first and let the file follow.
- **Run the test and lint suites in the canonical pipeline.** The GitLab pipeline
  runs the device-free checks and a lockfile SCA scan on a small `python:3-slim`
  image; the test and lint suites (`./gradlew testDebugUnitTest`, `lintDebug`,
  the Kover run) still happen locally. Instance runners are a metered allowance,
  so the question is what fits the monthly quota. In rising order of cost: a
  nightly scheduled pipeline over the existing checks; an SDK-bearing image for
  the unit tests and lint, which need the SDK but no emulator; and
  `make check-reuse` as its own job, since its exclusion from `check-static` only
  keeps the small image pip-free. Two things stay out of reach and are not worth
  re-investigating: the Swift suite cannot run on Linux, because PotillusKit
  imports `CryptoKit` and `Security`, and instrumented tests need virtualisation
  the instance runners do not offer. No badge tier changes either way — the open
  criteria are people, not pipelines.
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
- **UI / instrumented-test coverage on both platforms** (developer tooling). Both
  coverage gates measure unit tests only — Kover over the JVM tests on Android,
  `cover-check` over PotillusKit on iOS. A "coverage incl. UI" figure would need
  Kover's instrumented integration on one side and `xcodebuild test
  -enableCodeCoverage` with `xccov` on the other, both device-bound. Deferred: it
  buys nothing for the badge, where line coverage is already met and branch
  coverage is unobtainable from these paths.
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
  brace-balance check under `tools/`, run from `gmake ios` beside the existing
  Swift guards. No container check verifies delimiter balance today, and the one
  mechanical fault that reached the `ios` branch — an orphaned fragment leaving
  two unbalanced `}` — passed every one of them and was caught only by
  `xcodebuild`. Low priority: the Xcode build stays the real syntax gate, so this
  only shortens the round-trip for typo-class errors.
- **Surface load failures on Calendar, Statistics and Drinks.** On iOS the
  `failure` field of `CalendarModel`, `StatsModel` and `DrinksModel` is recorded
  and never rendered; on Android the two ViewModels carry no such field at all.
  Today shows the shape a fix would take, an alert whose OK calls
  `clearFailure()`. Whether the other screens should gain it is a product
  decision belonging to both ports at once. Low priority: every one of these
  reads runs against a database that has already opened.
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
