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
docs/PLAY_STORE.md -- Google Play publishing runbook
=============================================================================

WHAT THIS IS
  A repeatable, step-by-step runbook for publishing Libellus Potionis to the
  Google Play Store ALONGSIDE F-Droid, keeping a single signing identity across
  both channels. It documents decisions already made for this project (see
  "Signing model") so that a future release, or a future maintainer, can repeat
  the process without re-deriving them.

  This is a distribution/operations document. It describes NO change to the
  shipped APK and adds no runtime behaviour; it lives next to the source so the
  procedure travels with the code.
=============================================================================
-->

# Google Play publishing runbook

This runbook covers publishing **Libellus Potionis** to Google Play in parallel
with F-Droid, using **one signing identity** so an install can move between the
two stores without a reinstall.

> Companion file: [`PRIVACY.md`](../PRIVACY.md) is the privacy policy the Play
> listing must link to (see [Privacy policy hosting](#privacy-policy-hosting)).

## 1. Key facts for this app

| Item | Value |
| --- | --- |
| Package name (`applicationId`) | `de.godisch.potillus` |
| App signing certificate SHA-256 | `75:06:F1:71:84:B3:1A:2D:67:62:13:05:D1:90:A7:3E:49:78:06:B3:9F:7D:64:46:3F:F5:DB:C0:AF:D8:31:7B` |
| Same value, F-Droid format (`AllowedAPKSigningKeys`) | `7506f17184b31a2d67621305d190a73e497806b39f7d64463ff5dbc0afd8317b` |
| `minSdk` / `targetSdk` | 30 / 36 (Android 11 / Android 16) |
| Upload artifact | Android App Bundle (`.aab`) — not APK |
| Data collected / shared | none (no network permission) |

The two fingerprint rows above are the **same certificate**, printed two ways:
Play and `keytool` use uppercase, colon-separated hex; F-Droid uses lowercase
hex without separators. Source of truth is the keystore itself:

```sh
keytool -list -v -keystore potillus-release.jks -alias potillus   # read the "SHA256:" line
```

## 2. Signing model (read this first)

Play App Signing is mandatory for new apps. It uses **two** keys:

- **App signing key** — the key Google uses to sign the APKs delivered to users.
  Android checks this signature on every update. For this project it MUST be the
  **existing release key** (`potillus-release.jks`, alias `potillus`, the
  certificate `75:06:F1:…:7B`), because that is the key F-Droid already pins in
  `AllowedAPKSigningKeys`. You provide it to Google via the PEPK tool. Google's
  own guidance is explicit: to use the same signing key across multiple stores,
  you must provide your own key instead of letting Google generate one.
- **Upload key** — the key you sign the uploaded bundle with. **Decision for
  this project: a separate upload key.** Google verifies the upload with it and
  then re-signs with the app signing key. A separate upload key can be reset if
  it is lost or leaked, without ever touching the app signing key.

Consequence: an install from Play carries the same certificate (`75:06:F1:…:7B`)
as an install from F-Droid, so the two are update-compatible.

**What is NOT achievable, and is fine:** byte-for-byte identical APKs across the
two stores. Play delivers per-device split APKs generated from your `.aab`;
F-Droid delivers your single reproducibly-built APK. Only the signing
*certificate* is shared. F-Droid's reproducible-build verification is
independent and unaffected by anything in this runbook.

## 3. One-time setup

Do these once, in order. Steps marked **(Console only)** cannot be done by
fastlane — the tooling can upload builds and listing text, but it cannot create
the app, enroll signing, or answer policy declarations.

### 3.1 Account (Console only)

- Complete developer identity verification if you have not already.
- Enforce 2-Step Verification on the Google account that owns the Play Console.

### 3.2 Create the separate upload key

```sh
# Generate the upload key (kept private, off the repository):
keytool -genkeypair -v \
  -keystore potillus-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000

# Export its PUBLIC certificate, to register with Google during signing setup:
keytool -export -rfc \
  -keystore potillus-upload.jks \
  -alias upload \
  -file potillus-upload-certificate.pem
```

### 3.3 Register the package name (Console only)

This is the "add your public key to complete registration of this package name"
step (part of Android developer verification). Google asks for the SHA-256
fingerprint of the key that signs your updates — i.e. the **app signing key**,
not the upload key. Enter the certificate fingerprint from
[section 1](#1-key-facts-for-this-app):

```
75:06:F1:71:84:B3:1A:2D:67:62:13:05:D1:90:A7:3E:49:78:06:B3:9F:7D:64:46:3F:F5:DB:C0:AF:D8:31:7B
```

Because `de.godisch.potillus` is a new package name, providing this public
certificate fingerprint is sufficient; no proof-of-ownership APK upload is
required (that path is only for package names that already have installs).

### 3.4 Create the app (Console only)

Play Console → **Create app**: name "Libellus Potionis", default language, type
**App**, **Free**, and accept the developer declarations.

### 3.5 Enroll Play App Signing with your own key (Console only)

In **App integrity → Play App Signing**, choose to provide your own key
(**"Export and upload a key from Java keystore"**). The Console shows an exact
`pepk` command that embeds a one-time Google encryption key — use that exact
command; the general shape is:

```sh
java -jar pepk.jar \
  --keystore=potillus-release.jks \
  --alias=potillus \
  --output=potillus-app-signing-key.zip \
  --include-cert \
  --encryption-key-path=<file the Console tells you to use>
```

Upload the resulting file. Then register the **upload** certificate
(`potillus-upload-certificate.pem` from [3.2](#32-create-the-separate-upload-key))
as the upload key.

### 3.6 Store listing and "App content" (mostly Console)

The listing **text, changelogs, icon, feature graphic and screenshots** already
live under `fastlane/metadata/android/` and are pushed by fastlane
([section 4](#4-building-and-uploading)). The following are Console-only:

- **Category:** Health & Fitness. **Contact details:** the developer email.
- **Privacy policy URL:** required (see [3.7](#37-privacy-policy-hosting)).
- **Data safety form:** *no data collected, no data shared*; data stays on the
  device and is protected at rest. This matches `PRIVACY.md`.
- **Ads:** none.
- **Content rating questionnaire:** answer truthfully, including the references
  to alcohol. Expect a higher age rating in several regions — that is normal.
- **Target audience and content:** adults; **do not** target children.
- **Health/Government/Financial/News/Health Connect declarations:** none apply
  (the app is not a Health Connect app and stores only self-logged data).

### 3.7 Privacy policy hosting

Google needs a public URL that renders the policy in [`PRIVACY.md`](../PRIVACY.md).
Two supported options:

1. **Direct repository link (simplest):**
   `https://codeberg.org/godisch/potillus/src/branch/main/PRIVACY.md`
   — publicly reachable and shows the full policy.
2. **Codeberg Pages (cleaner URL):** add the policy to a `pages` branch (or a
   `pages` repository); it is then served at
   `https://godisch.codeberg.page/potillus/`. Use this if you prefer a
   listing-quality URL without the repository chrome.

## 4. Building and uploading

Build the signed bundle (requires `android/keystore.properties` or the
`POTILLUS_*` environment variables — see `android/keystore.properties.example`):

```sh
make bundle    # -> android/app/build/outputs/bundle/release/app-release.aab
```

Upload with the existing fastlane lane (reads `package_name` and the
service-account key from `fastlane/Appfile`):

```sh
bundle exec fastlane deploy track:internal status:completed   # smoke test
bundle exec fastlane deploy track:closed   status:completed   # the 14-day gate
bundle exec fastlane deploy track:production                  # once approved
```

The `deploy` lane defaults to the **internal** track and to
`release_status: draft`; you must pass `track:production` explicitly to touch
production. The very first upload to a track may need to be started in the
Console because the app, signing enrollment and content declarations must exist
first; afterwards fastlane handles builds and listing sync.

The service-account JSON key (`fastlane/play-store-credentials.json`, or the
`SUPPLY_JSON_KEY` environment variable) is created once in the Google Cloud
Console for a service account granted access in the Play Console. It is a secret
and is git-ignored.

## 5. The testing gate (personal developer account)

A personal developer account created after 2023-11-13 cannot publish straight to
production. You must run a **closed test with at least 12 testers who stay
opted-in for 14 continuous days**, then apply for production access (review
typically ≤ 7 days). Recommended track order: **internal → closed (14 days) →
production**. Recruit real testers on real devices via an email list or a Google
Group; keep them engaged, and ship fixes as normal releases during the window.

## 6. Release discipline and versioning

- Every artifact uploaded to Play needs a **strictly higher `versionCode`** than
  the previous Play upload. Keep `versionCode`/`versionName` in lockstep with the
  CHANGELOG and README — `tools/release-check.sh` §1 enforces this. Prefer
  iterating via real patch releases over throwaway builds.
- The F-Droid reference recipe (`fdroid/de.godisch.potillus.yml`) is kept only as
  a static backup / documentation snapshot; it is no longer auto-maintained or
  version-checked, so it does not participate in the lockstep above.
- Play and F-Droid track `versionCode` independently, so the current `88` is fine
  as a first Play upload; keep them numerically aligned per release for sanity.
- The introduction of Play publishing is intentionally documentation- and
  tooling-only (this file, `PRIVACY.md`, and the `deploy`-lane default); it ships
  no APK change and therefore carries no standalone `versionCode`. Its CHANGELOG
  note is folded into the next tagged release.

## 7. Secrets and where they live (all git-ignored)

| Secret | Purpose |
| --- | --- |
| `android/keystore.properties` | app signing key path + passwords for the build |
| `potillus-release.jks` | the app signing key (provided to Play via PEPK) |
| `potillus-upload.jks` | the separate upload key |
| `fastlane/play-store-credentials.json` | Play Developer API service-account key |

Never commit any of these. Environment-variable equivalents exist for CI
(`POTILLUS_KEYSTORE_FILE`, `POTILLUS_KEYSTORE_PASSWORD`, `POTILLUS_KEY_ALIAS`,
`POTILLUS_KEY_PASSWORD`, and `SUPPLY_JSON_KEY`).

## 8. References

- Play App Signing (provide your own key): <https://support.google.com/googleplay/android-developer/answer/9842756>
- Register Android package names: <https://support.google.com/googleplay/android-developer/answer/16761053>
- Testing requirements for new personal accounts: <https://support.google.com/googleplay/android-developer/answer/14151465>
- fastlane `supply`: <https://docs.fastlane.tools/actions/supply/>
