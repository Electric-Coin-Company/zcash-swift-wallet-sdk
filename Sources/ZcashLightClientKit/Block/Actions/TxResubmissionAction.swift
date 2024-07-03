//
//  TxResubmissionAction.swift
//
//
//  Created by Lukas Korba on 06-17-2024.
//

import Foundation

final class TxResubmissionAction {
    private enum Constants {
        static let thresholdToTrigger = TimeInterval(300.0)
    }
    
    var latestResolvedTime: TimeInterval = 0
    let transactionRepository: TransactionRepository
    let transactionEncoder: TransactionEncoder
    let logger: Logger

    init(container: DIContainer) {
        transactionRepository = container.resolve(TransactionRepository.self)
        transactionEncoder = container.resolve(TransactionEncoder.self)
        logger = container.resolve(Logger.self)
    }
}

extension TxResubmissionAction: Action {
    var removeBlocksCacheWhenFailed: Bool { true }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        let latestBlockHeight = await context.syncControlData.latestBlockHeight
        
        // find all candidates for the resubmission
        do {
            logger.info("TxResubmissionAction check started at \(latestBlockHeight) height.")
            let transactions = try await transactionRepository.findForResubmission(upTo: latestBlockHeight)

            // no candidates, update the time and continue with the next action
            if transactions.isEmpty {
                latestResolvedTime = Date().timeIntervalSince1970
            } else {
                let now = Date().timeIntervalSince1970
                let diff = now - latestResolvedTime
                
                // the last time resubmission was triggered is more than 5 minutes ago so try again
                if diff > Constants.thresholdToTrigger {
                    // resubmission
                    do {
                        for transaction in transactions {
                            logger.info("TxResubmissionAction trying to resubmit transaction \(transaction.rawID.toHexStringTxId()).")
                            let encodedTransaction = try transaction.encodedTransaction()
                            
                            try await transactionEncoder.submit(transaction: encodedTransaction)
                        }
                    } catch {
                        logger.error("TxResubmissionAction failed to resubmit candidates.")
                    }
                    
                    latestResolvedTime = Date().timeIntervalSince1970
                }
            }
        } catch {
            logger.error("TxResubmissionAction failed to find candidates.")
        }
        
        if await context.prevState == .enhance {
            await context.update(state: .updateChainTip)
        } else {
            await context.update(state: .finished)
        }
        return context
    }

    func stop() async { }
}
