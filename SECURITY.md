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

# Security Policy

Libellus Potionis is a privacy-focused application, and security reports are
taken seriously. This document describes the project's security model (what
users can and cannot expect), how to report a vulnerability, and what to expect
in return.

## Security model

These are the security properties Libellus Potionis is designed to provide, and
their limits. They describe what the software is intended to guarantee — not a
promise that no defect will ever exist. A structured argument for why these
requirements are met — including the threat model and trust boundaries — is in
[the assurance case](docs/ASSURANCE_CASE.md).

**What users can expect:**

- **The app never transmits your data.** It works entirely offline and contacts
  no server. On **Android** it holds no network permission at all, so it is
  incapable of network access. On **iOS**, where there is no equivalent
  install-time network permission, the guarantee is upheld in the code: the app
  contains no networking APIs whatsoever — no `URLSession`, no `Network`
  framework, no sockets — and its one web view (used only to lay out the PDF
  report) loads a local HTML string with no base URL, so it too reaches nothing.
  App Transport Security is left at its strict default, though with no connections
  to govern it has nothing to enforce.
- **Data minimization and least privilege.** The app requests no camera,
  microphone, location, contacts, or runtime storage permissions. It collects
  only the data you enter.
- **On-device, sandboxed storage.** Your drinks, log entries, and settings live
  in the app's private, sandboxed storage, protected at rest by the operating
  system's file-based storage encryption. On **Android**, the preferences store
  is additionally sealed with an AES-256-GCM key held in the hardware-backed
  Android Keystore. On **iOS**, the same preferences are sealed with an
  AES-256-GCM key held in the Keychain (a `ThisDeviceOnly` key, so it never leaves
  the device), and the database is kept out of the device backup by default (see
  "Backup control" below).
- **Optional biometric lock.** You can enable a lock as a convenience gate against
  casual physical access to an unlocked device — a fingerprint lock on Android,
  Face ID or Touch ID (with device-passcode fallback) on iOS.
- **App-switcher privacy.** On both platforms the app hides its own contents in
  the app switcher / recents preview by default, so a glance at the running-apps
  list does not reveal the diary; a setting lets you turn this off.
- **Backup control.** On **Android**, `android:allowBackup="false"` removes the
  app from Google's automatic cloud and device-transfer backup entirely. On
  **iOS**, the consumption log is excluded from every device backup (both iCloud
  and a local computer backup) by default, with an opt-in for users who want the
  log restored onto a new phone. Either way, personal data does not leave the
  device through an automatic backup unless you choose otherwise; the supported
  way to move data is the user-initiated JSON export.
- **No tracking.** No analytics, telemetry, crash reporting, or advertising.

**What users cannot expect (out of scope / known limits):**

- **No protection against a compromised device.** On a rooted, malware-infected,
  or otherwise compromised device, the platform guarantees the app relies on can
  be bypassed; the app cannot defend data on such a device.
- **No protection once an unlocked device is in someone else's hands beyond the
  optional lock.** The biometric lock is an access gate, not full-disk
  encryption or a forensic countermeasure; data protection ultimately depends on
  the device's own lock-screen and storage encryption.
- **Exported files leave the app's control.** CSV, PDF, and JSON files you
  export are written where you choose (e.g. the public Downloads folder) and are
  no longer protected by the app; safeguarding and deleting them is your
  responsibility.
- **Not a medical or clinical safety system.** BAC estimates and reports are
  informational approximations, not a safety-critical measurement.

## Reporting a vulnerability

Please report suspected security vulnerabilities **privately**. Do **not** open
a public issue for a security problem — a public issue would disclose the
vulnerability before a fix is available.

Send your report by e-mail to **android@godisch.de** or **ios@godisch.de**.

Because a report may contain sensitive details, please **encrypt it with PGP**
using the maintainer's public key:

- Fingerprint: `1842 323B 4FCF 9B90 995F  A17F A350 B991 F05A 4857`

The maintainer is a Debian Developer, so the key is distributed through the
official Debian keyserver and can be fetched from there:

```sh
gpg --keyserver hkps://keyring.debian.org:443 \
    --recv-keys 1842323B4FCF9B90995FA17FA350B991F05A4857
```

The same key is also part of the `debian-keyring` package. Before trusting the
key, verify that the fingerprint printed by `gpg --fingerprint` matches the one
above.

If you are unable to use PGP, still write to android@godisch.de or
ios@godisch.de; the maintainer will arrange a secure channel before you share
any sensitive details.

## What to include

To help triage and reproduce the issue, please include where possible:

- a description of the vulnerability and its potential impact;
- the app version (shown in the app, or the `versionName`) and the Android
  version and device model;
- step-by-step instructions or a proof of concept to reproduce it;
- any relevant logs, stack traces, or screenshots.

## What to expect

- **Acknowledgement:** the maintainer will acknowledge your report within
  **14 days** of receipt.
- **Assessment:** after acknowledgement you will receive confirmation of whether
  the report is accepted as a vulnerability and an estimate of the time to a
  fix.
- **Disclosure:** please practice coordinated disclosure — give the maintainer a
  reasonable opportunity to release a fix before disclosing the issue publicly.
  Unless you prefer to remain anonymous, your contribution will be credited in
  the release notes once a fix is published.

## Security advisories

When a vulnerability in Libellus Potionis is confirmed and fixed, the project
publishes an advisory through predictable public channels: the
security-relevant fix is recorded in the release notes
([CHANGELOG.md](CHANGELOG.md)) and in the corresponding Codeberg release. Each
advisory states, to the extent possible, the affected version(s), how a user
can determine whether they are affected, and the remediation — updating to the
fixed version, which is distributed through
[F-Droid](https://f-droid.org/packages/de.godisch.potillus/).

## Scope

This policy covers the Libellus Potionis application code in this repository.
Vulnerabilities in third-party dependencies should be reported to their
respective projects; if a dependency issue affects Libellus Potionis, you are
welcome to notify the maintainer as well so the dependency can be updated.

## Support

Libellus Potionis is maintained by a single volunteer maintainer and follows a
rolling-release model: only the **latest released version** is supported.

- **Scope.** Support consists of bug fixes and security updates, delivered in new
  releases through [F-Droid](https://f-droid.org/packages/de.godisch.potillus/),
  on a best-effort basis. There are no separate maintenance branches and fixes are
  not back-ported to older versions; users receive fixes by updating to the newest
  release.
- **Duration.** Each release is supported until the next release supersedes it.
  Security updates are provided for the current release for as long as the project
  remains active.
- **End of security updates.** A given version stops receiving security updates as
  soon as a newer release supersedes it, because security fixes ship in the new
  release rather than being back-ported. If the project is ever discontinued, that
  will be announced in the repository (README), after which no further updates —
  security or otherwise — will be provided.
- **Obtaining support.** Bug reports and questions go to the
  [Codeberg issue tracker](https://codeberg.org/godisch/potillus/issues); suspected
  vulnerabilities follow the process in "Reporting a vulnerability" above.

## Dependency monitoring

The project's external dependencies are checked periodically — at a minimum
before each release — for known vulnerabilities. The check is performed with
[osv-scanner](https://google.github.io/osv-scanner/), a free/libre scanner that
queries the [OSV](https://osv.dev/) database, run against the CycloneDX SBOM
each platform's build produces (the `cyclonedxDirectBom` task on Android, and
`tools/gen-ios-sbom.py` from `Package.resolved` on iOS). Each reported issue is
triaged: exploitable vulnerabilities are fixed by upgrading (or, where
necessary, mitigating) the affected dependency, and issues that are not
exploitable in this app are recorded as such. Because the app performs no
network communication and requests a minimal permission set, the exposure from
dependency vulnerabilities is limited, but they are tracked and addressed
regardless. This periodic check is part of the release checklist in
[CONTRIBUTING.md](CONTRIBUTING.md#7-versioning--release-checklist) §7.

The same discipline applies to dependency licenses: every third-party
dependency must be under a license compatible with the project's
GPL-3.0-or-later distribution — the licenses actually in use are recorded in
[COPYING.md](COPYING.md) — and any dependency whose license is not compatible
is replaced or removed before a release. Together with the vulnerability triage
above, this defines the project's remediation threshold for
software-composition-analysis (SCA) findings.

## Secrets and credentials

The project uses a small, fixed set of secrets, none of which are ever committed
to version control:

- the **release code-signing keystore** and the keystore file it references),
  used to sign the release artifacts, the Google Play upload bundle and the
  Codeberg/F-Droid APK;
- the **App Store upload credentials,** used only by the Fastlane App Store
  upload lanes; and
- the **Google Play upload credentials,** used only by the Fastlane Play Store
  upload lanes; and
- the maintainer's **OpenPGP signing key**, used to sign release tags and
  commits.

**Storing.** Secrets are never hard-coded in source and never stored in the
repository. The templates (`android/keystore.properties.example` and
`fastlane/Appfile`) document their structure without any secret values. On a
build host the values are supplied through those local files or, equivalently,
through environment variables (`POTILLUS_KEYSTORE_*`, `SUPPLY_JSON_KEY`), so a
secret is injected at build time rather than persisted in the tree.

**Accessing.** The project has a single maintainer, who is the only holder of
these secrets and keeps them solely on trusted and encrypted local machines;
they are not shared. Any future collaborator granted release duties would
receive only the specific credential their task requires.

**Rotating.** The Google Play API credential and any injected tokens can be
rotated at any time by revoking the old credential in the Google Play Console and
replacing the file or variable, with no code change. The OpenPGP signing key is
rotated by publishing a new key — updating the fingerprint recorded in this file —
and re-signing subsequent releases. The Android application-signing key is
deliberately long-lived, because update artifacts must be signed with the same
key for install continuity, so it is rotated only in response to suspected
compromise, following the key-rotation process of the distribution channel
(F-Droid or Play App Signing). Any secret believed to be exposed is revoked and
replaced before the next release.

## Verifying releases

Releases are cryptographically signed. The Codeberg release APK and the F-Droid
build are signed with the maintainer's own Android app-signing key (fingerprint
below); that private key is held only by the maintainer and is never stored on
Codeberg, F-Droid, or any other distribution site. On Google Play the maintainer
signs the uploaded App Bundle with the same private key in its role as the Play
upload key and likewise holds it alone, while Google holds the separate
app-signing key under Play App Signing and re-signs the artifact delivered to
Play users. The build is reproducible.

You can verify a downloaded or installed release in any of these ways:

- **Via F-Droid (automatic).** The F-Droid client verifies the APK signature on
  installation and on every update. This project's F-Droid metadata pins the
  allowed signing key (`AllowedAPKSigningKeys`), so an APK signed with any other
  key is rejected.

- **Manually, by certificate fingerprint.** Run:

  ```sh
  apksigner verify --print-certs de.godisch.potillus.apk
  ```

  and confirm that the reported signer certificate SHA-256 digest equals the
  project's signing-key fingerprint:

  ```
  7506f17184b31a2d67621305d190a73e497806b39f7d64463ff5dbc0afd8317b
  ```

  This fingerprint identifies the maintainer's app-signing key, which signs the
  F-Droid and Codeberg release APKs. An APK delivered by Google Play is re-signed
  by Google under Play App Signing and therefore reports a different signer
  certificate; verify a Play build against the app-signing certificate shown in
  the Play Console instead.

- **By reproducing the build.** Because the build is reproducible, you can
  rebuild the app from source at the corresponding release tag and compare the
  result against the published APK; F-Droid performs exactly this reproducibility
  check before publishing.

- **By verifying the release tag.** Release tags in the Git repository are
  GPG-signed with the maintainer's key (fingerprint
  `1842 323B 4FCF 9B90 995F  A17F A350 B991 F05A 4857`, the same key used for
  security reports above; fetch it from `hkps://keyring.debian.org:443`). After
  importing the key you can verify a tag with `git tag -v vX.Y.Z`.

- **By auditing commit signatures.** All commits are cryptographically signed —
  branch protection rejects unsigned or unverifiable commits — so you can check
  the authorship of the entire history with `git log --show-signature`. Codeberg
  also marks each verified commit as *Verified* in its web interface.
