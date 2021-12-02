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

    @discardableResult
    func blockStream(
        startHeight: BlockHeight,
        endHeight: BlockHeight,
        result: @escaping (Result<GRPCResult, LightWalletServiceError>) -> Void,
        handler: @escaping (ZcashCompactBlock) -> Void,
        progress: @escaping (BlockProgress) -> Void
    ) -> CancellableCall {
        return MockCancellable()
    }
    
    func getInfo() throws -> LightWalletdInfo {
        guard let info = mockLightDInfo else {
            throw LightWalletServiceError.generalError(message: "Not Implemented")
        }
        return info
    }
    
    func getInfo(result: @escaping (Result<LightWalletdInfo, LightWalletServiceError>) -> Void) {
        queue.async { [weak self] in
            guard let info = self?.mockLightDInfo else {
                result(.failure(LightWalletServiceError.generalError(message: "Not Implemented")))
                return
            }
            result(.success(info))
        }
    }
    
    func closeConnection() {
    }
    
    func fetchUTXOs(for tAddress: String, height: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        []
    }
    
    func fetchUTXOs(
        for tAddress: String,
        height: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void
    ) {
    }
    
    func fetchUTXOs(for tAddresses: [String], height: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        []
    }
    
    func fetchUTXOs(
        for tAddresses: [String],
        height: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void
    ) {
    }
    
    func fetchUTXOs(
        for tAddress: String,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void
    ) {
    }
    
    private var service: LightWalletService
    
    var latestHeight: BlockHeight

    init(latestBlockHeight: BlockHeight, service: LightWalletService) {
        self.latestHeight = latestBlockHeight
        self.service = service
    }
    
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            result(.success(self.latestHeight))
        }
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        return self.latestHeight
    }
    
    func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        self.service.blockRange(range, result: result)
    }
    
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        try self.service.blockRange(range)
    }
    
    func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
            result(.success(LightWalletServiceMockResponse(errorCode: 0, errorMessage: "", unknownFields: UnknownStorage())))
        }
    }
    
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        return LightWalletServiceMockResponse(errorCode: 0, errorMessage: "", unknownFields: UnknownStorage())
    }
    
    func fetchTransaction(txId: Data) throws -> TransactionEntity {
        Transaction(id: 1, transactionId: Data(), created: "Today", transactionIndex: 1, expiryHeight: -1, minedHeight: -1, raw: nil)
    }
    
    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
    }
}
