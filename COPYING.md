# COPYRIGHT

## Libellus Potionis - Privacy-Friendly Alcohol Tracker

Copyright &copy; 2026 Martin A. Godisch
<[android@godisch.de](mailto:android@godisch.de)>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see
<[https://www.gnu.org/licenses/](https://www.gnu.org/licenses/)>.

## App Store Distribution Exception

As an additional permission under section 7 of the GNU General Public License,
version 3, you are allowed to distribute the software through an app store,
even if that store has restrictive terms and conditions that are incompatible
with the GPL, provided that the source is also available under the GPL with or
without this permission through a channel without those restrictive terms and
conditions.

## Third-Party Software (bundled in the Android App)

The libraries below are compiled into the released application package (the
APK/AAB) and are therefore redistributed together with this program.  They are
consumed exclusively as Gradle build dependencies (declared in
`android/gradle/libs.versions.toml`), never as vendored source copies, so each
is "de-embedded" via build-depends as required.  The authoritative,
machine-readable inventory — exact Maven coordinates and the versions actually
resolved for a build — is generated for every release as a CycloneDX Software
Bill of Materials (`make sbom`; see the `cyclonedxDirectBom` configuration in
`android/app/build.gradle.kts`).  The list below records the copyright holders
and licenses that inventory refers to.

### Apache License 2.0

The AndroidX / Jetpack stack and the Kotlin runtime libraries are all licensed
under the Apache License, Version 2.0
(<[https://www.apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)>):

- **AndroidX / Jetpack** &mdash; Copyright &copy; The Android Open Source
  Project: `androidx.core:core-ktx`, `androidx.appcompat:appcompat`,
  `androidx.activity:activity-compose`, the Jetpack Compose UI and
  Material&nbsp;3 modules (`androidx.compose.ui:ui`, `:ui-graphics`,
  `:ui-tooling-preview`, `androidx.compose.material3:material3`,
  `androidx.compose.material:material-icons-extended`, pinned by the Compose
  BOM), `androidx.lifecycle:lifecycle-runtime-ktx` /
  `:lifecycle-runtime-compose` / `:lifecycle-viewmodel-compose`,
  `androidx.navigation:navigation-compose`, `androidx.room:room-runtime`,
  `androidx.datastore:datastore-preferences`, `androidx.biometric:biometric`
  and `androidx.tracing:tracing`.
- **Kotlin standard library and kotlinx libraries** &mdash; Copyright &copy;
  JetBrains s.r.o. and contributors: the Kotlin standard library,
  `org.jetbrains.kotlinx:kotlinx-serialization-core`, the
  `org.jetbrains.kotlinx:kotlinx-coroutines` runtime pulled in transitively,
  and the `org.jetbrains:annotations` artifact.
- **Okio** &mdash; Copyright &copy; Square, Inc.: `com.squareup.okio:okio`,
  pulled in transitively by `androidx.datastore:datastore-preferences`.
- **Guava ListenableFuture** &mdash; Copyright &copy; The Guava Authors
  (Google): `com.google.guava:listenablefuture`, pulled in transitively by
  `androidx.concurrent:concurrent-futures`.
- **JSpecify** &mdash; Copyright &copy; The JSpecify Authors:
  `org.jspecify:jspecify` (runtime-retention nullness annotations), pulled in
  transitively by the AndroidX lifecycle libraries.

The full Apache-2.0 license text is kept verbatim in the repository as
`LICENSE.Apache-2.0.md` and is bundled into the APK as `res/raw/license_apache2.md`
(a byte-for-byte copy, made at build time from the project-root file), which
the in-app About screen links to — satisfying the license's &sect;4(a) requirement
to give recipients a copy of the license.

Apache-2.0 &sect;4(d) requires reproducing any `NOTICE` text distributed with a
dependency.  This is verified automatically at release time by
`tools/release-check.sh` **Section 12**, which resolves every component in the
CycloneDX SBOM to its cached artifact and scans it for `META-INF/NOTICE*`
entries; when it warns about one, copy that `NOTICE` text into this section.

### GPL-2.0 with the Classpath Exception

`com.android.tools:desugar_jdk_libs` &mdash; Copyright &copy; Oracle and/or its
affiliates and The Android Open Source Project.  It repackages OpenJDK
class-library sources and is licensed under the GNU General Public License,
version&nbsp;2, **with the OpenJDK "Classpath" linking exception**.  The
Classpath Exception explicitly permits linking these classes into an
independent work (this application) without extending GPLv2 to it, and the
license is compatible with this program's GPL-3.0-or-later distribution.  Only
the backported `java.time` (and related) classes selected by core-library
desugaring are included in the APK/AAB; see the `desugar-jdk-libs` note in
`android/gradle/libs.versions.toml`.

The full GPL-2.0 text is kept verbatim in the repository as `LICENSE.GPL-2.0.md`
and is bundled into the APK as `res/raw/license_gpl2.md`, which the in-app About
screen links to.  The Classpath Exception is NOT part of that text — it is an
additional permission granted on top of it — so the About screen states the
exception itself beside the link.

### Build- and test-time dependencies (NOT redistributed)

The following are used only to build or test the app and are **not** compiled
into the released APK/AAB, so they carry no redistribution obligation; they are
listed here for completeness.  Apache-2.0 unless noted:
`org.jetbrains.kotlin:kotlin-test`,
`org.jetbrains.kotlinx:kotlinx-coroutines-test`, `app.cash.turbine:turbine`,
`androidx.compose.ui:ui-tooling` (the debug-only Compose inspector; its sibling
`ui-tooling-preview` IS on the release classpath and is listed above),
the AndroidX Test stack (`androidx.test.ext:junit`, `androidx.test:runner`,
`androidx.test.espresso:espresso-core`,
`androidx.test.uiautomator:uiautomator`), `androidx.room:room-testing`, the
Compose UI-test artifacts (`ui-test-junit4`, `ui-test-manifest`) and
`tools.fastlane:screengrab`; `junit:junit` 4 (Eclipse Public License 1.0);
`org.json:json` (the "JSON License"); and the Gradle build plugins — the
CycloneDX SBOM plugin `org.cyclonedx.bom`, the Kotlin Symbol Processing plugin
`com.google.devtools.ksp`, the Kover coverage plugin
`org.jetbrains.kotlinx.kover` and the ktlint wrapper plugin
`org.jlleitschuh.gradle.ktlint` (all Apache-2.0).

## Third-Party Software (bundled in the iOS application)

The library below is compiled into the released iOS application and is
therefore redistributed together with this program.  It is consumed exclusively
as a Swift Package Manager dependency (declared in
`ios/PotillusKit/Package.swift`, with the resolved revision pinned in
`ios/PotillusKit/Package.resolved`), never as a vendored source copy, so it is
"de-embedded" via build-depends as required.  As on Android, an authoritative
machine-readable inventory is generated for every release as a CycloneDX
Software Bill of Materials — here from `Package.resolved` by
`tools/gen-ios-sbom.py` (`make ios-sbom`), normalised by the same
`tools/sbom-normalize.py`.

### MIT License

**GRDB.swift** &mdash; Copyright &copy; 2015&ndash;2025 Gwendal Rou&eacute;,
licensed under the MIT License
(<[https://github.com/groue/GRDB.swift/blob/master/LICENSE](https://github.com/groue/GRDB.swift/blob/master/LICENSE)>).
GRDB is the iOS counterpart to Room: typed records, a schema migrator, and
database observation on top of the SQLite that ships with the operating system.
It has no transitive dependencies, performs no network access, and collects no
telemetry.

The MIT License requires that the copyright notice and the permission notice
accompany the software.  The full license text is reproduced verbatim below, and
the iOS about screen reproduces it inline (`AppInfo.grdbLicense`, pinned by the
`testGrdbLicense*` smoke tests) — short enough not to need a window of its own,
unlike the GPLv3 and Apache-2.0 texts, which the about screens link to:

```
Copyright (C) 2015-2025 Gwendal Roué

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Only the iOS application actually **ships** GRDB, so only it carries the MIT
redistribution obligation.  The Android application does not distribute GRDB and
therefore carries no MIT obligation, and since 0.83.0 it no longer shows the
notice either: each app now bundles exactly the licenses it is obliged to
reproduce, rather than a combined document built from this file on both
platforms — which had the APK carrying GRDB's MIT notice for a library it does
not ship, and the iOS app carrying the Apache-2.0 text for libraries it does not
have.  MIT is compatible with the GNU GPL version 3, so the combined work is
distributable under the terms stated at the top of this document.

### Build- and test-time dependencies (NOT redistributed)

The following build the iOS app but are not compiled into it, so they carry no
redistribution obligation; they are listed here for the same completeness as
their Android counterparts above.  All MIT:

  * **XcodeGen** &mdash; generates `ios/Potillus.xcodeproj` from
    `ios/project.yml`, which is why no `.xcodeproj` is tracked
    (<[https://github.com/yonaskolb/XcodeGen](https://github.com/yonaskolb/XcodeGen)>).
  * **SwiftLint** &mdash; the style gate `make check-swiftlint` pins to version
    0.65.0 (<[https://github.com/realm/SwiftLint](https://github.com/realm/SwiftLint)>).
  * **fastlane** &copy; The Fastlane Authors &mdash; drives the store uploads for
    BOTH platforms (the `ios` lanes here, `supply` and `screengrab` on Android;
    the `tools.fastlane:screengrab` Gradle artifact is a separate, Apache-2.0
    library and is listed above)
    (<[https://github.com/fastlane/fastlane](https://github.com/fastlane/fastlane)>).

## Third-Party Assets

### GPLv3 logo

The Play-Store feature graphic embeds the GPLv3 "Free as in Freedom" logo
(`fastlane/gpl-v3-logo.svg`, recoloured white where it appears in the graphic),
used to advertise that this program is licensed under version 3 of the GNU
General Public License.  The official GPL, AGPL and LGPL logos and their
variants are the work of José Obed and are in the public domain.  See
<[https://www.gnu.org/graphics/license-logos](https://www.gnu.org/graphics/license-logos)>
for the originals and terms.

### "Get it on F-Droid" badges

The `fdroid/get-it-on-<lang>.svg` files are the official "Get it on F-Droid"
download badges (one per store-listing language — e.g. `get-it-on-en.svg`,
`get-it-on-de.svg`, `get-it-on-pt-br.svg`, `get-it-on-zh-cn.svg`), used to link
to this app's listing in the F-Droid catalogue.  They all come from the same
source, the F-Droid artwork project
(<[https://gitlab.com/fdroid/artwork](https://gitlab.com/fdroid/artwork)>, also
mirrored at
<[https://github.com/f-droid/artwork](https://github.com/f-droid/artwork)>),
and are licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported
license (CC BY-SA 3.0); see
<[https://creativecommons.org/licenses/by-sa/3.0/](https://creativecommons.org/licenses/by-sa/3.0/)>
for the terms.  (F-Droid licenses the badge-generation scripts separately under
GPL-3.0-or-later; only the badge artwork is bundled here.)  These files are
repository and store-listing assets and are **not** distributed inside the
application package.

### Device fonts embedded in the sample report PDFs

The pre-rendered sample reports under `fastlane/report-pdf/` (one per
store-listing language, produced on a real device by the `ReportExportTest`
flow) embed subsets of the fonts the device's WebView used to render them.
Which font that is depends on the script, and the two cases are exclusive —
the WebView picks one family per document, it does not mix them:

- The seventeen Latin-, Greek- and Cyrillic-script files embed **Roboto**
  (Copyright &copy; The Roboto Project Authors; Apache License 2.0,
  <[https://github.com/googlefonts/roboto-classic](https://github.com/googlefonts/roboto-classic)>),
  as `Roboto-Regular` and `Roboto-Bold`.
- The `ja`, `ko`, `zh-CN` and `zh-TW` files embed **Noto Sans CJK**
  (Copyright &copy; Google LLC and Adobe; SIL Open Font License 1.1) — the
  script-specific faces `NotoSansCJK{jp,kr,sc,tc}-Regular` — and **no Roboto**.

Both licenses explicitly permit embedding subsets in documents.  These PDFs are
repository and store-listing assets and are **not** distributed inside the
application package.

### DejaVu Sans (feature-graphic badge text)

`tools/fonts/DejaVuSans/DejaVuSans.ttf` renders the small "GET IT ON" line of
the "Get it on F-Droid" badge embedded in the feature graphic.  DejaVu Sans is
published under the DejaVu Fonts license — a permissive free font license
derived from the Bitstream Vera and Arev font licenses (see the accompanying
`LICENSE`).  Like Inter, this file is build-time tooling for
`render-feature-graphic.py` and is **not** distributed inside the application
package.  See `tools/fonts/DejaVuSans/README.txt` for the exact source.

### Inter font (build tooling only)

`tools/fonts/Inter/` bundles static instances of the Inter typeface, used
solely by `tools/render-feature-graphic.py` to render the feature graphic
deterministically (so the result does not depend on the fonts installed on the
build host).  Inter is licensed under the SIL Open Font License 1.1 (see the
accompanying `OFL.txt`).  These files are build-time tooling and are **not**
distributed inside the application package.

### Noto Sans CJK (feature-graphic CJK text)

`tools/fonts/NotoSansCJK/NotoSansCJK-Regular.ttc` supplies the Japanese, Korean
and Simplified/Traditional Chinese glyphs for the `ja`, `ko`, `zh-CN` and
`zh-TW` feature-graphic copy (Inter has no CJK glyphs), and — through
fontconfig's per-glyph fallback — the CJK text in the localized "Get it on
F-Droid" badges. It is the Regular-weight OpenType Collection from the Noto CJK
project
(<[https://github.com/notofonts/noto-cjk](https://github.com/notofonts/noto-cjk)>,
`Sans/OTC/NotoSansCJK-Regular.ttc`) and is licensed under the SIL Open Font
License 1.1 (see the accompanying `LICENSE`; the source and version are
recorded in `README.txt`).  Like the other bundled faces, this file is
build-time tooling for `render-feature-graphic.py` and is **not** distributed
inside the application package.

### Rokkitt (feature-graphic badge text)

The "F-Droid" wordmark of that badge is set in Rokkitt Bold.  Rokkitt is the
work of Vernon Adams and is licensed under the SIL Open Font License 1.1.  The
upstream *variable* font is checked in at
`tools/fonts-src/Rokkitt/Rokkitt[wght].ttf` (with its `OFL.txt`); the static
`tools/fonts/Rokkitt/Rokkitt-Bold.ttf` the renderer actually uses is instanced
from it reproducibly via `make rokkitt-bold` (see
`tools/fonts-src/Rokkitt/README.txt`).  Like the fonts above, these are
build-time tooling for `render-feature-graphic.py` and are **not** distributed
inside the application package.

## Repository Documentation Under Other Licenses

The following repository document is not part of the program and is **not**
distributed inside the application package; it is reproduced from a third party
under its own license and is listed here for completeness.

### Contributor Covenant (Code of Conduct)

`docs/CODE_OF_CONDUCT.md` reproduces the **Contributor Covenant, version 2.1**
(Copyright &copy; the Contributor Covenant authors), licensed under the
**Creative Commons Attribution 4.0 International (CC BY 4.0)** license
(<[https://creativecommons.org/licenses/by/4.0/](https://creativecommons.org/licenses/by/4.0/)>).
Only the enforcement-contact placeholder has been filled in; the required
attribution is retained in that file's own "Attribution" section.  The original
is available at
<[https://www.contributor-covenant.org/version/2/1/code_of_conduct.html](https://www.contributor-covenant.org/version/2/1/code_of_conduct.html)>.
