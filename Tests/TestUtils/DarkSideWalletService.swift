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
    func getTaddressTxids(_ request: ZcashLightClientKit.TransparentAddressBlockFilter) -> AsyncThrowingStream<ZcashLightClientKit.RawTransaction, any Error> {
        service.getTaddressTxids(request)
    }
    
    var connectionStateChange: ((ZcashLightClientKit.ConnectionState, ZcashLightClientKit.ConnectionState) -> Void)? {
        get { service.connectionStateChange }
        set { service.connectionStateChange = newValue }
    }
    var channel: Channel
    var service: LightWalletService
    var darksideService: DarksideStreamerNIOClient
    
    init(endpoint: LightWalletEndpoint) {
        self.channel = ChannelProvider().channel(endpoint: endpoint)
        self.service = LightWalletServiceFactory(endpoint: endpoint).make()
        self.darksideService = DarksideStreamerNIOClient(channel: channel)
    }
    
    init(endpoint: LightWalletEndpoint, service: LightWalletService) {
        self.channel = ChannelProvider().channel(endpoint: endpoint)
        self.darksideService = DarksideStreamerNIOClient(channel: channel)
        self.service = service
    }
    
    convenience init() {
        self.init(endpoint: LightWalletEndpointBuilder.default)
    }
    
    func blockStream(startHeight: BlockHeight, endHeight: BlockHeight) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        service.blockStream(startHeight: startHeight, endHeight: endHeight)
    }
    
    func latestBlock() async throws -> ZcashLightClientKit.BlockID {
        throw "Not mocked"
    }
    
    func closeConnection() {
    }
    
    func fetchUTXOs(for tAddress: String, height: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        service.fetchUTXOs(for: tAddress, height: height)
    }
    
    func fetchUTXOs(for tAddresses: [String], height: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        service.fetchUTXOs(for: tAddresses, height: height)
    }
    
    func latestBlockHeight() async throws -> BlockHeight {
        try await service.latestBlockHeight()
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

    func reset(
        saplingActivation: BlockHeight,
        startSaplingTreeSize: UInt32,
        startOrchardTreeSize: UInt32,
        branchID: String = "d3adb33f",
        chainName: String = "test"
    ) throws {
        var metaState = DarksideMetaState()
        metaState.saplingActivation = Int32(saplingActivation)
        metaState.branchID = branchID
        metaState.chainName = chainName
        metaState.startSaplingCommitmentTreeSize = startSaplingTreeSize
        metaState.startOrchardCommitmentTreeSize = startOrchardTreeSize
        // TODO: [#718] complete meta state correctly, https://github.com/zcash/ZcashLightClientKit/issues/718
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
    
    func getInfo() async throws -> LightWalletdInfo {
        try await service.getInfo()
    }

    func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        service.blockRange(range)
    }
    
    /// Darskside lightwalletd should do a fake submission, by sending over the tx, retrieving it and including it in a new block
    func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        try await service.submit(spendTransaction: spendTransaction)
    }

    func fetchTransaction(txId: Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        try await service.fetchTransaction(txId: txId)
    }

    func getSubtreeRoots(_ request: ZcashLightClientKit.GetSubtreeRootsArg) -> AsyncThrowingStream<ZcashLightClientKit.SubtreeRoot, Error> {
        service.getSubtreeRoots(request)
    }

    func addTreeState(_ treeState: TreeState) throws {
        _ = try darksideService.addTreeState(treeState).response.wait()
    }

    func getTreeState(_ id: BlockID) async throws -> TreeState {
        try await service.getTreeState(id)
    }

    func setSubtreeRoots(_ request: DarksideSubtreeRoots) {
        _ = darksideService.setSubtreeRoots(request)
    }
}

enum DarksideWalletDConstants: NetworkConstants {
    static let defaultFsBlockDbRootName = "fs_cache"
    
    static var saplingActivationHeight: BlockHeight {
        663150
    }
    
    static var defaultDataDbName: String {
        ZcashSDKMainnetConstants.defaultDataDbName
    }

    static var defaultTorDirName: String {
        ZcashSDKMainnetConstants.defaultTorDirName
    }

    static var defaultCacheDbName: String {
        ZcashSDKMainnetConstants.defaultCacheDbName
    }
    
    static var defaultDbNamePrefix: String {
        ZcashSDKMainnetConstants.defaultDbNamePrefix
    }
}

class DarksideWalletDNetwork: ZcashNetwork {
    let constants: NetworkConstants.Type = DarksideWalletDConstants.self
    let networkType = NetworkType.mainnet
}
