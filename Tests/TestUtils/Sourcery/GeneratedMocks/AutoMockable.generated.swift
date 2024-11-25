// Generated using Sourcery 2.2.5 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
import Combine
@testable import ZcashLightClientKit
import Foundation



// MARK: - AutoMockable protocols
class ActionContextMock: ActionContext {


    init(
    ) {
    }
    var state: CBPState {
        get { return underlyingState }
    }
    var underlyingState: CBPState!
    var prevState: CBPState?
    var syncControlData: SyncControlData {
        get { return underlyingSyncControlData }
    }
    var underlyingSyncControlData: SyncControlData!
    var requestedRewindHeight: BlockHeight?
    var processedHeight: BlockHeight {
        get { return underlyingProcessedHeight }
    }
    var underlyingProcessedHeight: BlockHeight!
    var lastChainTipUpdateTime: TimeInterval {
        get { return underlyingLastChainTipUpdateTime }
    }
    var underlyingLastChainTipUpdateTime: TimeInterval!
    var lastScannedHeight: BlockHeight?
    var lastEnhancedHeight: BlockHeight?

    // MARK: - update

    var updateStateCallsCount = 0
    var updateStateCalled: Bool {
        return updateStateCallsCount > 0
    }
    var updateStateReceivedState: CBPState?
    var updateStateClosure: ((CBPState) async -> Void)?

    func update(state: CBPState) async {
        updateStateCallsCount += 1
        updateStateReceivedState = state
        await updateStateClosure!(state)
    }

    // MARK: - update

    var updateSyncControlDataCallsCount = 0
    var updateSyncControlDataCalled: Bool {
        return updateSyncControlDataCallsCount > 0
    }
    var updateSyncControlDataReceivedSyncControlData: SyncControlData?
    var updateSyncControlDataClosure: ((SyncControlData) async -> Void)?

    func update(syncControlData: SyncControlData) async {
        updateSyncControlDataCallsCount += 1
        updateSyncControlDataReceivedSyncControlData = syncControlData
        await updateSyncControlDataClosure!(syncControlData)
    }

    // MARK: - update

    var updateProcessedHeightCallsCount = 0
    var updateProcessedHeightCalled: Bool {
        return updateProcessedHeightCallsCount > 0
    }
    var updateProcessedHeightReceivedProcessedHeight: BlockHeight?
    var updateProcessedHeightClosure: ((BlockHeight) async -> Void)?

    func update(processedHeight: BlockHeight) async {
        updateProcessedHeightCallsCount += 1
        updateProcessedHeightReceivedProcessedHeight = processedHeight
        await updateProcessedHeightClosure!(processedHeight)
    }

    // MARK: - update

    var updateLastChainTipUpdateTimeCallsCount = 0
    var updateLastChainTipUpdateTimeCalled: Bool {
        return updateLastChainTipUpdateTimeCallsCount > 0
    }
    var updateLastChainTipUpdateTimeReceivedLastChainTipUpdateTime: TimeInterval?
    var updateLastChainTipUpdateTimeClosure: ((TimeInterval) async -> Void)?

    func update(lastChainTipUpdateTime: TimeInterval) async {
        updateLastChainTipUpdateTimeCallsCount += 1
        updateLastChainTipUpdateTimeReceivedLastChainTipUpdateTime = lastChainTipUpdateTime
        await updateLastChainTipUpdateTimeClosure!(lastChainTipUpdateTime)
    }

    // MARK: - update

    var updateLastScannedHeightCallsCount = 0
    var updateLastScannedHeightCalled: Bool {
        return updateLastScannedHeightCallsCount > 0
    }
    var updateLastScannedHeightReceivedLastScannedHeight: BlockHeight?
    var updateLastScannedHeightClosure: ((BlockHeight) async -> Void)?

    func update(lastScannedHeight: BlockHeight) async {
        updateLastScannedHeightCallsCount += 1
        updateLastScannedHeightReceivedLastScannedHeight = lastScannedHeight
        await updateLastScannedHeightClosure!(lastScannedHeight)
    }

    // MARK: - update

    var updateLastDownloadedHeightCallsCount = 0
    var updateLastDownloadedHeightCalled: Bool {
        return updateLastDownloadedHeightCallsCount > 0
    }
    var updateLastDownloadedHeightReceivedLastDownloadedHeight: BlockHeight?
    var updateLastDownloadedHeightClosure: ((BlockHeight) async -> Void)?

    func update(lastDownloadedHeight: BlockHeight) async {
        updateLastDownloadedHeightCallsCount += 1
        updateLastDownloadedHeightReceivedLastDownloadedHeight = lastDownloadedHeight
        await updateLastDownloadedHeightClosure!(lastDownloadedHeight)
    }

    // MARK: - update

    var updateLastEnhancedHeightCallsCount = 0
    var updateLastEnhancedHeightCalled: Bool {
        return updateLastEnhancedHeightCallsCount > 0
    }
    var updateLastEnhancedHeightReceivedLastEnhancedHeight: BlockHeight?
    var updateLastEnhancedHeightClosure: ((BlockHeight?) async -> Void)?

    func update(lastEnhancedHeight: BlockHeight?) async {
        updateLastEnhancedHeightCallsCount += 1
        updateLastEnhancedHeightReceivedLastEnhancedHeight = lastEnhancedHeight
        await updateLastEnhancedHeightClosure!(lastEnhancedHeight)
    }

    // MARK: - update

    var updateRequestedRewindHeightCallsCount = 0
    var updateRequestedRewindHeightCalled: Bool {
        return updateRequestedRewindHeightCallsCount > 0
    }
    var updateRequestedRewindHeightReceivedRequestedRewindHeight: BlockHeight?
    var updateRequestedRewindHeightClosure: ((BlockHeight) async -> Void)?

    func update(requestedRewindHeight: BlockHeight) async {
        updateRequestedRewindHeightCallsCount += 1
        updateRequestedRewindHeightReceivedRequestedRewindHeight = requestedRewindHeight
        await updateRequestedRewindHeightClosure!(requestedRewindHeight)
    }

}
class BlockDownloaderMock: BlockDownloader {


    init(
    ) {
    }

    // MARK: - setDownloadLimit

    var setDownloadLimitCallsCount = 0
    var setDownloadLimitCalled: Bool {
        return setDownloadLimitCallsCount > 0
    }
    var setDownloadLimitReceivedLimit: BlockHeight?
    var setDownloadLimitClosure: ((BlockHeight) async -> Void)?

    func setDownloadLimit(_ limit: BlockHeight) async {
        setDownloadLimitCallsCount += 1
        setDownloadLimitReceivedLimit = limit
        await setDownloadLimitClosure!(limit)
    }

    // MARK: - setSyncRange

    var setSyncRangeBatchSizeThrowableError: Error?
    var setSyncRangeBatchSizeCallsCount = 0
    var setSyncRangeBatchSizeCalled: Bool {
        return setSyncRangeBatchSizeCallsCount > 0
    }
    var setSyncRangeBatchSizeReceivedArguments: (range: CompactBlockRange, batchSize: Int)?
    var setSyncRangeBatchSizeClosure: ((CompactBlockRange, Int) async throws -> Void)?

    func setSyncRange(_ range: CompactBlockRange, batchSize: Int) async throws {
        if let error = setSyncRangeBatchSizeThrowableError {
            throw error
        }
        setSyncRangeBatchSizeCallsCount += 1
        setSyncRangeBatchSizeReceivedArguments = (range: range, batchSize: batchSize)
        try await setSyncRangeBatchSizeClosure!(range, batchSize)
    }

    // MARK: - startDownload

    var startDownloadMaxBlockBufferSizeCallsCount = 0
    var startDownloadMaxBlockBufferSizeCalled: Bool {
        return startDownloadMaxBlockBufferSizeCallsCount > 0
    }
    var startDownloadMaxBlockBufferSizeReceivedMaxBlockBufferSize: Int?
    var startDownloadMaxBlockBufferSizeClosure: ((Int) async -> Void)?

    func startDownload(maxBlockBufferSize: Int) async {
        startDownloadMaxBlockBufferSizeCallsCount += 1
        startDownloadMaxBlockBufferSizeReceivedMaxBlockBufferSize = maxBlockBufferSize
        await startDownloadMaxBlockBufferSizeClosure!(maxBlockBufferSize)
    }

    // MARK: - stopDownload

    var stopDownloadCallsCount = 0
    var stopDownloadCalled: Bool {
        return stopDownloadCallsCount > 0
    }
    var stopDownloadClosure: (() async -> Void)?

    func stopDownload() async {
        stopDownloadCallsCount += 1
        await stopDownloadClosure!()
    }

    // MARK: - waitUntilRequestedBlocksAreDownloaded

    var waitUntilRequestedBlocksAreDownloadedInThrowableError: Error?
    var waitUntilRequestedBlocksAreDownloadedInCallsCount = 0
    var waitUntilRequestedBlocksAreDownloadedInCalled: Bool {
        return waitUntilRequestedBlocksAreDownloadedInCallsCount > 0
    }
    var waitUntilRequestedBlocksAreDownloadedInReceivedRange: CompactBlockRange?
    var waitUntilRequestedBlocksAreDownloadedInClosure: ((CompactBlockRange) async throws -> Void)?

    func waitUntilRequestedBlocksAreDownloaded(in range: CompactBlockRange) async throws {
        if let error = waitUntilRequestedBlocksAreDownloadedInThrowableError {
            throw error
        }
        waitUntilRequestedBlocksAreDownloadedInCallsCount += 1
        waitUntilRequestedBlocksAreDownloadedInReceivedRange = range
        try await waitUntilRequestedBlocksAreDownloadedInClosure!(range)
    }

    // MARK: - update

    var updateLatestDownloadedBlockHeightForceCallsCount = 0
    var updateLatestDownloadedBlockHeightForceCalled: Bool {
        return updateLatestDownloadedBlockHeightForceCallsCount > 0
    }
    var updateLatestDownloadedBlockHeightForceReceivedArguments: (latestDownloadedBlockHeight: BlockHeight, force: Bool)?
    var updateLatestDownloadedBlockHeightForceClosure: ((BlockHeight, Bool) async -> Void)?

    func update(latestDownloadedBlockHeight: BlockHeight, force: Bool) async {
        updateLatestDownloadedBlockHeightForceCallsCount += 1
        updateLatestDownloadedBlockHeightForceReceivedArguments = (latestDownloadedBlockHeight: latestDownloadedBlockHeight, force: force)
        await updateLatestDownloadedBlockHeightForceClosure!(latestDownloadedBlockHeight, force)
    }

    // MARK: - latestDownloadedBlockHeight

    var latestDownloadedBlockHeightCallsCount = 0
    var latestDownloadedBlockHeightCalled: Bool {
        return latestDownloadedBlockHeightCallsCount > 0
    }
    var latestDownloadedBlockHeightReturnValue: BlockHeight!
    var latestDownloadedBlockHeightClosure: (() async -> BlockHeight)?

    func latestDownloadedBlockHeight() async -> BlockHeight {
        latestDownloadedBlockHeightCallsCount += 1
        if let closure = latestDownloadedBlockHeightClosure {
            return await closure()
        } else {
            return latestDownloadedBlockHeightReturnValue
        }
    }

    // MARK: - rewind

    var rewindLatestDownloadedBlockHeightCallsCount = 0
    var rewindLatestDownloadedBlockHeightCalled: Bool {
        return rewindLatestDownloadedBlockHeightCallsCount > 0
    }
    var rewindLatestDownloadedBlockHeightReceivedLatestDownloadedBlockHeight: BlockHeight?
    var rewindLatestDownloadedBlockHeightClosure: ((BlockHeight?) async -> Void)?

    func rewind(latestDownloadedBlockHeight: BlockHeight?) async {
        rewindLatestDownloadedBlockHeightCallsCount += 1
        rewindLatestDownloadedBlockHeightReceivedLatestDownloadedBlockHeight = latestDownloadedBlockHeight
        await rewindLatestDownloadedBlockHeightClosure!(latestDownloadedBlockHeight)
    }

}
class BlockDownloaderServiceMock: BlockDownloaderService {


    init(
    ) {
    }
    var storage: CompactBlockRepository {
        get { return underlyingStorage }
    }
    var underlyingStorage: CompactBlockRepository!

    // MARK: - downloadBlockRange

    var downloadBlockRangeThrowableError: Error?
    var downloadBlockRangeCallsCount = 0
    var downloadBlockRangeCalled: Bool {
        return downloadBlockRangeCallsCount > 0
    }
    var downloadBlockRangeReceivedHeightRange: CompactBlockRange?
    var downloadBlockRangeClosure: ((CompactBlockRange) async throws -> Void)?

    func downloadBlockRange(_ heightRange: CompactBlockRange) async throws {
        if let error = downloadBlockRangeThrowableError {
            throw error
        }
        downloadBlockRangeCallsCount += 1
        downloadBlockRangeReceivedHeightRange = heightRange
        try await downloadBlockRangeClosure!(heightRange)
    }

    // MARK: - rewind

    var rewindToThrowableError: Error?
    var rewindToCallsCount = 0
    var rewindToCalled: Bool {
        return rewindToCallsCount > 0
    }
    var rewindToReceivedHeight: BlockHeight?
    var rewindToClosure: ((BlockHeight) async throws -> Void)?

    func rewind(to height: BlockHeight) async throws {
        if let error = rewindToThrowableError {
            throw error
        }
        rewindToCallsCount += 1
        rewindToReceivedHeight = height
        try await rewindToClosure!(height)
    }

    // MARK: - lastDownloadedBlockHeight

    var lastDownloadedBlockHeightThrowableError: Error?
    var lastDownloadedBlockHeightCallsCount = 0
    var lastDownloadedBlockHeightCalled: Bool {
        return lastDownloadedBlockHeightCallsCount > 0
    }
    var lastDownloadedBlockHeightReturnValue: BlockHeight!
    var lastDownloadedBlockHeightClosure: (() async throws -> BlockHeight)?

    func lastDownloadedBlockHeight() async throws -> BlockHeight {
        if let error = lastDownloadedBlockHeightThrowableError {
            throw error
        }
        lastDownloadedBlockHeightCallsCount += 1
        if let closure = lastDownloadedBlockHeightClosure {
            return try await closure()
        } else {
            return lastDownloadedBlockHeightReturnValue
        }
    }

    // MARK: - latestBlockHeight

    var latestBlockHeightThrowableError: Error?
    var latestBlockHeightCallsCount = 0
    var latestBlockHeightCalled: Bool {
        return latestBlockHeightCallsCount > 0
    }
    var latestBlockHeightReturnValue: BlockHeight!
    var latestBlockHeightClosure: (() async throws -> BlockHeight)?

    func latestBlockHeight() async throws -> BlockHeight {
        if let error = latestBlockHeightThrowableError {
            throw error
        }
        latestBlockHeightCallsCount += 1
        if let closure = latestBlockHeightClosure {
            return try await closure()
        } else {
            return latestBlockHeightReturnValue
        }
    }

    // MARK: - fetchTransaction

    var fetchTransactionTxIdThrowableError: Error?
    var fetchTransactionTxIdCallsCount = 0
    var fetchTransactionTxIdCalled: Bool {
        return fetchTransactionTxIdCallsCount > 0
    }
    var fetchTransactionTxIdReceivedTxId: Data?
    var fetchTransactionTxIdReturnValue: (tx: ZcashTransaction.Fetched?, status: TransactionStatus)!
    var fetchTransactionTxIdClosure: ((Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus))?

    func fetchTransaction(txId: Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        if let error = fetchTransactionTxIdThrowableError {
            throw error
        }
        fetchTransactionTxIdCallsCount += 1
        fetchTransactionTxIdReceivedTxId = txId
        if let closure = fetchTransactionTxIdClosure {
            return try await closure(txId)
        } else {
            return fetchTransactionTxIdReturnValue
        }
    }

    // MARK: - fetchUnspentTransactionOutputs

    var fetchUnspentTransactionOutputsTAddressStartHeightCallsCount = 0
    var fetchUnspentTransactionOutputsTAddressStartHeightCalled: Bool {
        return fetchUnspentTransactionOutputsTAddressStartHeightCallsCount > 0
    }
    var fetchUnspentTransactionOutputsTAddressStartHeightReceivedArguments: (tAddress: String, startHeight: BlockHeight)?
    var fetchUnspentTransactionOutputsTAddressStartHeightReturnValue: AsyncThrowingStream<UnspentTransactionOutputEntity, Error>!
    var fetchUnspentTransactionOutputsTAddressStartHeightClosure: ((String, BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error>)?

    func fetchUnspentTransactionOutputs(tAddress: String, startHeight: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        fetchUnspentTransactionOutputsTAddressStartHeightCallsCount += 1
        fetchUnspentTransactionOutputsTAddressStartHeightReceivedArguments = (tAddress: tAddress, startHeight: startHeight)
        if let closure = fetchUnspentTransactionOutputsTAddressStartHeightClosure {
            return closure(tAddress, startHeight)
        } else {
            return fetchUnspentTransactionOutputsTAddressStartHeightReturnValue
        }
    }

    // MARK: - fetchUnspentTransactionOutputs

    var fetchUnspentTransactionOutputsTAddressesStartHeightCallsCount = 0
    var fetchUnspentTransactionOutputsTAddressesStartHeightCalled: Bool {
        return fetchUnspentTransactionOutputsTAddressesStartHeightCallsCount > 0
    }
    var fetchUnspentTransactionOutputsTAddressesStartHeightReceivedArguments: (tAddresses: [String], startHeight: BlockHeight)?
    var fetchUnspentTransactionOutputsTAddressesStartHeightReturnValue: AsyncThrowingStream<UnspentTransactionOutputEntity, Error>!
    var fetchUnspentTransactionOutputsTAddressesStartHeightClosure: (([String], BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error>)?

    func fetchUnspentTransactionOutputs(tAddresses: [String], startHeight: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        fetchUnspentTransactionOutputsTAddressesStartHeightCallsCount += 1
        fetchUnspentTransactionOutputsTAddressesStartHeightReceivedArguments = (tAddresses: tAddresses, startHeight: startHeight)
        if let closure = fetchUnspentTransactionOutputsTAddressesStartHeightClosure {
            return closure(tAddresses, startHeight)
        } else {
            return fetchUnspentTransactionOutputsTAddressesStartHeightReturnValue
        }
    }

    // MARK: - closeConnection

    var closeConnectionCallsCount = 0
    var closeConnectionCalled: Bool {
        return closeConnectionCallsCount > 0
    }
    var closeConnectionClosure: (() -> Void)?

    func closeConnection() {
        closeConnectionCallsCount += 1
        closeConnectionClosure!()
    }

}
class BlockEnhancerMock: BlockEnhancer {


    init(
    ) {
    }

    // MARK: - enhance

    var enhanceAtDidEnhanceThrowableError: Error?
    var enhanceAtDidEnhanceCallsCount = 0
    var enhanceAtDidEnhanceCalled: Bool {
        return enhanceAtDidEnhanceCallsCount > 0
    }
    var enhanceAtDidEnhanceReceivedArguments: (range: CompactBlockRange, didEnhance: (EnhancementProgress) async -> Void)?
    var enhanceAtDidEnhanceReturnValue: [ZcashTransaction.Overview]?
    var enhanceAtDidEnhanceClosure: ((CompactBlockRange, @escaping (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]?)?

    func enhance(at range: CompactBlockRange, didEnhance: @escaping (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]? {
        if let error = enhanceAtDidEnhanceThrowableError {
            throw error
        }
        enhanceAtDidEnhanceCallsCount += 1
        enhanceAtDidEnhanceReceivedArguments = (range: range, didEnhance: didEnhance)
        if let closure = enhanceAtDidEnhanceClosure {
            return try await closure(range, didEnhance)
        } else {
            return enhanceAtDidEnhanceReturnValue
        }
    }

}
class BlockScannerMock: BlockScanner {


    init(
    ) {
    }

    // MARK: - scanBlocks

    var scanBlocksAtDidScanThrowableError: Error?
    var scanBlocksAtDidScanCallsCount = 0
    var scanBlocksAtDidScanCalled: Bool {
        return scanBlocksAtDidScanCallsCount > 0
    }
    var scanBlocksAtDidScanReceivedArguments: (range: CompactBlockRange, didScan: (BlockHeight, UInt32) async throws -> Void)?
    var scanBlocksAtDidScanReturnValue: BlockHeight!
    var scanBlocksAtDidScanClosure: ((CompactBlockRange, @escaping (BlockHeight, UInt32) async throws -> Void) async throws -> BlockHeight)?

    func scanBlocks(at range: CompactBlockRange, didScan: @escaping (BlockHeight, UInt32) async throws -> Void) async throws -> BlockHeight {
        if let error = scanBlocksAtDidScanThrowableError {
            throw error
        }
        scanBlocksAtDidScanCallsCount += 1
        scanBlocksAtDidScanReceivedArguments = (range: range, didScan: didScan)
        if let closure = scanBlocksAtDidScanClosure {
            return try await closure(range, didScan)
        } else {
            return scanBlocksAtDidScanReturnValue
        }
    }

}
class CompactBlockRepositoryMock: CompactBlockRepository {


    init(
    ) {
    }

    // MARK: - create

    var createThrowableError: Error?
    var createCallsCount = 0
    var createCalled: Bool {
        return createCallsCount > 0
    }
    var createClosure: (() async throws -> Void)?

    func create() async throws {
        if let error = createThrowableError {
            throw error
        }
        createCallsCount += 1
        try await createClosure!()
    }

    // MARK: - latestHeight

    var latestHeightThrowableError: Error?
    var latestHeightCallsCount = 0
    var latestHeightCalled: Bool {
        return latestHeightCallsCount > 0
    }
    var latestHeightReturnValue: BlockHeight!
    var latestHeightClosure: (() async throws -> BlockHeight)?

    func latestHeight() async throws -> BlockHeight {
        if let error = latestHeightThrowableError {
            throw error
        }
        latestHeightCallsCount += 1
        if let closure = latestHeightClosure {
            return try await closure()
        } else {
            return latestHeightReturnValue
        }
    }

    // MARK: - write

    var writeBlocksThrowableError: Error?
    var writeBlocksCallsCount = 0
    var writeBlocksCalled: Bool {
        return writeBlocksCallsCount > 0
    }
    var writeBlocksReceivedBlocks: [ZcashCompactBlock]?
    var writeBlocksClosure: (([ZcashCompactBlock]) async throws -> Void)?

    func write(blocks: [ZcashCompactBlock]) async throws {
        if let error = writeBlocksThrowableError {
            throw error
        }
        writeBlocksCallsCount += 1
        writeBlocksReceivedBlocks = blocks
        try await writeBlocksClosure!(blocks)
    }

    // MARK: - rewind

    var rewindToThrowableError: Error?
    var rewindToCallsCount = 0
    var rewindToCalled: Bool {
        return rewindToCallsCount > 0
    }
    var rewindToReceivedHeight: BlockHeight?
    var rewindToClosure: ((BlockHeight) async throws -> Void)?

    func rewind(to height: BlockHeight) async throws {
        if let error = rewindToThrowableError {
            throw error
        }
        rewindToCallsCount += 1
        rewindToReceivedHeight = height
        try await rewindToClosure!(height)
    }

    // MARK: - clear

    var clearUpToThrowableError: Error?
    var clearUpToCallsCount = 0
    var clearUpToCalled: Bool {
        return clearUpToCallsCount > 0
    }
    var clearUpToReceivedHeight: BlockHeight?
    var clearUpToClosure: ((BlockHeight) async throws -> Void)?

    func clear(upTo height: BlockHeight) async throws {
        if let error = clearUpToThrowableError {
            throw error
        }
        clearUpToCallsCount += 1
        clearUpToReceivedHeight = height
        try await clearUpToClosure!(height)
    }

    // MARK: - clear

    var clearThrowableError: Error?
    var clearCallsCount = 0
    var clearCalled: Bool {
        return clearCallsCount > 0
    }
    var clearClosure: (() async throws -> Void)?

    func clear() async throws {
        if let error = clearThrowableError {
            throw error
        }
        clearCallsCount += 1
        try await clearClosure!()
    }

}
class LatestBlocksDataProviderMock: LatestBlocksDataProvider {


    init(
    ) {
    }
    var fullyScannedHeight: BlockHeight {
        get { return underlyingFullyScannedHeight }
    }
    var underlyingFullyScannedHeight: BlockHeight!
    var maxScannedHeight: BlockHeight {
        get { return underlyingMaxScannedHeight }
    }
    var underlyingMaxScannedHeight: BlockHeight!
    var latestBlockHeight: BlockHeight {
        get { return underlyingLatestBlockHeight }
    }
    var underlyingLatestBlockHeight: BlockHeight!
    var walletBirthday: BlockHeight {
        get { return underlyingWalletBirthday }
    }
    var underlyingWalletBirthday: BlockHeight!

    // MARK: - reset

    var resetCallsCount = 0
    var resetCalled: Bool {
        return resetCallsCount > 0
    }
    var resetClosure: (() async -> Void)?

    func reset() async {
        resetCallsCount += 1
        await resetClosure!()
    }

    // MARK: - updateScannedData

    var updateScannedDataCallsCount = 0
    var updateScannedDataCalled: Bool {
        return updateScannedDataCallsCount > 0
    }
    var updateScannedDataClosure: (() async -> Void)?

    func updateScannedData() async {
        updateScannedDataCallsCount += 1
        await updateScannedDataClosure!()
    }

    // MARK: - updateBlockData

    var updateBlockDataCallsCount = 0
    var updateBlockDataCalled: Bool {
        return updateBlockDataCallsCount > 0
    }
    var updateBlockDataClosure: (() async -> Void)?

    func updateBlockData() async {
        updateBlockDataCallsCount += 1
        await updateBlockDataClosure!()
    }

    // MARK: - updateWalletBirthday

    var updateWalletBirthdayCallsCount = 0
    var updateWalletBirthdayCalled: Bool {
        return updateWalletBirthdayCallsCount > 0
    }
    var updateWalletBirthdayReceivedWalletBirthday: BlockHeight?
    var updateWalletBirthdayClosure: ((BlockHeight) async -> Void)?

    func updateWalletBirthday(_ walletBirthday: BlockHeight) async {
        updateWalletBirthdayCallsCount += 1
        updateWalletBirthdayReceivedWalletBirthday = walletBirthday
        await updateWalletBirthdayClosure!(walletBirthday)
    }

    // MARK: - update

    var updateCallsCount = 0
    var updateCalled: Bool {
        return updateCallsCount > 0
    }
    var updateReceivedLatestBlockHeight: BlockHeight?
    var updateClosure: ((BlockHeight) async -> Void)?

    func update(_ latestBlockHeight: BlockHeight) async {
        updateCallsCount += 1
        updateReceivedLatestBlockHeight = latestBlockHeight
        await updateClosure!(latestBlockHeight)
    }

}
class LightWalletServiceMock: LightWalletService {


    init(
    ) {
    }
    var connectionStateChange: ((_ from: ConnectionState, _ to: ConnectionState) -> Void)?

    // MARK: - getInfo

    var getInfoThrowableError: Error?
    var getInfoCallsCount = 0
    var getInfoCalled: Bool {
        return getInfoCallsCount > 0
    }
    var getInfoReturnValue: LightWalletdInfo!
    var getInfoClosure: (() async throws -> LightWalletdInfo)?

    func getInfo() async throws -> LightWalletdInfo {
        if let error = getInfoThrowableError {
            throw error
        }
        getInfoCallsCount += 1
        if let closure = getInfoClosure {
            return try await closure()
        } else {
            return getInfoReturnValue
        }
    }

    // MARK: - latestBlock

    var latestBlockThrowableError: Error?
    var latestBlockCallsCount = 0
    var latestBlockCalled: Bool {
        return latestBlockCallsCount > 0
    }
    var latestBlockReturnValue: BlockID!
    var latestBlockClosure: (() async throws -> BlockID)?

    func latestBlock() async throws -> BlockID {
        if let error = latestBlockThrowableError {
            throw error
        }
        latestBlockCallsCount += 1
        if let closure = latestBlockClosure {
            return try await closure()
        } else {
            return latestBlockReturnValue
        }
    }

    // MARK: - latestBlockHeight

    var latestBlockHeightThrowableError: Error?
    var latestBlockHeightCallsCount = 0
    var latestBlockHeightCalled: Bool {
        return latestBlockHeightCallsCount > 0
    }
    var latestBlockHeightReturnValue: BlockHeight!
    var latestBlockHeightClosure: (() async throws -> BlockHeight)?

    func latestBlockHeight() async throws -> BlockHeight {
        if let error = latestBlockHeightThrowableError {
            throw error
        }
        latestBlockHeightCallsCount += 1
        if let closure = latestBlockHeightClosure {
            return try await closure()
        } else {
            return latestBlockHeightReturnValue
        }
    }

    // MARK: - blockRange

    var blockRangeCallsCount = 0
    var blockRangeCalled: Bool {
        return blockRangeCallsCount > 0
    }
    var blockRangeReceivedRange: CompactBlockRange?
    var blockRangeReturnValue: AsyncThrowingStream<ZcashCompactBlock, Error>!
    var blockRangeClosure: ((CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error>)?

    func blockRange(_ range: CompactBlockRange) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        blockRangeCallsCount += 1
        blockRangeReceivedRange = range
        if let closure = blockRangeClosure {
            return closure(range)
        } else {
            return blockRangeReturnValue
        }
    }

    // MARK: - submit

    var submitSpendTransactionThrowableError: Error?
    var submitSpendTransactionCallsCount = 0
    var submitSpendTransactionCalled: Bool {
        return submitSpendTransactionCallsCount > 0
    }
    var submitSpendTransactionReceivedSpendTransaction: Data?
    var submitSpendTransactionReturnValue: LightWalletServiceResponse!
    var submitSpendTransactionClosure: ((Data) async throws -> LightWalletServiceResponse)?

    func submit(spendTransaction: Data) async throws -> LightWalletServiceResponse {
        if let error = submitSpendTransactionThrowableError {
            throw error
        }
        submitSpendTransactionCallsCount += 1
        submitSpendTransactionReceivedSpendTransaction = spendTransaction
        if let closure = submitSpendTransactionClosure {
            return try await closure(spendTransaction)
        } else {
            return submitSpendTransactionReturnValue
        }
    }

    // MARK: - fetchTransaction

    var fetchTransactionTxIdThrowableError: Error?
    var fetchTransactionTxIdCallsCount = 0
    var fetchTransactionTxIdCalled: Bool {
        return fetchTransactionTxIdCallsCount > 0
    }
    var fetchTransactionTxIdReceivedTxId: Data?
    var fetchTransactionTxIdReturnValue: (tx: ZcashTransaction.Fetched?, status: TransactionStatus)!
    var fetchTransactionTxIdClosure: ((Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus))?

    func fetchTransaction(txId: Data) async throws -> (tx: ZcashTransaction.Fetched?, status: TransactionStatus) {
        if let error = fetchTransactionTxIdThrowableError {
            throw error
        }
        fetchTransactionTxIdCallsCount += 1
        fetchTransactionTxIdReceivedTxId = txId
        if let closure = fetchTransactionTxIdClosure {
            return try await closure(txId)
        } else {
            return fetchTransactionTxIdReturnValue
        }
    }

    // MARK: - fetchUTXOs

    var fetchUTXOsSingleCallsCount = 0
    var fetchUTXOsSingleCalled: Bool {
        return fetchUTXOsSingleCallsCount > 0
    }
    var fetchUTXOsSingleReceivedArguments: (tAddress: String, height: BlockHeight)?
    var fetchUTXOsSingleReturnValue: AsyncThrowingStream<UnspentTransactionOutputEntity, Error>!
    var fetchUTXOsSingleClosure: ((String, BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error>)?

    func fetchUTXOs(for tAddress: String, height: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        fetchUTXOsSingleCallsCount += 1
        fetchUTXOsSingleReceivedArguments = (tAddress: tAddress, height: height)
        if let closure = fetchUTXOsSingleClosure {
            return closure(tAddress, height)
        } else {
            return fetchUTXOsSingleReturnValue
        }
    }

    // MARK: - fetchUTXOs

    var fetchUTXOsForHeightCallsCount = 0
    var fetchUTXOsForHeightCalled: Bool {
        return fetchUTXOsForHeightCallsCount > 0
    }
    var fetchUTXOsForHeightReceivedArguments: (tAddresses: [String], height: BlockHeight)?
    var fetchUTXOsForHeightReturnValue: AsyncThrowingStream<UnspentTransactionOutputEntity, Error>!
    var fetchUTXOsForHeightClosure: (([String], BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error>)?

    func fetchUTXOs(for tAddresses: [String], height: BlockHeight) -> AsyncThrowingStream<UnspentTransactionOutputEntity, Error> {
        fetchUTXOsForHeightCallsCount += 1
        fetchUTXOsForHeightReceivedArguments = (tAddresses: tAddresses, height: height)
        if let closure = fetchUTXOsForHeightClosure {
            return closure(tAddresses, height)
        } else {
            return fetchUTXOsForHeightReturnValue
        }
    }

    // MARK: - blockStream

    var blockStreamStartHeightEndHeightCallsCount = 0
    var blockStreamStartHeightEndHeightCalled: Bool {
        return blockStreamStartHeightEndHeightCallsCount > 0
    }
    var blockStreamStartHeightEndHeightReceivedArguments: (startHeight: BlockHeight, endHeight: BlockHeight)?
    var blockStreamStartHeightEndHeightReturnValue: AsyncThrowingStream<ZcashCompactBlock, Error>!
    var blockStreamStartHeightEndHeightClosure: ((BlockHeight, BlockHeight) -> AsyncThrowingStream<ZcashCompactBlock, Error>)?

    func blockStream(startHeight: BlockHeight, endHeight: BlockHeight) -> AsyncThrowingStream<ZcashCompactBlock, Error> {
        blockStreamStartHeightEndHeightCallsCount += 1
        blockStreamStartHeightEndHeightReceivedArguments = (startHeight: startHeight, endHeight: endHeight)
        if let closure = blockStreamStartHeightEndHeightClosure {
            return closure(startHeight, endHeight)
        } else {
            return blockStreamStartHeightEndHeightReturnValue
        }
    }

    // MARK: - closeConnection

    var closeConnectionCallsCount = 0
    var closeConnectionCalled: Bool {
        return closeConnectionCallsCount > 0
    }
    var closeConnectionClosure: (() -> Void)?

    func closeConnection() {
        closeConnectionCallsCount += 1
        closeConnectionClosure!()
    }

    // MARK: - getSubtreeRoots

    var getSubtreeRootsCallsCount = 0
    var getSubtreeRootsCalled: Bool {
        return getSubtreeRootsCallsCount > 0
    }
    var getSubtreeRootsReceivedRequest: GetSubtreeRootsArg?
    var getSubtreeRootsReturnValue: AsyncThrowingStream<SubtreeRoot, Error>!
    var getSubtreeRootsClosure: ((GetSubtreeRootsArg) -> AsyncThrowingStream<SubtreeRoot, Error>)?

    func getSubtreeRoots(_ request: GetSubtreeRootsArg) -> AsyncThrowingStream<SubtreeRoot, Error> {
        getSubtreeRootsCallsCount += 1
        getSubtreeRootsReceivedRequest = request
        if let closure = getSubtreeRootsClosure {
            return closure(request)
        } else {
            return getSubtreeRootsReturnValue
        }
    }

    // MARK: - getTreeState

    var getTreeStateThrowableError: Error?
    var getTreeStateCallsCount = 0
    var getTreeStateCalled: Bool {
        return getTreeStateCallsCount > 0
    }
    var getTreeStateReceivedId: BlockID?
    var getTreeStateReturnValue: TreeState!
    var getTreeStateClosure: ((BlockID) async throws -> TreeState)?

    func getTreeState(_ id: BlockID) async throws -> TreeState {
        if let error = getTreeStateThrowableError {
            throw error
        }
        getTreeStateCallsCount += 1
        getTreeStateReceivedId = id
        if let closure = getTreeStateClosure {
            return try await closure(id)
        } else {
            return getTreeStateReturnValue
        }
    }

    // MARK: - getTaddressTxids

    var getTaddressTxidsCallsCount = 0
    var getTaddressTxidsCalled: Bool {
        return getTaddressTxidsCallsCount > 0
    }
    var getTaddressTxidsReceivedRequest: TransparentAddressBlockFilter?
    var getTaddressTxidsReturnValue: AsyncThrowingStream<RawTransaction, Error>!
    var getTaddressTxidsClosure: ((TransparentAddressBlockFilter) -> AsyncThrowingStream<RawTransaction, Error>)?

    func getTaddressTxids(_ request: TransparentAddressBlockFilter) -> AsyncThrowingStream<RawTransaction, Error> {
        getTaddressTxidsCallsCount += 1
        getTaddressTxidsReceivedRequest = request
        if let closure = getTaddressTxidsClosure {
            return closure(request)
        } else {
            return getTaddressTxidsReturnValue
        }
    }

}
class LightWalletdInfoMock: LightWalletdInfo {


    init(
    ) {
    }
    var version: String {
        get { return underlyingVersion }
    }
    var underlyingVersion: String!
    var vendor: String {
        get { return underlyingVendor }
    }
    var underlyingVendor: String!
    var taddrSupport: Bool {
        get { return underlyingTaddrSupport }
    }
    var underlyingTaddrSupport: Bool!
    var chainName: String {
        get { return underlyingChainName }
    }
    var underlyingChainName: String!
    var saplingActivationHeight: UInt64 {
        get { return underlyingSaplingActivationHeight }
    }
    var underlyingSaplingActivationHeight: UInt64!
    var consensusBranchID: String {
        get { return underlyingConsensusBranchID }
    }
    var underlyingConsensusBranchID: String!
    var blockHeight: UInt64 {
        get { return underlyingBlockHeight }
    }
    var underlyingBlockHeight: UInt64!
    var gitCommit: String {
        get { return underlyingGitCommit }
    }
    var underlyingGitCommit: String!
    var branch: String {
        get { return underlyingBranch }
    }
    var underlyingBranch: String!
    var buildDate: String {
        get { return underlyingBuildDate }
    }
    var underlyingBuildDate: String!
    var buildUser: String {
        get { return underlyingBuildUser }
    }
    var underlyingBuildUser: String!
    var estimatedHeight: UInt64 {
        get { return underlyingEstimatedHeight }
    }
    var underlyingEstimatedHeight: UInt64!
    var zcashdBuild: String {
        get { return underlyingZcashdBuild }
    }
    var underlyingZcashdBuild: String!
    var zcashdSubversion: String {
        get { return underlyingZcashdSubversion }
    }
    var underlyingZcashdSubversion: String!

}
class LoggerMock: Logger {


    init(
    ) {
    }

    // MARK: - maxLogLevel

    var maxLogLevelCallsCount = 0
    var maxLogLevelCalled: Bool {
        return maxLogLevelCallsCount > 0
    }
    var maxLogLevelReturnValue: OSLogger.LogLevel?
    var maxLogLevelClosure: (() -> OSLogger.LogLevel?)?

    func maxLogLevel() -> OSLogger.LogLevel? {
        maxLogLevelCallsCount += 1
        if let closure = maxLogLevelClosure {
            return closure()
        } else {
            return maxLogLevelReturnValue
        }
    }

    // MARK: - debug

    var debugFileFunctionLineCallsCount = 0
    var debugFileFunctionLineCalled: Bool {
        return debugFileFunctionLineCallsCount > 0
    }
    var debugFileFunctionLineReceivedArguments: (message: String, file: StaticString, function: StaticString, line: Int)?
    var debugFileFunctionLineClosure: ((String, StaticString, StaticString, Int) -> Void)?

    func debug(_ message: String, file: StaticString, function: StaticString, line: Int) {
        debugFileFunctionLineCallsCount += 1
        debugFileFunctionLineReceivedArguments = (message: message, file: file, function: function, line: line)
        debugFileFunctionLineClosure!(message, file, function, line)
    }

    // MARK: - info

    var infoFileFunctionLineCallsCount = 0
    var infoFileFunctionLineCalled: Bool {
        return infoFileFunctionLineCallsCount > 0
    }
    var infoFileFunctionLineReceivedArguments: (message: String, file: StaticString, function: StaticString, line: Int)?
    var infoFileFunctionLineClosure: ((String, StaticString, StaticString, Int) -> Void)?

    func info(_ message: String, file: StaticString, function: StaticString, line: Int) {
        infoFileFunctionLineCallsCount += 1
        infoFileFunctionLineReceivedArguments = (message: message, file: file, function: function, line: line)
        infoFileFunctionLineClosure!(message, file, function, line)
    }

    // MARK: - event

    var eventFileFunctionLineCallsCount = 0
    var eventFileFunctionLineCalled: Bool {
        return eventFileFunctionLineCallsCount > 0
    }
    var eventFileFunctionLineReceivedArguments: (message: String, file: StaticString, function: StaticString, line: Int)?
    var eventFileFunctionLineClosure: ((String, StaticString, StaticString, Int) -> Void)?

    func event(_ message: String, file: StaticString, function: StaticString, line: Int) {
        eventFileFunctionLineCallsCount += 1
        eventFileFunctionLineReceivedArguments = (message: message, file: file, function: function, line: line)
        eventFileFunctionLineClosure!(message, file, function, line)
    }

    // MARK: - warn

    var warnFileFunctionLineCallsCount = 0
    var warnFileFunctionLineCalled: Bool {
        return warnFileFunctionLineCallsCount > 0
    }
    var warnFileFunctionLineReceivedArguments: (message: String, file: StaticString, function: StaticString, line: Int)?
    var warnFileFunctionLineClosure: ((String, StaticString, StaticString, Int) -> Void)?

    func warn(_ message: String, file: StaticString, function: StaticString, line: Int) {
        warnFileFunctionLineCallsCount += 1
        warnFileFunctionLineReceivedArguments = (message: message, file: file, function: function, line: line)
        warnFileFunctionLineClosure!(message, file, function, line)
    }

    // MARK: - error

    var errorFileFunctionLineCallsCount = 0
    var errorFileFunctionLineCalled: Bool {
        return errorFileFunctionLineCallsCount > 0
    }
    var errorFileFunctionLineReceivedArguments: (message: String, file: StaticString, function: StaticString, line: Int)?
    var errorFileFunctionLineClosure: ((String, StaticString, StaticString, Int) -> Void)?

    func error(_ message: String, file: StaticString, function: StaticString, line: Int) {
        errorFileFunctionLineCallsCount += 1
        errorFileFunctionLineReceivedArguments = (message: message, file: file, function: function, line: line)
        errorFileFunctionLineClosure!(message, file, function, line)
    }

    // MARK: - sync

    var syncFileFunctionLineCallsCount = 0
    var syncFileFunctionLineCalled: Bool {
        return syncFileFunctionLineCallsCount > 0
    }
    var syncFileFunctionLineReceivedArguments: (message: String, file: StaticString, function: StaticString, line: Int)?
    var syncFileFunctionLineClosure: ((String, StaticString, StaticString, Int) -> Void)?

    func sync(_ message: String, file: StaticString, function: StaticString, line: Int) {
        syncFileFunctionLineCallsCount += 1
        syncFileFunctionLineReceivedArguments = (message: message, file: file, function: function, line: line)
        syncFileFunctionLineClosure!(message, file, function, line)
    }

}
class SDKMetricsMock: SDKMetrics {


    init(
    ) {
    }

    // MARK: - cbpStart

    var cbpStartCallsCount = 0
    var cbpStartCalled: Bool {
        return cbpStartCallsCount > 0
    }
    var cbpStartClosure: (() -> Void)?

    func cbpStart() {
        cbpStartCallsCount += 1
        cbpStartClosure!()
    }

    // MARK: - actionStart

    var actionStartCallsCount = 0
    var actionStartCalled: Bool {
        return actionStartCallsCount > 0
    }
    var actionStartReceivedAction: CBPState?
    var actionStartClosure: ((CBPState) -> Void)?

    func actionStart(_ action: CBPState) {
        actionStartCallsCount += 1
        actionStartReceivedAction = action
        actionStartClosure!(action)
    }

    // MARK: - actionDetail

    var actionDetailForCallsCount = 0
    var actionDetailForCalled: Bool {
        return actionDetailForCallsCount > 0
    }
    var actionDetailForReceivedArguments: (detail: String, action: CBPState)?
    var actionDetailForClosure: ((String, CBPState) -> Void)?

    func actionDetail(_ detail: String, `for` action: CBPState) {
        actionDetailForCallsCount += 1
        actionDetailForReceivedArguments = (detail: detail, action: action)
        actionDetailForClosure!(detail, action)
    }

    // MARK: - actionStop

    var actionStopCallsCount = 0
    var actionStopCalled: Bool {
        return actionStopCallsCount > 0
    }
    var actionStopClosure: (() -> Void)?

    func actionStop() {
        actionStopCallsCount += 1
        actionStopClosure!()
    }

    // MARK: - logCBPOverviewReport

    var logCBPOverviewReportWalletSummaryCallsCount = 0
    var logCBPOverviewReportWalletSummaryCalled: Bool {
        return logCBPOverviewReportWalletSummaryCallsCount > 0
    }
    var logCBPOverviewReportWalletSummaryReceivedArguments: (logger: Logger, walletSummary: WalletSummary?)?
    var logCBPOverviewReportWalletSummaryClosure: ((Logger, WalletSummary?) async -> Void)?

    func logCBPOverviewReport(_ logger: Logger, walletSummary: WalletSummary?) async {
        logCBPOverviewReportWalletSummaryCallsCount += 1
        logCBPOverviewReportWalletSummaryReceivedArguments = (logger: logger, walletSummary: walletSummary)
        await logCBPOverviewReportWalletSummaryClosure!(logger, walletSummary)
    }

}
class SaplingParametersHandlerMock: SaplingParametersHandler {


    init(
    ) {
    }

    // MARK: - handleIfNeeded

    var handleIfNeededAccountIndexThrowableError: Error?
    var handleIfNeededAccountIndexCallsCount = 0
    var handleIfNeededAccountIndexCalled: Bool {
        return handleIfNeededAccountIndexCallsCount > 0
    }
    var handleIfNeededAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var handleIfNeededAccountIndexClosure: ((Zip32AccountIndex) async throws -> Void)?

    func handleIfNeeded(accountIndex: Zip32AccountIndex) async throws {
        if let error = handleIfNeededAccountIndexThrowableError {
            throw error
        }
        handleIfNeededAccountIndexCallsCount += 1
        handleIfNeededAccountIndexReceivedAccountIndex = accountIndex
        try await handleIfNeededAccountIndexClosure!(accountIndex)
    }

}
class SynchronizerMock: Synchronizer {


    init(
    ) {
    }
    var alias: ZcashSynchronizerAlias {
        get { return underlyingAlias }
    }
    var underlyingAlias: ZcashSynchronizerAlias!
    var latestState: SynchronizerState {
        get { return underlyingLatestState }
    }
    var underlyingLatestState: SynchronizerState!
    var connectionState: ConnectionState {
        get { return underlyingConnectionState }
    }
    var underlyingConnectionState: ConnectionState!
    var stateStream: AnyPublisher<SynchronizerState, Never> {
        get { return underlyingStateStream }
    }
    var underlyingStateStream: AnyPublisher<SynchronizerState, Never>!
    var eventStream: AnyPublisher<SynchronizerEvent, Never> {
        get { return underlyingEventStream }
    }
    var underlyingEventStream: AnyPublisher<SynchronizerEvent, Never>!
    var exchangeRateUSDStream: AnyPublisher<FiatCurrencyResult?, Never> {
        get { return underlyingExchangeRateUSDStream }
    }
    var underlyingExchangeRateUSDStream: AnyPublisher<FiatCurrencyResult?, Never>!
    var transactions: [ZcashTransaction.Overview] {
        get async { return underlyingTransactions }
    }
    var underlyingTransactions: [ZcashTransaction.Overview] = []
    var sentTransactions: [ZcashTransaction.Overview] {
        get async { return underlyingSentTransactions }
    }
    var underlyingSentTransactions: [ZcashTransaction.Overview] = []
    var receivedTransactions: [ZcashTransaction.Overview] {
        get async { return underlyingReceivedTransactions }
    }
    var underlyingReceivedTransactions: [ZcashTransaction.Overview] = []

    // MARK: - prepare

    var prepareWithWalletBirthdayForThrowableError: Error?
    var prepareWithWalletBirthdayForCallsCount = 0
    var prepareWithWalletBirthdayForCalled: Bool {
        return prepareWithWalletBirthdayForCallsCount > 0
    }
    var prepareWithWalletBirthdayForReceivedArguments: (seed: [UInt8]?, walletBirthday: BlockHeight, walletMode: WalletInitMode)?
    var prepareWithWalletBirthdayForReturnValue: Initializer.InitializationResult!
    var prepareWithWalletBirthdayForClosure: (([UInt8]?, BlockHeight, WalletInitMode) async throws -> Initializer.InitializationResult)?

    func prepare(with seed: [UInt8]?, walletBirthday: BlockHeight, for walletMode: WalletInitMode) async throws -> Initializer.InitializationResult {
        if let error = prepareWithWalletBirthdayForThrowableError {
            throw error
        }
        prepareWithWalletBirthdayForCallsCount += 1
        prepareWithWalletBirthdayForReceivedArguments = (seed: seed, walletBirthday: walletBirthday, walletMode: walletMode)
        if let closure = prepareWithWalletBirthdayForClosure {
            return try await closure(seed, walletBirthday, walletMode)
        } else {
            return prepareWithWalletBirthdayForReturnValue
        }
    }

    // MARK: - start

    var startRetryThrowableError: Error?
    var startRetryCallsCount = 0
    var startRetryCalled: Bool {
        return startRetryCallsCount > 0
    }
    var startRetryReceivedRetry: Bool?
    var startRetryClosure: ((Bool) async throws -> Void)?

    func start(retry: Bool) async throws {
        if let error = startRetryThrowableError {
            throw error
        }
        startRetryCallsCount += 1
        startRetryReceivedRetry = retry
        try await startRetryClosure!(retry)
    }

    // MARK: - stop

    var stopCallsCount = 0
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCount += 1
        stopClosure!()
    }

    // MARK: - getSaplingAddress

    var getSaplingAddressAccountIndexThrowableError: Error?
    var getSaplingAddressAccountIndexCallsCount = 0
    var getSaplingAddressAccountIndexCalled: Bool {
        return getSaplingAddressAccountIndexCallsCount > 0
    }
    var getSaplingAddressAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getSaplingAddressAccountIndexReturnValue: SaplingAddress!
    var getSaplingAddressAccountIndexClosure: ((Zip32AccountIndex) async throws -> SaplingAddress)?

    func getSaplingAddress(accountIndex: Zip32AccountIndex) async throws -> SaplingAddress {
        if let error = getSaplingAddressAccountIndexThrowableError {
            throw error
        }
        getSaplingAddressAccountIndexCallsCount += 1
        getSaplingAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getSaplingAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getSaplingAddressAccountIndexReturnValue
        }
    }

    // MARK: - getUnifiedAddress

    var getUnifiedAddressAccountIndexThrowableError: Error?
    var getUnifiedAddressAccountIndexCallsCount = 0
    var getUnifiedAddressAccountIndexCalled: Bool {
        return getUnifiedAddressAccountIndexCallsCount > 0
    }
    var getUnifiedAddressAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getUnifiedAddressAccountIndexReturnValue: UnifiedAddress!
    var getUnifiedAddressAccountIndexClosure: ((Zip32AccountIndex) async throws -> UnifiedAddress)?

    func getUnifiedAddress(accountIndex: Zip32AccountIndex) async throws -> UnifiedAddress {
        if let error = getUnifiedAddressAccountIndexThrowableError {
            throw error
        }
        getUnifiedAddressAccountIndexCallsCount += 1
        getUnifiedAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getUnifiedAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getUnifiedAddressAccountIndexReturnValue
        }
    }

    // MARK: - getTransparentAddress

    var getTransparentAddressAccountIndexThrowableError: Error?
    var getTransparentAddressAccountIndexCallsCount = 0
    var getTransparentAddressAccountIndexCalled: Bool {
        return getTransparentAddressAccountIndexCallsCount > 0
    }
    var getTransparentAddressAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getTransparentAddressAccountIndexReturnValue: TransparentAddress!
    var getTransparentAddressAccountIndexClosure: ((Zip32AccountIndex) async throws -> TransparentAddress)?

    func getTransparentAddress(accountIndex: Zip32AccountIndex) async throws -> TransparentAddress {
        if let error = getTransparentAddressAccountIndexThrowableError {
            throw error
        }
        getTransparentAddressAccountIndexCallsCount += 1
        getTransparentAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getTransparentAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getTransparentAddressAccountIndexReturnValue
        }
    }

    // MARK: - proposeTransfer

    var proposeTransferAccountIndexRecipientAmountMemoThrowableError: Error?
    var proposeTransferAccountIndexRecipientAmountMemoCallsCount = 0
    var proposeTransferAccountIndexRecipientAmountMemoCalled: Bool {
        return proposeTransferAccountIndexRecipientAmountMemoCallsCount > 0
    }
    var proposeTransferAccountIndexRecipientAmountMemoReceivedArguments: (accountIndex: Zip32AccountIndex, recipient: Recipient, amount: Zatoshi, memo: Memo?)?
    var proposeTransferAccountIndexRecipientAmountMemoReturnValue: Proposal!
    var proposeTransferAccountIndexRecipientAmountMemoClosure: ((Zip32AccountIndex, Recipient, Zatoshi, Memo?) async throws -> Proposal)?

    func proposeTransfer(accountIndex: Zip32AccountIndex, recipient: Recipient, amount: Zatoshi, memo: Memo?) async throws -> Proposal {
        if let error = proposeTransferAccountIndexRecipientAmountMemoThrowableError {
            throw error
        }
        proposeTransferAccountIndexRecipientAmountMemoCallsCount += 1
        proposeTransferAccountIndexRecipientAmountMemoReceivedArguments = (accountIndex: accountIndex, recipient: recipient, amount: amount, memo: memo)
        if let closure = proposeTransferAccountIndexRecipientAmountMemoClosure {
            return try await closure(accountIndex, recipient, amount, memo)
        } else {
            return proposeTransferAccountIndexRecipientAmountMemoReturnValue
        }
    }

    // MARK: - proposeShielding

    var proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverThrowableError: Error?
    var proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverCallsCount = 0
    var proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverCalled: Bool {
        return proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverCallsCount > 0
    }
    var proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverReceivedArguments: (accountIndex: Zip32AccountIndex, shieldingThreshold: Zatoshi, memo: Memo, transparentReceiver: TransparentAddress?)?
    var proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverReturnValue: Proposal?
    var proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverClosure: ((Zip32AccountIndex, Zatoshi, Memo, TransparentAddress?) async throws -> Proposal?)?

    func proposeShielding(accountIndex: Zip32AccountIndex, shieldingThreshold: Zatoshi, memo: Memo, transparentReceiver: TransparentAddress?) async throws -> Proposal? {
        if let error = proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverThrowableError {
            throw error
        }
        proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverCallsCount += 1
        proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverReceivedArguments = (accountIndex: accountIndex, shieldingThreshold: shieldingThreshold, memo: memo, transparentReceiver: transparentReceiver)
        if let closure = proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverClosure {
            return try await closure(accountIndex, shieldingThreshold, memo, transparentReceiver)
        } else {
            return proposeShieldingAccountIndexShieldingThresholdMemoTransparentReceiverReturnValue
        }
    }

    // MARK: - createProposedTransactions

    var createProposedTransactionsProposalSpendingKeyThrowableError: Error?
    var createProposedTransactionsProposalSpendingKeyCallsCount = 0
    var createProposedTransactionsProposalSpendingKeyCalled: Bool {
        return createProposedTransactionsProposalSpendingKeyCallsCount > 0
    }
    var createProposedTransactionsProposalSpendingKeyReceivedArguments: (proposal: Proposal, spendingKey: UnifiedSpendingKey)?
    var createProposedTransactionsProposalSpendingKeyReturnValue: AsyncThrowingStream<TransactionSubmitResult, Error>!
    var createProposedTransactionsProposalSpendingKeyClosure: ((Proposal, UnifiedSpendingKey) async throws -> AsyncThrowingStream<TransactionSubmitResult, Error>)?

    func createProposedTransactions(proposal: Proposal, spendingKey: UnifiedSpendingKey) async throws -> AsyncThrowingStream<TransactionSubmitResult, Error> {
        if let error = createProposedTransactionsProposalSpendingKeyThrowableError {
            throw error
        }
        createProposedTransactionsProposalSpendingKeyCallsCount += 1
        createProposedTransactionsProposalSpendingKeyReceivedArguments = (proposal: proposal, spendingKey: spendingKey)
        if let closure = createProposedTransactionsProposalSpendingKeyClosure {
            return try await closure(proposal, spendingKey)
        } else {
            return createProposedTransactionsProposalSpendingKeyReturnValue
        }
    }

    // MARK: - sendToAddress

    var sendToAddressSpendingKeyZatoshiToAddressMemoThrowableError: Error?
    var sendToAddressSpendingKeyZatoshiToAddressMemoCallsCount = 0
    var sendToAddressSpendingKeyZatoshiToAddressMemoCalled: Bool {
        return sendToAddressSpendingKeyZatoshiToAddressMemoCallsCount > 0
    }
    var sendToAddressSpendingKeyZatoshiToAddressMemoReceivedArguments: (spendingKey: UnifiedSpendingKey, zatoshi: Zatoshi, toAddress: Recipient, memo: Memo?)?
    var sendToAddressSpendingKeyZatoshiToAddressMemoReturnValue: ZcashTransaction.Overview!
    var sendToAddressSpendingKeyZatoshiToAddressMemoClosure: ((UnifiedSpendingKey, Zatoshi, Recipient, Memo?) async throws -> ZcashTransaction.Overview)?

    func sendToAddress(spendingKey: UnifiedSpendingKey, zatoshi: Zatoshi, toAddress: Recipient, memo: Memo?) async throws -> ZcashTransaction.Overview {
        if let error = sendToAddressSpendingKeyZatoshiToAddressMemoThrowableError {
            throw error
        }
        sendToAddressSpendingKeyZatoshiToAddressMemoCallsCount += 1
        sendToAddressSpendingKeyZatoshiToAddressMemoReceivedArguments = (spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo)
        if let closure = sendToAddressSpendingKeyZatoshiToAddressMemoClosure {
            return try await closure(spendingKey, zatoshi, toAddress, memo)
        } else {
            return sendToAddressSpendingKeyZatoshiToAddressMemoReturnValue
        }
    }

    // MARK: - proposefulfillingPaymentURI

    var proposefulfillingPaymentURIAccountIndexThrowableError: Error?
    var proposefulfillingPaymentURIAccountIndexCallsCount = 0
    var proposefulfillingPaymentURIAccountIndexCalled: Bool {
        return proposefulfillingPaymentURIAccountIndexCallsCount > 0
    }
    var proposefulfillingPaymentURIAccountIndexReceivedArguments: (uri: String, accountIndex: Zip32AccountIndex)?
    var proposefulfillingPaymentURIAccountIndexReturnValue: Proposal!
    var proposefulfillingPaymentURIAccountIndexClosure: ((String, Zip32AccountIndex) async throws -> Proposal)?

    func proposefulfillingPaymentURI(_ uri: String, accountIndex: Zip32AccountIndex) async throws -> Proposal {
        if let error = proposefulfillingPaymentURIAccountIndexThrowableError {
            throw error
        }
        proposefulfillingPaymentURIAccountIndexCallsCount += 1
        proposefulfillingPaymentURIAccountIndexReceivedArguments = (uri: uri, accountIndex: accountIndex)
        if let closure = proposefulfillingPaymentURIAccountIndexClosure {
            return try await closure(uri, accountIndex)
        } else {
            return proposefulfillingPaymentURIAccountIndexReturnValue
        }
    }

    // MARK: - shieldFunds

    var shieldFundsSpendingKeyMemoShieldingThresholdThrowableError: Error?
    var shieldFundsSpendingKeyMemoShieldingThresholdCallsCount = 0
    var shieldFundsSpendingKeyMemoShieldingThresholdCalled: Bool {
        return shieldFundsSpendingKeyMemoShieldingThresholdCallsCount > 0
    }
    var shieldFundsSpendingKeyMemoShieldingThresholdReceivedArguments: (spendingKey: UnifiedSpendingKey, memo: Memo, shieldingThreshold: Zatoshi)?
    var shieldFundsSpendingKeyMemoShieldingThresholdReturnValue: ZcashTransaction.Overview!
    var shieldFundsSpendingKeyMemoShieldingThresholdClosure: ((UnifiedSpendingKey, Memo, Zatoshi) async throws -> ZcashTransaction.Overview)?

    func shieldFunds(spendingKey: UnifiedSpendingKey, memo: Memo, shieldingThreshold: Zatoshi) async throws -> ZcashTransaction.Overview {
        if let error = shieldFundsSpendingKeyMemoShieldingThresholdThrowableError {
            throw error
        }
        shieldFundsSpendingKeyMemoShieldingThresholdCallsCount += 1
        shieldFundsSpendingKeyMemoShieldingThresholdReceivedArguments = (spendingKey: spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
        if let closure = shieldFundsSpendingKeyMemoShieldingThresholdClosure {
            return try await closure(spendingKey, memo, shieldingThreshold)
        } else {
            return shieldFundsSpendingKeyMemoShieldingThresholdReturnValue
        }
    }

    // MARK: - paginatedTransactions

    var paginatedTransactionsOfCallsCount = 0
    var paginatedTransactionsOfCalled: Bool {
        return paginatedTransactionsOfCallsCount > 0
    }
    var paginatedTransactionsOfReceivedKind: TransactionKind?
    var paginatedTransactionsOfReturnValue: PaginatedTransactionRepository!
    var paginatedTransactionsOfClosure: ((TransactionKind) -> PaginatedTransactionRepository)?

    func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository {
        paginatedTransactionsOfCallsCount += 1
        paginatedTransactionsOfReceivedKind = kind
        if let closure = paginatedTransactionsOfClosure {
            return closure(kind)
        } else {
            return paginatedTransactionsOfReturnValue
        }
    }

    // MARK: - getMemos

    var getMemosForRawIDThrowableError: Error?
    var getMemosForRawIDCallsCount = 0
    var getMemosForRawIDCalled: Bool {
        return getMemosForRawIDCallsCount > 0
    }
    var getMemosForRawIDReceivedRawID: Data?
    var getMemosForRawIDReturnValue: [Memo]!
    var getMemosForRawIDClosure: ((Data) async throws -> [Memo])?

    func getMemos(for rawID: Data) async throws -> [Memo] {
        if let error = getMemosForRawIDThrowableError {
            throw error
        }
        getMemosForRawIDCallsCount += 1
        getMemosForRawIDReceivedRawID = rawID
        if let closure = getMemosForRawIDClosure {
            return try await closure(rawID)
        } else {
            return getMemosForRawIDReturnValue
        }
    }

    // MARK: - getMemos

    var getMemosForClearedTransactionThrowableError: Error?
    var getMemosForClearedTransactionCallsCount = 0
    var getMemosForClearedTransactionCalled: Bool {
        return getMemosForClearedTransactionCallsCount > 0
    }
    var getMemosForClearedTransactionReceivedTransaction: ZcashTransaction.Overview?
    var getMemosForClearedTransactionReturnValue: [Memo]!
    var getMemosForClearedTransactionClosure: ((ZcashTransaction.Overview) async throws -> [Memo])?

    func getMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        if let error = getMemosForClearedTransactionThrowableError {
            throw error
        }
        getMemosForClearedTransactionCallsCount += 1
        getMemosForClearedTransactionReceivedTransaction = transaction
        if let closure = getMemosForClearedTransactionClosure {
            return try await closure(transaction)
        } else {
            return getMemosForClearedTransactionReturnValue
        }
    }

    // MARK: - getRecipients

    var getRecipientsForClearedTransactionCallsCount = 0
    var getRecipientsForClearedTransactionCalled: Bool {
        return getRecipientsForClearedTransactionCallsCount > 0
    }
    var getRecipientsForClearedTransactionReceivedTransaction: ZcashTransaction.Overview?
    var getRecipientsForClearedTransactionReturnValue: [TransactionRecipient]!
    var getRecipientsForClearedTransactionClosure: ((ZcashTransaction.Overview) async -> [TransactionRecipient])?

    func getRecipients(for transaction: ZcashTransaction.Overview) async -> [TransactionRecipient] {
        getRecipientsForClearedTransactionCallsCount += 1
        getRecipientsForClearedTransactionReceivedTransaction = transaction
        if let closure = getRecipientsForClearedTransactionClosure {
            return await closure(transaction)
        } else {
            return getRecipientsForClearedTransactionReturnValue
        }
    }

    // MARK: - getTransactionOutputs

    var getTransactionOutputsForTransactionCallsCount = 0
    var getTransactionOutputsForTransactionCalled: Bool {
        return getTransactionOutputsForTransactionCallsCount > 0
    }
    var getTransactionOutputsForTransactionReceivedTransaction: ZcashTransaction.Overview?
    var getTransactionOutputsForTransactionReturnValue: [ZcashTransaction.Output]!
    var getTransactionOutputsForTransactionClosure: ((ZcashTransaction.Overview) async -> [ZcashTransaction.Output])?

    func getTransactionOutputs(for transaction: ZcashTransaction.Overview) async -> [ZcashTransaction.Output] {
        getTransactionOutputsForTransactionCallsCount += 1
        getTransactionOutputsForTransactionReceivedTransaction = transaction
        if let closure = getTransactionOutputsForTransactionClosure {
            return await closure(transaction)
        } else {
            return getTransactionOutputsForTransactionReturnValue
        }
    }

    // MARK: - allTransactions

    var allTransactionsFromLimitThrowableError: Error?
    var allTransactionsFromLimitCallsCount = 0
    var allTransactionsFromLimitCalled: Bool {
        return allTransactionsFromLimitCallsCount > 0
    }
    var allTransactionsFromLimitReceivedArguments: (transaction: ZcashTransaction.Overview, limit: Int)?
    var allTransactionsFromLimitReturnValue: [ZcashTransaction.Overview]!
    var allTransactionsFromLimitClosure: ((ZcashTransaction.Overview, Int) async throws -> [ZcashTransaction.Overview])?

    func allTransactions(from transaction: ZcashTransaction.Overview, limit: Int) async throws -> [ZcashTransaction.Overview] {
        if let error = allTransactionsFromLimitThrowableError {
            throw error
        }
        allTransactionsFromLimitCallsCount += 1
        allTransactionsFromLimitReceivedArguments = (transaction: transaction, limit: limit)
        if let closure = allTransactionsFromLimitClosure {
            return try await closure(transaction, limit)
        } else {
            return allTransactionsFromLimitReturnValue
        }
    }

    // MARK: - latestHeight

    var latestHeightThrowableError: Error?
    var latestHeightCallsCount = 0
    var latestHeightCalled: Bool {
        return latestHeightCallsCount > 0
    }
    var latestHeightReturnValue: BlockHeight!
    var latestHeightClosure: (() async throws -> BlockHeight)?

    func latestHeight() async throws -> BlockHeight {
        if let error = latestHeightThrowableError {
            throw error
        }
        latestHeightCallsCount += 1
        if let closure = latestHeightClosure {
            return try await closure()
        } else {
            return latestHeightReturnValue
        }
    }

    // MARK: - refreshUTXOs

    var refreshUTXOsAddressFromThrowableError: Error?
    var refreshUTXOsAddressFromCallsCount = 0
    var refreshUTXOsAddressFromCalled: Bool {
        return refreshUTXOsAddressFromCallsCount > 0
    }
    var refreshUTXOsAddressFromReceivedArguments: (address: TransparentAddress, height: BlockHeight)?
    var refreshUTXOsAddressFromReturnValue: RefreshedUTXOs!
    var refreshUTXOsAddressFromClosure: ((TransparentAddress, BlockHeight) async throws -> RefreshedUTXOs)?

    func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) async throws -> RefreshedUTXOs {
        if let error = refreshUTXOsAddressFromThrowableError {
            throw error
        }
        refreshUTXOsAddressFromCallsCount += 1
        refreshUTXOsAddressFromReceivedArguments = (address: address, height: height)
        if let closure = refreshUTXOsAddressFromClosure {
            return try await closure(address, height)
        } else {
            return refreshUTXOsAddressFromReturnValue
        }
    }

    // MARK: - getAccountBalance

    var getAccountBalanceAccountIndexThrowableError: Error?
    var getAccountBalanceAccountIndexCallsCount = 0
    var getAccountBalanceAccountIndexCalled: Bool {
        return getAccountBalanceAccountIndexCallsCount > 0
    }
    var getAccountBalanceAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getAccountBalanceAccountIndexReturnValue: AccountBalance?
    var getAccountBalanceAccountIndexClosure: ((Zip32AccountIndex) async throws -> AccountBalance?)?

    func getAccountBalance(accountIndex: Zip32AccountIndex) async throws -> AccountBalance? {
        if let error = getAccountBalanceAccountIndexThrowableError {
            throw error
        }
        getAccountBalanceAccountIndexCallsCount += 1
        getAccountBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getAccountBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getAccountBalanceAccountIndexReturnValue
        }
    }

    // MARK: - refreshExchangeRateUSD

    var refreshExchangeRateUSDCallsCount = 0
    var refreshExchangeRateUSDCalled: Bool {
        return refreshExchangeRateUSDCallsCount > 0
    }
    var refreshExchangeRateUSDClosure: (() -> Void)?

    func refreshExchangeRateUSD() {
        refreshExchangeRateUSDCallsCount += 1
        refreshExchangeRateUSDClosure!()
    }

    // MARK: - rewind

    var rewindCallsCount = 0
    var rewindCalled: Bool {
        return rewindCallsCount > 0
    }
    var rewindReceivedPolicy: RewindPolicy?
    var rewindReturnValue: AnyPublisher<Void, Error>!
    var rewindClosure: ((RewindPolicy) -> AnyPublisher<Void, Error>)?

    func rewind(_ policy: RewindPolicy) -> AnyPublisher<Void, Error> {
        rewindCallsCount += 1
        rewindReceivedPolicy = policy
        if let closure = rewindClosure {
            return closure(policy)
        } else {
            return rewindReturnValue
        }
    }

    // MARK: - wipe

    var wipeCallsCount = 0
    var wipeCalled: Bool {
        return wipeCallsCount > 0
    }
    var wipeReturnValue: AnyPublisher<Void, Error>!
    var wipeClosure: (() -> AnyPublisher<Void, Error>)?

    func wipe() -> AnyPublisher<Void, Error> {
        wipeCallsCount += 1
        if let closure = wipeClosure {
            return closure()
        } else {
            return wipeReturnValue
        }
    }

    // MARK: - switchTo

    var switchToEndpointThrowableError: Error?
    var switchToEndpointCallsCount = 0
    var switchToEndpointCalled: Bool {
        return switchToEndpointCallsCount > 0
    }
    var switchToEndpointReceivedEndpoint: LightWalletEndpoint?
    var switchToEndpointClosure: ((LightWalletEndpoint) async throws -> Void)?

    func switchTo(endpoint: LightWalletEndpoint) async throws {
        if let error = switchToEndpointThrowableError {
            throw error
        }
        switchToEndpointCallsCount += 1
        switchToEndpointReceivedEndpoint = endpoint
        try await switchToEndpointClosure!(endpoint)
    }

    // MARK: - isSeedRelevantToAnyDerivedAccount

    var isSeedRelevantToAnyDerivedAccountSeedThrowableError: Error?
    var isSeedRelevantToAnyDerivedAccountSeedCallsCount = 0
    var isSeedRelevantToAnyDerivedAccountSeedCalled: Bool {
        return isSeedRelevantToAnyDerivedAccountSeedCallsCount > 0
    }
    var isSeedRelevantToAnyDerivedAccountSeedReceivedSeed: [UInt8]?
    var isSeedRelevantToAnyDerivedAccountSeedReturnValue: Bool!
    var isSeedRelevantToAnyDerivedAccountSeedClosure: (([UInt8]) async throws -> Bool)?

    func isSeedRelevantToAnyDerivedAccount(seed: [UInt8]) async throws -> Bool {
        if let error = isSeedRelevantToAnyDerivedAccountSeedThrowableError {
            throw error
        }
        isSeedRelevantToAnyDerivedAccountSeedCallsCount += 1
        isSeedRelevantToAnyDerivedAccountSeedReceivedSeed = seed
        if let closure = isSeedRelevantToAnyDerivedAccountSeedClosure {
            return try await closure(seed)
        } else {
            return isSeedRelevantToAnyDerivedAccountSeedReturnValue
        }
    }

    // MARK: - evaluateBestOf

    var evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkCallsCount = 0
    var evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkCalled: Bool {
        return evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkCallsCount > 0
    }
    var evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkReceivedArguments: (endpoints: [LightWalletEndpoint], latencyThresholdMillis: Double, fetchThresholdSeconds: Double, nBlocksToFetch: UInt64, kServers: Int, network: NetworkType)?
    var evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkReturnValue: [LightWalletEndpoint]!
    var evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkClosure: (([LightWalletEndpoint], Double, Double, UInt64, Int, NetworkType) async -> [LightWalletEndpoint])?

    func evaluateBestOf(endpoints: [LightWalletEndpoint], latencyThresholdMillis: Double, fetchThresholdSeconds: Double, nBlocksToFetch: UInt64, kServers: Int, network: NetworkType) async -> [LightWalletEndpoint] {
        evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkCallsCount += 1
        evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkReceivedArguments = (endpoints: endpoints, latencyThresholdMillis: latencyThresholdMillis, fetchThresholdSeconds: fetchThresholdSeconds, nBlocksToFetch: nBlocksToFetch, kServers: kServers, network: network)
        if let closure = evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkClosure {
            return await closure(endpoints, latencyThresholdMillis, fetchThresholdSeconds, nBlocksToFetch, kServers, network)
        } else {
            return evaluateBestOfEndpointsLatencyThresholdMillisFetchThresholdSecondsNBlocksToFetchKServersNetworkReturnValue
        }
    }

}
class TransactionRepositoryMock: TransactionRepository {


    init(
    ) {
    }

    // MARK: - closeDBConnection

    var closeDBConnectionCallsCount = 0
    var closeDBConnectionCalled: Bool {
        return closeDBConnectionCallsCount > 0
    }
    var closeDBConnectionClosure: (() -> Void)?

    func closeDBConnection() {
        closeDBConnectionCallsCount += 1
        closeDBConnectionClosure!()
    }

    // MARK: - countAll

    var countAllThrowableError: Error?
    var countAllCallsCount = 0
    var countAllCalled: Bool {
        return countAllCallsCount > 0
    }
    var countAllReturnValue: Int!
    var countAllClosure: (() async throws -> Int)?

    func countAll() async throws -> Int {
        if let error = countAllThrowableError {
            throw error
        }
        countAllCallsCount += 1
        if let closure = countAllClosure {
            return try await closure()
        } else {
            return countAllReturnValue
        }
    }

    // MARK: - countUnmined

    var countUnminedThrowableError: Error?
    var countUnminedCallsCount = 0
    var countUnminedCalled: Bool {
        return countUnminedCallsCount > 0
    }
    var countUnminedReturnValue: Int!
    var countUnminedClosure: (() async throws -> Int)?

    func countUnmined() async throws -> Int {
        if let error = countUnminedThrowableError {
            throw error
        }
        countUnminedCallsCount += 1
        if let closure = countUnminedClosure {
            return try await closure()
        } else {
            return countUnminedReturnValue
        }
    }

    // MARK: - isInitialized

    var isInitializedThrowableError: Error?
    var isInitializedCallsCount = 0
    var isInitializedCalled: Bool {
        return isInitializedCallsCount > 0
    }
    var isInitializedReturnValue: Bool!
    var isInitializedClosure: (() async throws -> Bool)?

    func isInitialized() async throws -> Bool {
        if let error = isInitializedThrowableError {
            throw error
        }
        isInitializedCallsCount += 1
        if let closure = isInitializedClosure {
            return try await closure()
        } else {
            return isInitializedReturnValue
        }
    }

    // MARK: - find

    var findRawIDThrowableError: Error?
    var findRawIDCallsCount = 0
    var findRawIDCalled: Bool {
        return findRawIDCallsCount > 0
    }
    var findRawIDReceivedRawID: Data?
    var findRawIDReturnValue: ZcashTransaction.Overview!
    var findRawIDClosure: ((Data) async throws -> ZcashTransaction.Overview)?

    func find(rawID: Data) async throws -> ZcashTransaction.Overview {
        if let error = findRawIDThrowableError {
            throw error
        }
        findRawIDCallsCount += 1
        findRawIDReceivedRawID = rawID
        if let closure = findRawIDClosure {
            return try await closure(rawID)
        } else {
            return findRawIDReturnValue
        }
    }

    // MARK: - find

    var findOffsetLimitKindThrowableError: Error?
    var findOffsetLimitKindCallsCount = 0
    var findOffsetLimitKindCalled: Bool {
        return findOffsetLimitKindCallsCount > 0
    }
    var findOffsetLimitKindReceivedArguments: (offset: Int, limit: Int, kind: TransactionKind)?
    var findOffsetLimitKindReturnValue: [ZcashTransaction.Overview]!
    var findOffsetLimitKindClosure: ((Int, Int, TransactionKind) async throws -> [ZcashTransaction.Overview])?

    func find(offset: Int, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview] {
        if let error = findOffsetLimitKindThrowableError {
            throw error
        }
        findOffsetLimitKindCallsCount += 1
        findOffsetLimitKindReceivedArguments = (offset: offset, limit: limit, kind: kind)
        if let closure = findOffsetLimitKindClosure {
            return try await closure(offset, limit, kind)
        } else {
            return findOffsetLimitKindReturnValue
        }
    }

    // MARK: - find

    var findInLimitKindThrowableError: Error?
    var findInLimitKindCallsCount = 0
    var findInLimitKindCalled: Bool {
        return findInLimitKindCallsCount > 0
    }
    var findInLimitKindReceivedArguments: (range: CompactBlockRange, limit: Int, kind: TransactionKind)?
    var findInLimitKindReturnValue: [ZcashTransaction.Overview]!
    var findInLimitKindClosure: ((CompactBlockRange, Int, TransactionKind) async throws -> [ZcashTransaction.Overview])?

    func find(in range: CompactBlockRange, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview] {
        if let error = findInLimitKindThrowableError {
            throw error
        }
        findInLimitKindCallsCount += 1
        findInLimitKindReceivedArguments = (range: range, limit: limit, kind: kind)
        if let closure = findInLimitKindClosure {
            return try await closure(range, limit, kind)
        } else {
            return findInLimitKindReturnValue
        }
    }

    // MARK: - find

    var findFromLimitKindThrowableError: Error?
    var findFromLimitKindCallsCount = 0
    var findFromLimitKindCalled: Bool {
        return findFromLimitKindCallsCount > 0
    }
    var findFromLimitKindReceivedArguments: (from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind)?
    var findFromLimitKindReturnValue: [ZcashTransaction.Overview]!
    var findFromLimitKindClosure: ((ZcashTransaction.Overview, Int, TransactionKind) async throws -> [ZcashTransaction.Overview])?

    func find(from: ZcashTransaction.Overview, limit: Int, kind: TransactionKind) async throws -> [ZcashTransaction.Overview] {
        if let error = findFromLimitKindThrowableError {
            throw error
        }
        findFromLimitKindCallsCount += 1
        findFromLimitKindReceivedArguments = (from: from, limit: limit, kind: kind)
        if let closure = findFromLimitKindClosure {
            return try await closure(from, limit, kind)
        } else {
            return findFromLimitKindReturnValue
        }
    }

    // MARK: - findPendingTransactions

    var findPendingTransactionsLatestHeightOffsetLimitThrowableError: Error?
    var findPendingTransactionsLatestHeightOffsetLimitCallsCount = 0
    var findPendingTransactionsLatestHeightOffsetLimitCalled: Bool {
        return findPendingTransactionsLatestHeightOffsetLimitCallsCount > 0
    }
    var findPendingTransactionsLatestHeightOffsetLimitReceivedArguments: (latestHeight: BlockHeight, offset: Int, limit: Int)?
    var findPendingTransactionsLatestHeightOffsetLimitReturnValue: [ZcashTransaction.Overview]!
    var findPendingTransactionsLatestHeightOffsetLimitClosure: ((BlockHeight, Int, Int) async throws -> [ZcashTransaction.Overview])?

    func findPendingTransactions(latestHeight: BlockHeight, offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview] {
        if let error = findPendingTransactionsLatestHeightOffsetLimitThrowableError {
            throw error
        }
        findPendingTransactionsLatestHeightOffsetLimitCallsCount += 1
        findPendingTransactionsLatestHeightOffsetLimitReceivedArguments = (latestHeight: latestHeight, offset: offset, limit: limit)
        if let closure = findPendingTransactionsLatestHeightOffsetLimitClosure {
            return try await closure(latestHeight, offset, limit)
        } else {
            return findPendingTransactionsLatestHeightOffsetLimitReturnValue
        }
    }

    // MARK: - findReceived

    var findReceivedOffsetLimitThrowableError: Error?
    var findReceivedOffsetLimitCallsCount = 0
    var findReceivedOffsetLimitCalled: Bool {
        return findReceivedOffsetLimitCallsCount > 0
    }
    var findReceivedOffsetLimitReceivedArguments: (offset: Int, limit: Int)?
    var findReceivedOffsetLimitReturnValue: [ZcashTransaction.Overview]!
    var findReceivedOffsetLimitClosure: ((Int, Int) async throws -> [ZcashTransaction.Overview])?

    func findReceived(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview] {
        if let error = findReceivedOffsetLimitThrowableError {
            throw error
        }
        findReceivedOffsetLimitCallsCount += 1
        findReceivedOffsetLimitReceivedArguments = (offset: offset, limit: limit)
        if let closure = findReceivedOffsetLimitClosure {
            return try await closure(offset, limit)
        } else {
            return findReceivedOffsetLimitReturnValue
        }
    }

    // MARK: - findSent

    var findSentOffsetLimitThrowableError: Error?
    var findSentOffsetLimitCallsCount = 0
    var findSentOffsetLimitCalled: Bool {
        return findSentOffsetLimitCallsCount > 0
    }
    var findSentOffsetLimitReceivedArguments: (offset: Int, limit: Int)?
    var findSentOffsetLimitReturnValue: [ZcashTransaction.Overview]!
    var findSentOffsetLimitClosure: ((Int, Int) async throws -> [ZcashTransaction.Overview])?

    func findSent(offset: Int, limit: Int) async throws -> [ZcashTransaction.Overview] {
        if let error = findSentOffsetLimitThrowableError {
            throw error
        }
        findSentOffsetLimitCallsCount += 1
        findSentOffsetLimitReceivedArguments = (offset: offset, limit: limit)
        if let closure = findSentOffsetLimitClosure {
            return try await closure(offset, limit)
        } else {
            return findSentOffsetLimitReturnValue
        }
    }

    // MARK: - findForResubmission

    var findForResubmissionUpToThrowableError: Error?
    var findForResubmissionUpToCallsCount = 0
    var findForResubmissionUpToCalled: Bool {
        return findForResubmissionUpToCallsCount > 0
    }
    var findForResubmissionUpToReceivedUpTo: BlockHeight?
    var findForResubmissionUpToReturnValue: [ZcashTransaction.Overview]!
    var findForResubmissionUpToClosure: ((BlockHeight) async throws -> [ZcashTransaction.Overview])?

    func findForResubmission(upTo: BlockHeight) async throws -> [ZcashTransaction.Overview] {
        if let error = findForResubmissionUpToThrowableError {
            throw error
        }
        findForResubmissionUpToCallsCount += 1
        findForResubmissionUpToReceivedUpTo = upTo
        if let closure = findForResubmissionUpToClosure {
            return try await closure(upTo)
        } else {
            return findForResubmissionUpToReturnValue
        }
    }

    // MARK: - findMemos

    var findMemosForRawIDThrowableError: Error?
    var findMemosForRawIDCallsCount = 0
    var findMemosForRawIDCalled: Bool {
        return findMemosForRawIDCallsCount > 0
    }
    var findMemosForRawIDReceivedRawID: Data?
    var findMemosForRawIDReturnValue: [Memo]!
    var findMemosForRawIDClosure: ((Data) async throws -> [Memo])?

    func findMemos(for rawID: Data) async throws -> [Memo] {
        if let error = findMemosForRawIDThrowableError {
            throw error
        }
        findMemosForRawIDCallsCount += 1
        findMemosForRawIDReceivedRawID = rawID
        if let closure = findMemosForRawIDClosure {
            return try await closure(rawID)
        } else {
            return findMemosForRawIDReturnValue
        }
    }

    // MARK: - findMemos

    var findMemosForZcashTransactionThrowableError: Error?
    var findMemosForZcashTransactionCallsCount = 0
    var findMemosForZcashTransactionCalled: Bool {
        return findMemosForZcashTransactionCallsCount > 0
    }
    var findMemosForZcashTransactionReceivedTransaction: ZcashTransaction.Overview?
    var findMemosForZcashTransactionReturnValue: [Memo]!
    var findMemosForZcashTransactionClosure: ((ZcashTransaction.Overview) async throws -> [Memo])?

    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        if let error = findMemosForZcashTransactionThrowableError {
            throw error
        }
        findMemosForZcashTransactionCallsCount += 1
        findMemosForZcashTransactionReceivedTransaction = transaction
        if let closure = findMemosForZcashTransactionClosure {
            return try await closure(transaction)
        } else {
            return findMemosForZcashTransactionReturnValue
        }
    }

    // MARK: - getRecipients

    var getRecipientsForThrowableError: Error?
    var getRecipientsForCallsCount = 0
    var getRecipientsForCalled: Bool {
        return getRecipientsForCallsCount > 0
    }
    var getRecipientsForReceivedRawID: Data?
    var getRecipientsForReturnValue: [TransactionRecipient]!
    var getRecipientsForClosure: ((Data) async throws -> [TransactionRecipient])?

    func getRecipients(for rawID: Data) async throws -> [TransactionRecipient] {
        if let error = getRecipientsForThrowableError {
            throw error
        }
        getRecipientsForCallsCount += 1
        getRecipientsForReceivedRawID = rawID
        if let closure = getRecipientsForClosure {
            return try await closure(rawID)
        } else {
            return getRecipientsForReturnValue
        }
    }

    // MARK: - getTransactionOutputs

    var getTransactionOutputsForThrowableError: Error?
    var getTransactionOutputsForCallsCount = 0
    var getTransactionOutputsForCalled: Bool {
        return getTransactionOutputsForCallsCount > 0
    }
    var getTransactionOutputsForReceivedRawID: Data?
    var getTransactionOutputsForReturnValue: [ZcashTransaction.Output]!
    var getTransactionOutputsForClosure: ((Data) async throws -> [ZcashTransaction.Output])?

    func getTransactionOutputs(for rawID: Data) async throws -> [ZcashTransaction.Output] {
        if let error = getTransactionOutputsForThrowableError {
            throw error
        }
        getTransactionOutputsForCallsCount += 1
        getTransactionOutputsForReceivedRawID = rawID
        if let closure = getTransactionOutputsForClosure {
            return try await closure(rawID)
        } else {
            return getTransactionOutputsForReturnValue
        }
    }

}
class UTXOFetcherMock: UTXOFetcher {


    init(
    ) {
    }

    // MARK: - fetch

    var fetchDidFetchThrowableError: Error?
    var fetchDidFetchCallsCount = 0
    var fetchDidFetchCalled: Bool {
        return fetchDidFetchCallsCount > 0
    }
    var fetchDidFetchReceivedDidFetch: ((Float) async -> Void)?
    var fetchDidFetchReturnValue: (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity])!
    var fetchDidFetchClosure: ((@escaping (Float) async -> Void) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity]))?

    func fetch(didFetch: @escaping (Float) async -> Void) async throws -> (inserted: [UnspentTransactionOutputEntity], skipped: [UnspentTransactionOutputEntity]) {
        if let error = fetchDidFetchThrowableError {
            throw error
        }
        fetchDidFetchCallsCount += 1
        fetchDidFetchReceivedDidFetch = didFetch
        if let closure = fetchDidFetchClosure {
            return try await closure(didFetch)
        } else {
            return fetchDidFetchReturnValue
        }
    }

}
class ZcashFileManagerMock: ZcashFileManager {


    init(
    ) {
    }

    // MARK: - isReadableFile

    var isReadableFileAtPathCallsCount = 0
    var isReadableFileAtPathCalled: Bool {
        return isReadableFileAtPathCallsCount > 0
    }
    var isReadableFileAtPathReceivedPath: String?
    var isReadableFileAtPathReturnValue: Bool!
    var isReadableFileAtPathClosure: ((String) -> Bool)?

    func isReadableFile(atPath path: String) -> Bool {
        isReadableFileAtPathCallsCount += 1
        isReadableFileAtPathReceivedPath = path
        if let closure = isReadableFileAtPathClosure {
            return closure(path)
        } else {
            return isReadableFileAtPathReturnValue
        }
    }

    // MARK: - removeItem

    var removeItemAtThrowableError: Error?
    var removeItemAtCallsCount = 0
    var removeItemAtCalled: Bool {
        return removeItemAtCallsCount > 0
    }
    var removeItemAtReceivedURL: URL?
    var removeItemAtClosure: ((URL) throws -> Void)?

    func removeItem(at URL: URL) throws {
        if let error = removeItemAtThrowableError {
            throw error
        }
        removeItemAtCallsCount += 1
        removeItemAtReceivedURL = URL
        try removeItemAtClosure!(URL)
    }

    // MARK: - isDeletableFile

    var isDeletableFileAtPathCallsCount = 0
    var isDeletableFileAtPathCalled: Bool {
        return isDeletableFileAtPathCallsCount > 0
    }
    var isDeletableFileAtPathReceivedPath: String?
    var isDeletableFileAtPathReturnValue: Bool!
    var isDeletableFileAtPathClosure: ((String) -> Bool)?

    func isDeletableFile(atPath path: String) -> Bool {
        isDeletableFileAtPathCallsCount += 1
        isDeletableFileAtPathReceivedPath = path
        if let closure = isDeletableFileAtPathClosure {
            return closure(path)
        } else {
            return isDeletableFileAtPathReturnValue
        }
    }

}
class ZcashRustBackendWeldingMock: ZcashRustBackendWelding {


    init(
    ) {
    }

    // MARK: - listAccounts

    var listAccountsThrowableError: Error?
    var listAccountsCallsCount = 0
    var listAccountsCalled: Bool {
        return listAccountsCallsCount > 0
    }
    var listAccountsReturnValue: [Zip32AccountIndex]!
    var listAccountsClosure: (() async throws -> [Zip32AccountIndex])?

    func listAccounts() async throws -> [Zip32AccountIndex] {
        if let error = listAccountsThrowableError {
            throw error
        }
        listAccountsCallsCount += 1
        if let closure = listAccountsClosure {
            return try await closure()
        } else {
            return listAccountsReturnValue
        }
    }

    // MARK: - createAccount

    var createAccountSeedTreeStateRecoverUntilThrowableError: Error?
    var createAccountSeedTreeStateRecoverUntilCallsCount = 0
    var createAccountSeedTreeStateRecoverUntilCalled: Bool {
        return createAccountSeedTreeStateRecoverUntilCallsCount > 0
    }
    var createAccountSeedTreeStateRecoverUntilReceivedArguments: (seed: [UInt8], treeState: TreeState, recoverUntil: UInt32?)?
    var createAccountSeedTreeStateRecoverUntilReturnValue: UnifiedSpendingKey!
    var createAccountSeedTreeStateRecoverUntilClosure: (([UInt8], TreeState, UInt32?) async throws -> UnifiedSpendingKey)?

    func createAccount(seed: [UInt8], treeState: TreeState, recoverUntil: UInt32?) async throws -> UnifiedSpendingKey {
        if let error = createAccountSeedTreeStateRecoverUntilThrowableError {
            throw error
        }
        createAccountSeedTreeStateRecoverUntilCallsCount += 1
        createAccountSeedTreeStateRecoverUntilReceivedArguments = (seed: seed, treeState: treeState, recoverUntil: recoverUntil)
        if let closure = createAccountSeedTreeStateRecoverUntilClosure {
            return try await closure(seed, treeState, recoverUntil)
        } else {
            return createAccountSeedTreeStateRecoverUntilReturnValue
        }
    }

    // MARK: - isSeedRelevantToAnyDerivedAccount

    var isSeedRelevantToAnyDerivedAccountSeedThrowableError: Error?
    var isSeedRelevantToAnyDerivedAccountSeedCallsCount = 0
    var isSeedRelevantToAnyDerivedAccountSeedCalled: Bool {
        return isSeedRelevantToAnyDerivedAccountSeedCallsCount > 0
    }
    var isSeedRelevantToAnyDerivedAccountSeedReceivedSeed: [UInt8]?
    var isSeedRelevantToAnyDerivedAccountSeedReturnValue: Bool!
    var isSeedRelevantToAnyDerivedAccountSeedClosure: (([UInt8]) async throws -> Bool)?

    func isSeedRelevantToAnyDerivedAccount(seed: [UInt8]) async throws -> Bool {
        if let error = isSeedRelevantToAnyDerivedAccountSeedThrowableError {
            throw error
        }
        isSeedRelevantToAnyDerivedAccountSeedCallsCount += 1
        isSeedRelevantToAnyDerivedAccountSeedReceivedSeed = seed
        if let closure = isSeedRelevantToAnyDerivedAccountSeedClosure {
            return try await closure(seed)
        } else {
            return isSeedRelevantToAnyDerivedAccountSeedReturnValue
        }
    }

    // MARK: - decryptAndStoreTransaction

    var decryptAndStoreTransactionTxBytesMinedHeightThrowableError: Error?
    var decryptAndStoreTransactionTxBytesMinedHeightCallsCount = 0
    var decryptAndStoreTransactionTxBytesMinedHeightCalled: Bool {
        return decryptAndStoreTransactionTxBytesMinedHeightCallsCount > 0
    }
    var decryptAndStoreTransactionTxBytesMinedHeightReceivedArguments: (txBytes: [UInt8], minedHeight: UInt32?)?
    var decryptAndStoreTransactionTxBytesMinedHeightClosure: (([UInt8], UInt32?) async throws -> Void)?

    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: UInt32?) async throws {
        if let error = decryptAndStoreTransactionTxBytesMinedHeightThrowableError {
            throw error
        }
        decryptAndStoreTransactionTxBytesMinedHeightCallsCount += 1
        decryptAndStoreTransactionTxBytesMinedHeightReceivedArguments = (txBytes: txBytes, minedHeight: minedHeight)
        try await decryptAndStoreTransactionTxBytesMinedHeightClosure!(txBytes, minedHeight)
    }

    // MARK: - getCurrentAddress

    var getCurrentAddressAccountIndexThrowableError: Error?
    var getCurrentAddressAccountIndexCallsCount = 0
    var getCurrentAddressAccountIndexCalled: Bool {
        return getCurrentAddressAccountIndexCallsCount > 0
    }
    var getCurrentAddressAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getCurrentAddressAccountIndexReturnValue: UnifiedAddress!
    var getCurrentAddressAccountIndexClosure: ((Zip32AccountIndex) async throws -> UnifiedAddress)?

    func getCurrentAddress(accountIndex: Zip32AccountIndex) async throws -> UnifiedAddress {
        if let error = getCurrentAddressAccountIndexThrowableError {
            throw error
        }
        getCurrentAddressAccountIndexCallsCount += 1
        getCurrentAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getCurrentAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getCurrentAddressAccountIndexReturnValue
        }
    }

    // MARK: - getNextAvailableAddress

    var getNextAvailableAddressAccountIndexThrowableError: Error?
    var getNextAvailableAddressAccountIndexCallsCount = 0
    var getNextAvailableAddressAccountIndexCalled: Bool {
        return getNextAvailableAddressAccountIndexCallsCount > 0
    }
    var getNextAvailableAddressAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getNextAvailableAddressAccountIndexReturnValue: UnifiedAddress!
    var getNextAvailableAddressAccountIndexClosure: ((Zip32AccountIndex) async throws -> UnifiedAddress)?

    func getNextAvailableAddress(accountIndex: Zip32AccountIndex) async throws -> UnifiedAddress {
        if let error = getNextAvailableAddressAccountIndexThrowableError {
            throw error
        }
        getNextAvailableAddressAccountIndexCallsCount += 1
        getNextAvailableAddressAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getNextAvailableAddressAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getNextAvailableAddressAccountIndexReturnValue
        }
    }

    // MARK: - getMemo

    var getMemoTxIdOutputPoolOutputIndexThrowableError: Error?
    var getMemoTxIdOutputPoolOutputIndexCallsCount = 0
    var getMemoTxIdOutputPoolOutputIndexCalled: Bool {
        return getMemoTxIdOutputPoolOutputIndexCallsCount > 0
    }
    var getMemoTxIdOutputPoolOutputIndexReceivedArguments: (txId: Data, outputPool: UInt32, outputIndex: UInt16)?
    var getMemoTxIdOutputPoolOutputIndexReturnValue: Memo?
    var getMemoTxIdOutputPoolOutputIndexClosure: ((Data, UInt32, UInt16) async throws -> Memo?)?

    func getMemo(txId: Data, outputPool: UInt32, outputIndex: UInt16) async throws -> Memo? {
        if let error = getMemoTxIdOutputPoolOutputIndexThrowableError {
            throw error
        }
        getMemoTxIdOutputPoolOutputIndexCallsCount += 1
        getMemoTxIdOutputPoolOutputIndexReceivedArguments = (txId: txId, outputPool: outputPool, outputIndex: outputIndex)
        if let closure = getMemoTxIdOutputPoolOutputIndexClosure {
            return try await closure(txId, outputPool, outputIndex)
        } else {
            return getMemoTxIdOutputPoolOutputIndexReturnValue
        }
    }

    // MARK: - getTransparentBalance

    var getTransparentBalanceAccountIndexThrowableError: Error?
    var getTransparentBalanceAccountIndexCallsCount = 0
    var getTransparentBalanceAccountIndexCalled: Bool {
        return getTransparentBalanceAccountIndexCallsCount > 0
    }
    var getTransparentBalanceAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getTransparentBalanceAccountIndexReturnValue: Int64!
    var getTransparentBalanceAccountIndexClosure: ((Zip32AccountIndex) async throws -> Int64)?

    func getTransparentBalance(accountIndex: Zip32AccountIndex) async throws -> Int64 {
        if let error = getTransparentBalanceAccountIndexThrowableError {
            throw error
        }
        getTransparentBalanceAccountIndexCallsCount += 1
        getTransparentBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getTransparentBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getTransparentBalanceAccountIndexReturnValue
        }
    }

    // MARK: - initDataDb

    var initDataDbSeedThrowableError: Error?
    var initDataDbSeedCallsCount = 0
    var initDataDbSeedCalled: Bool {
        return initDataDbSeedCallsCount > 0
    }
    var initDataDbSeedReceivedSeed: [UInt8]?
    var initDataDbSeedReturnValue: DbInitResult!
    var initDataDbSeedClosure: (([UInt8]?) async throws -> DbInitResult)?

    func initDataDb(seed: [UInt8]?) async throws -> DbInitResult {
        if let error = initDataDbSeedThrowableError {
            throw error
        }
        initDataDbSeedCallsCount += 1
        initDataDbSeedReceivedSeed = seed
        if let closure = initDataDbSeedClosure {
            return try await closure(seed)
        } else {
            return initDataDbSeedReturnValue
        }
    }

    // MARK: - listTransparentReceivers

    var listTransparentReceiversAccountIndexThrowableError: Error?
    var listTransparentReceiversAccountIndexCallsCount = 0
    var listTransparentReceiversAccountIndexCalled: Bool {
        return listTransparentReceiversAccountIndexCallsCount > 0
    }
    var listTransparentReceiversAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var listTransparentReceiversAccountIndexReturnValue: [TransparentAddress]!
    var listTransparentReceiversAccountIndexClosure: ((Zip32AccountIndex) async throws -> [TransparentAddress])?

    func listTransparentReceivers(accountIndex: Zip32AccountIndex) async throws -> [TransparentAddress] {
        if let error = listTransparentReceiversAccountIndexThrowableError {
            throw error
        }
        listTransparentReceiversAccountIndexCallsCount += 1
        listTransparentReceiversAccountIndexReceivedAccountIndex = accountIndex
        if let closure = listTransparentReceiversAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return listTransparentReceiversAccountIndexReturnValue
        }
    }

    // MARK: - getVerifiedTransparentBalance

    var getVerifiedTransparentBalanceAccountIndexThrowableError: Error?
    var getVerifiedTransparentBalanceAccountIndexCallsCount = 0
    var getVerifiedTransparentBalanceAccountIndexCalled: Bool {
        return getVerifiedTransparentBalanceAccountIndexCallsCount > 0
    }
    var getVerifiedTransparentBalanceAccountIndexReceivedAccountIndex: Zip32AccountIndex?
    var getVerifiedTransparentBalanceAccountIndexReturnValue: Int64!
    var getVerifiedTransparentBalanceAccountIndexClosure: ((Zip32AccountIndex) async throws -> Int64)?

    func getVerifiedTransparentBalance(accountIndex: Zip32AccountIndex) async throws -> Int64 {
        if let error = getVerifiedTransparentBalanceAccountIndexThrowableError {
            throw error
        }
        getVerifiedTransparentBalanceAccountIndexCallsCount += 1
        getVerifiedTransparentBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getVerifiedTransparentBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getVerifiedTransparentBalanceAccountIndexReturnValue
        }
    }

    // MARK: - rewindToHeight

    var rewindToHeightHeightThrowableError: Error?
    var rewindToHeightHeightCallsCount = 0
    var rewindToHeightHeightCalled: Bool {
        return rewindToHeightHeightCallsCount > 0
    }
    var rewindToHeightHeightReceivedHeight: BlockHeight?
    var rewindToHeightHeightReturnValue: RewindResult!
    var rewindToHeightHeightClosure: ((BlockHeight) async throws -> RewindResult)?

    func rewindToHeight(height: BlockHeight) async throws -> RewindResult {
        if let error = rewindToHeightHeightThrowableError {
            throw error
        }
        rewindToHeightHeightCallsCount += 1
        rewindToHeightHeightReceivedHeight = height
        if let closure = rewindToHeightHeightClosure {
            return try await closure(height)
        } else {
            return rewindToHeightHeightReturnValue
        }
    }

    // MARK: - rewindCacheToHeight

    var rewindCacheToHeightHeightThrowableError: Error?
    var rewindCacheToHeightHeightCallsCount = 0
    var rewindCacheToHeightHeightCalled: Bool {
        return rewindCacheToHeightHeightCallsCount > 0
    }
    var rewindCacheToHeightHeightReceivedHeight: Int32?
    var rewindCacheToHeightHeightClosure: ((Int32) async throws -> Void)?

    func rewindCacheToHeight(height: Int32) async throws {
        if let error = rewindCacheToHeightHeightThrowableError {
            throw error
        }
        rewindCacheToHeightHeightCallsCount += 1
        rewindCacheToHeightHeightReceivedHeight = height
        try await rewindCacheToHeightHeightClosure!(height)
    }

    // MARK: - putSaplingSubtreeRoots

    var putSaplingSubtreeRootsStartIndexRootsThrowableError: Error?
    var putSaplingSubtreeRootsStartIndexRootsCallsCount = 0
    var putSaplingSubtreeRootsStartIndexRootsCalled: Bool {
        return putSaplingSubtreeRootsStartIndexRootsCallsCount > 0
    }
    var putSaplingSubtreeRootsStartIndexRootsReceivedArguments: (startIndex: UInt64, roots: [SubtreeRoot])?
    var putSaplingSubtreeRootsStartIndexRootsClosure: ((UInt64, [SubtreeRoot]) async throws -> Void)?

    func putSaplingSubtreeRoots(startIndex: UInt64, roots: [SubtreeRoot]) async throws {
        if let error = putSaplingSubtreeRootsStartIndexRootsThrowableError {
            throw error
        }
        putSaplingSubtreeRootsStartIndexRootsCallsCount += 1
        putSaplingSubtreeRootsStartIndexRootsReceivedArguments = (startIndex: startIndex, roots: roots)
        try await putSaplingSubtreeRootsStartIndexRootsClosure!(startIndex, roots)
    }

    // MARK: - putOrchardSubtreeRoots

    var putOrchardSubtreeRootsStartIndexRootsThrowableError: Error?
    var putOrchardSubtreeRootsStartIndexRootsCallsCount = 0
    var putOrchardSubtreeRootsStartIndexRootsCalled: Bool {
        return putOrchardSubtreeRootsStartIndexRootsCallsCount > 0
    }
    var putOrchardSubtreeRootsStartIndexRootsReceivedArguments: (startIndex: UInt64, roots: [SubtreeRoot])?
    var putOrchardSubtreeRootsStartIndexRootsClosure: ((UInt64, [SubtreeRoot]) async throws -> Void)?

    func putOrchardSubtreeRoots(startIndex: UInt64, roots: [SubtreeRoot]) async throws {
        if let error = putOrchardSubtreeRootsStartIndexRootsThrowableError {
            throw error
        }
        putOrchardSubtreeRootsStartIndexRootsCallsCount += 1
        putOrchardSubtreeRootsStartIndexRootsReceivedArguments = (startIndex: startIndex, roots: roots)
        try await putOrchardSubtreeRootsStartIndexRootsClosure!(startIndex, roots)
    }

    // MARK: - updateChainTip

    var updateChainTipHeightThrowableError: Error?
    var updateChainTipHeightCallsCount = 0
    var updateChainTipHeightCalled: Bool {
        return updateChainTipHeightCallsCount > 0
    }
    var updateChainTipHeightReceivedHeight: Int32?
    var updateChainTipHeightClosure: ((Int32) async throws -> Void)?

    func updateChainTip(height: Int32) async throws {
        if let error = updateChainTipHeightThrowableError {
            throw error
        }
        updateChainTipHeightCallsCount += 1
        updateChainTipHeightReceivedHeight = height
        try await updateChainTipHeightClosure!(height)
    }

    // MARK: - fullyScannedHeight

    var fullyScannedHeightThrowableError: Error?
    var fullyScannedHeightCallsCount = 0
    var fullyScannedHeightCalled: Bool {
        return fullyScannedHeightCallsCount > 0
    }
    var fullyScannedHeightReturnValue: BlockHeight?
    var fullyScannedHeightClosure: (() async throws -> BlockHeight?)?

    func fullyScannedHeight() async throws -> BlockHeight? {
        if let error = fullyScannedHeightThrowableError {
            throw error
        }
        fullyScannedHeightCallsCount += 1
        if let closure = fullyScannedHeightClosure {
            return try await closure()
        } else {
            return fullyScannedHeightReturnValue
        }
    }

    // MARK: - maxScannedHeight

    var maxScannedHeightThrowableError: Error?
    var maxScannedHeightCallsCount = 0
    var maxScannedHeightCalled: Bool {
        return maxScannedHeightCallsCount > 0
    }
    var maxScannedHeightReturnValue: BlockHeight?
    var maxScannedHeightClosure: (() async throws -> BlockHeight?)?

    func maxScannedHeight() async throws -> BlockHeight? {
        if let error = maxScannedHeightThrowableError {
            throw error
        }
        maxScannedHeightCallsCount += 1
        if let closure = maxScannedHeightClosure {
            return try await closure()
        } else {
            return maxScannedHeightReturnValue
        }
    }

    // MARK: - getWalletSummary

    var getWalletSummaryThrowableError: Error?
    var getWalletSummaryCallsCount = 0
    var getWalletSummaryCalled: Bool {
        return getWalletSummaryCallsCount > 0
    }
    var getWalletSummaryReturnValue: WalletSummary?
    var getWalletSummaryClosure: (() async throws -> WalletSummary?)?

    func getWalletSummary() async throws -> WalletSummary? {
        if let error = getWalletSummaryThrowableError {
            throw error
        }
        getWalletSummaryCallsCount += 1
        if let closure = getWalletSummaryClosure {
            return try await closure()
        } else {
            return getWalletSummaryReturnValue
        }
    }

    // MARK: - suggestScanRanges

    var suggestScanRangesThrowableError: Error?
    var suggestScanRangesCallsCount = 0
    var suggestScanRangesCalled: Bool {
        return suggestScanRangesCallsCount > 0
    }
    var suggestScanRangesReturnValue: [ScanRange]!
    var suggestScanRangesClosure: (() async throws -> [ScanRange])?

    func suggestScanRanges() async throws -> [ScanRange] {
        if let error = suggestScanRangesThrowableError {
            throw error
        }
        suggestScanRangesCallsCount += 1
        if let closure = suggestScanRangesClosure {
            return try await closure()
        } else {
            return suggestScanRangesReturnValue
        }
    }

    // MARK: - scanBlocks

    var scanBlocksFromHeightFromStateLimitThrowableError: Error?
    var scanBlocksFromHeightFromStateLimitCallsCount = 0
    var scanBlocksFromHeightFromStateLimitCalled: Bool {
        return scanBlocksFromHeightFromStateLimitCallsCount > 0
    }
    var scanBlocksFromHeightFromStateLimitReceivedArguments: (fromHeight: Int32, fromState: TreeState, limit: UInt32)?
    var scanBlocksFromHeightFromStateLimitReturnValue: ScanSummary!
    var scanBlocksFromHeightFromStateLimitClosure: ((Int32, TreeState, UInt32) async throws -> ScanSummary)?

    func scanBlocks(fromHeight: Int32, fromState: TreeState, limit: UInt32) async throws -> ScanSummary {
        if let error = scanBlocksFromHeightFromStateLimitThrowableError {
            throw error
        }
        scanBlocksFromHeightFromStateLimitCallsCount += 1
        scanBlocksFromHeightFromStateLimitReceivedArguments = (fromHeight: fromHeight, fromState: fromState, limit: limit)
        if let closure = scanBlocksFromHeightFromStateLimitClosure {
            return try await closure(fromHeight, fromState, limit)
        } else {
            return scanBlocksFromHeightFromStateLimitReturnValue
        }
    }

    // MARK: - putUnspentTransparentOutput

    var putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError: Error?
    var putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount = 0
    var putUnspentTransparentOutputTxidIndexScriptValueHeightCalled: Bool {
        return putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount > 0
    }
    var putUnspentTransparentOutputTxidIndexScriptValueHeightReceivedArguments: (txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight)?
    var putUnspentTransparentOutputTxidIndexScriptValueHeightClosure: (([UInt8], Int, [UInt8], Int64, BlockHeight) async throws -> Void)?

    func putUnspentTransparentOutput(txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight) async throws {
        if let error = putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError {
            throw error
        }
        putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount += 1
        putUnspentTransparentOutputTxidIndexScriptValueHeightReceivedArguments = (txid: txid, index: index, script: script, value: value, height: height)
        try await putUnspentTransparentOutputTxidIndexScriptValueHeightClosure!(txid, index, script, value, height)
    }

    // MARK: - proposeTransfer

    var proposeTransferAccountIndexToValueMemoThrowableError: Error?
    var proposeTransferAccountIndexToValueMemoCallsCount = 0
    var proposeTransferAccountIndexToValueMemoCalled: Bool {
        return proposeTransferAccountIndexToValueMemoCallsCount > 0
    }
    var proposeTransferAccountIndexToValueMemoReceivedArguments: (accountIndex: Zip32AccountIndex, address: String, value: Int64, memo: MemoBytes?)?
    var proposeTransferAccountIndexToValueMemoReturnValue: FfiProposal!
    var proposeTransferAccountIndexToValueMemoClosure: ((Zip32AccountIndex, String, Int64, MemoBytes?) async throws -> FfiProposal)?

    func proposeTransfer(accountIndex: Zip32AccountIndex, to address: String, value: Int64, memo: MemoBytes?) async throws -> FfiProposal {
        if let error = proposeTransferAccountIndexToValueMemoThrowableError {
            throw error
        }
        proposeTransferAccountIndexToValueMemoCallsCount += 1
        proposeTransferAccountIndexToValueMemoReceivedArguments = (accountIndex: accountIndex, address: address, value: value, memo: memo)
        if let closure = proposeTransferAccountIndexToValueMemoClosure {
            return try await closure(accountIndex, address, value, memo)
        } else {
            return proposeTransferAccountIndexToValueMemoReturnValue
        }
    }

    // MARK: - proposeTransferFromURI

    var proposeTransferFromURIAccountIndexThrowableError: Error?
    var proposeTransferFromURIAccountIndexCallsCount = 0
    var proposeTransferFromURIAccountIndexCalled: Bool {
        return proposeTransferFromURIAccountIndexCallsCount > 0
    }
    var proposeTransferFromURIAccountIndexReceivedArguments: (uri: String, accountIndex: Zip32AccountIndex)?
    var proposeTransferFromURIAccountIndexReturnValue: FfiProposal!
    var proposeTransferFromURIAccountIndexClosure: ((String, Zip32AccountIndex) async throws -> FfiProposal)?

    func proposeTransferFromURI(_ uri: String, accountIndex: Zip32AccountIndex) async throws -> FfiProposal {
        if let error = proposeTransferFromURIAccountIndexThrowableError {
            throw error
        }
        proposeTransferFromURIAccountIndexCallsCount += 1
        proposeTransferFromURIAccountIndexReceivedArguments = (uri: uri, accountIndex: accountIndex)
        if let closure = proposeTransferFromURIAccountIndexClosure {
            return try await closure(uri, accountIndex)
        } else {
            return proposeTransferFromURIAccountIndexReturnValue
        }
    }

    // MARK: - proposeShielding

    var proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverThrowableError: Error?
    var proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverCallsCount = 0
    var proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverCalled: Bool {
        return proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverCallsCount > 0
    }
    var proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverReceivedArguments: (accountIndex: Zip32AccountIndex, memo: MemoBytes?, shieldingThreshold: Zatoshi, transparentReceiver: String?)?
    var proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverReturnValue: FfiProposal?
    var proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverClosure: ((Zip32AccountIndex, MemoBytes?, Zatoshi, String?) async throws -> FfiProposal?)?

    func proposeShielding(accountIndex: Zip32AccountIndex, memo: MemoBytes?, shieldingThreshold: Zatoshi, transparentReceiver: String?) async throws -> FfiProposal? {
        if let error = proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverThrowableError {
            throw error
        }
        proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverCallsCount += 1
        proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverReceivedArguments = (accountIndex: accountIndex, memo: memo, shieldingThreshold: shieldingThreshold, transparentReceiver: transparentReceiver)
        if let closure = proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverClosure {
            return try await closure(accountIndex, memo, shieldingThreshold, transparentReceiver)
        } else {
            return proposeShieldingAccountIndexMemoShieldingThresholdTransparentReceiverReturnValue
        }
    }

    // MARK: - createProposedTransactions

    var createProposedTransactionsProposalUskThrowableError: Error?
    var createProposedTransactionsProposalUskCallsCount = 0
    var createProposedTransactionsProposalUskCalled: Bool {
        return createProposedTransactionsProposalUskCallsCount > 0
    }
    var createProposedTransactionsProposalUskReceivedArguments: (proposal: FfiProposal, usk: UnifiedSpendingKey)?
    var createProposedTransactionsProposalUskReturnValue: [Data]!
    var createProposedTransactionsProposalUskClosure: ((FfiProposal, UnifiedSpendingKey) async throws -> [Data])?

    func createProposedTransactions(proposal: FfiProposal, usk: UnifiedSpendingKey) async throws -> [Data] {
        if let error = createProposedTransactionsProposalUskThrowableError {
            throw error
        }
        createProposedTransactionsProposalUskCallsCount += 1
        createProposedTransactionsProposalUskReceivedArguments = (proposal: proposal, usk: usk)
        if let closure = createProposedTransactionsProposalUskClosure {
            return try await closure(proposal, usk)
        } else {
            return createProposedTransactionsProposalUskReturnValue
        }
    }

    // MARK: - consensusBranchIdFor

    var consensusBranchIdForHeightThrowableError: Error?
    var consensusBranchIdForHeightCallsCount = 0
    var consensusBranchIdForHeightCalled: Bool {
        return consensusBranchIdForHeightCallsCount > 0
    }
    var consensusBranchIdForHeightReceivedHeight: Int32?
    var consensusBranchIdForHeightReturnValue: Int32!
    var consensusBranchIdForHeightClosure: ((Int32) throws -> Int32)?

    func consensusBranchIdFor(height: Int32) throws -> Int32 {
        if let error = consensusBranchIdForHeightThrowableError {
            throw error
        }
        consensusBranchIdForHeightCallsCount += 1
        consensusBranchIdForHeightReceivedHeight = height
        if let closure = consensusBranchIdForHeightClosure {
            return try closure(height)
        } else {
            return consensusBranchIdForHeightReturnValue
        }
    }

    // MARK: - initBlockMetadataDb

    var initBlockMetadataDbThrowableError: Error?
    var initBlockMetadataDbCallsCount = 0
    var initBlockMetadataDbCalled: Bool {
        return initBlockMetadataDbCallsCount > 0
    }
    var initBlockMetadataDbClosure: (() async throws -> Void)?

    func initBlockMetadataDb() async throws {
        if let error = initBlockMetadataDbThrowableError {
            throw error
        }
        initBlockMetadataDbCallsCount += 1
        try await initBlockMetadataDbClosure!()
    }

    // MARK: - writeBlocksMetadata

    var writeBlocksMetadataBlocksThrowableError: Error?
    var writeBlocksMetadataBlocksCallsCount = 0
    var writeBlocksMetadataBlocksCalled: Bool {
        return writeBlocksMetadataBlocksCallsCount > 0
    }
    var writeBlocksMetadataBlocksReceivedBlocks: [ZcashCompactBlock]?
    var writeBlocksMetadataBlocksClosure: (([ZcashCompactBlock]) async throws -> Void)?

    func writeBlocksMetadata(blocks: [ZcashCompactBlock]) async throws {
        if let error = writeBlocksMetadataBlocksThrowableError {
            throw error
        }
        writeBlocksMetadataBlocksCallsCount += 1
        writeBlocksMetadataBlocksReceivedBlocks = blocks
        try await writeBlocksMetadataBlocksClosure!(blocks)
    }

    // MARK: - latestCachedBlockHeight

    var latestCachedBlockHeightThrowableError: Error?
    var latestCachedBlockHeightCallsCount = 0
    var latestCachedBlockHeightCalled: Bool {
        return latestCachedBlockHeightCallsCount > 0
    }
    var latestCachedBlockHeightReturnValue: BlockHeight!
    var latestCachedBlockHeightClosure: (() async throws -> BlockHeight)?

    func latestCachedBlockHeight() async throws -> BlockHeight {
        if let error = latestCachedBlockHeightThrowableError {
            throw error
        }
        latestCachedBlockHeightCallsCount += 1
        if let closure = latestCachedBlockHeightClosure {
            return try await closure()
        } else {
            return latestCachedBlockHeightReturnValue
        }
    }

    // MARK: - transactionDataRequests

    var transactionDataRequestsThrowableError: Error?
    var transactionDataRequestsCallsCount = 0
    var transactionDataRequestsCalled: Bool {
        return transactionDataRequestsCallsCount > 0
    }
    var transactionDataRequestsReturnValue: [TransactionDataRequest]!
    var transactionDataRequestsClosure: (() async throws -> [TransactionDataRequest])?

    func transactionDataRequests() async throws -> [TransactionDataRequest] {
        if let error = transactionDataRequestsThrowableError {
            throw error
        }
        transactionDataRequestsCallsCount += 1
        if let closure = transactionDataRequestsClosure {
            return try await closure()
        } else {
            return transactionDataRequestsReturnValue
        }
    }

    // MARK: - setTransactionStatus

    var setTransactionStatusTxIdStatusThrowableError: Error?
    var setTransactionStatusTxIdStatusCallsCount = 0
    var setTransactionStatusTxIdStatusCalled: Bool {
        return setTransactionStatusTxIdStatusCallsCount > 0
    }
    var setTransactionStatusTxIdStatusReceivedArguments: (txId: Data, status: TransactionStatus)?
    var setTransactionStatusTxIdStatusClosure: ((Data, TransactionStatus) async throws -> Void)?

    func setTransactionStatus(txId: Data, status: TransactionStatus) async throws {
        if let error = setTransactionStatusTxIdStatusThrowableError {
            throw error
        }
        setTransactionStatusTxIdStatusCallsCount += 1
        setTransactionStatusTxIdStatusReceivedArguments = (txId: txId, status: status)
        try await setTransactionStatusTxIdStatusClosure!(txId, status)
    }

}
