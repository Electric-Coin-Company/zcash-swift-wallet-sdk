//
//  FigureNextBatchOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 6/17/21.
//

import Foundation

class FigureNextBatchOperation: ZcashOperation {
    enum NextState {
        case finishProcessing(height: BlockHeight)
        case processNewBlocks(range: CompactBlockRange)
        case wait(latestHeight: BlockHeight, latestDownloadHeight: BlockHeight)
    }
    
    private var service: LightWalletService
    private var downloader: CompactBlockDownloading
    private var config: CompactBlockProcessor.Configuration
    private var rustBackend: ZcashRustBackendWelding.Type
    private(set) var result: NextState?

    required init(
        downloader: CompactBlockDownloading,
        service: LightWalletService,
        config: CompactBlockProcessor.Configuration,
        rustBackend: ZcashRustBackendWelding.Type
    ) {
        self.service = service
        self.config = config
        self.downloader = downloader
        self.rustBackend = rustBackend

        super.init()

        self.name = "Next Batch Operation"
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }

        self.startedHandler?()
        
        do {
            result = try CompactBlockProcessor.NextStateHelper.nextState(
                service: self.service,
                downloader: self.downloader,
                config: self.config,
                rustBackend: self.rustBackend
            )
        } catch {
            self.fail(error: error)
        }
    }
}
