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

## About the App (v0.85.0)

Libellus Potionis is a privacy-first, open-source, free and ad-free alcohol
consumption tracker designed to help users monitor, pace, and manage their
drinking habits entirely offline. It requires no invasive device permissions,
no camera, microphone, or location access, and operates completely without
network connectivity.

The app runs on both Android and iOS, and is available on
[F-Droid](https://f-droid.org/packages/de.godisch.potillus), on [Google Play
(Beta)](https://play.google.com/store/apps/details?id=de.godisch.potillus), and
on the [App Store (Beta)](https://testflight.apple.com/join/sfJvr3VK).

## Key Features

* Predefine custom beverages or use internationally common presets. Log drinks
  instantly or retroactively with timestamp corrections.
* Set three boundaries at once: a daily limit in grams of pure alcohol, a
  rolling 7-day limit in grams, and a maximum number of drinking days per week.
  Each limit has its own progress bar.
* Enter your body weight to get a live estimate of your blood alcohol
  concentration (BAC): from the Widmark formula.
* Generate a two-page PDF report of your consumption for a counseling
  appointment.
* Export the dataset as a CSV file for external processing (e.g. in
  [LibreOffice](https://www.libreoffice.org/) Calc), or create JSON backups to
  move data between devices.
* Adjust the app to set your own "day start" time, so that late-night drinks
  count toward the preceding evening, or set an evaluation start date for a
  clean restart.
* Screen-reader names on every interactive control, text that follows the system
  font size, right-to-left layouts, and a limit palette that reads without
  telling red from green.

Every screen is described in the User's Guide inside the app.

## Privacy & Security Architecture

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
[`PRIVACY.md`](PRIVACY.md).

## Platform Compatibility

The app runs on Android 11 (API 30) and newer — a Pixel 5 or Galaxy S21 and
later — and on iOS 17 and newer, an iPhone XS (2018) and later. It consists of
two separate native apps in this one repository — Kotlin/Jetpack Compose for
Android, Swift/SwiftUI for iOS — that share the same design, the same feature
set, and a common JSON backup format, so a backup exported on one platform
imports on the other. Their behaviour is kept in lock-step by a shared set of
test vectors. Why each floor sits where it does is recorded beside the settings
that define it, in `android/app/build.gradle.kts` and `ios/project.yml`.

F-Droid applies no age rating. The two commercial consoles ask different
questions and reach different verdicts for the same app — Apple 18+, Google 3+ —
because one rates the content and the other the purpose; what each asked and
what was answered is in [`docs/STORE_RATINGS.md`](docs/STORE_RATINGS.md).

## Build Infrastructure & Tooling

To build the app from source, follow the step-by-step guides
[`docs/INSTALL-ANDROID.md`](docs/INSTALL-ANDROID.md) and
[`docs/INSTALL-IOS.md`](docs/INSTALL-IOS.md).

Changes are documented in [`CHANGELOG.md`](CHANGELOG.md). The project's
intended direction and its explicit non-goals are described in
[`docs/ROADMAP.md`](docs/ROADMAP.md).

## AI Involvement

This project was developed with assistance from Anthropic's Claude across
implementation, documentation, and tooling. This statement is for transparency:
all changes are reviewed and maintained under the same test suites and quality
standards as human-written code. As with any open-source software provided
under the GPLv3, the code is provided "as is", and users remain responsible for
evaluating its suitability for their own use.

## Feedback & Contributing

The preferred channel for feedback, bug reports, and enhancement requests is
the issue tracker of the canonical repository at
[GitLab](https://gitlab.com/godisch/potillus/-/issues); if you would rather not
use the tracker, you may instead write to
[android@godisch.de](mailto:android@godisch.de) or
[ios@godisch.de](mailto:ios@godisch.de). To report a security vulnerability,
please do _not_ open a public issue. Instead, follow the private, PGP-encrypted
reporting process described in [`SECURITY.md`](SECURITY.md).

Translation contributions are where help is most useful: of the 21 interface
languages, only English and German are hand-written, and the rest have never
been read by a native speaker. Which are which, and how to send a correction, is
in [`CONTRIBUTING.md`](CONTRIBUTING.md), section 6.

All contributors are expected to follow the project's [Code of
Conduct](docs/CODE_OF_CONDUCT.md).

## License

Libellus Potionis - Privacy-Friendly Alcohol Tracker, Copyright &copy; 2026
Martin A. Godisch <[martin@godisch.de](mailto:martin@godisch.de)>

The source code can be found at the [canonical repository at
gitlab.com](https://gitlab.com/godisch/potillus/). A read-only push mirror is
available at [github.com](https://github.com/mgodisch/potillus); it carries no
development, but it does run supplementary checks that the canonical pipeline
cannot — see [`docs/MIRROR-CHECKS.md`](docs/MIRROR-CHECKS.md).

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
