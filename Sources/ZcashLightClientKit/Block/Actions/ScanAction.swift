//
//  ScanAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class ScanAction {
    enum Constants {
        static let reportDelay = 5
    }
    
    let configProvider: CompactBlockProcessor.ConfigProvider
    let blockScanner: BlockScanner
    let rustBackend: ZcashRustBackendWelding
    let latestBlocksDataProvider: LatestBlocksDataProvider
    let logger: Logger
    var progressReportReducer = 0

    init(container: DIContainer, configProvider: CompactBlockProcessor.ConfigProvider) {
        self.configProvider = configProvider
        blockScanner = container.resolve(BlockScanner.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        latestBlocksDataProvider = container.resolve(LatestBlocksDataProvider.self)
        logger = container.resolve(Logger.self)
    }

    private func update(context: ActionContext) async -> ActionContext {
        await context.update(state: .clearAlreadyScannedBlocks)
        return context
    }
}

extension ScanAction: Action {
    var removeBlocksCacheWhenFailed: Bool { true }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        guard let lastScannedHeight = await context.lastScannedHeight else {
            return await update(context: context)
        }

        let config = await configProvider.config
        let latestBlockHeight = await context.syncControlData.latestBlockHeight
        // This action is executed for each batch (batch size is 100 blocks by default) until all the blocks in whole `scanRange` are scanned.
        // So the right range for this batch must be computed.
        let batchRangeStart = lastScannedHeight
        let batchRangeEnd = min(latestBlockHeight, batchRangeStart + config.batchSize)

        guard batchRangeStart <= batchRangeEnd else {
            return await update(context: context)
        }

        let batchRange = batchRangeStart...batchRangeEnd
        
        logger.debug("Starting scan blocks with range: \(batchRange.lowerBound)...\(batchRange.upperBound)")
        logger.sync("Starting scan blocks with range \(batchRange.lowerBound)...\(batchRange.upperBound)")

        do {
            try await blockScanner.scanBlocks(at: batchRange) { [weak self] lastScannedHeight, increment in
                let processedHeight = await context.processedHeight
                let incrementedProcessedHeight = processedHeight + BlockHeight(increment)
                await context.update(processedHeight: incrementedProcessedHeight)
                await self?.latestBlocksDataProvider.updateScannedData()

                // ScanAction is controlled locally so it must report back the updated scanned height
                await context.update(lastScannedHeight: lastScannedHeight)
            }
            
            // This is a simple change that reduced the synchronization time significantly while affecting the UX only a bit.
            // The frequency of UI progress update is lowered x5 times.
            // Proper solution is handled in
            // TODO: [#1353] Advanced progress reporting, https://github.com/Electric-Coin-Company/zcash-swift-wallet-sdk/issues/1353
            if progressReportReducer == 0 {
                // report scan progress only if it's available
                if let scanProgress = try? await rustBackend.getWalletSummary()?.scanProgress {
                    let progress = try scanProgress.progress()
                    logger.debug("progress: \(progress)")
                    await didUpdate(.syncProgress(progress))
                }
                progressReportReducer = Constants.reportDelay
            } else {
                progressReportReducer -= 1
            }
        } catch ZcashError.rustScanBlocks(let errorMsg) {
            if isContinuityError(errorMsg) {
                await context.update(requestedRewindHeight: batchRange.lowerBound - 10)
                await context.update(state: .rewind)
                return context
            } else {
                throw ZcashError.rustScanBlocks(errorMsg)
            }
        } catch {
            throw error
        }

        return await update(context: context)
    }

    func stop() async { 
        progressReportReducer = 0
    }
}

private extension ScanAction {
    func isContinuityError(_ errorMsg: String) -> Bool {
        errorMsg.contains("The parent hash of proposed block does not correspond to the block hash at height")
        || errorMsg.contains("Block height discontinuity at height")
        || errorMsg.contains("note commitment tree size provided by a compact block did not match the expected size at height")
    }
}
