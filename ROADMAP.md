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

This roadmap describes the intended direction of Libellus Potionis for roughly
the next year, and — just as importantly — what the project deliberately will
**not** do. It is a statement of intent, not a promise: priorities may shift,
and items listed here may be reordered, deferred, or dropped. Its purpose is to
help users and potential contributors understand where the project is going.

## Direction for the next ~12 months

- **Stay current and maintained.** Keep the dependency stack up to date —
  Android Gradle Plugin, Gradle, the Kotlin toolchain, and the AndroidX/Jetpack
  and Compose libraries — and track new stable Android API levels, without
  compromising the minimal-permission, offline-first design.
- **Improve the translations.** English and German are hand-authored; all other
  locales are machine-generated. A standing goal is to improve those locales as
  native-speaker corrections arrive (see the translation workflow in
  CONTRIBUTING.md) and to keep every locale complete.
- **Pursue the OpenSSF Best Practices badges.** Work toward the passing badge,
  then silver, then gold, and adopt the documentation and process improvements
  those criteria encourage.
- **Small, in-scope UX and feature refinements.** Incremental improvements to
  the existing screens and reports that stay within the app's purpose, without
  expanding its scope or permissions.
- **Strengthen tests and automation.** Add measurable test coverage reporting
  (e.g. Kover) and continuous integration (e.g. Codeberg Woodpecker) so tests
  and static analysis run automatically on changes.
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
- **No expansion of the permission profile.** The app will not add camera,
  microphone, location, contacts, or runtime storage permissions.
- **No scope creep beyond alcohol tracking.** The app will stay focused on its
  purpose rather than growing into a general health or lifestyle suite.
