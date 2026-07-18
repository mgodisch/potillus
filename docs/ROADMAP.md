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
- **Continuous integration** (`automated_integration_testing`). Add a Woodpecker
  pipeline (`.woodpecker.yml`) on Codeberg that runs the automated test suite on
  each push and reports success/failure. `./gradlew testDebugUnitTest` plus
  `lintDebug` and `ktlintCheck` is sufficient; instrumented tests need an
  emulator and are optional. The iOS side has no CI runner yet; once the pipeline
  exists it should also run the Swift package suite (`swift test` in
  `ios/PotillusKit`) and the container-runnable `tools/` checks, so the Swift
  toolchain is covered too. Requires enabling Woodpecker for the repository.
  Also satisfies `test_continuous_integration` (SUGGESTED at passing, a MUST at
  gold) and `static_analysis_often`, and is the natural home for the periodic
  `osv-scanner` run (see [../SECURITY.md](../SECURITY.md), "Dependency monitoring").
  When added, the pipeline should be configured to satisfy the CI-conditional OSPS
  Baseline controls that are answered N/A today for want of any CI, across Level 1
  and Level 2: sanitize and validate untrusted inputs (`OSPS-BR-01.01`), deny
  untrusted code snapshots access to privileged credentials (`OSPS-BR-01.03`), run
  with least-privilege default permissions (`OSPS-AC-04.01`), and run the test
  suite and any status checks in the pipeline before merge (`OSPS-QA-06.01`,
  `OSPS-QA-03.01`).

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

**Conformance status — no WCAG level is claimed.** Potillus follows accessibility
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
  Guidelines; a logo covers "a single page"). Potillus is a native mobile app;
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
  root). This is a one-way mirror site -> repo: the maintainer edits answers on
  bestpractices.dev, and `make bestpractices-json` pulls them back into the file
  from the site's own JSON export (no credentials; review `git diff` before
  committing). The reverse direction is unavailable here — bestpractices.dev's
  automation does not ingest a `.bestpractices.json` committed to a Codeberg
  repository (its repository analysis targets GitHub/GitLab), and the URL-based
  automation-proposal path is impractical because the server rejects the long URLs
  the full answer set produces. (Baseline Level 2 is complete; Level 3 is in
  progress — see "Working toward OpenSSF Baseline Level 3" below.)

## Working toward OpenSSF Baseline Level 3

Baseline Levels 1 and 2 are complete. The remaining Level 3 gaps are largely the
same structural constraints as the gold tier — a non-author human reviewer
(`OSPS-QA-07.01`, cf. `two_person_review`) and CI-based automated blocking of
policy violations — plus establishing a VEX feed:

- **Publish a VEX feed** (`OSPS-VM-04.02`). The project already scans dependencies
  with osv-scanner against the CycloneDX SBOM and triages non-exploitable findings
  (see [../SECURITY.md](../SECURITY.md), "Dependency monitoring"). To satisfy this
  Baseline Level 3 criterion, formalize that triage into a machine-readable VEX
  document (OpenVEX or CycloneDX VEX) recording the exploitability status and
  non-exploitability justifications of known vulnerabilities, and publish it as a
  release asset alongside the SBOM. Most valuable once a scan surfaces a
  vulnerability that does not affect the app.
- **Automated, blocking policy gates in CI** (`OSPS-VM-05.03`, and strengthening
  `OSPS-VM-06.02`). Wire the existing checks into the Woodpecker CI pipeline noted
  above so every change is evaluated automatically and blocked on violation: run
  osv-scanner against the SBOM to gate on vulnerable or malicious dependencies
  (`OSPS-VM-05.03`, today only a manual pre-release step), and run Android Lint as a
  required check (`OSPS-VM-06.02` is already enforced locally by the `abortOnError`
  build gate, but CI would enforce it on every change rather than only at build
  time). Both depend on introducing the CI pipeline.

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
- **Hardened site headers** (`hardened_site`, gold MUST). The criterion requires
  the repository and download sites to send all four key hardening headers:
  Content-Security-Policy, HTTP Strict-Transport-Security, X-Content-Type-Options
  (`nosniff`), and X-Frame-Options — with no exemption for static sites. The
  download site (F-Droid) sends all four. The repository host (Codeberg) sends
  strong HSTS and X-Frame-Options but not CSP or `nosniff`; those headers are
  controlled by Codeberg, not the project, so they cannot be set from the
  repository. Remediation options: ask Codeberg to emit the missing headers (at
  least `X-Content-Type-Options: nosniff`), or host/mirror the repository on a
  platform known to satisfy this criterion (GitHub and GitLab are listed as
  compliant). Revisit once Codeberg's header set changes.
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
- **More run-time assertions checked during testing**
  (`dynamic_analysis_enable_assertions`, gold SHOULD; non-blocking). This
  criterion targets fault detection during dynamic analysis (testing) before
  deployment — explicitly not production. Today the code uses always-on Kotlin
  preconditions (`require`, `check`, `error`) in a few critical places; these are
  checked whenever the code runs, including under the test suite, but they are
  not "many". Kotlin's compile-time null-safety and exhaustive typing already
  enforce many invariants statically, reducing the need. To satisfy this SHOULD,
  add invariant assertions in the JVM-testable domain and data layers using
  Kotlin `assert()`: Gradle's unit-test task runs with assertions enabled
  (`-ea`) by default, so they are verified during dynamic analysis, while ART
  leaves them disabled in release builds — the "on for testing, off in
  production" split the criterion recommends.

## Longer-term direction (~12 months)

Lower-criticality, forward-looking directions, roughly in priority order:

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
- **iOS code-coverage gate** (`test_statement_coverage80`,
  `test_branch_coverage80`; near-term). The Swift package suite (`swift test` in
  `ios/PotillusKit`) runs today, but its coverage is neither measured nor enforced.
  Wire up `swift test --enable-code-coverage`, extract the figure with `xccov`, and
  enforce a floor as a `cover-check` target in `ios/Makefile` — the iOS counterpart
  of Android's `:app:koverVerify` — so the release path gates iOS coverage the same
  way it gates Android's. The build tooling's `cover-check` (in `make/release.mk`)
  is already structured to take this second platform: today it runs only `make -C
  android cover-check`, and the iOS line slots in beside it.
- **Decompose `tools/release-check.sh`** (developer tooling). The Android invariant
  gate is a ~1800-line shell monolith. It is wired into the release path as-is
  (`release-android` runs `--Werror --release`), but it should be split into
  per-check files under `tools/`, each mapping onto the corresponding `check-*`
  make target, so the checks are individually runnable, testable and documented —
  the way the Mac-free checks already are in `make/checks.mk`.
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
