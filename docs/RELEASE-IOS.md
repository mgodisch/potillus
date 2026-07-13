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

The first export may prompt for authentication with the Apple Developer website.
`-allowProvisioningUpdates` uses the Apple ID signed into Xcode (Settings →
Accounts); if it reports a login/session error, sign in there again, or ensure
“Access to Cloud Managed Distribution Certificate” is enabled for your account in
App Store Connect → Users and Access.

Then pick the destination — both take the staged path the build just printed:

- **TestFlight (device testing).** Internal testing; no App Store metadata or
  screenshots are involved:

      cd fastlane && bundle exec fastlane ios beta ipa:../releases/de.godisch.potillus_<versionCode>.ipa

  The build appears under TestFlight in App Store Connect once Apple finishes
  processing it; internal testers are notified per your App Store Connect
  settings. Install it on the device through the TestFlight app.

- **App Store listing + screenshots.** This is a SEPARATE concern from device
  testing. The existing `ios testing` / `ios production` lanes push the listing
  texts and the store screenshots from `fastlane/metadata/ios/` and
  `fastlane/screenshots/ios/` via `upload_to_app_store`; `testing` uploads
  without submitting for review, `production` submits. They accept the same
  staged `ipa:` path.

## Internal vs. external TestFlight

The `beta` lane distributes **internally** (`distribute_external: false`):
immediate, no Beta App Review, up to the team's internal-tester limit. External
testing (public groups) additionally needs a Beta App Review and beta metadata
and is intentionally not wired here yet; add `groups:` and
`distribute_external: true` to the lane when that becomes relevant.

## Export compliance

`ios/project.yml` sets `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: "NO"`. The
app uses only Apple's standard OS cryptography (Keychain and the system
frameworks), which is exempt, so TestFlight uploads carry the encryption
declaration automatically and do not prompt for it per build.
