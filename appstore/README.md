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

Home for the Apple App Store listing assets and metadata, mirroring the role of
`fdroid/` for F-Droid. Populated during the store-preparation phase (see
`docs/IOS_MIGRATION.md`, phase 7).

Expected contents later:

- App Store Connect metadata (name, subtitle, description, keywords, support URL)
  per locale — managed with fastlane `deliver`, under `fastlane/metadata/ios/`.
- Screenshots per required device size, produced with fastlane `snapshot`.
- The privacy "nutrition label" answers (expected: "Data Not Collected").
- Export-compliance answers (the app uses only standard platform cryptography).
