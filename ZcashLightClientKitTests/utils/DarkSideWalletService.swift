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
    
    /**
     see
     https://github.com/zcash-hackworks/darksidewalletd-test-data/tree/master/tx-index-reorg
     */
    case txIndexChangeBefore = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/tx-index-reorg/before-reorg.txt"
    
    case txIndexChangeAfter = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/tx-index-reorg/after-reorg.txt"
    
    /**
        See https://github.com/zcash-hackworks/darksidewalletd-test-data/tree/master/tx-height-reorg
     */
    case txHeightReOrgBefore = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/tx-height-reorg/before-reorg.txt"
    
    case txHeightReOrgAfter = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/tx-height-reorg/after-reorg.txt"
    
    /*
     see: https://github.com/zcash-hackworks/darksidewalletd-test-data/tree/master/tx-remove-reorg
     */
    case txReOrgRemovesInboundTxBefore = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/tx-remove-reorg/before-reorg.txt"
    
    case txReOrgRemovesInboundTxAfter = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/tx-remove-reorg/after-reorg.txt"
}

class DarksideWalletService: LightWalletService {
    func fetchUTXOs(for tAddress: String, result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void) {
        
    }
    

    func fetchTransaction(txId: Data) throws -> TransactionEntity {
        try service.fetchTransaction(txId: txId)
    }
    
    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
        service.fetchTransaction(txId: txId, result: result)
    }
    
    var channel: Channel
    init(channelProvider: ChannelProvider) {
        self.channel = ChannelProvider().channel()
        self.service = LightWalletGRPCService(channel: channel)
        self.darksideService = DarksideStreamerClient(channel: channel)
    }
    
    convenience init() {
        self.init(channelProvider: ChannelProvider())
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
    
    func useDataset(_ datasetUrl: String) throws {
        try useDataset(from: datasetUrl)
    }
    
    func useDataset(from urlString: String) throws {
        var blocksUrl = DarksideBlocksURL()
        blocksUrl.url = urlString
        _ = try darksideService.stageBlocks(blocksUrl, callOptions: nil).response.wait()
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
        switch response.code {
        case .ok:
            return txs.count > 0 ? txs : nil
        default:
            throw response
        }
    }
    
    func reset(saplingActivation: BlockHeight, branchID: String = "d3adb33f", chainName: String = "test") throws {
        var metaState = DarksideMetaState()
        metaState.saplingActivation = Int32(saplingActivation)
        metaState.branchID = "d3adb33f"
        metaState.chainName = "test"
        // TODO: complete meta state correctly
        _ = try darksideService.reset(metaState).response.wait()
    }
    
    func stageBlocksCreate(from height: BlockHeight, count: Int = 1, nonce: Int = 0) throws {
        var emptyBlocks = DarksideEmptyBlocks()
        emptyBlocks.count = Int32(count)
        emptyBlocks.height = Int32(height)
        emptyBlocks.nonce = Int32(nonce)
        _ = try darksideService.stageBlocksCreate(emptyBlocks).response.wait()
    }
    
    func stageTransaction(_ rawTransaction: RawTransaction, at height: BlockHeight) throws {
        var tx = rawTransaction
        tx.height = UInt64(height)
        _ = try darksideService.stageTransactionsStream().sendMessage(tx).wait()
    }
    
    func stageTransaction(from url: String, at height: BlockHeight) throws {
        var txUrl = DarksideTransactionsURL()
        txUrl.height = Int32(height)
        txUrl.url = url
        _ = try darksideService.stageTransactions(txUrl, callOptions: nil).response.wait()
    }
 
}
