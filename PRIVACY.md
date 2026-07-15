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
PRIVACY.md -- privacy policy for the app store listings
=============================================================================

WHAT THIS IS

The privacy policy required by the Google Play "App content" section (every
Play listing must link to a publicly reachable privacy policy URL, regardless
of whether the app collects data). It is written to be hosted verbatim as a web
page -- see `docs/PLAY_STORE.md`, section "Privacy policy hosting", for the two
supported ways to turn this file into a public URL.

Keep the "Last updated" line and the version/package facts below in sync with
the app whenever the privacy-relevant behaviour changes. This document makes NO
claim that is not already true of the shipped app; if you ever add a
permission, a network call, or any telemetry, this file MUST be revised in the
same change, and the Play Data safety form updated accordingly.

=============================================================================
-->

# Privacy Policy — Libellus Potionis

- **Last updated:** 2026-07-15
- **Application:** Libellus Potionis (package `de.godisch.potillus`)
- **Developer:** Martin A. Godisch — <android@godisch.de> <ios@godisch.de>
- **Source code:** <https://codeberg.org/godisch/potillus>

## Summary

Libellus Potionis is an offline-first, ad-free, open-source alcohol-consumption
tracker. It **collects no personal data, transmits nothing, and has no network
access.** Everything you enter stays on your device. The developer never
receives, stores, or has any access to your data.

## What the app stores, and where

To do its job the app keeps the following **on your device only**:

- Your drink log (beverages, amounts, timestamps).
- Your configured limits (daily grams of pure alcohol, rolling 7-day weekly
  grams, and the maximum number of drinking days per week).
- Your body weight, if you enter it, used solely for the on-device Blood Alcohol
  Concentration (BAC) estimate (Widmark formula).
- Your app preferences (for example the configured "day start" time and the
  selected in-app language).

This data lives in the app's private, sandboxed storage. It is protected at rest
by Android's device storage encryption and the per-app sandbox. The small
preferences secret is additionally sealed with a key held in the Android
Keystore (AES-256-GCM). The app is **not** end-to-end encrypted at the database
level; it relies on the platform's storage encryption and sandbox isolation.

An optional biometric fingerprint lock can guard the app against unauthorized
physical access. Biometric matching is performed entirely by the Android system;
the app never sees, receives, or stores your biometric data.

## What the app does NOT do

- **No network access.** The app declares no internet permission and makes no
  network connections. Your data cannot leave the device through the app.
- **No tracking, analytics, advertising, or crash reporting.** There are no
  third-party SDKs that phone home.
- **No data sharing or selling.** Because nothing is transmitted, there is no
  data to share, sell, or disclose to anyone, including the developer.

## Data you export yourself

The app can, only when you explicitly ask it to, produce:

- a CSV export of your dataset to your device's Downloads folder,
- a two-page PDF report intended for counseling appointments, and
- a JSON backup to move data between your own devices.

These files are created by your own action and placed where you direct them.
Once a file leaves the app this way, it is under your control and the control of
whatever apps or people you subsequently share it with; this policy no longer
governs it. The developer is never involved in and never receives these exports.

## Automatic device backups

Beyond the files you export yourself, mobile platforms can copy an app's data into
an automatic device backup. Libellus Potionis keeps your data out of these by
default:

- On **Android**, the app declares `android:allowBackup="false"`, so it is excluded
  from Google's automatic cloud and device-transfer backup entirely.
- On **iOS**, your consumption log is excluded from every device backup — both the
  iCloud backup and a local computer (Finder/iTunes) backup — by default. A setting
  ("Include in device backup") lets you opt in if you would rather your log be
  restored automatically onto a new phone.

Either way, the supported and recommended way to move your data to a new device is
the JSON backup you export yourself, described above.

## Permissions

The app requests a single, optional permission:

- `USE_BIOMETRIC` — to offer the optional fingerprint app lock described above.

It requests no camera, microphone, location, telephony, contacts, or storage
permissions. Writing CSV/PDF/JSON to the public Downloads folder uses the
scoped MediaStore API and needs no storage permission.

## Children

This app concerns alcohol consumption and is intended for adults; it is not
directed to children. In any case, the app collects no data from anyone.

## Your rights

Because the developer processes no personal data about you (nothing ever leaves
your device), there is no server-side data to access, correct, export, or
delete. You are in full control of your data at all times: you can edit or
delete individual entries in the app, and uninstalling the app removes all of
its data from your device. If you have questions about this policy, contact the
developer at the address above.

## Changes to this policy

If this policy changes, the "Last updated" date above will change and the
updated policy will be published at the same URL. Material changes that affect
what data the app handles will be accompanied by a corresponding update to the
app and to the Google Play Data safety disclosure.

## Contact

Martin A. Godisch — <android@godisch.de> <ios@godisch.de>
