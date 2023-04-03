//
//  File.swift
//  
//
//  Created by Francisco Gindre on 3/31/23.
//

import Foundation
@testable import ZcashLightClientKit

extension SDKSynchronizer {
    convenience init(initializer: Initializer, sessionGenerator: SyncSessionIDGenerator, sessionTicker: SessionTicker) {
        let metrics = SDKMetrics()
        self.init(
            status: .unprepared,
            initializer: initializer,
            transactionManager: OutboundTransactionManagerBuilder.build(initializer: initializer),
            transactionRepository: initializer.transactionRepository,
            utxoRepository: UTXORepositoryBuilder.build(initializer: initializer),
            blockProcessor: CompactBlockProcessor(
                initializer: initializer,
                metrics: metrics,
                logger: initializer.logger,
                walletBirthdayProvider: { initializer.walletBirthday }
            ),
            metrics: metrics,
            syncSessionIDGenerator: sessionGenerator,
            syncSessionTicker: sessionTicker
        )
    }
}
