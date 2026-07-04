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

# Assurance Case

This document is a short, structured argument for why Libellus Potionis meets
its security requirements. It states the threat model, identifies the trust
boundaries, argues that secure design principles were applied, and argues that
common implementation weaknesses have been countered. It complements the
security requirements documented in [SECURITY.md](SECURITY.md) ("Security
model").

## Security requirements (what is claimed)

The security goals, and their explicit limits, are defined in SECURITY.md
("Security model"). In summary, the app claims to: keep all user data on the
device (no network transmission), apply least privilege, store data in the app's
private sandbox with at-rest encryption (an AES-256-GCM key in the hardware-backed
Android Keystore for the preferences store), offer an optional biometric access
gate, and perform no tracking. It explicitly does **not** claim to protect data
on a compromised or rooted device, to protect exported files once they leave the
app, or to provide more than an access gate via biometrics.

## Threat model

### Assets

- The user's drinking history and related entries (sensitive personal data).
- Application settings, including the encrypted preferences store.

### Adversaries and attacks considered in scope

- **Another app on the same device** attempting to read this app's data →
  countered by the Android application sandbox and `allowBackup="false"`.
- **A bystander with brief physical access to the running device** (e.g.
  glancing at the screen, the Recents view, or screenshots) → countered by
  `FLAG_SECURE` (applied by default from cold start) and the optional biometric
  lock.
- **Someone who obtains the locked device** → data at rest is protected by the
  platform's storage encryption plus the Keystore-sealed preferences.
- **A network attacker** → not applicable: the app holds no network permission
  and performs no network communication, so there is no network attack surface.
- **Malformed or malicious input** (imported backup files, user-entered values)
  → countered by input validation (see below).

### Out of scope (residual risks, stated honestly)

- A **rooted, malware-infected, or otherwise compromised device**: the platform
  guarantees the app relies on can be bypassed; the app cannot defend data there.
- **Forensic extraction from an unlocked device**: the biometric lock is an
  access gate, not full-disk encryption.
- **Exported files** (CSV/PDF/JSON): once written to a user-chosen location they
  leave the app's control and are the user's responsibility.

## Trust boundaries

1. **App sandbox boundary** — between this app's private storage and other apps
   or the wider OS. Enforced by the Android sandbox; reinforced by
   `allowBackup="false"`.
2. **Keystore boundary** — between application code and the hardware-backed key
   store. The AES-256-GCM key is generated inside the Keystore; raw key material
   never crosses into application memory in exportable form.
3. **Screen/UI boundary** — between sensitive on-screen content and screenshot,
   screen-recording, and Recents surfaces. Enforced by `FLAG_SECURE`.
4. **User/device authentication boundary** — the device lock screen and the
   optional in-app biometric gate.
5. **Export boundary** — data crossing from the app to user-chosen file
   locations. This is explicitly **outside** the app's trust boundary.
6. **No network boundary** — no data crosses a network boundary, because the app
   has no network access.

## Argument: secure design principles were applied

- **Least privilege / minimal attack surface** — no network, camera, microphone,
  location, contacts, or runtime-storage permissions; only `USE_BIOMETRIC`.
- **Secure defaults** — offline-only; `FLAG_SECURE` on by default; no tracking,
  analytics, or ads; encrypted preferences.
- **Economy of mechanism** — a small, focused architecture with a framework-free
  domain layer and few dependencies, reducing the code that must be trusted.
- **Defense in depth** — sandbox + at-rest encryption + optional biometric gate +
  `FLAG_SECURE` layer independently.
- **Fail-safe defaults** — invalid input is rejected rather than coerced; the
  amount dialog enters a controlled error state instead of accepting bad values.

These are the principles referenced by the `implement_secure_design` criterion.

## Argument: common implementation weaknesses were countered

Mapped to well-known mobile weakness classes:

- **Injection** — Room uses parameterized queries (no string-built SQL); the CSV
  exporter neutralizes spreadsheet formula injection (OWASP "CSV Injection").
- **Insecure data storage** — private sandbox, at-rest encryption, an AES-256-GCM
  Keystore key for preferences, `allowBackup="false"`, and `FLAG_SECURE`.
- **Insufficient cryptography** — AES-256 in GCM (authenticated) with a
  per-encryption random 96-bit IV from a secure RNG and a 128-bit tag; no weak
  algorithms (no MD5/SHA-1/ECB/DES). See `KeystoreSecretStore`.
- **Improper input validation** — backup/import data is validated on restore and
  rejected if invalid (covered by `BackupRepositoryInstrumentedTest`); numeric
  inputs are range/format checked; locale-aware parsing is regression-tested
  (`NumberFormatTest`).
- **Sensitive data exposure over the network** — impossible by construction: the
  app cannot make network connections.
- **Memory-safety vulnerabilities** — the app is written in Kotlin on the JVM/ART
  runtime, which is memory-safe (no manual memory management, no buffer
  overflows).
- **Tampering / integrity** — releases are reproducible and signed; the signing
  key and tag verification are documented in SECURITY.md ("Verifying releases").
- **Data integrity across upgrades** — versioned Room migrations validated by
  `MigrationTest`.

## Conclusion

Given the threat model above, the identified trust boundaries are enforced by the
Android sandbox, the hardware-backed Keystore, `FLAG_SECURE`, the device/biometric
authentication gate, and the absence of any network surface; secure design
principles are applied; and the common implementation weakness classes relevant
to a local, offline Android app are countered. The residual risks (a compromised
device, forensic access to an unlocked device, and exported files) are stated
explicitly rather than claimed to be mitigated. On this basis, the security
requirements in SECURITY.md are met for the app's intended threat model.
