<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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

# Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker

## About the App (v0.68.1)

**Libellus Potionis** ("Potillus") is a privacy-first, free, open-source, and
ad-free alcohol consumption tracker designed to help users monitor, pace, and
manage their drinking habits entirely offline. It requires absolutely no
invasive device permissions—no camera, microphone, or location access—and
completely operates without network connectivity.

### Key Features

*   **Intelligent Logging:** Predefine custom beverages or use internationally
    common presets. Log drinks instantly or retroactively with precise
    timestamp corrections.
*   **Concurrent Limit Tracking:** Set three simultaneous boundaries—a daily
    limit (in grams of pure alcohol), a weekly rolling 7-day limit (in grams),
    and a maximum number of drinking days per week. Visual progress bars keep
    you informed in real time.
*   **Blood Alcohol Concentration (BAC) Estimation:** Input your body weight to
    get a live approximation of your BAC based on the established Widmark
    formula.
*   **Addiction Counseling Reports:** Generate a professional, highly organized
    two-page PDF report designed specifically for consultations and counseling
    appointments, providing a clear statistical analysis of your habits.
*   **Data Portability:** Export your complete dataset as a standard CSV file
    for external processing (e.g., in LibreOffice Calc) or create secure JSON
    backups to easily migrate data between devices.
*   **Granular Adjustments:** Customize your "day start" time (ensuring
    late-night drinks count toward the correct evening) and define custom
    evaluation start dates for clean restarts.

A comprehensive User's Guide is fully accessible in-app.

## Technical Aspects

### Privacy & Security Architecture

Built with an unwavering commitment to user privacy, Libellus Potionis
prioritizes absolute data sovereignty through a strict data-minimization
architecture. It operates under a minimal permission profile that completely
excludes network access, ensuring that personal data never leaves the device.
Security is strictly enforced locally through fully encrypted data storage via
hardware-backed cryptography, combined with an optional biometric fingerprint
lock to prevent unauthorized physical access. This offline-first approach
completely eliminates tracking, cloud synchronizations, and external data
extraction leaks.

### Platform Compatibility

The app runs on **Android 11 (API 30) and newer**. API 30 is a deliberate
floor: it is the lowest level at which the app can save CSV, PDF, and backup
files to the public `Downloads` folder via `MediaStore` *without* requesting
any runtime storage permissions, keeping the app's minimal-permission promise
completely intact. 

While the system-level per-app language picker is restricted to API 33+,
Libellus Potionis features a fully independent in-app language selector that
functions across all supported versions. 

The application is actively maintained and verified across a modern device
spectrum, including a Google Pixel 10 Pro running GrapheneOS (Android 16), a
Fairphone 4 (Android 15), and a virtual Google Pixel 4 reference image (Android
11).

### Build Infrastructure & Tooling

This project maintains a highly modern and robust build infrastructure by
leveraging the cutting-edge Android Gradle Plugin 9.2.0, Gradle 9.4.1, and the
Kotlin 2.3.21 compiler line. To ensure architecture stability and compliance
with modern platform standards, the application fully decouples Kotlin Symbol
Processing via KSP 2.3.7 and structures its UI layer around the Jetpack Compose
BOM 2026.04.01 (Compose Runtime 1.11.0), Jetpack Activity 1.12.3, and Jetpack
Lifecycle 2.10.0. 

UI navigation is anchored on the type-safe Navigation Compose 2.8.9 stable
release, and the runtime environment utilizes Kotlinx Serialization Core 1.11.0
to eliminate compiler compatibility conflicts. On the data and security front,
the app utilizes Room 2.8.4 paired with SQLite 2.6.2, and integrates the modern
`net.zetetic:sqlcipher-android` 4.15.0 artifact to natively support 16 KB
memory page sizes, ensuring full runtime stability on Android 15+ devices and
meeting Google Play compliance. Modern security practices are enforced through
direct, hardware-backed Android Keystore integration without deprecated crypto
wrappers, while reliable backward compatibility for advanced Java time APIs is
guaranteed across all target devices through the inclusion of Desugar JDK Libs
2.1.5 alongside a consolidated Jetpack and Turbine test stack.

### Source Code Documentation

Libellus Potionis treats its own source code as a teaching artifact. Every
Kotlin file opens with a header that states its purpose, and every public type
and function carries a KDoc comment that explains not merely *what* the code
does but *why* it is written that way — the trade-offs considered, the failure
modes guarded against, and the platform quirks worked around. Inline comments
accompany the non-obvious lines rather than restating the obvious ones, so the
narrative reads like a guided tour of an idiomatic, modern Android codebase.

This discipline is deliberately enforced, not merely encouraged. A read-only
release gate (`android/tools/release-check.sh`) scans the tree on every build
and flags missing file headers or undocumented public functions, keeping the
documentation from silently rotting as the code evolves. The same gate enforces
version consistency across all release artifacts and insists that the source
stay free of non-English prose, so the documentation remains uniformly
accessible.

This project's documentation structure provides practical benefits for
contributors, security auditors, and developers looking to understand the
implementation details of Jetpack Compose, Room, or the minimal-permission
privacy model. Because the rationale behind architectural choices is documented
directly alongside the implementation, long-term maintenance is simplified and
code reviews can focus on functional correctness rather than intent. For an
offline, privacy-focused application that relies on transparency and
auditability, this structured documentation is an essential component of
verifying the application's integrity.

## Changes

Changes are documented in
[CHANGELOG.md](https://codeberg.org/godisch/potillus/src/branch/main/CHANGELOG.md).

## License

Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker, Copyright
&copy; 2026 Martin A. Godisch <[android@godisch.de](mailto:android@godisch.de)>

The source code can be found at the [canonical repository at
codeberg.org](https://codeberg.org/godisch/potillus/).

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
