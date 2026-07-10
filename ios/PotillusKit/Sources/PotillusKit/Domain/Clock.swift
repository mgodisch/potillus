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

import Foundation

// =============================================================================
// Clock.swift – "now", as an injected value
// =============================================================================
//
// The Today screen needs the current instant twice: to decide which LOGICAL day
// the user is looking at, and to age the blood-alcohol estimate. Both are
// time-dependent behaviour, and time-dependent behaviour that reads a global is
// untestable: a test for "the logical day flips at 04:00" cannot wait until 4am.
//
// So "now" arrives as a dependency. Production passes `SystemClock`; a test
// passes `FixedClock`. Nothing in the domain calls `Date()` directly.
//
// This is also where Android's `clockOverride` screenshot seam will land when the
// fastlane run needs a frozen clock — as a different `Clock`, injected at the
// composition root, without the domain gaining a mutable global.
// =============================================================================

/// Supplies the current instant.
public protocol Clock: Sendable {
    func now() -> Date
}

/// The real clock.
public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}

/// A clock frozen at one instant, for tests, previews and screenshots.
public struct FixedClock: Clock {
    private let instant: Date

    public init(_ instant: Date) {
        self.instant = instant
    }

    /// Convenience for the millisecond timestamps the database stores.
    public init(millis: Int64) {
        self.instant = Date(timeIntervalSince1970: Double(millis) / 1000.0)
    }

    public func now() -> Date { instant }
}
