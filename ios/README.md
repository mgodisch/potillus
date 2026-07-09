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

In addition, as permitted by section 7 of the GNU General Public License,
this program may carry additional permissions; any such permissions that
apply to it are stated in the accompanying COPYING.md file.

=============================================================================
-->

# Potillus for iOS

Native Swift/SwiftUI port of Libellus Potionis. See
[`../docs/IOS_MIGRATION.md`](../docs/IOS_MIGRATION.md) for the full strategy.

## Layout

- `PotillusKit/` — Swift package for the ported domain and data layer (where
  `AlcoholCalculator`, `DayResolver`, the GRDB-backed SQLite layer, and the JSON
  backup reader/writer will live). The package also builds for macOS, so its
  unit tests run natively with `swift test` — no simulator needed.
- `Potillus/` — the SwiftUI app shell that depends on `PotillusKit`.
- `project.yml` — the XcodeGen spec; `Potillus.xcodeproj` is generated from it
  and is git-ignored.

## Build and run

Requires a Mac with Xcode and
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

    brew install xcodegen        # once
    cd ios
    xcodegen generate            # (re)generate Potillus.xcodeproj from project.yml
    open Potillus.xcodeproj

Select the `Potillus` scheme and an iPhone simulator, then Run. Building for a
physical device additionally needs your Apple Development team set on the target
(Signing & Capabilities), or `DEVELOPMENT_TEAM` in `project.yml`.

## Tests

The domain tests live in the package and are platform-neutral, so they run
natively on the Mac without a simulator:

    cd ios/PotillusKit
    swift test

The app target additionally has a smoke-test bundle, run from the app scheme
with `Cmd+U` in Xcode, or on the command line:

    cd ios
    xcodebuild test -project Potillus.xcodeproj -scheme Potillus \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

If `xcodebuild` complains that it "requires Xcode" but finds the command line
tools, point it at the full Xcode once:

    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

## Dependencies

The only iOS dependency is [GRDB.swift](https://github.com/groue/GRDB.swift)
(MIT), resolved by Swift Package Manager. `PotillusKit/Package.resolved` records
the exact revision and **is committed on purpose**: a checkout of this repository
must build the same bytes as the release, which is the same reason the Android
build pins its dependency versions. Run `swift package update` deliberately, and
review the resulting diff.

GRDB is recorded in `COPYING.md`. Its MIT licence text must be reproduced in the
app's about screen before the first App Store submission.

## A note on `make`

None of the iOS workflow needs the repository `Makefile`. If you do invoke it on
macOS, use `gmake` (`brew install make`): the bundled GNU Make 3.81 cannot parse
the `VERSION` assignment. See "Building on macOS" in `CONTRIBUTING.md`.

This is a scaffold: the app shows a placeholder screen and the domain logic is
not ported yet.
