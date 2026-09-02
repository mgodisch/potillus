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

import Foundation

// =============================================================================
// GplNotice – the licence text an export carries
// =============================================================================
//
// The twin of Android's `util/GplNotice.kt`: one place for the wording, so a
// backup written on either platform opens with the same lines. Kept in English
// on purpose — it is a legal notice, not UI chrome — and pinned to Android by
// `test-vectors/gpl-notice.json`. Until the v0.86.0 review `BackupWriter` carried
// a four-line summary of its own.
// =============================================================================

public enum GplNotice {
    /// The licence header as individual lines, ready to be stored as a JSON
    /// array; blank entries reproduce the paragraph breaks of the canonical header.
    public static let headerLines: [String] = [
        "Libellus Potionis - Privacy-Friendly Alcohol Tracker",
        "Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>",
        "",
        "This program is free software: you can redistribute it and/or modify it",
        "under the terms of the GNU General Public License as published by the",
        "Free Software Foundation, either version 3 of the License, or (at your",
        "option) any later version.",
        "",
        "This program is distributed in the hope that it will be useful, but",
        "WITHOUT ANY WARRANTY; without even the implied warranty of",
        "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General",
        "Public License for more details.",
        "",
        "You should have received a copy of the GNU General Public License along",
        "with this program. If not, see <https://www.gnu.org/licenses/>.",
    ]
}
