//
//  TorClientTests.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 27/02/2025.
//

import GRPC
import XCTest

@testable import TestUtils
@testable import ZcashLightClientKit

class TorClientTests: ZcashTestCase {
    let network: ZcashNetwork = ZcashNetworkBuilder.network(for: .testnet)

    func testLwdCanFetchAndSubmitTx() throws {
        // Spin up a new Tor client.
        let client = try TorClient(torDir: testTempDirectory)

        // Connect to a testnet lightwalletd server.
        let lwdConn = try client.connectToLightwalletd(
            endpoint: LightWalletEndpointBuilder.publicTestnet.urlString)

        // Fetch a known testnet transaction.
        let txId =
            "9e309d29a99f06e6dcc7aee91dca23c0efc2cf5083cc483463ddbee19c1fadf1"
            .toTxIdString().hexadecimal!
        let (tx, status) = try lwdConn.fetchTransaction(txId: txId)
        XCTAssertEqual(status, .mined(1_234_567))

        // We should fail to resubmit the already-mined transaction.
        let result = try lwdConn.submit(spendTransaction: tx!.raw)
        XCTAssertEqual(result.errorCode, -25)
        XCTAssertEqual(
            result.errorMessage,
            "failed to validate tx: transaction::Hash(\"private\"), error: transaction is already in state"
        )
    }
}
