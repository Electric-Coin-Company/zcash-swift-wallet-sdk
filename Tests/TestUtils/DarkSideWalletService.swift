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
    case afterSmallReorg = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/basic-reorg/after-small-reorg.txt"
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
    var channel: Channel
    var service: LightWalletGRPCService
    var darksideService: DarksideStreamerClient

    init(endpoint: LightWalletEndpoint) {
        self.channel = ChannelProvider().channel()
        self.service = LightWalletGRPCService(endpoint: endpoint)
        self.darksideService = DarksideStreamerClient(channel: channel)
    }

    init(service: LightWalletGRPCService) {
        self.channel = ChannelProvider().channel()
        self.darksideService = DarksideStreamerClient(channel: channel)
        self.service = service
    }

    convenience init() {
        self.init(endpoint: LightWalletEndpointBuilder.default)
    }

    @discardableResult
    func blockStream(
        startHeight: BlockHeight,
        endHeight: BlockHeight,
        result: @escaping (Result<GRPCResult, LightWalletServiceError>) -> Void,
        handler: @escaping (ZcashCompactBlock) -> Void,
        progress: @escaping (BlockProgress) -> Void
    ) -> CancellableCall {
        return service.blockStream(
            startHeight: startHeight,
            endHeight: endHeight,
            result: result,
            handler: handler,
            progress: progress
        )
    }

    func getInfo() throws -> LightWalletdInfo {
        try service.getInfo()
    }

    func getInfo(result: @escaping (Result<LightWalletdInfo, LightWalletServiceError>) -> Void) {
        service.getInfo(result: result)
    }

    func closeConnection() {
    }

    func fetchUTXOs(for tAddress: String, height: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        return []
    }

    func fetchUTXOs(
        for tAddress: String,
        height: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void
    ) {
        service.fetchUTXOs(for: tAddress, height: height, result: result)
    }

    func fetchUTXOs(for tAddresses: [String], height: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        try service.fetchUTXOs(for: tAddresses, height: height)
    }

    func fetchUTXOs(
        for tAddresses: [String],
        height: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void
    ) {
        service.fetchUTXOs(for: tAddresses, height: height, result: result)
    }


    func fetchTransaction(txId: Data) throws -> TransactionEntity {
        try service.fetchTransaction(txId: txId)
    }

    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
        service.fetchTransaction(txId: txId, result: result)
    }

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
        var txs: [RawTransaction] = []
        let response = try darksideService.getIncomingTransactions(
            Empty(),
            handler: { txs.append($0) }
        )
        .status
        .wait()

        switch response.code {
        case .ok:
            return !txs.isEmpty ? txs : nil
        default:
            throw response
        }
    }

    func reset(saplingActivation: BlockHeight, branchID: String = "d3adb33f", chainName: String = "test") throws {
        var metaState = DarksideMetaState()
        metaState.saplingActivation = Int32(saplingActivation)
        metaState.branchID = branchID
        metaState.chainName = chainName
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
        var transaction = rawTransaction
        transaction.height = UInt64(height)
        _ = try darksideService.stageTransactionsStream()
            .sendMessage(transaction)
            .wait()
    }

    func stageTransaction(from url: String, at height: BlockHeight) throws {
        var txUrl = DarksideTransactionsURL()
        txUrl.height = Int32(height)
        txUrl.url = url
        _ = try darksideService.stageTransactions(txUrl, callOptions: nil).response.wait()
    }

    func addUTXO(_ utxo: GetAddressUtxosReply) throws {
        _ = try darksideService.addAddressUtxo(utxo, callOptions: nil).response.wait()
    }

    func clearAddedUTXOs() throws {
        _ = try darksideService.clearAddressUtxo(Empty(), callOptions: nil).response.wait()
    }
}

enum DarksideWalletDConstants: NetworkConstants {
    static var saplingActivationHeight: BlockHeight {
        663150
    }

    static var defaultDataDbName: String {
        ZcashSDKMainnetConstants.defaultDataDbName
    }

    static var defaultCacheDbName: String {
        ZcashSDKMainnetConstants.defaultCacheDbName
    }

    static var defaultPendingDbName: String {
        ZcashSDKMainnetConstants.defaultPendingDbName
    }

    static var defaultDbNamePrefix: String {
        ZcashSDKMainnetConstants.defaultDbNamePrefix
    }

    static var feeChangeHeight: BlockHeight {
        ZcashSDKMainnetConstants.feeChangeHeight
    }
}

class DarksideWalletDNetwork: ZcashNetwork {
    var constants: NetworkConstants.Type = DarksideWalletDConstants.self
    var networkType = NetworkType.mainnet
}

