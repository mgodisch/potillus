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
// ReportTemplate
// =============================================================================
//
// `report/report_template.html` lives at the repository root, outside both the app
// and the kit, because BOTH platforms read it: Android registers it as an asset
// directory, and `ios/project.yml` copies it into the app bundle. One file, two
// reports, no chance of them drifting.
// =============================================================================

enum ReportTemplate {

    enum Failure: Error, LocalizedError {
        case missing

        var errorDescription: String? {
            "The report template is missing from the app bundle."
        }
    }

    /// The template text, as shipped.
    ///
    /// A missing template is a build error that escaped, not a user error. It fails
    /// with a sentence rather than a trap, because a crash in an alcohol diary at
    /// the moment of export is the worst possible time to lose the user's trust.
    static func load(from bundle: Bundle = .main) throws -> String {
        guard
            let url = bundle.url(forResource: "report_template", withExtension: "html"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { throw Failure.missing }

        return text
    }
}
