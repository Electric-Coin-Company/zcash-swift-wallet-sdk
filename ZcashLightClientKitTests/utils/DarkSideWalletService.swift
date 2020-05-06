//
//  DarkSideWalletService.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/23/20.
//

import Foundation
@testable import ZcashLightClientKit
import GRPC
class DarksideWalletService: LightWalletService {
    
    enum DarksideDataset: String {
        case afterLargeReorg = "https://raw.githubusercontent.com/defuse/darksidewalletd-test-data/basic-reorg/basic-reorg/after-large-large.txt"
        case afterSmallReorg =  "https://raw.githubusercontent.com/defuse/darksidewalletd-test-data/basic-reorg/basic-reorg/after-small-reorg.txt"
        case beforeReOrg = "https://raw.githubusercontent.com/defuse/darksidewalletd-test-data/basic-reorg/basic-reorg/before-reorg.txt"
        
    }
    func fetchTransaction(txId: Data) throws -> TransactionEntity {
        try service.fetchTransaction(txId: txId)
    }
    
    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
        service.fetchTransaction(txId: txId, result: result)
    }
    
    var channel: Channel
    init() {
        let channel = ChannelProvider().channel()
        self.channel = channel
        self.service = LightWalletGRPCService(channel: channel)
        self.darksideService = DarksideStreamerClient(channel: channel)
    }
    var service: LightWalletGRPCService
    var darksideService: DarksideStreamerClient
    
    func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        service.latestBlockHeight(result: result)
    }
    
    func latestBlockHeight() throws -> BlockHeight {
        try service.latestBlockHeight()
    }
    
    func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        service.blockRange(range, result: result)
    }
    
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        try service.blockRange(range)
    }
    
    func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        service.submit(spendTransaction: spendTransaction, result: result)
    }
    
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        try service.submit(spendTransaction: spendTransaction)
    }
    
    func useDataset(_ dataset: DarksideDataset) throws {
        var blocksUrl = DarksideBlocksURL()
        blocksUrl.url = dataset.rawValue
        _ = try darksideService.setBlocksURL(blocksUrl).response.wait()
    }
    
}
