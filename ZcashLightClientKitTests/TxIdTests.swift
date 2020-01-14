//
//  TxIdTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 1/10/20.
//

import XCTest

class TxIdTests: XCTestCase {

    func testTxIdAsString() {
        let transactionId = "5cf915c5d01007c39d602e08ab59d98aba366e2fb7ac01f2cdad4bf4f8f300bb"
        let expectedTxIdString = "bb003f8f4fb4dadc2f10ca7bf2e663aba89d95ba80e206d93c70010d5c519fc5"
        
        XCTAssertEqual(transactionId.hexDecodedData().toHexStringTxId(), expectedTxIdString)
    }

}
