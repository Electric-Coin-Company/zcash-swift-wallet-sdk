//
//  FakeService.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 10/23/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftProtobuf
@testable import ZcashLightClientKit

struct LightWalletServiceMockResponse: LightWalletServiceResponse {
    var errorCode: Int32
    var errorMessage: String
    var unknownFields: UnknownStorage
}

struct MockCancellable: CancellableCall {
    func cancel() {}
}

class MockLightWalletService: LightWalletService {
    var mockLightDInfo: LightWalletdInfo?
    var queue = DispatchQueue(label: "mock service queue")

    func blockStream(startHeight: BlockHeight, endHeight: BlockHeight) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        service.blockStream(startHeight: startHeight, endHeight: endHeight)
    }

    func closeConnection() {
    }

    func fetchUTXOs(for tAddress: String, height: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        service.fetchUTXOs(for: tAddress, height: height)
    }

    func fetchUTXOs(for tAddresses: [String], height: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        service.fetchUTXOs(for: tAddresses, height: height)
    }
    
    private var service: LightWalletService
    
    var latestHeight: BlockHeight

    init(latestBlockHeight: BlockHeight, service: LightWalletService) {
        self.latestHeight = latestBlockHeight
        self.service = service
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        return self.latestHeight
    }
    
    func getInfo() async throws -> LightWalletdInfo {
        guard let info = mockLightDInfo else {
            throw LightWalletServiceError.generalError(message: "Not Implemented")
        }
        return info
    }

    func latestBlockHeightAsync() async throws -> BlockHeight {
        latestHeight
    }
    
    func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        service.blockRange(range)
    }
    
    func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        LightWalletServiceMockResponse(errorCode: 0, errorMessage: "", unknownFields: UnknownStorage())
    }
    
    func fetchTransaction(txId: Data) async throws -> TransactionEntity {
        Transaction(id: 1, transactionId: Data(), created: "Today", transactionIndex: 1, expiryHeight: -1, minedHeight: -1, raw: nil)
    }
}
