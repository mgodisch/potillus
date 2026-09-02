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

The security goals and their explicit limits are defined in
[SECURITY.md](../SECURITY.md) ("Security model") and are not restated here. This
document takes them as given and argues that they hold. The claim covers both
native apps in this repository — Kotlin/Jetpack Compose on Android and
Swift/SwiftUI on iOS — which share the same ported domain and data-validation
logic; where a guarantee rests on a platform facility, the Android and iOS
mechanisms are named side by side below.

## Threat model

### Assets

- The user's drinking history and related entries (sensitive personal data), in
  a plain SQLite database inside the app's private storage.
- Application settings, including the body weight, in a preferences store the
  app seals itself.

The asset that matters most carries the weaker application-level protection, a
point SECURITY.md states in full under "What users cannot expect". Wherever this
document says "at-rest encryption" as a property of the app rather than of the
platform, it means the preferences store and not the history.

### Adversaries and attacks considered in scope

- **Another app on the same device** → the platform sandbox, reinforced against
  automatic off-device copies by `allowBackup="false"` (Android) and
  `isExcludedFromBackup` on the database (iOS).
- **A bystander with brief access to the running device** → the optional
  biometric lock and the switcher cover. The screen defence differs by platform:
  Android's `FLAG_SECURE` blocks screenshots, recording and the Recents
  thumbnail alike, while iOS covers only the switcher snapshot.
- **Someone who obtains the locked device** → the platform's storage encryption
  and the sealed preferences, whose iOS key never leaves the device. For the
  history the platform is the whole of the defence: the biometric lock gates the
  app, not the file.
- **A network attacker** → no attack surface; neither app can reach a network.
- **Malformed or malicious input** (imported backups, entered values) → the
  shared validation argued below.

### Out of scope

The residual risks are a compromised or jailbroken device, forensic extraction
from an unlocked one, active screen capture on iOS, and exported files once they
leave the app. SECURITY.md states each of them and why it is not defended.

## Trust boundaries

1. **App sandbox boundary** — between this app's private storage and other apps
   or the wider OS.
2. **Key-store boundary** — between application code and the platform key store.
   On Android raw key material never crosses into application memory in
   exportable form. On iOS it does, transiently: the Keychain returns the 32
   key bytes, which live in process memory while the preferences are sealed or
   opened. The Secure Enclave cannot hold an AES key, so a non-exportable
   symmetric key is not available on that platform; the boundary there is the
   Keychain's access class (`WhenUnlockedThisDeviceOnly`), not the key's
   non-exportability.
3. **Screen/UI boundary** — between on-screen content and the screenshot,
   recording and switcher surfaces. Enforced on Android, partial on iOS.
4. **User/device authentication boundary** — the device lock screen and the
   optional in-app biometric gate. The gate fails closed: an armed lock on a
   device that has lost every credential stays locked rather than opening
   (SECURITY.md, "Optional biometric lock"); the rule is pinned by
   `AppLockModelTests` on iOS and enforced by the prompt's own error path on
   Android.
5. **Export boundary** — data crossing to user-chosen file locations, explicitly
   **outside** the app's trust boundary.
6. **No network boundary** — nothing crosses one, because neither app has
   network access.

Which mechanism enforces which boundary on which platform is named under
Adversaries above and in SECURITY.md.

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
- **Defense in depth** — sandbox + platform storage encryption + the sealed
  preferences store + optional biometric gate + screen-privacy layer, each
  independent of the others. The layers are not uniform across the assets: see
  the note under Assets for which of them covers the drinking history.
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
- **Insecure data storage** — the sandbox, the sealed preferences store, the
  backup exclusions and the screen-privacy layer named above, on both platforms.
- **Insufficient cryptography** — AES-256 in GCM (authenticated) with a
  per-encryption random 96-bit nonce from a secure RNG and a 128-bit tag; no weak
  algorithms (no MD5/SHA-1/ECB/DES). Implemented by `KeystoreSecretStore` on
  Android and by CryptoKit's `AES.GCM` over a `KeychainKeyProvider` 256-bit key on
  iOS, which write the identical `nonce || ciphertext || tag` layout. That
  identity is pinned by `test-vectors/sealed-blob.json`, which both suites open
  under a fixed key (`SealedBlobVectorTest` on each side).
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

The trust boundaries above are enforced on each platform by its sandbox, its key
store, its screen-privacy facility, the device and biometric gate, and the
absence of a network surface; the design principles are applied; and the weakness
classes relevant to a local, offline app are countered on both. The residual
risks are stated rather than claimed to be mitigated. On this basis the security
requirements in SECURITY.md are met, for both apps, within the intended threat
model.

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

Outcome: the countermeasures described above are in place, and no unresolved
high-severity issues are known. This record is updated whenever a further review
is performed.

Since 2026-07, the manual argument above is complemented by a machine one. CodeQL
analyses Kotlin/Java and Swift on the GitHub mirror (see
[MIRROR-CHECKS.md](MIRROR-CHECKS.md)). It is a different kind of evidence from
everything else cited here: the `tools/` checks, ktlint, Android Lint and
SwiftLint each reason about one file, whereas CodeQL follows data flow across
functions and files, which is the level at which the weakness classes above would
manifest. Findings are triaged in the code-scanning view and anything
substantiated is recorded here at the next review. The analysis is advisory; the
enforcing gate remains the GitLab pipeline.
