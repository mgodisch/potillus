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

# Libellus Potionis — OpenSSF badge status

What is still open on the OpenSSF Best Practices badge (project 13480) and the
OpenSSF Security Baseline, one chapter per tier. **Only criteria that are not yet
met appear here.** A tier whose criteria are all Met or N/A says so in a line;
the per-criterion answers and their full justifications live in
[../.bestpractices.json](../.bestpractices.json), which is the source of truth
this file summarises.

Listing an open criterion is not a commitment to close it. Several are answered
"not planned" on the merits, and the largest group needs a second person rather
than a change to the software.

## Passing

Complete. Six criteria are recorded N/A rather than Met, all for the same reason —
the app has no network, no password storage, no dynamic-analysis surface of the
kind the criterion means, and no vulnerability report to have responded to yet.

## Silver

One MUST is unmet:

- **`access_continuity`.** The project is maintained by one person, and no
  arrangement is in place that would let it continue — issues, changes, releases —
  within a week if that person became unavailable. What already limits the damage
  is recorded in [GOVERNANCE.md](GOVERNANCE.md) under "Continuity": the licence,
  the public history, F-Droid's reproducible re-signing (which removes the
  private-key hand-off) and the documented backup format. What is missing is the
  naming itself — a trusted successor or co-maintainer with the necessary
  repository access and legal rights, willing to take it on.

Two SHOULD criteria are unmet, which the badge permits where the rationale is
documented, so neither blocks silver:

- **`bus_factor`.** One maintainer, so the bus factor is 1. Not a design choice
  but a consequence of the project's size: a second significantly involved
  maintainer has not come forward, and one cannot be declared into existence. The
  same step answers this and `access_continuity`. It is a MUST at gold.
- **`crypto_algorithm_agility`.** Answered "deliberately not planned", and the
  reasoning is in the criterion's justification. In short: the software seals
  exactly one artifact at rest, the preferences blob, under AES-256-GCM; on
  Android the key is generated inside the Keystore and never leaves it, so a
  second AEAD the platform key store cannot hold would trade a hardware-backed
  key for algorithm choice. The sealed framing is byte-identical on both
  platforms, so changing it touches Android, iOS, the backup path and the shared
  test vectors. The algorithm is encapsulated per platform, so replacing it would
  be a localised change rather than a rewrite.

## Gold

Gold requires silver first, so `achieve_silver` is unmet by consequence. The other
three are the same structural gap seen from three sides, and each needs a second,
independent person:

- **`bus_factor`.** A SHOULD at silver, a MUST here.
- **`contributors_unassociated`.** Two significant contributors not associated
  with each other, e.g. not the same employer. With one maintainer there is one.
- **`two_person_review`.** At least half of all changes reviewed before release by
  someone other than their author. The review process and its checklist are
  documented in [../CONTRIBUTING.md](../CONTRIBUTING.md); what is missing is the
  second reviewer.

## Security Baseline Level 1

Complete. `OSPS-QA-04.01` is N/A: it applies to a project spanning several source
repositories, and this one is built from a single repository with no submodules.

## Security Baseline Level 2

Complete. `OSPS-QA-06.01` is recorded N/A rather than Met, which is worth reading
before it is mistaken for a gap: the project maintains automated test suites and
runs them, so the MUST is satisfied in substance, but the control's details
recommend running the suite inside the pipeline, and the canonical GitLab pipeline
is deliberately device-free.

Level 2 briefly lost `OSPS-QA-03.01` (automated status checks before merge) when
the move to GitLab retired the old pipeline, and regained it with the GitLab
pipeline and the *Merge requests > "Pipelines must succeed"* setting;
`OSPS-AC-04.01` made the same round trip.

## Security Baseline Level 3

One control is unmet:

- **`OSPS-QA-07.01`.** A reviewer who is not the author, on at least half of all
  changes. This is `two_person_review` under a different name, and it is the only
  thing between the project and Level 3.

Two further controls are N/A with reasons worth keeping: `OSPS-BR-01.04` is
conditional on a pipeline that accepts collaborator input, and this pipeline has no
manual trigger, no inputs and no user-supplied variables, so the precondition never
occurs; `OSPS-QA-04.02` applies to a release built from several source
repositories, which this is not. Everything else at this level is Met.

## Badge administration (bestpractices.dev, project 13480)

[../.bestpractices.json](../.bestpractices.json) in the repository root is the
version-controlled snapshot of the badge answers — the metal series and the OSPS
Baseline levels — and the maintained source of truth. `make bestpractices`
downloads the current bestpractices.dev export and reports, grouped by level,
which committed answers the site does not yet match, so the maintainer knows what
to enter upstream. It needs no credentials and does not touch the working tree.

The reverse direction is unavailable: bestpractices.dev has no path that reads a
committed answer file back into the site, and the URL-based automation-proposal
path is impractical because the server rejects the long URLs the full answer set
produces. Its repository analysis targets GitHub and GitLab, so with the move to
GitLab that analysis now sees the canonical repository rather than a mirror.

## OpenSSF Scorecard badge

The move of the canonical repository to GitLab removed the reason this badge was
previously ruled out. Scorecard analyses a single repository on GitHub or GitLab,
and its badge is fed by a CI job that publishes a signed result through the forge's
OIDC token. That was impossible while the canonical repository lived on a forge
Scorecard has no backend for and the GitHub/GitLab repositories were read-only
mirrors carrying no development, review, CI or release activity.

An earlier trial run against the GitHub mirror scored 5.2/10, and that shortfall
was almost entirely a measurement artifact of the mirror topology rather than a
security weakness. The substantive checks were already maximal —
Dangerous-Workflow, Token-Permissions, Vulnerabilities, Security-Policy,
Pinned-Dependencies and License each scored 10, Binary-Artifacts 9. The low checks
were the host-dependent ones — Code-Review, CI-Tests, Contributors,
Branch-Protection and Signed-Releases — which measured a mirror on which nothing
happens.

Two prerequisites remain before the badge can be pursued honestly:

1. **A Scorecard job.** The pipeline exists and is enforced, but the badge's
   publication needs a job of its own that runs the analysis and pushes the signed
   result, and CI-Tests scores what the pipeline actually runs — for now the
   device-free checks only.
2. **Badge re-registration.** The CII-Best-Practices check reads the project's
   bestpractices.dev entry, which is registered under the old canonical URL and
   has to be re-pointed at the GitLab repository.

Until both are done the badge is not linked: publishing a score that understates
the project's real posture would be worse than publishing none.

### What the GitHub mirror does and does not settle

The mirror carries supplementary GitHub Actions checks — an Android build with
lint and unit tests, a macOS runner that builds with XcodeGen and xcodebuild and
runs the PotillusKit suite and real SwiftLint at the pinned version, the Android
instrumentation tests on an API 36 emulator, and CodeQL over Kotlin and Swift
weekly and on `main`. The scope and its limits are in
[MIRROR-CHECKS.md](MIRROR-CHECKS.md). What remains uncovered anywhere but locally
are the iOS tests that need a booted simulator: the app-target XCTests and the
XCUITests.

Two questions have to be kept apart when reading what that buys.

*Does a criterion ask whether a check GATES a change?* Then the mirror does not
help. `OSPS-QA-03.01` and `OSPS-QA-06.01` are about enforcement, and enforcement
lives in the GitLab pipeline together with *Merge requests > "Pipelines must
succeed"*. A workflow that cannot block a merge cannot satisfy them.

*Or does it ask whether a PRACTICE is carried out?* Then the mirror settles it,
because the practice is real regardless of where the machine stands.
`static_analysis_often` and `automated_integration_testing` are both Met on that
reading.

One follow-up stays open on the mirror itself: **dependency submission.**
Dependabot cannot see the Android dependency graph without a submitted graph, and
submitting one needs `contents: write` on the mirror. The write scope has been
declined for now; the consequence is that Dependabot's coverage there is limited
to the committed lockfiles, which the GitLab scan already covers.
