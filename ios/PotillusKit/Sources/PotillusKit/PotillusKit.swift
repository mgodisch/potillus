// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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

/// Namespace for the shared Potillus domain and data layer.
///
/// The ported domain logic — `AlcoholCalculator`, `DayResolver`, the chart
/// bucketing, the GRDB-backed SQLite layer, and the JSON backup reader/writer —
/// lives in this package so it can be unit tested with `swift test`, mirroring
/// the Android `domain/` and `data/` layers. (The scaffold-era wording that
/// described this as still-to-be-ported was refreshed in the v0.84.0 QA round.)
public enum PotillusKit {

    /// A short identifier for the kit, asserted non-empty by the package and
    /// app smoke tests as a minimal "the module links and runs" probe.
    public static func about() -> String {
        "PotillusKit — the shared Potillus domain and data layer"
    }
}
