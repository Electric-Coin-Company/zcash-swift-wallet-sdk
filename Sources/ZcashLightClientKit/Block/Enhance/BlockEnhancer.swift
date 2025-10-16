//
//  CompactBlockEnhancement.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 4/10/20.
//

import Foundation

public struct EnhancementProgress: Equatable {
    /// total transactions that were detected in the `range`
    public let totalTransactions: Int
    /// enhanced transactions so far
    public let enhancedTransactions: Int
    /// last found transaction
    public let lastFoundTransaction: ZcashTransaction.Overview?
    /// block range that's being enhanced
    public let range: CompactBlockRange
    /// whether this transaction can be considered `newly mined` and not part of the
    /// wallet catching up to stale and uneventful blocks.
    public let newlyMined: Bool

    public init(
        totalTransactions: Int,
        enhancedTransactions: Int,
        lastFoundTransaction: ZcashTransaction.Overview?,
        range: CompactBlockRange,
        newlyMined: Bool
    ) {
        self.totalTransactions = totalTransactions
        self.enhancedTransactions = enhancedTransactions
        self.lastFoundTransaction = lastFoundTransaction
        self.range = range
        self.newlyMined = newlyMined
    }

    public var progress: Float {
        totalTransactions > 0 ? Float(enhancedTransactions) / Float(totalTransactions) : 0
    }

    public static var zero: EnhancementProgress {
        EnhancementProgress(totalTransactions: 0, enhancedTransactions: 0, lastFoundTransaction: nil, range: 0...0, newlyMined: false)
    }

    public static func == (lhs: EnhancementProgress, rhs: EnhancementProgress) -> Bool {
        return
            lhs.totalTransactions == rhs.totalTransactions &&
            lhs.enhancedTransactions == rhs.enhancedTransactions &&
            lhs.lastFoundTransaction?.rawID == rhs.lastFoundTransaction?.rawID &&
            lhs.range == rhs.range
    }
}

protocol BlockEnhancer {
    func enhance(at range: CompactBlockRange, didEnhance: @escaping (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]?
}

struct BlockEnhancerImpl {
    let blockDownloaderService: BlockDownloaderService
    let rustBackend: ZcashRustBackendWelding
    let transactionRepository: TransactionRepository
    let metrics: SDKMetrics
    let service: LightWalletService
    let logger: Logger
    let sdkFlags: SDKFlags
}

extension BlockEnhancerImpl: BlockEnhancer {
    // swiftlint:disable:next cyclomatic_complexity
    func enhance(at range: CompactBlockRange, didEnhance: @escaping (EnhancementProgress) async -> Void) async throws -> [ZcashTransaction.Overview]? {
        try Task.checkCancellation()
        
        logger.debug("Started Enhancing range: \(range)")

        // fetch transactions
        do {
            let transactionDataRequests = try await rustBackend.transactionDataRequests()

            guard !transactionDataRequests.isEmpty else {
                logger.debug("No transaction data requests detected.")
                logger.sync("No transaction data requests detected.")
                return nil
            }

            for index in 0 ..< transactionDataRequests.count {
                let transactionDataRequest = transactionDataRequests[index]
                var retry = true
                var retries = 0
                let maxRetries = 5

                while retry && retries < maxRetries {
                    try Task.checkCancellation()
                    do {
                        switch transactionDataRequest {
                        case .getStatus(let txId):
                            let response = try await blockDownloaderService.fetchTransaction(
                                txId: txId.data,
                                mode: await sdkFlags.ifTor(ServiceMode.txIdGroup(prefix: "fetch", txId: txId.data))
                            )
                            retry = false

                            if let fetchedTransaction = response.tx {
                                try await rustBackend.setTransactionStatus(txId: fetchedTransaction.rawID, status: response.status)
                            }
                            
                        case .enhancement(let txId):
                            let response = try await blockDownloaderService.fetchTransaction(
                                txId: txId.data,
                                mode: await sdkFlags.ifTor(ServiceMode.txIdGroup(prefix: "fetch", txId: txId.data))
                            )
                            retry = false

                            if response.status == .txidNotRecognized {
                                try await rustBackend.setTransactionStatus(txId: txId.data, status: .txidNotRecognized)
                            } else if let fetchedTransaction = response.tx {
                                _ = try await rustBackend.decryptAndStoreTransaction(
                                    txBytes: fetchedTransaction.raw.bytes,
                                    minedHeight: fetchedTransaction.minedHeight
                                )
                            }

                        case .transactionsInvolvingAddress(let tia):
                            // TODO: [#1554] Remove this guard once lightwalletd servers support open-ended ranges.
                            guard tia.blockRangeEnd != nil else {
                                logger.error("transactionsInvolvingAddress \(tia) is missing blockRangeEnd, ignoring the request.")
                                retry = false
                                continue
                            }

                            // TODO: [#1551] Support this.
                            if tia.requestAt != nil {
                                logger.error("transactionsInvolvingAddress \(tia) has requestAt set, ignoring the unsupported request.")
                                retry = false
                                continue
                            }

                            // TODO: [#1552] Support the OutputStatusFilter
                            if tia.outputStatusFilter == .unspent {
                                retry = false
                                continue
                            }

                            var filter = TransparentAddressBlockFilter()
                            filter.address = tia.address
                            filter.range = if let blockRangeEnd = tia.blockRangeEnd {
                                BlockRange(startHeight: Int(tia.blockRangeStart), endHeight: Int(blockRangeEnd - 1))
                            } else {
                                BlockRange(startHeight: Int(tia.blockRangeStart))
                            }

                            // ServiceMode to resolve
                            let stream = try service.getTaddressTxids(filter, mode: .direct)

                            for try await rawTransaction in stream {
                                let minedHeight = (rawTransaction.height == 0 || rawTransaction.height > UInt32.max)
                                ? nil : UInt32(rawTransaction.height)

                                // Ignore transactions that don't match the status filter.
                                if (tia.txStatusFilter == .mined && minedHeight == nil) || (tia.txStatusFilter == .mempool && minedHeight != nil) {
                                    continue
                                }

                                _ = try await rustBackend.decryptAndStoreTransaction(
                                    txBytes: rawTransaction.data.bytes,
                                    minedHeight: minedHeight
                                )
                            }
                            retry = false
                        }
                    } catch {
                        retries += 1
                        logger.error("could not enhance transactionDataRequest \(transactionDataRequest) - Error: \(error)")
                    }
                }
            }
        } catch {
            logger.error("error enhancing transactions! \(error)")
            throw error
        }
        
        if Task.isCancelled {
            logger.debug("Warning: compactBlockEnhancement on range \(range) cancelled")
        }

        return (try? await transactionRepository.find(in: range, limit: Int.max, kind: .all))
    }
}
