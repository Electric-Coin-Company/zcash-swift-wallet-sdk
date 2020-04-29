//
//  TestCoordinator.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/29/20.
//

import Foundation
@testable import ZcashLightClientKit

class TestCoordinator {
    enum SyncThreshold {
        case upTo(height: BlockHeight)
        case latestHeight
    }
    
    func sync(_ :Synchronizer, to: SyncThreshold, completion: (Synchronizer) -> Void, error: (Error) -> Void) {
        
    }
    
    func reorg(at: BlockHeight, backTo: BlockHeight) {
        
    }
    
    
}


class TestSynchronizerBuilder {
    
    static func build(
                        rustBackend: ZcashRustBackendWelding.Type,
                        lowerBoundHeight: BlockHeight,
                        cacheDbURL: URL,
                        dataDbURL: URL,
                        pendingDbURL: URL,
                        service: LightWalletService,
                        repository: TransactionRepository,
                        downloader: CompactBlockDownloader,
                        spendParamsURL: URL,
                        outputParamsURL: URL,
                        seedBytes: [UInt8],
                        walletBirthday: WalletBirthday,
                        loggerProxy: Logger? = nil
                    ) throws -> (credentials: [String]?, synchronizer: Synchronizer) {
        
        let initializer = Initializer(
                                      rustBackend: rustBackend,
                                      lowerBoundHeight: lowerBoundHeight,
                                      cacheDbURL: cacheDbURL,
                                      dataDbURL: dataDbURL,
                                      pendingDbURL: pendingDbURL,
                                      service: service,
                                      repository: repository,
                                      downloader: downloader,
                                      spendParamsURL: spendParamsURL,
                                      outputParamsURL: outputParamsURL,
                                      loggerProxy: loggerProxy
                            )

        return (
            try initializer.initialize(seedProvider: StubSeedProvider(bytes: seedBytes), walletBirthdayHeight: walletBirthday.height),
            try SDKSynchronizer(initializer: initializer)
            )
    }
}

class StubSeedProvider: SeedProvider {
    
    let bytes: [UInt8]
    init(bytes: [UInt8]) {
        self.bytes = bytes
    }
    func seed() -> [UInt8] {
        self.bytes
    }
}
