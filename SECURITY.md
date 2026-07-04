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
[ASSURANCE_CASE.md](docs/ASSURANCE_CASE.md).

**What users can expect:**

- **The app never transmits your data.** It holds no network permission at all,
  so it cannot exfiltrate data, sync to a cloud, or contact any server. It works
  entirely offline.
- **Data minimization and least privilege.** The app requests no camera,
  microphone, location, contacts, or runtime storage permissions. It collects
  only the data you enter.
- **On-device, sandboxed storage.** Your drinks, log entries, and settings live
  in the app's private, sandboxed storage, protected at rest by Android's
  file-based storage encryption. The preferences store is additionally sealed
  with an AES-256-GCM key held in the hardware-backed Android Keystore.
- **Optional biometric lock.** You can enable a fingerprint lock as a
  convenience gate against casual physical access to an unlocked device.
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

Send your report by e-mail to **android@godisch.de**.

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

If you are unable to use PGP, still write to android@godisch.de; the maintainer
will arrange a secure channel before you share any sensitive details.

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

## Scope

This policy covers the Libellus Potionis application code in this repository.
Vulnerabilities in third-party dependencies should be reported to their
respective projects; if a dependency issue affects Libellus Potionis, you are
welcome to notify the maintainer as well so the dependency can be updated.

## Dependency monitoring

The project's external dependencies are checked periodically — at a minimum
before each release — for known vulnerabilities. The check is performed with
[osv-scanner](https://google.github.io/osv-scanner/), a free/libre scanner that
queries the [OSV](https://osv.dev/) database, run against the CycloneDX SBOM the
build produces (the `cyclonedxDirectBom` task). Each reported issue is triaged:
exploitable vulnerabilities are fixed by upgrading (or, where necessary,
mitigating) the affected dependency, and issues that are not exploitable in this
app are recorded as such. Because the app performs no network communication and
requests a minimal permission set, the exposure from dependency vulnerabilities
is limited, but they are tracked and addressed regardless. This periodic check
is part of the release checklist in CONTRIBUTING.md §7.

## Verifying releases

Releases are distributed through F-Droid and are cryptographically signed with
the project maintainer's own Android app-signing key. The build is reproducible,
and the private signing key is held only by the maintainer — it is never stored
on Codeberg, F-Droid, or any other distribution site.

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

- **By reproducing the build.** Because the build is reproducible, you can
  rebuild the app from source at the corresponding release tag and compare the
  result against the published APK; F-Droid performs exactly this reproducibility
  check before publishing.

- **By verifying the release tag.** Release tags in the Git repository are
  GPG-signed with the maintainer's key (fingerprint
  `1842 323B 4FCF 9B90 995F  A17F A350 B991 F05A 4857`, the same key used for
  security reports above; fetch it from `hkps://keyring.debian.org:443`). After
  importing the key you can verify a tag with `git tag -v vX.Y.Z`.
