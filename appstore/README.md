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

# App Store distribution

How the iOS build reaches the Apple App Store. This is the counterpart to the
Google Play flow driven by `make push-playstore`, but because the App Store
toolchain (Xcode, `xcodebuild`, the iOS Simulator) only runs on macOS, there is
**no Makefile target** for it: the steps below are run by hand on the Mac. The
repository stays the single source of truth for the listing — every upload
overwrites the App Store texts from `fastlane/metadata/ios/`, exactly as the
Android upload does from `fastlane/metadata/android/`.

This directory is documentation only; it holds no build artifacts or
credentials.

## One-time setup

1. **App record.** Create the app in App Store Connect with bundle identifier
   `de.godisch.potillus` (the same identifier as `ios/project.yml` →
   `PRODUCT_BUNDLE_IDENTIFIER` and the Android `applicationId`).
2. **API key.** In App Store Connect → *Users and Access* → *Integrations* →
   *Keys*, create an App Store Connect API key (a *Team* key) and download the
   `AuthKey_<KEYID>.p8`. It can be downloaded **once**. Place it at
   `fastlane/AuthKey_<KEYID>.p8` (git-ignored).
3. **Environment.** Export the three values fastlane reads by default (see the
   iOS block in `fastlane/Fastfile`):

   ```sh
   export APP_STORE_CONNECT_API_KEY_KEY_ID=<KEYID>
   export APP_STORE_CONNECT_API_KEY_ISSUER_ID=<ISSUER-UUID>
   export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH=fastlane/AuthKey_<KEYID>.p8
   ```
4. **Reviewer contact.** Fill in the placeholder files under
   `fastlane/metadata/ios/review_information/` with a real contact. The app is
   fully offline and needs no demo account, which `notes.txt` already states.
5. **Ruby gems.** `cd fastlane && bundle install` (the same Gemfile the Android
   lanes use).

## Building the signed app

fastlane does **not** build the app (mirroring the Android lanes, which never
build the AAB). Produce a signed `.ipa` first, either from Xcode
(*Product → Archive → Distribute App*) or from the command line, and place it at
`ios/build/Potillus.ipa` (the path the `upload_appstore` lane expects).

Reproducibility note: as with the GitLab/F-Droid Android artifacts, the build
is reproducible **up to the point of upload** — the archive you sign locally is
the artifact you ship. Apple then re-signs the binary on ingestion, so the bytes
Apple distributes are not bit-identical to your local archive; this is the same
store-side re-signing already documented for Google Play in `.bestpractices.json`
and `SECURITY.md`.

## Screenshots

```sh
bundle exec fastlane ios screenshots
```

This runs the `snapshot` UI-test capture configured in `fastlane/Snapfile`. It
requires a `PotillusUITests` scheme that drives the app through the six screens
(added with the app target in `ios/`). The captured PNGs land under
`fastlane/screenshots/ios/`.

## Uploading the listing

Two lanes, both of which upload the `.ipa` and overwrite the listing texts,
keywords, subtitles, descriptions and screenshots from `fastlane/metadata/ios/`:

```sh
# Upload without submitting for review (lands in App Store Connect / TestFlight):
bundle exec fastlane ios testing

# Upload AND submit the build for Apple review:
bundle exec fastlane ios production
```

Apple review gates the actual release; nothing goes live automatically without
passing review.

## App Store Connect console answers

A few listing answers are console-side (not repository files):

- The privacy "nutrition label": expected "Data Not Collected" (the app makes no
  network requests and collects nothing off-device).
- Export compliance: the app uses only standard platform cryptography
  (`ITSAppUsesNonExemptEncryption` is already set to `NO` in `ios/project.yml`).
- Age rating: answer Apple's questionnaire (the app concerns alcohol, so expect a
  17+ rating).

## Store metadata and translations

The listing texts live in `fastlane/metadata/ios/<locale>/`. **English and German
are the maintainer's own wording; every other language is machine-assisted and
has not been reviewed by a native speaker.** Native-speaker corrections are very
welcome — see the localization section in
[`CONTRIBUTING.md`](../CONTRIBUTING.md#6-translation-workflow), which covers both
the in-app strings and these store texts.
