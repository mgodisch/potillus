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

# Releasing the iOS app (TestFlight and the App Store)

This note describes how a signed iOS build reaches a real device through
TestFlight, and how the same build populates the App Store listing. It mirrors
the Android split exactly: **the Makefile builds and stages the artifact, and a
fastlane lane uploads it** — nothing is built inside a lane.

Everything here needs a **Mac with Xcode** and an **active Apple Developer
Program membership**. None of it runs in the container, and none of it is
needed for Simulator development or for the container-runnable static checks.

## One-time setup

1. **Team ID.** Copy `ios/signing.properties.example` to
   `ios/signing.properties` and fill in your ten-character Apple Developer Team
   ID. The file is git-ignored; the environment variable `DEVELOPMENT_TEAM`
   overrides it for a single build. See the template's own comments for where to
   read the Team ID.
2. **App Store Connect API key.** Download the `.p8` key once (App Store Connect
   → Users and Access → Integrations → App Store Connect API) and point the
   fastlane environment variables at it:
   `APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`,
   `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH`. The key is git-ignored
   (`fastlane/AuthKey_*.p8`) and cannot be re-downloaded, so keep a backup. This
   is the same key the App Store upload lanes already use.
3. **App record.** The app must exist in App Store Connect under the bundle ID
   `de.godisch.potillus` before the first upload.

## Build once, then choose where it goes

Build and stage the signed `.ipa` (this is the iOS analogue of
`make release-android`):

    make release-ios

`release-ios` archives the `Potillus` scheme in the Release configuration
*without code signing*, then signs the `.ipa` only at the App-Store export step
(automatic cloud signing via `-allowProvisioningUpdates`). That keeps the release
device-independent: no registered device and no development provisioning profile
are needed — the export mints the distribution certificate and the App-Store
profile itself. It stages a copy into `releases/` under the canonical
`de.godisch.potillus_<versionCode>.ipa` name — with the same fail-fast guard that
refuses to overwrite an already-staged release — and prints the exact upload
commands when it finishes.

The export needs to authenticate with the Apple Developer website (to mint the
distribution certificate and App-Store profile). It uses the same App Store
Connect API key as the upload: when `APP_STORE_CONNECT_API_KEY_KEY_ID`,
`APP_STORE_CONNECT_API_KEY_ISSUER_ID` and `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH`
are set, `release-ios` passes them to `xcodebuild` explicitly, so the whole
release runs head-less (e.g. over SSH) without a signed-in Xcode account. If those
variables are not set, it falls back to the Apple ID signed into Xcode (Settings →
Accounts).

Troubleshooting the export's Apple authentication:

- **“No Accounts”** — no credentials were seen. Set the three variables, or sign
  in to Xcode (Settings → Accounts).
- **“Your Apple Account or password was entered incorrectly” / HTTP 401** — the
  API key ID and the `.p8` file are from different keys, or the path is wrong.
  Check that `APP_STORE_CONNECT_API_KEY_KEY_ID` matches the `AuthKey_<id>.p8` that
  `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH` points at (an absolute path), and that
  the issuer ID belongs to the same team.
- **“Cloud signing permission error” / “No signing certificate ‘iOS Distribution’
  found”** — the API key lacks access to cloud-managed distribution certificates.
  For an API key this requires the **Admin** role: there is no per-key web toggle
  for it (the “Access to Cloud Managed Distribution Certificate” checkbox exists
  only for Apple-ID users on the Xcode-account path). Create an Admin-role key, or
  install a distribution certificate in the keychain so the export signs locally.

Then pick the destination — both take the staged path the build just printed:

- **TestFlight (device testing).** Internal testing; no App Store metadata or
  screenshots are involved:

      cd fastlane && bundle exec fastlane ios alpha ipa:releases/de.godisch.potillus_<versionCode>.ipa

  The build appears under TestFlight in App Store Connect once Apple finishes
  processing it; internal testers are notified per your App Store Connect
  settings. Install it on the device through the TestFlight app.

- **App Store listing + screenshots.** This is a SEPARATE concern from device
  testing, and it goes through `make push-appstore` rather than a bare fastlane
  call:

      make push-appstore            # upload + listing, NOT submitted for review
      make push-appstore SUBMIT=1   # the same upload, and submit for Apple review

  The target never builds: it uploads the `.ipa` `make release-ios` staged. Before
  handing it to fastlane it checks that the staged `.ipa` exists, that the release
  tag `vX.Y.Z` is pushed, that the `.ipa`'s own bundle identifier, build number and
  marketing version match this working tree, that its signature verifies and
  carries your Team ID, and that the App Store Connect API key can actually reach
  the app record. The upload itself is the fastlane `ios testing` lane (or
  `ios production` with `SUBMIT=1`), which pushes the listing texts and store
  screenshots from `fastlane/metadata/ios/` and `fastlane/screenshots/ios/`.

  Mind what `ios testing` is *not*: unlike Play's alpha track it has no separate
  audience. The App Store has one listing and this overwrites it — "testing" means
  "not submitted for review", not "not public". There is no iOS equivalent of
  `push-playstore`'s `VALIDATE_ONLY=1`, because `deliver` has no validate-only
  mode; `make push-appstore-preflight` is the closest thing — it checks the
  credentials read-only and uploads nothing.

  What fastlane does *not* push, and you therefore curate once in App Store
  Connect: the age rating, pricing and availability, and the App Privacy answers.

- **The reviewer contact is set up once per machine, not committed.** Apple wants
  a person it can phone. That is not something a public repository should answer,
  so the four files are git-ignored and created from the templates beside them:

  ```sh
  cd fastlane/metadata/ios/review_information
  for f in first_name last_name email_address phone_number; do
      cp "$f.txt.example" "$f.txt"
  done
  # then edit each one
  ```

  The phone number must start with `+` and its country code, and must be at most
  20 **bytes** — Apple counts bytes, not characters. `push-appstore` refuses to
  upload without all four, and `make check-ios-metadata` checks their shape,
  including the two fields Apple does not: a first or last name still reading
  `PLACEHOLDER` would otherwise go to the review team verbatim.

  `notes.txt` stays committed — it tells the reviewer the app is fully offline
  and needs no login, which is a fact about the app rather than about a person.
  `demo_user.txt` and `demo_password.txt` stay committed and empty for the same
  reason.

## Internal vs. external TestFlight

The `alpha` lane distributes **internally** (`distribute_external: false`):
immediate, no Beta App Review, up to the team's internal-tester limit. External
testing (public groups) additionally needs a Beta App Review and beta metadata
and is intentionally not wired here yet; add `groups:` and
`distribute_external: true` to the lane when that becomes relevant.

## Export compliance

`ios/project.yml` sets `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: "NO"`. The
app uses only Apple's standard OS cryptography (Keychain and the system
frameworks), which is exempt, so TestFlight uploads carry the encryption
declaration automatically and do not prompt for it per build.
