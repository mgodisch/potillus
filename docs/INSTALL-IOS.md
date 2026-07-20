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

# Building the iOS debug app from a blank macOS install

This guide takes a **fresh macOS** system and builds the **debug** version of
the iOS port of Libellus Potionis, then runs it in the **iPhone Simulator**.
Like its Android sibling it is written to be followed top to bottom with no
prior iOS-build experience assumed, and it explains *why* each step exists.

**Scope.** The primary target is a Simulator debug build — the closest iOS
analogue of Android's "debug APK", and the one that needs no Apple Developer
account. Running on a **physical iPhone** is covered as an optional appendix
(§7). Signing for and publishing to the App Store are **out of scope** on
purpose.

**What you will have at the end.** The app compiled in the `Debug`
configuration and running in an iPhone Simulator.

**Relation to `gmake help`.** Like its Android sibling, this guide is the
extended companion to the iOS Makefile's help: it walks the build-path targets
(`gmake -C ios project`, then the Simulator build and `gmake ios`) in order, with
the *why* behind each. `gmake help` (run in `ios/`) is the one-line index of
every iOS target; project generation comes first there too, matching §5 below.

---

## 1. Why these tools, and nothing else

| Tool | Version | Why it is needed | Installed how |
|------|---------|------------------|---------------|
| **Xcode** | **26** | Supplies the iOS **17** SDK, the Simulators, the Swift compiler and `xcodebuild`. The project targets iOS 17.0 (`deploymentTarget.iOS: "17.0"` in `ios/project.yml`). | App Store |
| **Command Line Tools** | bundled with Xcode | Provides `git`, `python3` and the CLI shims. | Xcode / `xcode-select` |
| **Homebrew** | any | The package manager used for the two Mac-side build tools below. | script |
| **GNU Make** | any recent (`gmake`) | The build is driven by the repository's `Makefile`, which uses GNU Make features. macOS ships **GNU Make 3.81**, too old to parse it, so a newer one is installed as `gmake`. | `brew` |
| **XcodeGen** | any recent | `ios/Potillus.xcodeproj` is **generated** from `ios/project.yml`; XcodeGen does the generating. The `.xcodeproj` is not committed. | `brew` |
| **GRDB.swift** | **7.11.1** | The SQLite layer (iOS's counterpart to Room). It is **not** installed by hand: the local Swift package `PotillusKit` depends on it, and Swift Package Manager resolves it automatically on the first build (needs network once). | automatic |
| **SwiftLint** | 0.65.0 | Only needed to run the *full* `gmake ios` verification gate. **Not required** to build or run the app. | `brew` (optional) |

The important idea: the Xcode project is a **build artifact**, not a source
file. You never edit `Potillus.xcodeproj`; you edit `project.yml` and
regenerate. This keeps the project definition small, reviewable and free of the
merge conflicts a checked-in `.xcodeproj` is famous for.

**The one dependency.** GRDB.swift (MIT) is the only iOS dependency, resolved by
Swift Package Manager. `ios/PotillusKit/Package.resolved` records the exact
revision and **is committed on purpose**: a checkout of this repository must
build the same bytes as the release, the same reason the Android build pins its
dependency versions. Run `swift package update` deliberately, and review the
resulting diff. GRDB is recorded in `COPYING.md`; its MIT license text must be
reproduced in the app's about screen before the first App Store submission.

---

## 2. Install Xcode and the Command Line Tools

1. Install **Xcode 26** from the App Store (a multi-gigabyte download).
2. Launch it once so it finishes installing its components, and accept the
   license:

        sudo xcodebuild -license accept

3. Make sure the command-line tools point at the **full Xcode**, not the
   stand-alone Command Line Tools package — otherwise `xcodebuild` later
   complains that it "requires Xcode":

        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

   Verify:

        xcodebuild -version
        # Xcode 26.x

`git` and `python3` come with the tools installed above; no separate step is
needed for them.

---

## 3. Install Homebrew and the two Mac-side tools

If you do not already have Homebrew:

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Then install GNU Make and XcodeGen:

    brew install make xcodegen

Homebrew installs GNU Make as **`gmake`** (leaving the system `make 3.81`
untouched). Every `make` command in this guide is therefore written as
`gmake`.

> SwiftLint is only for the full check gate (§6, optional). Install it later
> with `brew install swiftlint` if you want that gate; the version is pinned to
> **0.65.0**, and the gate refuses a different one because lint rules change
> between releases.

---

## 4. Get the source

    git clone <repository-url> potillus
    cd potillus

The repository holds both platforms side by side (`android/` and `ios/`); the
iOS build lives under `ios/`, but the `Makefile` you drive it with sits at the
**repository root**.

Inside `ios/`, the source is split in two, plus a generator spec:

- `ios/PotillusKit/` — a Swift package holding the ported domain and data layer:
  `AlcoholCalculator`, `DayResolver`, the GRDB-backed SQLite store, and the JSON
  backup reader/writer. The package also builds for macOS, so its unit tests run
  natively with `swift test`, no simulator needed.
- `ios/Potillus/` — the SwiftUI app shell that depends on `PotillusKit`.
- `ios/project.yml` — the XcodeGen spec; `Potillus.xcodeproj` is generated from
  it and is git-ignored.

---

## 5. Generate the Xcode project

From the **repository root** (not from `ios/`):

    gmake -C ios project

This does two things in the required order:

1. Regenerates `ios/Version.xcconfig` from the shared sources of truth (via
   `tools/gen-ios-version.py`): the top `## vX.Y.Z` entry of `CHANGELOG.md`
   and the Android `versionCode`, so the iOS build number can never drift
   from the changelog. XcodeGen cannot resolve `project.yml` until this file
   exists.
2. Runs `xcodegen generate` inside `ios/`, producing `ios/Potillus.xcodeproj`.

You must re-run `gmake -C ios project` whenever `project.yml` or the version
changes; for a plain build-from-scratch you run it once here.

`Version.xcconfig` carries `MARKETING_VERSION`, taken from the top `## vX.Y.Z`
entry of `CHANGELOG.md`, and `CURRENT_PROJECT_VERSION`, taken from the Android
`versionCode`, so the App Store and Play Store builds report the same version and
the same build number, and neither can drift from the changelog. `gmake
ios-version-check` verifies the file exists and is current — suitable for a
release gate, and worth running by hand after a version bump if you build with
`xcodebuild` directly rather than through `gmake -C ios project`, which regenerates
the file anyway. No target depends on it.
The values must **never** be set in `project.yml` directly: a value in `settings`
overrides an xcconfig and would silently defeat the generator. To confirm the
values took effect, ask the build system rather than the Xcode UI, where a
generated project shows the unexpanded `$(MARKETING_VERSION)` placeholder:

    cd ios && xcodebuild -project Potillus.xcodeproj -target Potillus \
        -showBuildSettings 2>/dev/null | grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION'

---

## 6. Build and run in the Simulator (primary path)

Open the generated project:

    open ios/Potillus.xcodeproj

In Xcode, select the **`Potillus`** scheme and an **iPhone simulator** in the
destination menu at the top, then press **Run** (⌘R). On the first build,
Swift Package Manager fetches **GRDB 7.11.1**; give it a moment and a network
connection.

### Command-line equivalent (headless)

To build the same thing without opening the Xcode UI:

    xcodebuild \
        -project ios/Potillus.xcodeproj \
        -scheme Potillus \
        -destination 'generic/platform=iOS Simulator' \
        -configuration Debug \
        CODE_SIGNING_ALLOWED=NO \
        build

Two details in that command are worth understanding, because getting them
wrong produces a confusing error:

- **`-destination 'generic/platform=iOS Simulator'`, not `-sdk
  iphonesimulator`.** With only an SDK and no destination, `xcodebuild` cannot
  choose an architecture, tries to build both `arm64` and `x86_64`, and fails
  with `error: Unable to resolve module dependency: 'GRDB'` — which looks like
  a missing dependency but is really a missing destination. A generic
  Simulator destination fixes one architecture without pinning a specific
  simulator device.
- **`CODE_SIGNING_ALLOWED=NO`** is valid for the Simulator (which does not
  require signing). Do **not** carry it over to a device build.

### (Optional) Run the kit's unit tests

The domain logic lives in the `PotillusKit` Swift package, which also builds
for macOS, so its tests run natively with no simulator:

    cd ios/PotillusKit && swift test

### (Optional) The app's smoke-test bundle

The app target additionally has a small smoke-test bundle, run from the app
scheme with ⌘U in Xcode, or on the command line:

    cd ios
    xcodebuild test -project Potillus.xcodeproj -scheme Potillus \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

### (Optional) The full verification gate

    gmake ios

This runs the container-side checks, the kit's `swift test`, SwiftLint
(**0.65.0** required), regenerates the project, and does the Simulator build
above. It is the full local verification a contributor runs on a Mac; the
Codeberg CI pipeline deliberately runs only the device-free subset (it has no
Mac), so this local gate is stricter. It is not needed just to run the app.

---

## 7. (Optional) Run on a physical iPhone

The Simulator needs no Apple account; a real device does, because iOS only runs
signed apps. A **free** Apple ID is enough — you do not need a paid Developer
Program membership for a debug install.

1. In Xcode, open the project's **Signing & Capabilities** tab for the
   `Potillus` target.
2. Under **Team**, add your Apple ID and select the automatically created
   **Personal Team**. If Xcode reports the bundle identifier is unavailable,
   change it to something unique to you (this only affects your local build).
3. Connect the iPhone, select it as the run destination, and press **Run**.
4. The first launch is blocked by iOS until you trust the developer profile on
   the device: **Settings → General → VPN & Device Management → Developer App**
   → trust your Apple ID.

Note that free personal-team signing produces builds that expire after a few
days and must be re-installed from Xcode; that is an Apple limitation of
unpaid signing, not a project setting.

---

## 8. Troubleshooting

- **`make: *** No rule to make target` or GNU Make parse errors.** You used the
  system `make 3.81`. Use `gmake` (installed by `brew install make`).
- **`xcodebuild` says it "requires Xcode" but finds the command line tools.**
  Point it at the full Xcode once:
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- **XcodeGen cannot resolve the config / `Version.xcconfig` missing.** Run
  `gmake -C ios version` (or the whole `gmake -C ios project`) before
  `xcodegen generate`.
- **`Unable to resolve module dependency: 'GRDB'`.** You built with `-sdk
  iphonesimulator` instead of a `-destination`. Use the exact command in §6.
- **SwiftPM cannot fetch GRDB.** The first resolve needs network access; run it
  once online, after which the resolved package is cached.
- **No simulator to select.** Install a runtime from Xcode → Settings →
  Components (or Platforms), then pick a matching iPhone in the destination
  menu.
