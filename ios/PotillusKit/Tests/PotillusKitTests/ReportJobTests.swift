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

import XCTest

@testable import PotillusKit

final class ReportJobTests: XCTestCase {

    /// 2026-06-03T14:30:00Z, the instant Android's own doc comment uses as its
    /// example. Checked against the epoch rather than trusted: the first draft of
    /// this file was off by ten minutes.
    private let moment = Date(timeIntervalSince1970: 1_780_497_000)

    func testTheNameCarriesTheDateAndTheSuffix() {
        XCTAssertEqual(
            ReportJob.fileName(date: moment, timeZone: TimeZone(identifier: "UTC")!),
            "potillus_report_20260603_1430.pdf"
        )
    }

    /// The wall clock is the reader's, so the same instant names two files.
    func testTheNameFollowsTheGivenZone() {
        XCTAssertEqual(
            ReportJob.fileName(date: moment, timeZone: TimeZone(identifier: "Europe/Berlin")!),
            "potillus_report_20260603_1630.pdf"
        )
    }

    // ── Structure ────────────────────────────────────────────────────────────

    /// The shape of the bug that shipped in patch -59: a header, pages, no ending.
    func testABufferReadBeforeTheContextWasClosedIsRejected() {
        let truncated = Data("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n".utf8)
        XCTAssertFalse(ReportJob.isWellFormed(truncated), "no %%EOF means no document")
    }

    func testAFinishedDocumentIsAccepted() {
        let complete = Data("%PDF-1.7\n1 0 obj\nendobj\ntrailer\n%%EOF\n".utf8)
        XCTAssertTrue(ReportJob.isWellFormed(complete))
    }

    func testAnEmptyBufferIsNotAPdf() {
        XCTAssertFalse(ReportJob.isWellFormed(Data()))
        XCTAssertFalse(ReportJob.isWellFormed(Data("%PDF-".utf8)), "a header alone is not a file")
    }

    func testSomethingElseEntirelyIsNotAPdf() {
        XCTAssertFalse(ReportJob.isWellFormed(Data("<html>%%EOF</html>".utf8)))
    }

    /// It sorts, which is the point of putting the date first.
    func testNamesSortChronologically() {
        let earlier = ReportJob.fileName(
            date: moment, timeZone: TimeZone(identifier: "UTC")!
        )
        let later = ReportJob.fileName(
            date: moment.addingTimeInterval(3600), timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertLessThan(earlier, later)
    }
}
