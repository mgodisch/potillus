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

# Assurance Case

This document is a short, structured argument for why Libellus Potionis meets
its security requirements. It states the threat model, identifies the trust
boundaries, argues that secure design principles were applied, and argues that
common implementation weaknesses have been countered. It complements the
security requirements documented in [SECURITY.md](../SECURITY.md) ("Security
model").

## Security requirements (what is claimed)

The security goals, and their explicit limits, are defined in SECURITY.md
("Security model"). In summary, the app claims to: keep all user data on the
device (no network transmission), apply least privilege, store data in the app's
private sandbox with at-rest encryption (an AES-256-GCM key held in the
hardware-backed Android Keystore on Android, and in the iOS Keychain — a
`WhenUnlockedThisDeviceOnly` key — on iOS, each sealing the preferences store),
offer an optional biometric access gate, and perform no tracking. It explicitly
does **not** claim to protect data on a compromised or rooted/jailbroken device,
to protect exported files once they leave the app, or to provide more than an
access gate via biometrics. The claim holds for both native apps in this
repository — Kotlin/Jetpack Compose on Android and Swift/SwiftUI on iOS — which
share the same ported domain and data-validation logic; where a guarantee rests
on a platform facility, the Android and iOS mechanisms are named side by side
below.

## Threat model

### Assets

- The user's drinking history and related entries (sensitive personal data).
- Application settings, including the encrypted preferences store.

### Adversaries and attacks considered in scope

- **Another app on the same device** attempting to read this app's data →
  countered by the platform application sandbox, reinforced on Android by
  `allowBackup="false"` and on iOS by excluding the database from device backups
  (`isExcludedFromBackup`).
- **A bystander with brief physical access to the running device** (e.g.
  glancing at the screen, the Recents / app-switcher view, or screenshots) →
  countered by the optional biometric lock and by hiding the app's contents in
  the switcher preview. The strength of the screen defence differs by platform
  and is stated honestly: on Android `FLAG_SECURE` (applied by default from cold
  start) blocks screenshots, screen recording, and the Recents thumbnail alike;
  on iOS the app can cover its switcher snapshot but **cannot** block an active
  screenshot or screen recording, because the platform offers no equivalent of
  `FLAG_SECURE` (see the residual risk below).
- **Someone who obtains the locked device** → data at rest is protected by the
  platform's storage encryption, plus the Keystore-sealed (Android) or
  Keychain-sealed (iOS) preferences; the iOS key's `ThisDeviceOnly` class keeps
  it off every backup and off any other device.
- **A network attacker** → not applicable on either platform: the app holds no
  network permission or entitlement and performs no network communication, so
  there is no network attack surface.
- **Malformed or malicious input** (imported backup files, user-entered values)
  → countered by the shared input validation (see below).

### Out of scope (residual risks, stated honestly)

- A **rooted, jailbroken, malware-infected, or otherwise compromised device**:
  the platform guarantees the app relies on can be bypassed; the app cannot
  defend data there.
- **Forensic extraction from an unlocked device**: the biometric lock is an
  access gate, not full-disk encryption.
- **Active screen capture on iOS**: because iOS exposes no `FLAG_SECURE`
  equivalent, a screenshot or screen recording the user (or software acting as
  the user) takes while the app is in the foreground is not prevented; the
  app-switcher cover addresses only the passive switcher preview.
- **Exported files** (CSV/PDF/JSON): once written to a user-chosen location they
  leave the app's control and are the user's responsibility.

## Trust boundaries

1. **App sandbox boundary** — between this app's private storage and other apps
   or the wider OS. Enforced by the platform sandbox; reinforced against
   automatic off-device copies by `allowBackup="false"` (Android) and by
   `isExcludedFromBackup` on the database (iOS).
2. **Key-store boundary** — between application code and the platform key store.
   The AES-256-GCM key is generated inside the hardware-backed Android Keystore,
   or held in the iOS Keychain (`WhenUnlockedThisDeviceOnly`); on Android raw key
   material never crosses into application memory in exportable form.
3. **Screen/UI boundary** — between sensitive on-screen content and screenshot,
   screen-recording, and Recents/app-switcher surfaces. Fully enforced on Android
   by `FLAG_SECURE`; on iOS only the switcher snapshot is covered, and active
   screen capture is out of scope (see residual risks).
4. **User/device authentication boundary** — the device lock screen and the
   optional in-app biometric gate (fingerprint on Android; Face ID / Touch ID
   with device-passcode fallback on iOS).
5. **Export boundary** — data crossing from the app to user-chosen file
   locations. This is explicitly **outside** the app's trust boundary.
6. **No network boundary** — no data crosses a network boundary, because neither
   app has network access.

## Argument: secure design principles were applied

- **Least privilege / minimal attack surface** — no network, camera, microphone,
  location, or contacts access on either platform; Android requests only
  `USE_BIOMETRIC`, and iOS declares no network entitlement and uses only local
  authentication.
- **Secure defaults** — offline-only; screen-privacy on by default (`FLAG_SECURE`
  on Android, the switcher cover on iOS); no tracking, analytics, or ads;
  encrypted preferences.
- **Economy of mechanism** — a small, focused architecture with a framework-free,
  shared domain layer and few dependencies (Room on Android, GRDB on iOS),
  reducing the code that must be trusted.
- **Defense in depth** — sandbox + at-rest encryption + optional biometric gate +
  screen-privacy layer independently.
- **Fail-safe defaults** — invalid input is rejected rather than coerced by the
  shared validators; the amount dialog enters a controlled error state instead of
  accepting bad values.

These are the principles referenced by the `implement_secure_design` criterion.

## Argument: common implementation weaknesses were countered

Mapped to well-known mobile weakness classes:

- **Injection** — the database layer uses parameterized queries with no
  string-built SQL from user input (Room on Android, GRDB on iOS); the CSV
  exporter neutralizes spreadsheet formula injection on both platforms (OWASP
  "CSV Injection"), prefixing a cell that begins with `=`, `+`, `-`, `@`, TAB, or
  CR.
- **Insecure data storage** — private sandbox and at-rest storage encryption on
  both; an AES-256-GCM-sealed preferences store keyed from the Android Keystore or
  the iOS Keychain; `allowBackup="false"` (Android) and database backup exclusion
  (iOS); screen-privacy via `FLAG_SECURE` (Android) and the switcher cover (iOS).
- **Insufficient cryptography** — AES-256 in GCM (authenticated) with a
  per-encryption random 96-bit nonce from a secure RNG and a 128-bit tag; no weak
  algorithms (no MD5/SHA-1/ECB/DES). Implemented by `KeystoreSecretStore` on
  Android and by CryptoKit's `AES.GCM` over a `KeychainKeyProvider` 256-bit key on
  iOS, which write the identical `nonce || ciphertext || tag` layout.
- **Improper input validation** — backup/import data is validated on restore and
  rejected if invalid; numeric inputs are range/format checked; locale-aware
  parsing is regression-tested. The validators are part of the shared domain, so
  both apps enforce them, and both carry the regression suites (Android's
  `BackupRepositoryInstrumentedTest` and `NumberFormatTest`; the iOS
  `BackupValidationTests`, `BackupImporterTests`, and `DrinkValidatorTests`).
- **Sensitive data exposure over the network** — impossible by construction on
  either platform: neither app can make network connections.
- **Memory-safety vulnerabilities** — both apps are written in memory-safe
  languages with automatic memory management and no manual pointer arithmetic:
  Kotlin on the JVM/ART runtime (Android) and Swift with ARC (iOS), so classes
  like buffer overflows do not arise.
- **Tampering / integrity** — Android releases are reproducible and signed, with
  the signing key and tag verification documented in SECURITY.md ("Verifying
  releases"); iOS builds are code-signed and distributed through Apple's App
  Store review and signing chain.
- **Data integrity across upgrades** — versioned schema migrations on both
  platforms, validated by Android's `MigrationTest` and cross-checked on iOS by
  `SchemaParityTests`, which holds the GRDB schema (via `DatabaseMigrator`) in
  step with Room's.

## Conclusion

Given the threat model above, the identified trust boundaries are enforced on
each platform by its sandbox, its key store (the hardware-backed Android Keystore
or the iOS Keychain), its screen-privacy facility (`FLAG_SECURE` on Android; the
switcher cover on iOS, with active screen capture stated as a residual risk), the
device/biometric authentication gate, and the absence of any network surface;
secure design principles are applied; and the common implementation weakness
classes relevant to a local, offline mobile app are countered on both. The
residual risks (a compromised/jailbroken device, forensic access to an unlocked
device, active screen capture on iOS, and exported files) are stated explicitly
rather than claimed to be mitigated. On this basis, the security requirements in
SECURITY.md are met, for both the Android and iOS apps, within the app's intended
threat model.

## Security review record

A security review of Libellus Potionis was performed in 2026 by the maintainer.
It took into account the security requirements (SECURITY.md, "Security model")
and the security boundary (the threat model and trust boundaries described above
in this document). The review combined the assurance-case analysis with an
Android-focused code and quality-assurance pass over the security-relevant areas:
at-rest encryption (`KeystoreSecretStore`), input and backup/import validation,
CSV-injection neutralization, the permission surface and exported components, and
the `FLAG_SECURE` / `allowBackup="false"` / R8 hardening measures.

The iOS port's security-relevant areas are argued in this document and exercised
by the package's automated tests and release gates: the Keychain key provider and
the `AES.GCM` preferences sealing (`PreferencesStoreTests`), backup exclusion
(`BackupExclusionTests`), CSV-injection neutralization (`CsvExporterTests`),
backup/import validation (`BackupValidationTests`, `BackupImporterTests`), the
biometric gate (`AppLockModelTests`), and schema parity with Android
(`SchemaParityTests`). A dedicated on-device iOS security-review pass — the
counterpart of the Android one above — is to be recorded here when performed.

Outcome: the countermeasures described above are in place; the residual risks (a
compromised device, forensic access to an unlocked device, active screen capture
on iOS, and exported files) are documented rather than claimed to be mitigated;
and no unresolved high-severity issues are known. This record is updated whenever
a further review is performed.

Since 2026-07, the manual argument above is complemented by a machine one.
CodeQL analyses both languages — Kotlin/Java and Swift — weekly and on every
change to `main`, on the project's GitHub mirror, where the builds each language
needs can actually run (see [MIRROR-CHECKS.md](MIRROR-CHECKS.md)). This is a
different kind of evidence from everything else cited in this document: the
`tools/` checks, ktlint, Android Lint and SwiftLint all reason about one file at
a time, whereas CodeQL reasons about data flow across functions and files, which
is the level at which the weakness classes in the section above would actually
manifest. Its findings are triaged in GitHub's code-scanning view, and anything
substantiated is recorded here as part of the next review. The analysis is
advisory and does not gate a merge; the enforcing gate remains the GitLab
pipeline.
