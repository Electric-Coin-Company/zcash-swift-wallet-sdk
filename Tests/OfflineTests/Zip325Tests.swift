//
//  Zip325Tests.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 25/02/2025.
//

import XCTest
@testable import ZcashLightClientKit

class Zip325Tests: XCTestCase {
    let seedBytes: [UInt8] = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
    ]
    let privateUseSubject: [UInt8] = [UInt8]("Zip325TestVectors".utf8)

    let ufvk = UnifiedFullViewingKey(
        validatedEncoding: """
        uview1cgrqnry478ckvpr0f580t6fsahp0a5mj2e9xl7hv2d2jd4ldzy449mwwk2l9yeuts85wjls6hjtghdsy5vhhvmjdw3jxl3cxhrg3vs296a3czazrycrr5cywjhwc5c3ztfyjdhm\
        z0exvzzeyejamyp0cr9z8f9wj0953fzht0m4lenk94t70ruwgjxag2tvp63wn9ftzhtkh20gyre3w5s24f6wlgqxnjh40gd2lxe75sf3z8h5y2x0atpxcyf9t3em4h0evvsftluruqne6\
        w4sm066sw0qe5y8qg423grple5fftxrqyy7xmqmatv7nzd7tcjadu8f7mqz4l83jsyxy4t8pkayytyk7nrp467ds85knekdkvnd7hqkfer8mnqd7pv
        """
    )

    func testInherentKeyDerivation() throws {
        // From https://github.com/zcash-hackworks/zcash-test-vectors/blob/master/zip_0325.py
        let tvs = [
            "d88239020bcc64d08282cd3d242cc12be207eb7154b1065fbeaf262dc4cbc94f",
            "3bf2fd2bfcead493ae3a1e2b6c5dedc3f4c4a6129ef23699ca8e2015da557728",
            "a73ffccd70c8c7c7bc47ac555512e8ffdc41e02f32716372f46dbf5a4e207aa2",
            "e237eb4cceb983cc8703996a63668bacb2208289e49dc863fa96feb402bf7b42",
        ]

        for account in 0..<4 {
            let accountMetadataKey = try AccountMetadataKey(from: seedBytes, accountIndex: Zip32AccountIndex(UInt32(account)), networkType: .mainnet)
            let keys = try accountMetadataKey.derivePrivateUseMetadataKey(ufvk: nil, privateUseSubject: privateUseSubject)

            // Inherent metadata keys are unique per account.
            XCTAssertEqual(keys.count, 1)
            XCTAssertEqual(keys[0].hexEncodedString(), tvs[account])
        }
    }

    func testImportedUFVKKeyDerivation() throws {
        // From https://github.com/zcash-hackworks/zcash-test-vectors/blob/master/zip_0325.py
        let tvs = [
            [
                "02f6dfb0096dad5401a8fa7e371c1b4838341673cc7010a66b17ddb68a851e4f",
                "f4cd290baf093e9454de5f5cb75ce049102951348f60c666f393c915f23d0310",
                "dfd34cabdc9afc4ac8ed0b631b109e5ff80824b80c12ecb2892080222d970e43",
            ],
            [
                "b24ebfefc04f4eb98ac7c5beecf7a3ab1474a97ac7b3c7d857a23afea547caaf",
                "fa07cfc2c7ed10d173f7e28f4d601595facd41072e72f6e5936a1440c9cbc7df",
                "b34929a3f05af8a5ab16ad94708f031c08217b8369f35d125e7fcdfec56ea1bb",
            ],
            [
                "ebf59396fb27862406b1984309d4784eedf14cb28c969344eabec1c300160da5",
                "dd39129515151a8e77d280d1e8513fd091eec6c9cce5ce0096fdfc60d8d3f204",
                "32650eb08e10b17ae37f9d82680e4d83cad25150061a3910a82bc72e25cda568",
            ],
            [
                "6a4124096c38b0132da7fb94c199df4156d804a3589e46f33395c1d0e358e9f0",
                "d9ef369e616a31e8c40996cc625c352f2cf9815f5119a4edad6562165c8b727a",
                "9d83e6d209792bd5796f2d0fe19ceb18bfdfec3d09ad0386ed27339a1e7f8501",
            ],
        ]

        for account in 0..<1 {
            let accountMetadataKey = try AccountMetadataKey(from: seedBytes, accountIndex: Zip32AccountIndex(UInt32(account)), networkType: .mainnet)
            let keys = try accountMetadataKey.derivePrivateUseMetadataKey(ufvk: ufvk, privateUseSubject: privateUseSubject)

            // UFVK has Orchard, transparent, and unknown FVK items.
            XCTAssertEqual(keys.count, 3)

            for i in 0..<3 {
                XCTAssertEqual(keys[i].hexEncodedString(), tvs[account][i])
            }
        }
    }
}
