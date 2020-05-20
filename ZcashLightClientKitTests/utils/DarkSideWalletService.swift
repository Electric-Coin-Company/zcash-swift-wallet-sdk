//
//  DarkSideWalletService.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/23/20.
//

import Foundation
@testable import ZcashLightClientKit
import GRPC

enum DarksideDataset: String {
    case afterLargeReorg = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/basic-reorg/after-large-large.txt"
    case afterSmallReorg =  "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/basic-reorg/after-small-reorg.txt"
    case beforeReOrg = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/basic-reorg/before-reorg.txt"
    
}

class DarksideWalletService: LightWalletService {

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
    
    /**
     Darskside lightwalletd should do a fake submission, by sending over the tx, retrieving it and including it in a new block
     */
    func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        service.submit(spendTransaction: spendTransaction, result: result)
    }
    
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        try service.submit(spendTransaction: spendTransaction)
    }
    
    func useDataset(_ datasetUrl: String, startHeight: BlockHeight = 663174) throws {
        try useDataset(from: datasetUrl, startHeight: startHeight)
    }
    
    func useDataset(from urlString: String, startHeight: BlockHeight) throws {
        var blocksUrl = DarksideBlocksURL()
        blocksUrl.url = urlString
        _ = try darksideService.stageBlocks(blocksUrl, callOptions: CallOptions()).response.wait()
    }
    
    func applyStaged(nextLatestHeight: BlockHeight) throws {
        var darksideHeight = DarksideHeight()
        darksideHeight.height = Int32(nextLatestHeight)
        _ = try darksideService.applyStaged(darksideHeight).response.wait()
    }
    
    func clearIncomingTransactions() throws {
        _ = try darksideService.clearIncomingTransactions(Empty()).response.wait()
    }
    
    func getIncomingTransactions() throws -> [RawTransaction]? {
        var txs = [RawTransaction]()
        let response = try darksideService.getIncomingTransactions(Empty(), handler: { txs.append($0) }).status.wait()
        switch response {
        case .ok:
            return txs.count > 0 ? txs : nil
        default:
            throw response
        }
    }
    
    func reset(saplingActivation: BlockHeight) throws {
        var metaState = DarksideMetaState()
        metaState.saplingActivation = Int32(saplingActivation)
        metaState.branchID = "DEADBEEF"
        metaState.chainName = "MAINNET"
        // TODO: complete meta state correctly
        _ = try darksideService.reset(metaState).response.wait()
    }
    
    func stageBlocksCreate(from height: BlockHeight, count: Int = 1) throws {
        var emptyBlocks = DarksideEmptyBlocks()
        emptyBlocks.count = Int32(count)
        emptyBlocks.height = Int32(height)
        _ = try darksideService.stageBlocksCreate(emptyBlocks).response.wait()
    }
    
    func stageTransaction(_ rawTransaction: RawTransaction, at height: BlockHeight) throws {
        var tx = rawTransaction
        tx.height = UInt64(height)
        _ = try darksideService.stageTransactionsStream().sendMessage(tx).wait()
    }
    
}
