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

    required init(downloader: CompactBlockDownloading,
                  service: LightWalletService,
                  config: CompactBlockProcessor.Configuration,
                  rustBackend: ZcashRustBackendWelding.Type) {
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
            let info = try service.getInfo()
            
            try CompactBlockProcessor.validateServerInfo(info, saplingActivation: config.saplingActivation, rustBackend: self.rustBackend)
            
            // get latest block height
            let latestDownloadedBlockHeight: BlockHeight = max(config.walletBirthday,try downloader.lastDownloadedBlockHeight())
            let latestBlockheight = BlockHeight(info.blockHeight)
            
            if latestDownloadedBlockHeight < latestBlockheight {
                result = .processNewBlocks(range: CompactBlockProcessor.nextBatchBlockRange(latestHeight: latestBlockheight, latestDownloadedHeight: latestDownloadedBlockHeight, walletBirthday: config.walletBirthday))
            } else if latestBlockheight == latestDownloadedBlockHeight {
                result = .finishProcessing(height: latestBlockheight)
            } else {
                result = .wait(latestHeight: latestBlockheight, latestDownloadHeight: latestBlockheight)
            }
        } catch {
            self.fail(error: error)
        }
    }
}
