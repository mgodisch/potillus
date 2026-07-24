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
list. Near-term work is listed first, ordered by criticality (most critical
first), followed by the longer-term direction and — just as importantly — what
the project deliberately will **not** do. It is a statement of intent, not a
promise: priorities may shift, and items may be reordered, deferred, or dropped.

Many near-term items arose while working toward the OpenSSF Best Practices badges
(project 13480); each notes its originating criterion in `code` font for
traceability.

## Current state: the iOS port

Libellus Potionis is no longer Android-only. A native Swift/SwiftUI port lives in
this same repository under `ios/`, sharing the data-interchange backup format (not
live sync) and a single human-readable version with Android. It is feature-complete
for daily use — the five screens, CSV and PDF export, the app lock, the twenty UI
languages with localised report and plurals — and its behaviour is pinned to
Android's by a shared set of golden test vectors. Two Android features are
consciously not ported (the calendar year heat-map and, pending on-device
verification, a PDF footer tweak); both are recorded as possible future work below.
The design and parity strategy are recorded in the `v0.82.0`
[changelog](../CHANGELOG.md) entry and enforced by the shared golden test vectors
in `test-vectors/`. What is still open is App Store distribution
(listing, screenshots, and the compliance declarations), tracked below.

## Blocking the OpenSSF silver badge (MUST)

These silver-level MUST criteria are currently unmet; the silver badge is not
attainable until each is resolved. They are the most critical open items.

- **Continuity arrangement** (`access_continuity`). Ensure the project can
  continue — issues, changes, and releases within a week — if the sole
  maintainer becomes unavailable. Designate a trusted successor or co-maintainer
  with the necessary repository access and legal rights, and document the
  arrangement in `docs/GOVERNANCE.md`. F-Droid distribution helps (its
  reproducible-build re-signing removes the private-key hand-off) but is not
  itself a successor.
- **Continuous integration** (`automated_integration_testing`). A GitLab CI
  pipeline (`.gitlab-ci.yml`) now replaces the Woodpecker pipeline the project
  ran while hosted on Codeberg. It stands where the old one stood — device-free
  only, no build — and runs three jobs on a plain `python:3-slim` image: the two
  gates that pass in the QA log, `tools/release-check.sh --Werror` and
  `make check-static`, which together cover the shared invariants plus the iOS
  static checks reproduced in Python (Swift symbol/length/test linting, l10n
  parity, store-metadata limits, ...), so the Swift toolchain is covered without
  a Mac; plus a `dependency-scan` job running osv-scanner over the committed
  lockfiles on every change (see the security work below and
  [../SECURITY.md](../SECURITY.md), "Dependency monitoring"). A workflow rule
  restricts it to merge requests targeting `main`; `main` is protected against
  direct pushes, so no second path into it needs its own trigger. A full Android
  build (`lintDebug`, `./gradlew testDebugUnitTest`, instrumented tests) needs
  the SDK and an emulator; an iOS build needs macOS + Xcode and cannot run on a
  hosted Linux runner at all — so building, and running the unit-test/lint
  suites in CI, stays out of this first pipeline and remains its own heavier
  item below ("Run the test and lint suites in CI"). CI also settles
  `test_continuous_integration` (SUGGESTED at passing, a MUST at gold) and
  contributes to `static_analysis_often`.
  The gate is enforced, not advisory: *Merge requests > "Pipelines must
  succeed"* is enabled, so a red pipeline blocks the merge. With that in place
  the CI-conditional answers in `.bestpractices.json` are Met again — sanitize
  and validate untrusted inputs (`OSPS-BR-01.01`), deny untrusted code snapshots
  access to privileged credentials (`OSPS-BR-01.03`), least-privilege default
  permissions and job permissions (`OSPS-AC-04.01`, `OSPS-AC-04.02`), status
  checks before merge (`OSPS-QA-03.01`) and automated per-change
  dependency-policy enforcement (`OSPS-VM-05.03`). `OSPS-QA-03.01` was the
  single control keeping OSPS Baseline Level 2 incomplete, so **Level 2 is
  complete again**. `OSPS-BR-01.04` stays N/A on purpose: it is conditional on a
  pipeline that accepts collaborator input, and this one has no manual trigger,
  no inputs and no user-supplied variables.
  Two criteria stay unmet by design rather than by omission. `OSPS-QA-06.01`
  (a test SUITE inside CI) and `automated_integration_testing` wait on the
  heavier item below, and `static_analysis_often` is left unmet on both its
  counts: the analysis is tied to merge requests rather than every commit, and
  the two real linters (`./gradlew lintDebug`, SwiftLint) need an SDK-bearing
  image and a Mac runner. Running on every push to a working branch was
  considered and rejected — `main` is closed to direct pushes, so the merge
  request is the only way in and therefore the only place the gate has to sit;
  scanning half-finished intermediate commits would spend compute minutes on
  states the author already knows are unfinished. `OSPS-QA-06.01` (a test SUITE running inside
  CI) stays N/A on purpose: even the restored pipeline runs the device-free
  checks only, not the unit-test suites (which need the Android SDK and, for
  `swift test`, a Linux Swift toolchain), so claiming a CI test run would assert
  something that does not happen — that widening is the heavier item below.

## Recommended, not blocking (SHOULD)

- **Raise the bus factor** (`bus_factor`). Gain a second significant, ongoing
  maintainer — the same underlying need as the continuity arrangement above.
- **Cryptographic algorithm agility** (`crypto_algorithm_agility`). Not planned.
  Sealing the preferences blob under a second algorithm would buy no practical
  protection here and would risk moving the key out of the Android Keystore; the
  full reasoning is recorded in the criterion's justification in
  `.bestpractices.json`. Note also that the versioned blob format previously
  sketched here would *not* by itself satisfy the criterion, which asks for
  multiple algorithms rather than a migration marker. Should a self-describing,
  versioned blob (a version byte authenticated as GCM AAD, with a read-legacy /
  write-versioned migration) in `KeystoreSecretStore` be wanted anyway, it should
  be justified on its own merits as a future migration aid — a security-critical
  change requiring thorough tests, including an instrumented round-trip, a
  legacy-blob read, and tamper/downgrade rejection.
- **Re-visit explicit iOS App Transport Security.** ATS is currently left at its
  strict Xcode default, which is correct: the app makes no network connections at
  all, so there is nothing for an explicit declaration to harden, and the only way
  to state one (a nested Info.plist dictionary) would trade a working
  `GENERATE_INFOPLIST_FILE` setup for either an `info:`/`properties:` block or a
  PlistBuddy build step, all for zero behavioural change. If a future auditor or a
  store reviewer wants an explicit `NSAllowsArbitraryLoads = false` on record as a
  visible commitment, revisit this and add it deliberately, verifying the Info.plist
  generation stays intact.

## Accessibility

**Conformance status — no WCAG level is claimed.** Libellus Potionis follows accessibility
best practices but does **not** claim conformance to any WCAG 2.2 level, and it
uses **none** of the W3C WCAG conformance logos. The reasons are deliberate and
honest:

- A W3C conformance logo is a formal *claim* that **all** success criteria of
  the chosen level are met, backed by a **thorough human evaluation** — W3C
  states explicitly that no automated/tool check suffices. No such evaluation
  has been performed here.
- There are **verified unmet Level AA criteria** (listed below), so AA/AAA are
  out regardless; and at least one **Level A** item (the on-screen chart's text
  alternative) is unresolved, so even Level A is not cleanly established.
- The W3C logos are **web-page scoped** (WCAG = *Web Content* Accessibility
  Guidelines; a logo covers "a single page"). Libellus Potionis is a native mobile app;
  the per-page conformance model does not map onto it. (WCAG could be applied via
  WCAG2ICT as a written claim, but that is not a W3C logo.)

What the app *does* support today (capabilities, not a conformance claim):
screen-reader (TalkBack) names on **all** interactive controls — including, since
the sixth QA review, the calendar month/year navigation arrows, the
drink-category icon, and every year heat-map day cell that carries data
(`year_calendar_day_desc`); a per-app language selector with RTL support;
`sp`-based text that honours the system font-scale (WCAG 1.4.4); and an
under/over-limit palette that is **blue vs. red — not a red/green pair** — so it
is colour-blind distinguishable.

### Verified gaps toward Level AA (measured in the sixth QA review)

Reaching full AA is a larger effort (roughly 1.5–2.5 person-weeks plus manual
on-device assistive-technology testing that no sandbox check can replace). The
concrete, measured gaps are:

- **Non-text contrast (1.4.11, AA).** Empty heat-map cells
  (`surfaceVariant`) sit at **1.1–1.3 : 1** against the background and the
  "today" outline at **1.2–1.5 : 1** — both below the required 3 : 1. Needs a
  heat-map palette rework for cell separation and the today indicator.
- **Text contrast (1.4.3, AA).** The light-theme secondary caption colour
  (`onSurfaceVariant`) is **4.39 : 1** (below 4.5 : 1 for small text); the
  warning-red used as *text* is **3.25–4.23 : 1** in dark theme (fine as a
  non-text indicator at ≥ 3 : 1, marginal as text).
- **Target size (2.5.8, AA — new in 2.2).** The 10 dp heat-map day cells are
  below the 24 px minimum; a ≥ 24 dp (ideally 48 dp) touch target should wrap the
  10 dp visual. (Standard Material `IconButton`s already meet this.)
- **Chart text alternative (1.1.1, A).** The on-screen bar/donut chart is a bare
  `Canvas` with no `semantics`, so a screen reader gets nothing from it; it needs
  a summary or per-bar semantics. (This is the Level-A blocker above.)
- **Focus visibility / role (2.4.7 AA, 4.1.2 A).** The four custom
  `clickable` heat-map/chart surfaces need a visible focus indicator and an
  explicit `role = Button`.

Each new user-facing string (e.g. a chart summary) triggers `LocaleSyncTest`
across all locales, so these are i18n-touching changes, not one-liners.

A lightweight regression guard exists in the meantime: `tools/release-check.sh`
§13 fails the build if any `Icon` inside an `IconButton` is left with
`contentDescription = null`, so the labels the project *has* added cannot silently
regress. It is a labelling invariant only — it deliberately does **not** assert
WCAG conformance, which (per W3C) a static check cannot.

### iOS accessibility assessment (future work)

The conformance discussion, the measured Level-AA gaps, and the on-device
self-assessment protocol ([WCAG_LEVEL_A_CHECKLIST.md](WCAG_LEVEL_A_CHECKLIST.md))
above are scoped to the Android app and TalkBack. The iOS port already provides
VoiceOver names on its controls — the calendar navigation arrows and the capacity
traffic-light dot, for instance, carry explicit accessibility labels — but no
structured VoiceOver evaluation has been recorded for it, and the checklist does
not yet cover it. Future accessibility work therefore includes an iOS/VoiceOver
counterpart to that protocol: walk the same success criteria on-device with
VoiceOver, record the iOS-specific findings (the Compose-specific heat-map and
`Canvas`-chart gaps above do not transfer verbatim — the iOS chart and calendar
are separate implementations that must be assessed on their own terms), and
extend or fork the checklist so each platform's self-assessment is tracked
separately. Like the Android assessment, this is a manual on-device effort no
sandbox check can replace.

## Finalize already-documented "Met" items

These are met in the repository but depend on a maintainer action to hold in
practice.

- **Run ktlint formatting once** (`coding_standards_enforced`). Run
  `./gradlew ktlintFormat`, commit the result, and push, so `ktlintCheck` passes.
- **Sign release tags** (`version_tags_signed`). Create future release tags with
  `git tag -s` (`tag.gpgSign true` is documented); optionally re-sign the current
  release tag.

## Badge administration (bestpractices.dev, project 13480)

- Complete and submit the **passing**-badge form with the prepared justifications
  (`achieve_passing`).
- Keep the silver "Met URL" entries pointing at the moved docs: `governance` and
  `roles_responsibilities` -> `docs/GOVERNANCE.md`, `documentation_roadmap` ->
  `docs/ROADMAP.md`, `assurance_case` -> `docs/ASSURANCE_CASE.md`.
- Keep a version-controlled snapshot of the badge answers (metal series passing,
  silver, gold, plus OSPS Baseline Level 1) in `.bestpractices.json` (repository
  root), the maintained source of truth. `make bestpractices` downloads the
  current bestpractices.dev export and reports, grouped by level, which committed
  answers the site does not yet match, so the maintainer knows what to enter
  upstream (no credentials; the working tree is not touched). The reverse
  direction is unavailable here — bestpractices.dev has no path that reads a
  committed answer file back into the site, and the URL-based automation-proposal
  path is impractical because the server rejects the long URLs the full answer set
  produces. (Its repository analysis targets GitHub and GitLab, so with the move
  to GitLab that analysis at least now sees the canonical repository rather than a
  mirror.) (Baseline Level 1 is complete; Level 2 lost a single control with the
  retirement of CI and returns with it; Level 3 is in progress — see "Working
  toward OpenSSF Baseline Level 3" below.)

## OpenSSF Scorecard badge (newly in reach, pending CI)

The move of the canonical repository to GitLab removed the reason this badge was
previously ruled out. Scorecard analyses a single repository on GitHub or GitLab,
and its badge is fed by a CI job that publishes a signed result through the
forge's OIDC token. That was impossible while the canonical repository lived on a
forge Scorecard has no backend for and the GitHub/GitLab repositories were
read-only mirrors carrying no development, review, CI or release activity. Now
the canonical repository *is* one Scorecard can analyse, so the measurement would
for the first time look at where the project actually lives.

The earlier trial run against the GitHub mirror scored 5.2/10, and that shortfall
was almost entirely a **measurement artifact of the mirror topology**, not a
security weakness. The substantive checks were already maximal --
Dangerous-Workflow, Token-Permissions, Vulnerabilities, Security-Policy,
Pinned-Dependencies and License each scored 10, Binary-Artifacts 9. The low checks
were the host-dependent ones -- Code-Review, CI-Tests, Contributors,
Branch-Protection and Signed-Releases -- which measured a mirror on which nothing
happens; pointed at gitlab.com/godisch/potillus they measure real activity
instead. Two prerequisites remain before the badge can be pursued honestly:

1. **CI.** The pipeline exists and is enforced (first roadmap item above), but
   Scorecard's badge publication needs a job of its own that runs the analysis
   and pushes the signed result, and CI-Tests scores what the pipeline actually
   runs — for now the device-free checks only.
2. **Badge re-registration.** The CII-Best-Practices check reads the project's
   bestpractices.dev entry (project 13480), which is registered under the old
   canonical URL; it has to be re-pointed at the GitLab repository.

Until both are done the badge is not linked, because publishing a score that
understates the project's real posture would be worse than publishing none.

The GitHub mirror now carries supplementary GitHub Actions checks (an Android
build with lint and unit tests, plus `actionlint`/`zizmor` over the workflows
themselves — see [MIRROR-CHECKS.md](MIRROR-CHECKS.md)). This does **not** change
the conclusion above: Scorecard must still be pointed at GitLab, where the
development, review and release activity actually is. The mirror workflows are
relevant to the badge in one narrow way only — they are the surface
Dangerous-Workflow and Token-Permissions measure, which is why every action is
SHA-pinned and every file declares `contents: read`. Two follow-ups remain open
there:

- **The mirror checks now cover iOS too.** A macOS runner builds the app with
  XcodeGen and xcodebuild, runs the PotillusKit suite with its coverage floor,
  and runs real SwiftLint at the pinned version — the first time any of this
  happens outside the maintainer's own Mac. The Python reimplementations in
  `tools/check-swift-*.py` stay: they are what covers the Swift side on the
  canonical, Linux-only pipeline, which is the blocking one. The Android
  instrumentation tests run there too, on an API 36 emulator. What remains
  uncovered anywhere but locally are the iOS tests that need a booted simulator:
  the app-target XCTests and the XCUITests.
- **Decide on dependency submission.** Dependabot cannot see the Android
  dependency graph without a submitted graph, and submitting one needs
  `contents: write` on the mirror. The write scope has been declined for now;
  the consequence is that Dependabot's coverage there is limited to the
  committed lockfiles, which the GitLab scan already covers.

CodeQL also runs there now, over Kotlin and Swift, weekly and on `main`. It adds
a class of analysis the project had on neither platform: data flow across
functions and files, rather than the per-file reasoning ktlint, Android Lint,
SwiftLint and the `tools/` scripts do. Note carefully what this does **not**
settle. `static_analysis_often` and `OSPS-QA-06.01` are judged on the pipeline
that actually gates a change, and that remains the GitLab one; an advisory
analysis on a mirror does not make a criterion Met, and claiming otherwise would
be exactly the kind of overstatement the badge answers are meant to avoid. The
items above — a scheduled pipeline, an SDK-bearing image — are still the path to
those criteria.

## Working toward OpenSSF Baseline Level 3

Baseline Levels 1 and 2 are complete. Level 2 briefly lost `OSPS-QA-03.01`
(automated status checks before merge) when the move to GitLab retired the old CI
pipeline, and regained it with the GitLab pipeline and the *Merge requests >
"Pipelines must succeed"* setting (first roadmap item); `OSPS-AC-04.01` made the
same round trip.

The remaining Level 3 gaps are largely the same structural constraints as the
gold tier — a non-author human reviewer
(`OSPS-QA-07.01`, cf. `two_person_review`) and CI-based automated blocking of
policy violations:

- **Unify VEX with the scanner, and publish it as a feed** (strengthens
  `OSPS-VM-04.02`, already Met). The project records non-exploitable advisories
  in a machine-readable VEX document, [../openvex.json](../openvex.json)
  (OpenVEX), kept in step with the scanner's `osv-scanner.toml` triage by
  `tools/check-vex.py` (see [../SECURITY.md](../SECURITY.md), "Dependency
  monitoring"). Two improvements remain, both blocked on upstream rather than on
  effort here. First, osv-scanner does not yet consume VEX (support is announced
  but unreleased); once it does, the VEX document can drive suppression directly
  and the parallel `osv-scanner.toml` ignores — and `check-vex.py` — can be
  retired, removing the double bookkeeping. Second, the in-repo document could be
  published as a release asset (a VEX "feed") alongside the SBOM, so downstream
  consumers can fetch it. Neither is pressing while the dependency set is clean
  and the VEX document therefore empty.
- **Run the test and lint suites in CI (the "heavy" pipeline widening)**
  (`OSPS-QA-06.01`, `OSPS-VM-06.02`, `test_continuous_integration`,
  `automated_integration_testing`, `static_analysis_often`). The GitLab pipeline
  (first roadmap item) runs the device-free checks and a lockfile SCA scan, all
  on a small `python:3-slim` image. The remaining CI-conditional criteria ask
  specifically for the TEST and LINT suites to run in the pipeline: `./gradlew
  testDebugUnitTest` and `lintDebug` (Android Lint is enforced locally by the
  `abortOnError` build gate today, but CI would enforce it on every change), and
  ideally `swift test` for the Swift package.
  The premise this item was written under has changed with the move to GitLab,
  and the reasoning is worth restating rather than inheriting. The old pipeline
  was shaped by the principle of being a good guest on DONATED infrastructure;
  GitLab's instance runners are a metered allowance instead, so the question is
  no longer whether a heavy image is an imposition but whether it fits the
  monthly compute quota (Settings > Usage Quotas). That reframes the cost from a
  matter of courtesy into an arithmetic one.
  What that opens up, in rising order of cost:
  1. **A scheduled pipeline** (Build > Pipeline schedules, available on the free
     plan) would run the existing checks nightly. That alone settles the "on
     every commit or at least daily" half of `static_analysis_often` without
     touching the merge-request rule or adding a single megabyte.
  2. **An Android SDK image** would carry `./gradlew testDebugUnitTest`,
     `lintDebug` and the Kover coverage run. Worth being precise where the
     earlier wording was not: UNIT tests need the SDK but NOT an emulator, so
     this is a container job, not a virtualisation problem. It is what would move
     `OSPS-QA-06.01` off N/A, settle `automated_integration_testing`, supply the
     linter half of `static_analysis_often`, and produce the branch-coverage
     figure `test_branch_coverage80` is measured against. Pin the image to a
     version matching the local toolchain (as the CI osv-scanner is pinned to the
     maintainer's local version) to avoid CI-vs-local drift.
  3. **`make check-reuse` as its own job.** Its exclusion from `check-static` is
     self-imposed — the aggregate is kept pip-free so the small image needs no
     install step (see tools/check-reuse.py). A separate job may `pip install
     reuse`, which would turn the REUSE gate from local-plus-badge into an
     enforced per-merge-request check.
  What stays out of reach, and why, so it is not re-investigated:
  * **The Swift suite cannot run on Linux.** PotillusKit declares macOS as a
     platform precisely so `swift test` needs no simulator, but its sources
     import `CryptoKit` and `Security`, both Apple-only. A Linux Swift toolchain
     image is therefore not enough; it would take porting the crypto layer to
     swift-crypto, which is a change to shipping code and not worth making for a
     CI convenience. The iOS half stays locally verified.
  * **Instrumented (on-device) tests** need an emulator and thus nested
     virtualisation, which instance runners do not offer. This also keeps
     `dynamic_analysis` out of reach by that route; the Kover branch-coverage
     path remains its more likely remedy.
  Note what none of this buys: no badge TIER changes. Baseline Level 3 hangs on
  `OSPS-QA-07.01` alone (a reviewer who is not the author), and silver and gold
  hang on `access_continuity`, `bus_factor`, `two_person_review` and
  `contributors_unassociated`. Those are people, not pipelines. The widening is
  worth doing for the tighter net it gives the maintainer, and for the three
  individual criteria named above — not as a route to the next tier.

## Working toward the OpenSSF gold badge

Gold requires the silver badge first (every silver item above must be resolved).
These are the additional gold-level criteria that are not yet met, recorded as
they are assessed and ordered by criticality. Several are structural and need a
second active participant in the project.

- **Bus factor of 2 or more** (`bus_factor`, gold MUST). With a single maintainer
  the bus factor is 1. This is the silver "Raise the bus factor" item above,
  promoted to a hard requirement at gold: it needs a second, significantly
  involved maintainer.
- **Two unassociated significant contributors** (`contributors_unassociated`,
  gold MUST). Requires at least two significant contributors who are not
  associated with each other (e.g. not the same employer/organization). With a
  single maintainer this is unmet; it is resolved by the same step as the bus
  factor — a second, independent contributor.
- **Two-person review of >= 50% of changes** (`two_person_review`, gold MUST).
  Requires at least half of all proposed modifications to be reviewed before
  release by someone other than their author. The review process itself is
  documented (CONTRIBUTING.md, "Code review requirements"), but with a single
  author-reviewer no change is reviewed by a second person. Resolved by the same
  step as the two items above — a second, independent maintainer who can review.
- **Branch coverage >= 80%** (`test_branch_coverage80`, gold MUST; also unlocks
  `dynamic_analysis`). *Priority 2 — deliberately not forced.* Kover is fully
  integrated and enforced: statement coverage is ~97% and branch coverage ~80%,
  with a build-breaking floor (`koverVerify`: LINE >= 90 / BRANCH >= 75) wired
  into the release gate (`make cover-check`). Reaching the gold threshold needs
  branch coverage at or above 80%; the last few percent of branches sit in
  Android-/Compose-adjacent code (ViewModel `StateFlow` assembly, resource-bound
  error mapping) that is awkward to exercise from JVM unit tests. Closing the gap
  — via targeted tests or a small refactor that makes that logic pure — also
  satisfies the gold `dynamic_analysis` criterion (an automated suite at that
  coverage counts as dynamic analysis). The related passing `test_most` and the
  silver/gold statement-coverage criteria (`test_statement_coverage80`,
  `test_statement_coverage90`) are already met.

## Longer-term direction (~12 months)

Lower-criticality, forward-looking directions, roughly in priority order:

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
- **Two deferred iOS parity items (possible, not planned).** Both are conscious
  omissions, not oversights, and neither blocks the port:
  - *Calendar year view.* Android's calendar offers a Month/Year toggle whose
    year layout is a 12-month heat-map of coloured day squares. iOS ships the
    month view only, because the *analytical* year overview it would duplicate is
    already covered by the Statistics screen's `year` period (KPIs, trend, and a
    monthly-bucket chart). The year heat-map would be a second, purely visual take
    on the same data; it can be added later if it proves wanted.
  - *iOS PDF report rendering (footer and layout parity).* The two-page report is
    now rendered by the app itself and rasterized into store screenshots 07–08 by
    `make screenshots-ios`, fully non-interactively (unlike Android's semi-manual
    `report-pdfs`). The WebKit-printed iOS output does not yet match Android's
    layout exactly — the footer placement in particular is still off — and this
    imperfection is knowingly accepted as VISIBLE in the 07–08 screenshots for now.
    Bringing the iOS `ReportRenderer` output into full parity with Android (footer
    position, the `min-height: 267mm` sheet, and the two-page split) is a
    template/renderer tweak, deferred here; the capture pipeline already produces
    the pages, so this is polish, not a blocker.
- **Publish on the Google Play Store.** In addition to F-Droid, make the app
  available on Google Play so more users can find and install it.
- **Publish on the Apple App Store.** The iOS port is feature-complete (see
  below); what remains before submission is App Store tooling — the store
  listing, screenshots, and the export-compliance and privacy declarations.
- **Independent iOS reproducibility verification** (`build_repeatable`,
  `build_reproducible`). `make release-ios` already rebuilds the archive twice on
  the pinned Xcode and refuses to stage unless the two unsigned `Potillus.app`
  payloads are byte-for-byte identical, so the iOS build is self-verified
  reproducible. What Android gets from F-Droid but the App Store cannot provide is
  an *independent* rebuilder; a cross-machine or third-party reproduction check
  would raise this from self-attested to externally verified.
- **iOS branch coverage (parity with Android).** The new iOS `cover-check` enforces
  a LINE floor of 90 (matching Android's Kover LINE bound -- the gold
  `test_statement_coverage90` level) over PotillusKit, which measures ~94.8%. It is
  line-only: Android's Kover also enforces `BRANCH >= 75`, but the
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
