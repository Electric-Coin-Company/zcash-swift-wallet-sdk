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
import libzcashlc

class TorClientTests: ZcashTestCase {
    let network: ZcashNetwork = ZcashNetworkBuilder.network(for: .testnet)

    func testApis() throws {
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

        // We can background the Tor client.
        try client.setDormant(mode: Soft)
        // Usage of the Tor client after this point should un-background it automatically.

        // Test HTTP GET.
        let getUrl = "https://httpbin.org/get"
        var getRequest = URLRequest(url: URL(string: getUrl)!)
        getRequest.httpMethod = "GET"
        getRequest.addValue("testHeaderValue", forHTTPHeaderField: "X-Test-Header")
        let (getData, getResponse) = try client.httpRequest(for: getRequest, retryLimit: 3)
        XCTAssertEqual(getResponse.statusCode, 200)
        let getPayload: HTTPBinGet = try JSONDecoder().decode(HTTPBinGet.self, from: getData)
        XCTAssertEqual(getPayload.url, getUrl)
        XCTAssertEqual(getPayload.args, [:])
        XCTAssertEqual(getPayload.headers["Host"], "httpbin.org")
        XCTAssertEqual(getPayload.headers["X-Test-Header"], "testHeaderValue")

        // Test HTTP GET with 419 response.
        let getErrorUrl = "https://httpbin.org/status/419"
        var getErrorRequest = URLRequest(url: URL(string: getErrorUrl)!)
        getErrorRequest.httpMethod = "GET"
        let (_, getErrorResponse) = try client.httpRequest(for: getErrorRequest, retryLimit: 3)
        XCTAssertEqual(getErrorResponse.statusCode, 419)

        // Test HTTP POST.
        let postUrl = "https://httpbin.org/post"
        let postedData = "Some body"
        var postRequest = URLRequest(url: URL(string: postUrl)!)
        postRequest.httpMethod = "POST"
        postRequest.httpBody = Data(postedData.utf8)
        postRequest.addValue("testHeaderValue", forHTTPHeaderField: "X-Test-Header")
        let (postData, postResponse) = try client.httpRequest(for: postRequest, retryLimit: 3)
        XCTAssertEqual(postResponse.statusCode, 200)
        let postPayload: HTTPBinPost = try JSONDecoder().decode(HTTPBinPost.self, from: postData)
        XCTAssertEqual(postPayload.url, postUrl)
        XCTAssertEqual(postPayload.args, [:])
        XCTAssertEqual(postPayload.headers["Host"], "httpbin.org")
        XCTAssertEqual(postPayload.data, postedData)
    }
}

struct HTTPBinGet: Decodable {
    let origin: String
    let url: String
    let args: [String: String]
    let headers: [String: String]
}

struct HTTPBinPost: Decodable {
    let origin: String
    let url: String
    let args: [String: String]
    let headers: [String: String]
    let data: String
}
