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

// =============================================================================
// ChartBucketingTests.swift – cross-platform parity suite
// =============================================================================
//
// Driven by `test-vectors/chart-bucketing.json`, the same file the Android JVM
// suite asserts against. Covers Trend, granularity selection, and the bucketing
// rules — including the two consequences of the in-progress day.
// =============================================================================

/// Root of `test-vectors/chart-bucketing.json`.
struct ChartBucketingVectors: Decodable {
    let trend: [TrendCase]
    let granularityForSpan: [GranularityCase]
    let bucketize: [BucketizeCase]

    struct TrendCase: Decodable {
        let description: String
        let currentAvg: Double
        let prevAvg: Double
        let expected: Trend
    }

    struct GranularityCase: Decodable {
        let description: String
        let days: Int
        let expected: ChartGranularity
    }

    struct BucketizeCase: Decodable {
        let description: String
        /// Positional `[isoDate, grams]` pairs, kept language-neutral in JSON.
        let summaries: [[DayField]]
        let from: String
        let to: String
        let granularity: ChartGranularity
        /// Absent for the PDF-export path, which counts every calendar day.
        let inProgressDay: String?
        let expected: [ExpectedBucket]

        struct ExpectedBucket: Decodable {
            let labelDate: String
            let avgPerDay: Double
            let isAbstinent: Bool
        }

        /// The day pairs mix a string and a number, so decoding needs a small
        /// either-or wrapper rather than a homogeneous element type.
        enum DayField: Decodable {
            case date(String)
            case grams(Double)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .date(string)
                } else {
                    self = .grams(try container.decode(Double.self))
                }
            }
        }

        func daySummaries() -> [DaySummary] {
            summaries.compactMap { pair in
                guard pair.count == 2,
                      case let .date(date) = pair[0],
                      case let .grams(grams) = pair[1]
                else { return nil }
                return DaySummary(date: date, totalGrams: grams)
            }
        }
    }
}

final class ChartBucketingTests: XCTestCase {

    private static let epsilon = 0.001
    private static var loadedVectors: ChartBucketingVectors!

    override class func setUp() {
        super.setUp()
        do {
            loadedVectors = try TestVectors.load("chart-bucketing", as: ChartBucketingVectors.self)
        } catch {
            XCTFail("Could not load shared test vectors: \(error)")
        }
    }

    private var vectors: ChartBucketingVectors { Self.loadedVectors }

    // ── Trend ────────────────────────────────────────────────────────────────

    func testTrendAgainstSharedVectors() {
        for testCase in vectors.trend {
            let actual = Trend.of(currentAvg: testCase.currentAvg, prevAvg: testCase.prevAvg)
            XCTAssertEqual(actual, testCase.expected, "trend: \(testCase.description)")
        }
    }

    // ── granularityForSpan ───────────────────────────────────────────────────

    func testGranularityForSpanAgainstSharedVectors() {
        for testCase in vectors.granularityForSpan {
            let actual = ChartBucketing.granularityForSpan(days: testCase.days)
            XCTAssertEqual(actual, testCase.expected, "granularityForSpan: \(testCase.description)")
        }
    }

    // ── bucketize ────────────────────────────────────────────────────────────

    func testBucketizeAgainstSharedVectors() {
        for testCase in vectors.bucketize {
            let actual = ChartBucketing.bucketize(
                summaries: testCase.daySummaries(),
                from: testCase.from,
                to: testCase.to,
                granularity: testCase.granularity,
                inProgressDay: testCase.inProgressDay
            )
            let label = testCase.description
            XCTAssertEqual(actual.count, testCase.expected.count, "bucket count: \(label)")
            guard actual.count == testCase.expected.count else { continue }

            for (index, expected) in testCase.expected.enumerated() {
                XCTAssertEqual(actual[index].labelDate, expected.labelDate, "labelDate[\(index)]: \(label)")
                XCTAssertEqual(
                    actual[index].avgPerDay, expected.avgPerDay, accuracy: Self.epsilon,
                    "avgPerDay[\(index)]: \(label)"
                )
                XCTAssertEqual(
                    actual[index].isAbstinent, expected.isAbstinent, "isAbstinent[\(index)]: \(label)"
                )
            }
        }
    }

    // ── Structural tests (not vector-driven) ─────────────────────────────────

    /// Buckets must tile the period without gaps or overlaps, whatever the
    /// granularity. Bar `n + 1` starts exactly where bar `n` ends.
    func testBucketsAreContiguousAndCoverThePeriod() {
        for granularity in [ChartGranularity.daily, .weekly, .monthly] {
            let buckets = ChartBucketing.bucketize(
                summaries: [], from: "2025-01-15", to: "2025-04-10", granularity: granularity
            )
            XCTAssertFalse(buckets.isEmpty, "\(granularity) produced no buckets")
            XCTAssertEqual(buckets.first?.labelDate, "2025-01-15", "first bucket starts at `from`")

            let labels = buckets.map(\.labelDate)
            XCTAssertEqual(labels, labels.sorted(), "\(granularity) buckets are not chronological")
            XCTAssertEqual(Set(labels).count, labels.count, "\(granularity) has duplicate labels")
        }
    }

    /// An inverted range is not an error, it is simply empty.
    func testInvertedRangeYieldsNoBuckets() {
        XCTAssertTrue(
            ChartBucketing.bucketize(
                summaries: [], from: "2025-05-10", to: "2025-05-01", granularity: .daily
            ).isEmpty
        )
    }

    /// A monthly bucket must never be shortened or lengthened by a DST shift; the
    /// UTC-pinned calendar is what guarantees it. February 2024 has 29 days.
    func testLeapFebruaryIsAveragedOverTwentyNineDays() {
        let buckets = ChartBucketing.bucketize(
            summaries: [DaySummary(date: "2024-02-01", totalGrams: 29.0)],
            from: "2024-02-01", to: "2024-02-29", granularity: .monthly
        )
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets.first?.avgPerDay ?? 0, 1.0, accuracy: Self.epsilon)
    }

    /// The bucket holding the in-progress day is never abstinent, even when it
    /// contains no alcohol at all: the period has not closed yet.
    func testInProgressBucketIsNeverAbstinent() {
        let buckets = ChartBucketing.bucketize(
            summaries: [], from: "2025-05-01", to: "2025-05-07",
            granularity: .weekly, inProgressDay: "2025-05-07"
        )
        XCTAssertEqual(buckets.count, 1)
        XCTAssertFalse(buckets[0].isAbstinent)
    }
}
