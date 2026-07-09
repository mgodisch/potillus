// swift-tools-version: 5.9
// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import PackageDescription

let package = Package(
    name: "PotillusKit",
    // The domain layer is platform-neutral, so the package also builds for
    // macOS. That lets `swift test` run the suite natively on the command line,
    // with no simulator, while the app itself still targets iOS 17.
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PotillusKit", targets: ["PotillusKit"])
    ],
    targets: [
        .target(name: "PotillusKit"),
        .testTarget(name: "PotillusKitTests", dependencies: ["PotillusKit"])
    ]
)
