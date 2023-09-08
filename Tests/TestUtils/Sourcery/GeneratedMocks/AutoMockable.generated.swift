// Generated using Sourcery 2.0.3 — https://github.com/krzysztofzablocki/Sourcery
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
    var totalProgressRange: CompactBlockRange {
        get { return underlyingTotalProgressRange }
    }
    var underlyingTotalProgressRange: CompactBlockRange!
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

    var updateTotalProgressRangeCallsCount = 0
    var updateTotalProgressRangeCalled: Bool {
        return updateTotalProgressRangeCallsCount > 0
    }
    var updateTotalProgressRangeReceivedTotalProgressRange: CompactBlockRange?
    var updateTotalProgressRangeClosure: ((CompactBlockRange) async -> Void)?

    func update(totalProgressRange: CompactBlockRange) async {
        updateTotalProgressRangeCallsCount += 1
        updateTotalProgressRangeReceivedTotalProgressRange = totalProgressRange
        await updateTotalProgressRangeClosure!(totalProgressRange)
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
    var fetchTransactionTxIdReturnValue: ZcashTransaction.Fetched!
    var fetchTransactionTxIdClosure: ((Data) async throws -> ZcashTransaction.Fetched)?

    func fetchTransaction(txId: Data) async throws -> ZcashTransaction.Fetched {
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

    var scanBlocksAtTotalProgressRangeDidScanThrowableError: Error?
    var scanBlocksAtTotalProgressRangeDidScanCallsCount = 0
    var scanBlocksAtTotalProgressRangeDidScanCalled: Bool {
        return scanBlocksAtTotalProgressRangeDidScanCallsCount > 0
    }
    var scanBlocksAtTotalProgressRangeDidScanReceivedArguments: (range: CompactBlockRange, totalProgressRange: CompactBlockRange, didScan: (BlockHeight, UInt32) async throws -> Void)?
    var scanBlocksAtTotalProgressRangeDidScanReturnValue: BlockHeight!
    var scanBlocksAtTotalProgressRangeDidScanClosure: ((CompactBlockRange, CompactBlockRange, @escaping (BlockHeight, UInt32) async throws -> Void) async throws -> BlockHeight)?

    func scanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange, didScan: @escaping (BlockHeight, UInt32) async throws -> Void) async throws -> BlockHeight {
        if let error = scanBlocksAtTotalProgressRangeDidScanThrowableError {
            throw error
        }
        scanBlocksAtTotalProgressRangeDidScanCallsCount += 1
        scanBlocksAtTotalProgressRangeDidScanReceivedArguments = (range: range, totalProgressRange: totalProgressRange, didScan: didScan)
        if let closure = scanBlocksAtTotalProgressRangeDidScanClosure {
            return try await closure(range, totalProgressRange, didScan)
        } else {
            return scanBlocksAtTotalProgressRangeDidScanReturnValue
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
    var fetchTransactionTxIdReturnValue: ZcashTransaction.Fetched!
    var fetchTransactionTxIdClosure: ((Data) async throws -> ZcashTransaction.Fetched)?

    func fetchTransaction(txId: Data) async throws -> ZcashTransaction.Fetched {
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

}
class SaplingParametersHandlerMock: SaplingParametersHandler {


    init(
    ) {
    }

    // MARK: - handleIfNeeded

    var handleIfNeededThrowableError: Error?
    var handleIfNeededCallsCount = 0
    var handleIfNeededCalled: Bool {
        return handleIfNeededCallsCount > 0
    }
    var handleIfNeededClosure: (() async throws -> Void)?

    func handleIfNeeded() async throws {
        if let error = handleIfNeededThrowableError {
            throw error
        }
        handleIfNeededCallsCount += 1
        try await handleIfNeededClosure!()
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
    var metrics: SDKMetrics {
        get { return underlyingMetrics }
    }
    var underlyingMetrics: SDKMetrics!
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
    var getSaplingAddressAccountIndexReceivedAccountIndex: Int?
    var getSaplingAddressAccountIndexReturnValue: SaplingAddress!
    var getSaplingAddressAccountIndexClosure: ((Int) async throws -> SaplingAddress)?

    func getSaplingAddress(accountIndex: Int) async throws -> SaplingAddress {
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
    var getUnifiedAddressAccountIndexReceivedAccountIndex: Int?
    var getUnifiedAddressAccountIndexReturnValue: UnifiedAddress!
    var getUnifiedAddressAccountIndexClosure: ((Int) async throws -> UnifiedAddress)?

    func getUnifiedAddress(accountIndex: Int) async throws -> UnifiedAddress {
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
    var getTransparentAddressAccountIndexReceivedAccountIndex: Int?
    var getTransparentAddressAccountIndexReturnValue: TransparentAddress!
    var getTransparentAddressAccountIndexClosure: ((Int) async throws -> TransparentAddress)?

    func getTransparentAddress(accountIndex: Int) async throws -> TransparentAddress {
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

    // MARK: - getTransparentBalance

    var getTransparentBalanceAccountIndexThrowableError: Error?
    var getTransparentBalanceAccountIndexCallsCount = 0
    var getTransparentBalanceAccountIndexCalled: Bool {
        return getTransparentBalanceAccountIndexCallsCount > 0
    }
    var getTransparentBalanceAccountIndexReceivedAccountIndex: Int?
    var getTransparentBalanceAccountIndexReturnValue: WalletBalance!
    var getTransparentBalanceAccountIndexClosure: ((Int) async throws -> WalletBalance)?

    func getTransparentBalance(accountIndex: Int) async throws -> WalletBalance {
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

    // MARK: - getShieldedBalance

    var getShieldedBalanceAccountIndexThrowableError: Error?
    var getShieldedBalanceAccountIndexCallsCount = 0
    var getShieldedBalanceAccountIndexCalled: Bool {
        return getShieldedBalanceAccountIndexCallsCount > 0
    }
    var getShieldedBalanceAccountIndexReceivedAccountIndex: Int?
    var getShieldedBalanceAccountIndexReturnValue: Zatoshi!
    var getShieldedBalanceAccountIndexClosure: ((Int) async throws -> Zatoshi)?

    func getShieldedBalance(accountIndex: Int) async throws -> Zatoshi {
        if let error = getShieldedBalanceAccountIndexThrowableError {
            throw error
        }
        getShieldedBalanceAccountIndexCallsCount += 1
        getShieldedBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getShieldedBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getShieldedBalanceAccountIndexReturnValue
        }
    }

    // MARK: - getShieldedVerifiedBalance

    var getShieldedVerifiedBalanceAccountIndexThrowableError: Error?
    var getShieldedVerifiedBalanceAccountIndexCallsCount = 0
    var getShieldedVerifiedBalanceAccountIndexCalled: Bool {
        return getShieldedVerifiedBalanceAccountIndexCallsCount > 0
    }
    var getShieldedVerifiedBalanceAccountIndexReceivedAccountIndex: Int?
    var getShieldedVerifiedBalanceAccountIndexReturnValue: Zatoshi!
    var getShieldedVerifiedBalanceAccountIndexClosure: ((Int) async throws -> Zatoshi)?

    func getShieldedVerifiedBalance(accountIndex: Int) async throws -> Zatoshi {
        if let error = getShieldedVerifiedBalanceAccountIndexThrowableError {
            throw error
        }
        getShieldedVerifiedBalanceAccountIndexCallsCount += 1
        getShieldedVerifiedBalanceAccountIndexReceivedAccountIndex = accountIndex
        if let closure = getShieldedVerifiedBalanceAccountIndexClosure {
            return try await closure(accountIndex)
        } else {
            return getShieldedVerifiedBalanceAccountIndexReturnValue
        }
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

    var findIdThrowableError: Error?
    var findIdCallsCount = 0
    var findIdCalled: Bool {
        return findIdCallsCount > 0
    }
    var findIdReceivedId: Int?
    var findIdReturnValue: ZcashTransaction.Overview!
    var findIdClosure: ((Int) async throws -> ZcashTransaction.Overview)?

    func find(id: Int) async throws -> ZcashTransaction.Overview {
        if let error = findIdThrowableError {
            throw error
        }
        findIdCallsCount += 1
        findIdReceivedId = id
        if let closure = findIdClosure {
            return try await closure(id)
        } else {
            return findIdReturnValue
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

    // MARK: - findMemos

    var findMemosForThrowableError: Error?
    var findMemosForCallsCount = 0
    var findMemosForCalled: Bool {
        return findMemosForCallsCount > 0
    }
    var findMemosForReceivedTransaction: ZcashTransaction.Overview?
    var findMemosForReturnValue: [Memo]!
    var findMemosForClosure: ((ZcashTransaction.Overview) async throws -> [Memo])?

    func findMemos(for transaction: ZcashTransaction.Overview) async throws -> [Memo] {
        if let error = findMemosForThrowableError {
            throw error
        }
        findMemosForCallsCount += 1
        findMemosForReceivedTransaction = transaction
        if let closure = findMemosForClosure {
            return try await closure(transaction)
        } else {
            return findMemosForReturnValue
        }
    }

    // MARK: - getRecipients

    var getRecipientsForThrowableError: Error?
    var getRecipientsForCallsCount = 0
    var getRecipientsForCalled: Bool {
        return getRecipientsForCallsCount > 0
    }
    var getRecipientsForReceivedId: Int?
    var getRecipientsForReturnValue: [TransactionRecipient]!
    var getRecipientsForClosure: ((Int) async throws -> [TransactionRecipient])?

    func getRecipients(for id: Int) async throws -> [TransactionRecipient] {
        if let error = getRecipientsForThrowableError {
            throw error
        }
        getRecipientsForCallsCount += 1
        getRecipientsForReceivedId = id
        if let closure = getRecipientsForClosure {
            return try await closure(id)
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
    var getTransactionOutputsForReceivedId: Int?
    var getTransactionOutputsForReturnValue: [ZcashTransaction.Output]!
    var getTransactionOutputsForClosure: ((Int) async throws -> [ZcashTransaction.Output])?

    func getTransactionOutputs(for id: Int) async throws -> [ZcashTransaction.Output] {
        if let error = getTransactionOutputsForThrowableError {
            throw error
        }
        getTransactionOutputsForCallsCount += 1
        getTransactionOutputsForReceivedId = id
        if let closure = getTransactionOutputsForClosure {
            return try await closure(id)
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
actor ZcashRustBackendWeldingMock: ZcashRustBackendWelding {

    nonisolated let consensusBranchIdForHeightClosure: ((Int32) throws -> Int32)?

    init(
        consensusBranchIdForHeightClosure: ((Int32) throws -> Int32)? = nil
    ) {
        self.consensusBranchIdForHeightClosure = consensusBranchIdForHeightClosure
    }

    // MARK: - createAccount

    var createAccountSeedTreeStateRecoverUntilThrowableError: Error?
    func setCreateAccountSeedTreeStateRecoverUntilThrowableError(_ param: Error?) async {
        createAccountSeedTreeStateRecoverUntilThrowableError = param
    }
    var createAccountSeedTreeStateRecoverUntilCallsCount = 0
    var createAccountSeedTreeStateRecoverUntilCalled: Bool {
        return createAccountSeedTreeStateRecoverUntilCallsCount > 0
    }
    var createAccountSeedTreeStateRecoverUntilReceivedArguments: (seed: [UInt8], treeState: [UInt8], recoverUntil: UInt32?)?
    var createAccountSeedTreeStateRecoverUntilReturnValue: UnifiedSpendingKey!
    func setCreateAccountSeedTreeStateRecoverUntilReturnValue(_ param: UnifiedSpendingKey) async {
        createAccountSeedTreeStateRecoverUntilReturnValue = param
    }
    var createAccountSeedTreeStateRecoverUntilClosure: (([UInt8], [UInt8], UInt32?) async throws -> UnifiedSpendingKey)?
    func setCreateAccountSeedTreeStateRecoverUntilClosure(_ param: (([UInt8], [UInt8], UInt32?) async throws -> UnifiedSpendingKey)?) async {
        createAccountSeedTreeStateRecoverUntilClosure = param
    }

    func createAccount(seed: [UInt8], treeState: [UInt8], recoverUntil: UInt32?) async throws -> UnifiedSpendingKey {
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

    // MARK: - createToAddress

    var createToAddressUskToValueMemoThrowableError: Error?
    func setCreateToAddressUskToValueMemoThrowableError(_ param: Error?) async {
        createToAddressUskToValueMemoThrowableError = param
    }
    var createToAddressUskToValueMemoCallsCount = 0
    var createToAddressUskToValueMemoCalled: Bool {
        return createToAddressUskToValueMemoCallsCount > 0
    }
    var createToAddressUskToValueMemoReceivedArguments: (usk: UnifiedSpendingKey, address: String, value: Int64, memo: MemoBytes?)?
    var createToAddressUskToValueMemoReturnValue: Data!
    func setCreateToAddressUskToValueMemoReturnValue(_ param: Data) async {
        createToAddressUskToValueMemoReturnValue = param
    }
    var createToAddressUskToValueMemoClosure: ((UnifiedSpendingKey, String, Int64, MemoBytes?) async throws -> Data)?
    func setCreateToAddressUskToValueMemoClosure(_ param: ((UnifiedSpendingKey, String, Int64, MemoBytes?) async throws -> Data)?) async {
        createToAddressUskToValueMemoClosure = param
    }

    func createToAddress(usk: UnifiedSpendingKey, to address: String, value: Int64, memo: MemoBytes?) async throws -> Data {
        if let error = createToAddressUskToValueMemoThrowableError {
            throw error
        }
        createToAddressUskToValueMemoCallsCount += 1
        createToAddressUskToValueMemoReceivedArguments = (usk: usk, address: address, value: value, memo: memo)
        if let closure = createToAddressUskToValueMemoClosure {
            return try await closure(usk, address, value, memo)
        } else {
            return createToAddressUskToValueMemoReturnValue
        }
    }

    // MARK: - decryptAndStoreTransaction

    var decryptAndStoreTransactionTxBytesMinedHeightThrowableError: Error?
    func setDecryptAndStoreTransactionTxBytesMinedHeightThrowableError(_ param: Error?) async {
        decryptAndStoreTransactionTxBytesMinedHeightThrowableError = param
    }
    var decryptAndStoreTransactionTxBytesMinedHeightCallsCount = 0
    var decryptAndStoreTransactionTxBytesMinedHeightCalled: Bool {
        return decryptAndStoreTransactionTxBytesMinedHeightCallsCount > 0
    }
    var decryptAndStoreTransactionTxBytesMinedHeightReceivedArguments: (txBytes: [UInt8], minedHeight: Int32)?
    var decryptAndStoreTransactionTxBytesMinedHeightClosure: (([UInt8], Int32) async throws -> Void)?
    func setDecryptAndStoreTransactionTxBytesMinedHeightClosure(_ param: (([UInt8], Int32) async throws -> Void)?) async {
        decryptAndStoreTransactionTxBytesMinedHeightClosure = param
    }

    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: Int32) async throws {
        if let error = decryptAndStoreTransactionTxBytesMinedHeightThrowableError {
            throw error
        }
        decryptAndStoreTransactionTxBytesMinedHeightCallsCount += 1
        decryptAndStoreTransactionTxBytesMinedHeightReceivedArguments = (txBytes: txBytes, minedHeight: minedHeight)
        try await decryptAndStoreTransactionTxBytesMinedHeightClosure!(txBytes, minedHeight)
    }

    // MARK: - getBalance

    var getBalanceAccountThrowableError: Error?
    func setGetBalanceAccountThrowableError(_ param: Error?) async {
        getBalanceAccountThrowableError = param
    }
    var getBalanceAccountCallsCount = 0
    var getBalanceAccountCalled: Bool {
        return getBalanceAccountCallsCount > 0
    }
    var getBalanceAccountReceivedAccount: Int32?
    var getBalanceAccountReturnValue: Int64!
    func setGetBalanceAccountReturnValue(_ param: Int64) async {
        getBalanceAccountReturnValue = param
    }
    var getBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getBalanceAccountClosure = param
    }

    func getBalance(account: Int32) async throws -> Int64 {
        if let error = getBalanceAccountThrowableError {
            throw error
        }
        getBalanceAccountCallsCount += 1
        getBalanceAccountReceivedAccount = account
        if let closure = getBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getBalanceAccountReturnValue
        }
    }

    // MARK: - getCurrentAddress

    var getCurrentAddressAccountThrowableError: Error?
    func setGetCurrentAddressAccountThrowableError(_ param: Error?) async {
        getCurrentAddressAccountThrowableError = param
    }
    var getCurrentAddressAccountCallsCount = 0
    var getCurrentAddressAccountCalled: Bool {
        return getCurrentAddressAccountCallsCount > 0
    }
    var getCurrentAddressAccountReceivedAccount: Int32?
    var getCurrentAddressAccountReturnValue: UnifiedAddress!
    func setGetCurrentAddressAccountReturnValue(_ param: UnifiedAddress) async {
        getCurrentAddressAccountReturnValue = param
    }
    var getCurrentAddressAccountClosure: ((Int32) async throws -> UnifiedAddress)?
    func setGetCurrentAddressAccountClosure(_ param: ((Int32) async throws -> UnifiedAddress)?) async {
        getCurrentAddressAccountClosure = param
    }

    func getCurrentAddress(account: Int32) async throws -> UnifiedAddress {
        if let error = getCurrentAddressAccountThrowableError {
            throw error
        }
        getCurrentAddressAccountCallsCount += 1
        getCurrentAddressAccountReceivedAccount = account
        if let closure = getCurrentAddressAccountClosure {
            return try await closure(account)
        } else {
            return getCurrentAddressAccountReturnValue
        }
    }

    // MARK: - getNearestRewindHeight

    var getNearestRewindHeightHeightThrowableError: Error?
    func setGetNearestRewindHeightHeightThrowableError(_ param: Error?) async {
        getNearestRewindHeightHeightThrowableError = param
    }
    var getNearestRewindHeightHeightCallsCount = 0
    var getNearestRewindHeightHeightCalled: Bool {
        return getNearestRewindHeightHeightCallsCount > 0
    }
    var getNearestRewindHeightHeightReceivedHeight: Int32?
    var getNearestRewindHeightHeightReturnValue: Int32!
    func setGetNearestRewindHeightHeightReturnValue(_ param: Int32) async {
        getNearestRewindHeightHeightReturnValue = param
    }
    var getNearestRewindHeightHeightClosure: ((Int32) async throws -> Int32)?
    func setGetNearestRewindHeightHeightClosure(_ param: ((Int32) async throws -> Int32)?) async {
        getNearestRewindHeightHeightClosure = param
    }

    func getNearestRewindHeight(height: Int32) async throws -> Int32 {
        if let error = getNearestRewindHeightHeightThrowableError {
            throw error
        }
        getNearestRewindHeightHeightCallsCount += 1
        getNearestRewindHeightHeightReceivedHeight = height
        if let closure = getNearestRewindHeightHeightClosure {
            return try await closure(height)
        } else {
            return getNearestRewindHeightHeightReturnValue
        }
    }

    // MARK: - getNextAvailableAddress

    var getNextAvailableAddressAccountThrowableError: Error?
    func setGetNextAvailableAddressAccountThrowableError(_ param: Error?) async {
        getNextAvailableAddressAccountThrowableError = param
    }
    var getNextAvailableAddressAccountCallsCount = 0
    var getNextAvailableAddressAccountCalled: Bool {
        return getNextAvailableAddressAccountCallsCount > 0
    }
    var getNextAvailableAddressAccountReceivedAccount: Int32?
    var getNextAvailableAddressAccountReturnValue: UnifiedAddress!
    func setGetNextAvailableAddressAccountReturnValue(_ param: UnifiedAddress) async {
        getNextAvailableAddressAccountReturnValue = param
    }
    var getNextAvailableAddressAccountClosure: ((Int32) async throws -> UnifiedAddress)?
    func setGetNextAvailableAddressAccountClosure(_ param: ((Int32) async throws -> UnifiedAddress)?) async {
        getNextAvailableAddressAccountClosure = param
    }

    func getNextAvailableAddress(account: Int32) async throws -> UnifiedAddress {
        if let error = getNextAvailableAddressAccountThrowableError {
            throw error
        }
        getNextAvailableAddressAccountCallsCount += 1
        getNextAvailableAddressAccountReceivedAccount = account
        if let closure = getNextAvailableAddressAccountClosure {
            return try await closure(account)
        } else {
            return getNextAvailableAddressAccountReturnValue
        }
    }

    // MARK: - getMemo

    var getMemoTxIdOutputIndexThrowableError: Error?
    func setGetMemoTxIdOutputIndexThrowableError(_ param: Error?) async {
        getMemoTxIdOutputIndexThrowableError = param
    }
    var getMemoTxIdOutputIndexCallsCount = 0
    var getMemoTxIdOutputIndexCalled: Bool {
        return getMemoTxIdOutputIndexCallsCount > 0
    }
    var getMemoTxIdOutputIndexReceivedArguments: (txId: Data, outputIndex: UInt16)?
    var getMemoTxIdOutputIndexReturnValue: Memo?
    func setGetMemoTxIdOutputIndexReturnValue(_ param: Memo?) async {
        getMemoTxIdOutputIndexReturnValue = param
    }
    var getMemoTxIdOutputIndexClosure: ((Data, UInt16) async throws -> Memo?)?
    func setGetMemoTxIdOutputIndexClosure(_ param: ((Data, UInt16) async throws -> Memo?)?) async {
        getMemoTxIdOutputIndexClosure = param
    }

    func getMemo(txId: Data, outputIndex: UInt16) async throws -> Memo? {
        if let error = getMemoTxIdOutputIndexThrowableError {
            throw error
        }
        getMemoTxIdOutputIndexCallsCount += 1
        getMemoTxIdOutputIndexReceivedArguments = (txId: txId, outputIndex: outputIndex)
        if let closure = getMemoTxIdOutputIndexClosure {
            return try await closure(txId, outputIndex)
        } else {
            return getMemoTxIdOutputIndexReturnValue
        }
    }

    // MARK: - getTransparentBalance

    var getTransparentBalanceAccountThrowableError: Error?
    func setGetTransparentBalanceAccountThrowableError(_ param: Error?) async {
        getTransparentBalanceAccountThrowableError = param
    }
    var getTransparentBalanceAccountCallsCount = 0
    var getTransparentBalanceAccountCalled: Bool {
        return getTransparentBalanceAccountCallsCount > 0
    }
    var getTransparentBalanceAccountReceivedAccount: Int32?
    var getTransparentBalanceAccountReturnValue: Int64!
    func setGetTransparentBalanceAccountReturnValue(_ param: Int64) async {
        getTransparentBalanceAccountReturnValue = param
    }
    var getTransparentBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetTransparentBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getTransparentBalanceAccountClosure = param
    }

    func getTransparentBalance(account: Int32) async throws -> Int64 {
        if let error = getTransparentBalanceAccountThrowableError {
            throw error
        }
        getTransparentBalanceAccountCallsCount += 1
        getTransparentBalanceAccountReceivedAccount = account
        if let closure = getTransparentBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getTransparentBalanceAccountReturnValue
        }
    }

    // MARK: - initDataDb

    var initDataDbSeedThrowableError: Error?
    func setInitDataDbSeedThrowableError(_ param: Error?) async {
        initDataDbSeedThrowableError = param
    }
    var initDataDbSeedCallsCount = 0
    var initDataDbSeedCalled: Bool {
        return initDataDbSeedCallsCount > 0
    }
    var initDataDbSeedReceivedSeed: [UInt8]?
    var initDataDbSeedReturnValue: DbInitResult!
    func setInitDataDbSeedReturnValue(_ param: DbInitResult) async {
        initDataDbSeedReturnValue = param
    }
    var initDataDbSeedClosure: (([UInt8]?) async throws -> DbInitResult)?
    func setInitDataDbSeedClosure(_ param: (([UInt8]?) async throws -> DbInitResult)?) async {
        initDataDbSeedClosure = param
    }

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

    var listTransparentReceiversAccountThrowableError: Error?
    func setListTransparentReceiversAccountThrowableError(_ param: Error?) async {
        listTransparentReceiversAccountThrowableError = param
    }
    var listTransparentReceiversAccountCallsCount = 0
    var listTransparentReceiversAccountCalled: Bool {
        return listTransparentReceiversAccountCallsCount > 0
    }
    var listTransparentReceiversAccountReceivedAccount: Int32?
    var listTransparentReceiversAccountReturnValue: [TransparentAddress]!
    func setListTransparentReceiversAccountReturnValue(_ param: [TransparentAddress]) async {
        listTransparentReceiversAccountReturnValue = param
    }
    var listTransparentReceiversAccountClosure: ((Int32) async throws -> [TransparentAddress])?
    func setListTransparentReceiversAccountClosure(_ param: ((Int32) async throws -> [TransparentAddress])?) async {
        listTransparentReceiversAccountClosure = param
    }

    func listTransparentReceivers(account: Int32) async throws -> [TransparentAddress] {
        if let error = listTransparentReceiversAccountThrowableError {
            throw error
        }
        listTransparentReceiversAccountCallsCount += 1
        listTransparentReceiversAccountReceivedAccount = account
        if let closure = listTransparentReceiversAccountClosure {
            return try await closure(account)
        } else {
            return listTransparentReceiversAccountReturnValue
        }
    }

    // MARK: - getVerifiedBalance

    var getVerifiedBalanceAccountThrowableError: Error?
    func setGetVerifiedBalanceAccountThrowableError(_ param: Error?) async {
        getVerifiedBalanceAccountThrowableError = param
    }
    var getVerifiedBalanceAccountCallsCount = 0
    var getVerifiedBalanceAccountCalled: Bool {
        return getVerifiedBalanceAccountCallsCount > 0
    }
    var getVerifiedBalanceAccountReceivedAccount: Int32?
    var getVerifiedBalanceAccountReturnValue: Int64!
    func setGetVerifiedBalanceAccountReturnValue(_ param: Int64) async {
        getVerifiedBalanceAccountReturnValue = param
    }
    var getVerifiedBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetVerifiedBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getVerifiedBalanceAccountClosure = param
    }

    func getVerifiedBalance(account: Int32) async throws -> Int64 {
        if let error = getVerifiedBalanceAccountThrowableError {
            throw error
        }
        getVerifiedBalanceAccountCallsCount += 1
        getVerifiedBalanceAccountReceivedAccount = account
        if let closure = getVerifiedBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getVerifiedBalanceAccountReturnValue
        }
    }

    // MARK: - getVerifiedTransparentBalance

    var getVerifiedTransparentBalanceAccountThrowableError: Error?
    func setGetVerifiedTransparentBalanceAccountThrowableError(_ param: Error?) async {
        getVerifiedTransparentBalanceAccountThrowableError = param
    }
    var getVerifiedTransparentBalanceAccountCallsCount = 0
    var getVerifiedTransparentBalanceAccountCalled: Bool {
        return getVerifiedTransparentBalanceAccountCallsCount > 0
    }
    var getVerifiedTransparentBalanceAccountReceivedAccount: Int32?
    var getVerifiedTransparentBalanceAccountReturnValue: Int64!
    func setGetVerifiedTransparentBalanceAccountReturnValue(_ param: Int64) async {
        getVerifiedTransparentBalanceAccountReturnValue = param
    }
    var getVerifiedTransparentBalanceAccountClosure: ((Int32) async throws -> Int64)?
    func setGetVerifiedTransparentBalanceAccountClosure(_ param: ((Int32) async throws -> Int64)?) async {
        getVerifiedTransparentBalanceAccountClosure = param
    }

    func getVerifiedTransparentBalance(account: Int32) async throws -> Int64 {
        if let error = getVerifiedTransparentBalanceAccountThrowableError {
            throw error
        }
        getVerifiedTransparentBalanceAccountCallsCount += 1
        getVerifiedTransparentBalanceAccountReceivedAccount = account
        if let closure = getVerifiedTransparentBalanceAccountClosure {
            return try await closure(account)
        } else {
            return getVerifiedTransparentBalanceAccountReturnValue
        }
    }

    // MARK: - rewindToHeight

    var rewindToHeightHeightThrowableError: Error?
    func setRewindToHeightHeightThrowableError(_ param: Error?) async {
        rewindToHeightHeightThrowableError = param
    }
    var rewindToHeightHeightCallsCount = 0
    var rewindToHeightHeightCalled: Bool {
        return rewindToHeightHeightCallsCount > 0
    }
    var rewindToHeightHeightReceivedHeight: Int32?
    var rewindToHeightHeightClosure: ((Int32) async throws -> Void)?
    func setRewindToHeightHeightClosure(_ param: ((Int32) async throws -> Void)?) async {
        rewindToHeightHeightClosure = param
    }

    func rewindToHeight(height: Int32) async throws {
        if let error = rewindToHeightHeightThrowableError {
            throw error
        }
        rewindToHeightHeightCallsCount += 1
        rewindToHeightHeightReceivedHeight = height
        try await rewindToHeightHeightClosure!(height)
    }

    // MARK: - rewindCacheToHeight

    var rewindCacheToHeightHeightThrowableError: Error?
    func setRewindCacheToHeightHeightThrowableError(_ param: Error?) async {
        rewindCacheToHeightHeightThrowableError = param
    }
    var rewindCacheToHeightHeightCallsCount = 0
    var rewindCacheToHeightHeightCalled: Bool {
        return rewindCacheToHeightHeightCallsCount > 0
    }
    var rewindCacheToHeightHeightReceivedHeight: Int32?
    var rewindCacheToHeightHeightClosure: ((Int32) async throws -> Void)?
    func setRewindCacheToHeightHeightClosure(_ param: ((Int32) async throws -> Void)?) async {
        rewindCacheToHeightHeightClosure = param
    }

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
    func setPutSaplingSubtreeRootsStartIndexRootsThrowableError(_ param: Error?) async {
        putSaplingSubtreeRootsStartIndexRootsThrowableError = param
    }
    var putSaplingSubtreeRootsStartIndexRootsCallsCount = 0
    var putSaplingSubtreeRootsStartIndexRootsCalled: Bool {
        return putSaplingSubtreeRootsStartIndexRootsCallsCount > 0
    }
    var putSaplingSubtreeRootsStartIndexRootsReceivedArguments: (startIndex: UInt64, roots: [SubtreeRoot])?
    var putSaplingSubtreeRootsStartIndexRootsClosure: ((UInt64, [SubtreeRoot]) async throws -> Void)?
    func setPutSaplingSubtreeRootsStartIndexRootsClosure(_ param: ((UInt64, [SubtreeRoot]) async throws -> Void)?) async {
        putSaplingSubtreeRootsStartIndexRootsClosure = param
    }

    func putSaplingSubtreeRoots(startIndex: UInt64, roots: [SubtreeRoot]) async throws {
        if let error = putSaplingSubtreeRootsStartIndexRootsThrowableError {
            throw error
        }
        putSaplingSubtreeRootsStartIndexRootsCallsCount += 1
        putSaplingSubtreeRootsStartIndexRootsReceivedArguments = (startIndex: startIndex, roots: roots)
        try await putSaplingSubtreeRootsStartIndexRootsClosure!(startIndex, roots)
    }

    // MARK: - updateChainTip

    var updateChainTipHeightThrowableError: Error?
    func setUpdateChainTipHeightThrowableError(_ param: Error?) async {
        updateChainTipHeightThrowableError = param
    }
    var updateChainTipHeightCallsCount = 0
    var updateChainTipHeightCalled: Bool {
        return updateChainTipHeightCallsCount > 0
    }
    var updateChainTipHeightReceivedHeight: Int32?
    var updateChainTipHeightClosure: ((Int32) async throws -> Void)?
    func setUpdateChainTipHeightClosure(_ param: ((Int32) async throws -> Void)?) async {
        updateChainTipHeightClosure = param
    }

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
    func setFullyScannedHeightThrowableError(_ param: Error?) async {
        fullyScannedHeightThrowableError = param
    }
    var fullyScannedHeightCallsCount = 0
    var fullyScannedHeightCalled: Bool {
        return fullyScannedHeightCallsCount > 0
    }
    var fullyScannedHeightReturnValue: BlockHeight?
    func setFullyScannedHeightReturnValue(_ param: BlockHeight?) async {
        fullyScannedHeightReturnValue = param
    }
    var fullyScannedHeightClosure: (() async throws -> BlockHeight?)?
    func setFullyScannedHeightClosure(_ param: (() async throws -> BlockHeight?)?) async {
        fullyScannedHeightClosure = param
    }

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
    func setMaxScannedHeightThrowableError(_ param: Error?) async {
        maxScannedHeightThrowableError = param
    }
    var maxScannedHeightCallsCount = 0
    var maxScannedHeightCalled: Bool {
        return maxScannedHeightCallsCount > 0
    }
    var maxScannedHeightReturnValue: BlockHeight?
    func setMaxScannedHeightReturnValue(_ param: BlockHeight?) async {
        maxScannedHeightReturnValue = param
    }
    var maxScannedHeightClosure: (() async throws -> BlockHeight?)?
    func setMaxScannedHeightClosure(_ param: (() async throws -> BlockHeight?)?) async {
        maxScannedHeightClosure = param
    }

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

    // MARK: - getScanProgress

    var getScanProgressThrowableError: Error?
    func setGetScanProgressThrowableError(_ param: Error?) async {
        getScanProgressThrowableError = param
    }
    var getScanProgressCallsCount = 0
    var getScanProgressCalled: Bool {
        return getScanProgressCallsCount > 0
    }
    var getScanProgressReturnValue: ScanProgress?
    func setGetScanProgressReturnValue(_ param: ScanProgress?) async {
        getScanProgressReturnValue = param
    }
    var getScanProgressClosure: (() async throws -> ScanProgress?)?
    func setGetScanProgressClosure(_ param: (() async throws -> ScanProgress?)?) async {
        getScanProgressClosure = param
    }

    func getScanProgress() async throws -> ScanProgress? {
        if let error = getScanProgressThrowableError {
            throw error
        }
        getScanProgressCallsCount += 1
        if let closure = getScanProgressClosure {
            return try await closure()
        } else {
            return getScanProgressReturnValue
        }
    }

    // MARK: - suggestScanRanges

    var suggestScanRangesThrowableError: Error?
    func setSuggestScanRangesThrowableError(_ param: Error?) async {
        suggestScanRangesThrowableError = param
    }
    var suggestScanRangesCallsCount = 0
    var suggestScanRangesCalled: Bool {
        return suggestScanRangesCallsCount > 0
    }
    var suggestScanRangesReturnValue: [ScanRange]!
    func setSuggestScanRangesReturnValue(_ param: [ScanRange]) async {
        suggestScanRangesReturnValue = param
    }
    var suggestScanRangesClosure: (() async throws -> [ScanRange])?
    func setSuggestScanRangesClosure(_ param: (() async throws -> [ScanRange])?) async {
        suggestScanRangesClosure = param
    }

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

    var scanBlocksFromHeightLimitThrowableError: Error?
    func setScanBlocksFromHeightLimitThrowableError(_ param: Error?) async {
        scanBlocksFromHeightLimitThrowableError = param
    }
    var scanBlocksFromHeightLimitCallsCount = 0
    var scanBlocksFromHeightLimitCalled: Bool {
        return scanBlocksFromHeightLimitCallsCount > 0
    }
    var scanBlocksFromHeightLimitReceivedArguments: (fromHeight: Int32, limit: UInt32)?
    var scanBlocksFromHeightLimitClosure: ((Int32, UInt32) async throws -> Void)?
    func setScanBlocksFromHeightLimitClosure(_ param: ((Int32, UInt32) async throws -> Void)?) async {
        scanBlocksFromHeightLimitClosure = param
    }

    func scanBlocks(fromHeight: Int32, limit: UInt32) async throws {
        if let error = scanBlocksFromHeightLimitThrowableError {
            throw error
        }
        scanBlocksFromHeightLimitCallsCount += 1
        scanBlocksFromHeightLimitReceivedArguments = (fromHeight: fromHeight, limit: limit)
        try await scanBlocksFromHeightLimitClosure!(fromHeight, limit)
    }

    // MARK: - putUnspentTransparentOutput

    var putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError: Error?
    func setPutUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError(_ param: Error?) async {
        putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError = param
    }
    var putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount = 0
    var putUnspentTransparentOutputTxidIndexScriptValueHeightCalled: Bool {
        return putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount > 0
    }
    var putUnspentTransparentOutputTxidIndexScriptValueHeightReceivedArguments: (txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight)?
    var putUnspentTransparentOutputTxidIndexScriptValueHeightClosure: (([UInt8], Int, [UInt8], Int64, BlockHeight) async throws -> Void)?
    func setPutUnspentTransparentOutputTxidIndexScriptValueHeightClosure(_ param: (([UInt8], Int, [UInt8], Int64, BlockHeight) async throws -> Void)?) async {
        putUnspentTransparentOutputTxidIndexScriptValueHeightClosure = param
    }

    func putUnspentTransparentOutput(txid: [UInt8], index: Int, script: [UInt8], value: Int64, height: BlockHeight) async throws {
        if let error = putUnspentTransparentOutputTxidIndexScriptValueHeightThrowableError {
            throw error
        }
        putUnspentTransparentOutputTxidIndexScriptValueHeightCallsCount += 1
        putUnspentTransparentOutputTxidIndexScriptValueHeightReceivedArguments = (txid: txid, index: index, script: script, value: value, height: height)
        try await putUnspentTransparentOutputTxidIndexScriptValueHeightClosure!(txid, index, script, value, height)
    }

    // MARK: - shieldFunds

    var shieldFundsUskMemoShieldingThresholdThrowableError: Error?
    func setShieldFundsUskMemoShieldingThresholdThrowableError(_ param: Error?) async {
        shieldFundsUskMemoShieldingThresholdThrowableError = param
    }
    var shieldFundsUskMemoShieldingThresholdCallsCount = 0
    var shieldFundsUskMemoShieldingThresholdCalled: Bool {
        return shieldFundsUskMemoShieldingThresholdCallsCount > 0
    }
    var shieldFundsUskMemoShieldingThresholdReceivedArguments: (usk: UnifiedSpendingKey, memo: MemoBytes?, shieldingThreshold: Zatoshi)?
    var shieldFundsUskMemoShieldingThresholdReturnValue: Data!
    func setShieldFundsUskMemoShieldingThresholdReturnValue(_ param: Data) async {
        shieldFundsUskMemoShieldingThresholdReturnValue = param
    }
    var shieldFundsUskMemoShieldingThresholdClosure: ((UnifiedSpendingKey, MemoBytes?, Zatoshi) async throws -> Data)?
    func setShieldFundsUskMemoShieldingThresholdClosure(_ param: ((UnifiedSpendingKey, MemoBytes?, Zatoshi) async throws -> Data)?) async {
        shieldFundsUskMemoShieldingThresholdClosure = param
    }

    func shieldFunds(usk: UnifiedSpendingKey, memo: MemoBytes?, shieldingThreshold: Zatoshi) async throws -> Data {
        if let error = shieldFundsUskMemoShieldingThresholdThrowableError {
            throw error
        }
        shieldFundsUskMemoShieldingThresholdCallsCount += 1
        shieldFundsUskMemoShieldingThresholdReceivedArguments = (usk: usk, memo: memo, shieldingThreshold: shieldingThreshold)
        if let closure = shieldFundsUskMemoShieldingThresholdClosure {
            return try await closure(usk, memo, shieldingThreshold)
        } else {
            return shieldFundsUskMemoShieldingThresholdReturnValue
        }
    }

    // MARK: - consensusBranchIdFor


    nonisolated func consensusBranchIdFor(height: Int32) throws -> Int32 {
        try consensusBranchIdForHeightClosure!(height)
    }

    // MARK: - initBlockMetadataDb

    var initBlockMetadataDbThrowableError: Error?
    func setInitBlockMetadataDbThrowableError(_ param: Error?) async {
        initBlockMetadataDbThrowableError = param
    }
    var initBlockMetadataDbCallsCount = 0
    var initBlockMetadataDbCalled: Bool {
        return initBlockMetadataDbCallsCount > 0
    }
    var initBlockMetadataDbClosure: (() async throws -> Void)?
    func setInitBlockMetadataDbClosure(_ param: (() async throws -> Void)?) async {
        initBlockMetadataDbClosure = param
    }

    func initBlockMetadataDb() async throws {
        if let error = initBlockMetadataDbThrowableError {
            throw error
        }
        initBlockMetadataDbCallsCount += 1
        try await initBlockMetadataDbClosure!()
    }

    // MARK: - writeBlocksMetadata

    var writeBlocksMetadataBlocksThrowableError: Error?
    func setWriteBlocksMetadataBlocksThrowableError(_ param: Error?) async {
        writeBlocksMetadataBlocksThrowableError = param
    }
    var writeBlocksMetadataBlocksCallsCount = 0
    var writeBlocksMetadataBlocksCalled: Bool {
        return writeBlocksMetadataBlocksCallsCount > 0
    }
    var writeBlocksMetadataBlocksReceivedBlocks: [ZcashCompactBlock]?
    var writeBlocksMetadataBlocksClosure: (([ZcashCompactBlock]) async throws -> Void)?
    func setWriteBlocksMetadataBlocksClosure(_ param: (([ZcashCompactBlock]) async throws -> Void)?) async {
        writeBlocksMetadataBlocksClosure = param
    }

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
    func setLatestCachedBlockHeightThrowableError(_ param: Error?) async {
        latestCachedBlockHeightThrowableError = param
    }
    var latestCachedBlockHeightCallsCount = 0
    var latestCachedBlockHeightCalled: Bool {
        return latestCachedBlockHeightCallsCount > 0
    }
    var latestCachedBlockHeightReturnValue: BlockHeight!
    func setLatestCachedBlockHeightReturnValue(_ param: BlockHeight) async {
        latestCachedBlockHeightReturnValue = param
    }
    var latestCachedBlockHeightClosure: (() async throws -> BlockHeight)?
    func setLatestCachedBlockHeightClosure(_ param: (() async throws -> BlockHeight)?) async {
        latestCachedBlockHeightClosure = param
    }

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

}
