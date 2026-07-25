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

[![Feature Image](fastlane/metadata/android/en-US/images/featureGraphic-4K.png)](https://f-droid.org/packages/de.godisch.potillus/)

# Libellus Potionis - Privacy-Friendly Alcohol Tracker

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13480/badge)](https://www.bestpractices.dev/projects/13480)
[![OpenSSF Baseline](https://www.bestpractices.dev/projects/13480/baseline)](https://www.bestpractices.dev/projects/13480)
[![εxodus: 0 trackers](https://img.shields.io/badge/%CE%B5xodus-0%20trackers-brightgreen)](https://reports.exodus-privacy.eu.org/en/reports/de.godisch.potillus/latest/)
[![REUSE status](https://api.reuse.software/badge/gitlab.com/godisch/potillus)](https://api.reuse.software/info/gitlab.com/godisch/potillus)

## About the App (v0.84.0)

**Libellus Potionis** is a privacy-first, free, open-source, and ad-free
alcohol consumption tracker designed to help users monitor, pace, and manage
their drinking habits entirely offline. It requires no invasive device
permissions—no camera, microphone, or location access—and completely operates
without network connectivity.

It runs on both **Android** and **iOS**. The two are separate native apps in
this one repository — Kotlin/Jetpack Compose for Android, Swift/SwiftUI for iOS —
that share the same design, the same feature set, and a common JSON backup format,
so a backup exported on one platform imports on the other. Their behaviour is kept
in lock-step by a shared set of golden test vectors.

### Key Features

*   Logging: predefine custom beverages or use internationally common presets.
    Log drinks instantly or retroactively with precise timestamp corrections.
*   Concurrent limits: set three boundaries at once — a daily limit in grams of
    pure alcohol, a rolling 7-day limit in grams, and a maximum number of
    drinking days per week. Each has its own progress bar.
*   Blood alcohol concentration (BAC): enter your body weight to get a live
    estimate from the Widmark formula.
*   Counseling reports: generate a two-page PDF report of your consumption for
    a counseling appointment.
*   Data portability: export the dataset as a CSV file for external processing
    (e.g. in LibreOffice Calc), or create JSON backups to move data between
    devices.
*   Adjustments: set your own "day start" time, so that late-night drinks count
    toward the preceding evening, and an evaluation start date for a clean
    restart.

A User's Guide is available inside the app, which can be installed from
[F-Droid](https://f-droid.org/packages/de.godisch.potillus).

## Quick start

1. Install Libellus Potionis from
   [F-Droid](https://f-droid.org/packages/de.godisch.potillus).
2. Log your first drink. Open the app; on the Today screen, tap the plus button
   and pick a common preset, or define your own beverage. It is logged
   instantly, and you can correct the timestamp for a drink you had earlier.
3. See where you stand. The Today screen shows the grams of pure alcohol you
   have consumed today, your progress toward the daily and rolling 7-day limits
   as bars, and your drinking-days count for the week.
4. Optional: personalize. In Settings you can set the daily, weekly and
   drinking-days limits, enter your body weight for a live blood-alcohol (BAC)
   estimate, and enable the fingerprint lock.
5. Optional: export. Generate a two-page PDF report for a counseling
   appointment, export a CSV for a spreadsheet, or create a JSON backup to move
   your data to another device.

The in-app User's Guide describes every screen.

## Feedback & Contributing

Feedback, bug reports, and enhancement requests are welcome. The preferred
channel is the issue tracker of the canonical repository at
[GitLab](https://gitlab.com/godisch/potillus/-/issues); if you would rather
not use the tracker, you may instead write to
[android@godisch.de](mailto:android@godisch.de).

Code and documentation contributions are welcome too. The contribution
process — how changes are proposed and reviewed, together with the
architecture, coding, testing, and release conventions a change must follow —
is documented in
[CONTRIBUTING.md](https://gitlab.com/godisch/potillus/-/blob/main/CONTRIBUTING.md).

All participants are expected to follow the project's
[Code of Conduct](https://gitlab.com/godisch/potillus/-/blob/main/docs/CODE_OF_CONDUCT.md).

## Security

To report a security vulnerability, please do **not** open a public issue.
Instead, follow the private, PGP-encrypted reporting process described in
[SECURITY.md](https://gitlab.com/godisch/potillus/-/blob/main/SECURITY.md).

## Technical Aspects

### Privacy & Security Architecture

The app stores only what you enter. On Android it holds no network permission,
so it is incapable of network access; on iOS, where there is no equivalent
install-time permission, it contains no networking APIs at all. Personal data
therefore does not leave the device on its own. Your data rests in the app's
private, sandboxed storage, protected at rest by the operating system's
file-based storage encryption. An optional biometric lock guards against
unauthorized physical access. There is no tracking, no analytics and no cloud
synchronization.

The app's full privacy policy — detailing exactly what is stored on the device
and confirming that nothing is ever transmitted — is available in
[PRIVACY.md](https://gitlab.com/godisch/potillus/-/blob/main/PRIVACY.md).

### Platform Compatibility

The app runs on **Android 11 (API 30) and newer** and on **iOS 17 and newer**.

Android API 30 is a deliberate floor: it is the lowest level at which the app
can save CSV, PDF, and backup files to the public `Downloads` folder via
`MediaStore` *without* requesting any runtime storage permissions, which keeps
the minimal-permission profile intact. The system-level per-app language picker
is restricted to API 33+, so the app carries its own language selector, which
works on every supported version.

iOS 17 is a deliberate floor as well: it is where the SwiftUI Observation
framework and String Catalog localisation the app relies on became available,
while the pre-iOS-17 installed base is a small, shrinking tail. The hardware
floor that follows is iPhone XS (2018) and later. The app's own language
selector works here too, and the JSON backup format is shared with Android, so
a backup moves between the two platforms unchanged.

Libellus Potionis is distributed through
[F-Droid](https://f-droid.org/packages/de.godisch.potillus/), which applies no
age rating. Where the app is offered through the commercial stores, the two
consoles ask different questions and reach very different age ratings for the
same app — Apple's App Store at **18+**, Google Play at **3+** — because one
rates the *content* (a catalogue of alcoholic drinks) and the other the
*purpose* (a harm-reduction tool that neither sells nor promotes anything). What
each store asked, what was answered, and why is recorded in
[`docs/STORE_RATINGS.md`](docs/STORE_RATINGS.md).

The app is tested on a Google Pixel 10 Pro running
[GrapheneOS](https://grapheneos.org/) (Android 16), a Fairphone 4 (Android 15),
an iPhone 16e and an iPhone SE (3rd generation), both running iOS 26, and on
Android and iPhone emulators.

### Accessibility

Libellus Potionis follows Android accessibility best practices: every
interactive control carries a screen-reader (TalkBack) name — including the
calendar navigation arrows, the drink-category icon, and each year heat-map day
cell that holds data — text scales with the system font size (`sp` units), the
layout mirrors for right-to-left languages, and the under/over-limit palette is
blue vs. red (not a red/green pair) so it is colour-blind distinguishable. A
release-check gate (§13) keeps interactive icons from silently losing their
labels.

On iOS the same principles apply through the platform's own facilities: controls
carry VoiceOver labels, text scales with Dynamic Type, the layout mirrors for
right-to-left languages, and the same blue-vs-red limit palette is used.

**No formal WCAG conformance level is claimed and no W3C conformance logo is
used**, because a conformance claim requires meeting *all* criteria of a level
under a thorough human evaluation (which has not been done), there are known
open Level AA items, and the W3C logos are scoped to web pages rather than a
native app. The concrete, measured accessibility gaps and the path toward WCAG
2.2 Level AA are tracked in [`docs/ROADMAP.md`](docs/ROADMAP.md#accessibility).

### Build Infrastructure & Tooling

To build the app from source, follow the step-by-step guides that take a blank
operating system to a runnable debug build:
[docs/INSTALL-ANDROID.md](docs/INSTALL-ANDROID.md) (debug APK from a fresh Debian GNU/Linux
install) and [docs/INSTALL-IOS.md](docs/INSTALL-IOS.md) (debug build in the iPhone Simulator
from a fresh macOS install).

The Android build runs on the current Android Gradle Plugin, Gradle and Kotlin
compiler line. Annotation processing goes through KSP, which Room uses to
generate its DAO implementations. The UI layer is built on the Jetpack Compose
BOM together with Jetpack Activity and Jetpack Lifecycle; navigation uses the
type-safe routes of Navigation Compose, which is why kotlinx-serialization-core
is on the classpath.

Persistence is Room over a plain SQLite database, protected at rest by
Android's file-based storage encryption and the per-app sandbox rather than by
an application-level cipher; data leaves the device only through the
user-initiated JSON backup export and import. The preferences secret is sealed
with a key held directly in the hardware-backed Android Keystore, without a
deprecated crypto wrapper. Core library desugaring makes the `java.time` API
behave the same down to API 30, independently of the device's ART module
revision. Tests use the Jetpack test libraries and Turbine.

The exact, pinned versions are deliberately left out of this document so it does
not drift on every dependency bump; they live in the Gradle build files —
`android/gradle/libs.versions.toml` and the module `build.gradle.kts` — which are
the single source of truth.

### Source Code Documentation

The source code is written to be read. Every file opens with a header stating
its purpose, and every public type and function carries a doc comment that
explains why the code is written the way it is: the trade-offs considered, the
failure modes guarded against, the platform quirks worked around. Inline
comments accompany the non-obvious lines and leave the obvious ones alone.

A read-only release gate (`tools/release-check.sh`) scans the tree on every
build and flags missing file headers or undocumented public functions, so the
documentation cannot rot silently as the code changes. The same gate enforces
version consistency across the release artifacts and rejects non-English prose
in the source.

### Changes

Changes are documented in
[CHANGELOG.md](https://gitlab.com/godisch/potillus/-/blob/main/CHANGELOG.md).

### Roadmap

The project's intended direction and its explicit non-goals are described in
[ROADMAP.md](https://gitlab.com/godisch/potillus/-/blob/main/docs/ROADMAP.md).

## AI Involvement

This project was developed with assistance from Anthropic's Claude across
implementation, documentation, and tooling. This statement is for transparency:
all changes are reviewed and maintained under the same test suites and quality
standards as human-written code. As with any open-source software provided
under the GPLv3, the code is provided "as is", and users remain responsible for
evaluating its suitability for their own use.

## License

Libellus Potionis - Privacy-Friendly Alcohol Tracker, Copyright
&copy; 2026 Martin A. Godisch <[martin@godisch.de](mailto:martin@godisch.de)>

The source code can be found at the [canonical repository at
gitlab.com](https://gitlab.com/godisch/potillus/). A read-only push mirror is
available at [github.com](https://github.com/mgodisch/potillus); it carries no
development, but it does run supplementary checks that the canonical pipeline
cannot — see [docs/MIRROR-CHECKS.md](docs/MIRROR-CHECKS.md).

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see
<[https://www.gnu.org/licenses/](https://www.gnu.org/licenses/)>.
