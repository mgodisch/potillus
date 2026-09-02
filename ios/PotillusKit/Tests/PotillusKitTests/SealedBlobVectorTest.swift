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
import CryptoKit
import XCTest

@testable import PotillusKit

/// Drives CryptoKit's `AES.GCM.open` over `SealedBox(combined:)` from the shared
/// `sealed-blob.json` vectors — the same file Android's `SealedBlobVectorTest.kt`
/// feeds to `KeystoreSecretStore.openWithKey`. A fixed key and a fixed blob that
/// open on both sides pin the `nonce || ciphertext || tag` layout the assurance
/// case claims, which the round-trip tests in `PreferencesStoreTests` cannot: a
/// layout change that kept the round-trip would pass them unnoticed.
final class SealedBlobVectorTest: XCTestCase {

    func testOpenMatchesTheVectors() throws {
        let vectors = try TestVectors.load("sealed-blob", as: SealedBlobVectors.self)
        let key = SymmetricKey(data: try XCTUnwrap(Data(hex: vectors.keyHex)))

        XCTAssertEqual(vectors.nonceLength, 12)
        XCTAssertEqual(vectors.tagLength, 16)
        XCTAssertEqual(key.bitCount, 256)

        for testCase in vectors.open {
            let blob = try XCTUnwrap(Data(hex: testCase.blobHex), testCase.description)
            if testCase.expectFailure == true {
                XCTAssertThrowsError(
                    try AES.GCM.open(AES.GCM.SealedBox(combined: blob), using: key),
                    testCase.description
                )
            } else {
                let plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: blob), using: key)
                XCTAssertEqual(
                    String(bytes: plaintext, encoding: .utf8),
                    testCase.expected,
                    testCase.description
                )
            }
        }
    }
}

private extension Data {
    /// Lower-case hex, as the vector file writes every byte string. `nil` on odd
    /// length or a non-hex digit, so a malformed vector fails the test loudly.
    init?(hex: String) {
        guard hex.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
