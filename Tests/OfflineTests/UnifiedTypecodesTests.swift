//
//  UnifiedTypecodesTests.swift
//  OfflineTests
//
//  Created by Francisco Gindre on 9/14/22.
//

import XCTest
@testable import ZcashLightClientKit
import TestUtils

final class UnifiedTypecodesTests: XCTestCase {
    func testVectorBuilding() throws {
        guard let testVectors = TestVector.testVectors else {
            XCTFail("fail to construct vectors")
            return
        }

        XCTAssertEqual(testVectors.count, 60)
    }

    func testUnifiedAddressHasTransparentSaplingReceiversBackend() throws {
        guard let testVectors = TestVector.testVectors,
            let firstVector = testVectors.first,
            let uAddress = firstVector.unified_addr
        else {
            XCTFail("fail to construct vectors")
            return
        }

        let address = UnifiedAddress(validatedEncoding: uAddress)

        let typecodes = try ZcashRustBackend.receiverTypecodesOnUnifiedAddress(address.stringEncoded)

        XCTAssertEqual(typecodes, [2, 0])
    }

    func testUnifiedAddressHasTransparentSaplingReceivers() throws {
        guard let testVectors = TestVector.testVectors,
            let firstVector = testVectors.first,
            let uAddress = firstVector.unified_addr
        else {
            XCTFail("fail to construct vectors")
            return
        }

        let address = UnifiedAddress(validatedEncoding: uAddress)

        let typecodes = try DerivationTool.receiverTypecodesFromUnifiedAddress(address)

        XCTAssertEqual(
            Set<UnifiedAddress.ReceiverTypecodes>(typecodes),
            Set([
                .sapling,
                .p2pkh
            ])
        )
    }

    func testReceiverTypecodes() {
        XCTAssertEqual(UnifiedAddress.ReceiverTypecodes(typecode: 0x00), .p2pkh)
        XCTAssertEqual(UnifiedAddress.ReceiverTypecodes(typecode: 0x01), .p2sh)
        XCTAssertEqual(UnifiedAddress.ReceiverTypecodes(typecode: 0x02), .sapling)
        XCTAssertEqual(UnifiedAddress.ReceiverTypecodes(typecode: 0x03), .orchard)
        XCTAssertEqual(UnifiedAddress.ReceiverTypecodes(typecode: 0x0F), .unknown(0x0F))
    }

    func testExtractTypecode() throws {
        // swiftlint:disable:next line_length
        let ua = UnifiedAddress(validatedEncoding: "u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj")
        XCTAssertEqual(try ua.availableReceiverTypecodes(), [.sapling, .p2pkh])
    }
}
