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
// AppInfo — the app's own name, version, and the notices it must display.
//
// The version was read in StatsScreenExport for the report footer; it belongs
// here, where the About screen also needs it, so both read one definition rather
// than two copies of the same Bundle lookup drifting apart.
// =============================================================================

enum AppInfo {

    /// The display name, fixed rather than read from the bundle: it is the Latin
    /// title of the work and is not localised or renamed per platform.
    static let name = "Libellus Potionis"

    /// `MAJOR.MINOR.PATCH`, with any build suffix (`-debug`) stripped, exactly as
    /// the report footer prints it. `CFBundleShortVersionString` is set from
    /// `MARKETING_VERSION`, which the build derives from CHANGELOG.md.
    static var version: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        let version = (raw as? String) ?? "0.0.0"
        return String(version.prefix(while: { $0 != "-" }))
    }

    /// GRDB's license, reproduced verbatim from the project's LICENSE file
    /// (github.com/groue/GRDB.swift). docs/NOTICES.md records that the iOS about
    /// screen reproduces this inline (and pins it with the testGrdbLicense smoke
    /// tests); GRDB is the app's one third-party
    /// dependency, MIT-licensed and compatible with the GPL v3 the app ships under.
    /// The text is stored exactly as published — copyright line, permission grant,
    /// and warranty disclaimer — because a license quoted loosely is not the license.
    static let grdbLicense = """
        Copyright (C) 2015-2025 Gwendal Roué

        Permission is hereby granted, free of charge, to any person obtaining a \
        copy of this software and associated documentation files (the "Software"), \
        to deal in the Software without restriction, including without limitation \
        the rights to use, copy, modify, merge, publish, distribute, sublicense, \
        and/or sell copies of the Software, and to permit persons to whom the \
        Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in \
        all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING \
        FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER \
        DEALINGS IN THE SOFTWARE.
        """

    /// The same license, cut at its blank lines.
    ///
    /// NOT a second copy: this is `grdbLicense` itself, split — the words, the
    /// order and the punctuation are whatever that constant says, and a test pins
    /// that rejoining the pieces reproduces it exactly.
    ///
    /// It exists because a blank line inside one `Text` is a whole line high, some
    /// 21pt, while the About screen spaces its own paragraphs by 10. Rendering the
    /// notice as a single string therefore made it sit looser than the prose above
    /// it — the same text told in two rhythms. Handing the view the paragraphs lets
    /// it use its own.
    static var grdbLicenseParagraphs: [String] {
        grdbLicense.components(separatedBy: "\n\n")
    }
}
