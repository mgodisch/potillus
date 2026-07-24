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

# Supplementary checks on the GitHub mirror

The canonical repository is [gitlab.com/godisch/potillus](https://gitlab.com/godisch/potillus);
[github.com/mgodisch/potillus](https://github.com/mgodisch/potillus) is a
read-only push mirror of every branch. This document describes the checks that
run on that mirror, why they run *there* rather than on GitLab, and — just as
importantly — what they are not.

## Why anything runs on a mirror at all

The GitLab pipeline ([../.gitlab-ci.yml](../.gitlab-ci.yml)) is deliberately
device-free: it runs the `tools/` checks, the release gate and an
osv-scanner source scan, and it never builds. That scope was not chosen out of
preference. A real Android build needs the SDK and several minutes of metered
runner time; an iOS build needs macOS and Xcode, which a Linux runner cannot
provide at all.

A public GitHub repository removes both obstacles: runner minutes are free and
macOS runners are available. That is the whole argument. The mirror is used as a
*machine*, not as a second home for the project — the canonical pipeline stays
the gate, and everything here is an addition to it.

Two GitHub features also have no GitLab equivalent on this project's plan, and
they are used for the same reason: code scanning (a durable, deduplicated view of
static-analysis findings, fed by SARIF) and private vulnerability reporting.

One consequence is worth stating plainly. The Swift checks in `tools/`
(`check-swift-symbols.py`, `check-swift-length.py`, `check-swift-tests.py`)
exist because the canonical pipeline cannot run SwiftLint or a Swift compiler;
they approximate both in Python. The macOS runner now runs the real tools
alongside them. The Python checks are **not** retired by this: they are what
covers the Swift side on the canonical, blocking pipeline, while the macOS run
is advisory. The two are complementary, and a disagreement between them is worth
investigating rather than resolving by deleting one.

## What runs

| Workflow | What it does | Where it could not run |
| --- | --- | --- |
| [`meta.yml`](../.github/workflows/meta.yml) | `actionlint` (workflow syntax and shell correctness) and `zizmor` (workflow security: template injection, over-broad permissions, unpinned actions) | Nowhere else — it lints GitHub workflow files, which only exist here |
| [`android.yml`](../.github/workflows/android.yml) | `make -C android lint`, `unit-tests`, `cover-check`; the Android Lint findings go to code scanning as SARIF | GitLab, in practice: the SDK build exceeds what the free tier's metered minutes make sensible |
| [`ios.yml`](../.github/workflows/ios.yml) | `gmake -C ios lint` (real SwiftLint at the pinned version), `build` (XcodeGen + xcodebuild), `cover-check` (PotillusKit suite + coverage floor) | GitLab, absolutely: xcodebuild needs macOS, and the canonical pipeline is Linux-only |
| [`device-tests.yml`](../.github/workflows/device-tests.yml) | `make -C android device-tests EXCLUDE_SCREENSHOTS=1` on an API 36 emulator — the Compose UI and Espresso suite | GitLab: needs KVM and a system image, well past what the free tier's runners provide |
| [`codeql.yml`](../.github/workflows/codeql.yml) | CodeQL over Kotlin and Swift — data-flow analysis across functions and files, not the per-file reasoning every other check here does | GitLab: SAST of this depth is a paid-tier feature there |

Both run on a push to **any** branch, so a topic branch under review on GitLab
gets its verdict while the merge request is still open. Neither runs on tags.

`device-tests.yml` runs per branch too, but only when something under `android/`
changed, and additionally on a weekly schedule and on demand. Emulator time is
the most expensive thing here, and a translation or an iOS change cannot alter
the result.

`codeql.yml` is the exception: it runs on `main` only, and only when something
under `android/` or `ios/` changed, plus weekly and on demand. A run is about
forty minutes — two full builds under CodeQL's tracer, on two runner platforms —
and its findings are research rather than build breaks, so paying that for a
translation or a documentation change buys nothing. The weekly run is the safety
net and ignores the path filter: GitHub updates the query packs, so unchanged
code can acquire a new finding, and no stretch of non-source work leaves the
analysis older than seven days.

## What these checks are NOT

- **They do not gate anything.** A red run on GitHub cannot block a merge request
  on GitLab; GitLab's external status checks are not available on this project's
  plan. The blocking gate remains the GitLab pipeline together with the
  *Settings > Merge requests > "Pipelines must succeed"* setting. Treat a failed
  mirror run as a message, not as a verdict — and read it before merging.
- **They are not a release path.** Nothing here builds a release artifact, signs
  anything, or publishes. The mirror holds no secrets, and every workflow is
  restricted to `contents: read` apart from the one scope needed to write
  findings into the Security tab.
- **They do not replace the local pre-release work.** The app-target XCTests and
  XCUITests that need a booted iOS simulator, the reproducible-build checks and
  the store staging remain where [CONTRIBUTING.md](../CONTRIBUTING.md) §7 puts
  them. The Android instrumentation tests no longer belong to that list.

## Conventions these workflows follow

- **Every action is pinned to a full commit SHA**, with the release name in a
  trailing comment. A tag is a movable pointer its author can re-point; a SHA is
  not. This is the same discipline the project applies to its Gradle and SwiftPM
  dependencies, and it is what OpenSSF Scorecard's Pinned-Dependencies check
  asks for. The pinned tools themselves (the `actionlint` container, the `zizmor`
  release) are pinned by digest or version for the same reason.
- **Least privilege.** `permissions: contents: read` at the top of every file;
  any additional scope is declared on the single job that needs it.
- **`concurrency` with `cancel-in-progress`.** A mirror updates by force-push, so
  a rebased branch can arrive several times a minute; only the newest run is
  worth paying for.
- **The workflows call `make`,** never their own `./gradlew` or `xcodebuild`
  lines, so the definition of "build the app" stays in `android/Makefile` and
  `ios/Makefile` alone. On macOS that means `gmake`: the system `make` is 3.81
  and `make/guard.mk` requires 4.3 or newer.
- **Runner images are named, not floated.** `macos-26` rather than
  `macos-latest`, so an Xcode generation changes under the project only when the
  workflow changes. SwiftLint is fetched at the version `ios/Makefile` pins and
  verified against a recorded checksum before it is unpacked, because its rules
  differ between releases.

## Repository settings this assumes

These cannot live in the repository and must be set once, by the maintainer, in
the GitHub project settings:

1. **Actions enabled**, with workflow permissions set to read-only.
2. **Private vulnerability reporting** (*Settings > Advanced Security*) — a
   confidential report channel that GitHub, as a CNA, also connects to a CVE
   request path. Referenced from [../SECURITY.md](../SECURITY.md).
3. **Dependabot alerts** — enabled; Dependabot **version updates** deliberately
   NOT enabled, because a pull request on a force-pushed mirror can never be
   merged. Alerts are read as a second advisory source next to osv-scanner, and
   findings are triaged in `osv-scanner.toml` / `openvex.json` on GitLab as
   usual. Note the limit: without a submitted dependency graph, Dependabot sees
   only the committed lockfiles (`fastlane/Gemfile.lock`,
   `ios/PotillusKit/Package.resolved`) — the same ones the GitLab scan already
   covers. The Android graph would need `gradle/actions/setup-gradle` with
   dependency submission, which requires `contents: write` on the mirror; that
   trade-off has not been taken.
4. **Secret scanning and push protection** — enabled. One consequence is worth
   knowing in advance: push protection rejects a push containing a detected
   secret, and for a mirror that surfaces as a *mirroring error* on GitLab rather
   than as a tidy notification.
