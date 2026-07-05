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
  emulator and are optional. Requires enabling Woodpecker for the repository.
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
- **Cryptographic algorithm agility** (`crypto_algorithm_agility`). Give the
  encrypted-preferences blob a self-describing, versioned format (a version byte
  authenticated as GCM AAD, with a read-legacy / write-versioned migration) in
  `KeystoreSecretStore`, so a future algorithm can be selected per record. A
  security-critical change: requires thorough tests, including an instrumented
  round-trip, a legacy-blob read, and tamper/downgrade rejection.

## Accessibility

- **Accessible year heatmap** (`accessibility_best_practices`). The
  `YearCalendarView` (`ui/component/CalendarComponents.kt`) distinguishes under-
  vs. over-limit days by colour alone (10 dp green/red cells) with no per-cell
  screen-reader label. Add a `contentDescription`/semantics per cell (date +
  grams + within/over limit) and, ideally, a non-colour indicator, to address
  WCAG 1.4.1. A new user-facing string triggers `LocaleSyncTest` across all
  locales, so this is an i18n-touching change, not a one-liner.

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
- **Publish on the Google Play Store.** In addition to F-Droid, make the app
  available on Google Play so more users can find and install it.
- **Port the app to iOS.** Bring Libellus Potionis to Apple devices, preserving
  the same privacy-first, offline-first design and feature set.
- **Publish on the Apple App Store.** Once the iOS port is ready, distribute it
  through the Apple App Store.

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
