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
  Also satisfies passing `test_continuous_integration` and
  `static_analysis_often`, and is the natural home for the periodic `osv-scanner`
  run (see [../SECURITY.md](../SECURITY.md), "Dependency monitoring").
- **Statement coverage >= 80%** (`test_statement_coverage80`). Integrate Kover,
  measure statement coverage over the JVM-testable code, apply legitimate
  exclusions for generated/non-testable code (Room-generated classes,
  `MainActivity`, pure Compose previews), and add tests to reach the threshold.
  Also satisfies passing `test_most` and `dynamic_analysis`.

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
- **Continue toward the OpenSSF gold badge.** After silver, adopt the further
  documentation and process improvements the gold criteria encourage.
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
