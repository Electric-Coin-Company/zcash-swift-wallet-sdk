//
//  CompactBlockDownloadOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class CompactBlockDownloadOperation: ZcashOperation {
    
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    private var downloader: CompactBlockDownloading
    
    private var range: CompactBlockRange
    
    required init(downloader: CompactBlockDownloading, range: CompactBlockRange) {
        self.range = range
        self.downloader = downloader
        super.init()
        self.name = "Download Operation: \(range)"
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        do {
            try downloader.downloadBlockRange(range)
        } catch {
            self.error = error
            self.fail()
        }
    }
}

protocol BlockStreamProgressDelegate: AnyObject {
    func progressUpdated(_ progress: BlockStreamProgressReporting)
}

class CompactBlockStreamDownloadOperation: ZcashOperation {
    enum CompactBlockStreamDownloadOperationError: Error {
        case startHeightMissing
    }
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    private var storage: CompactBlockStorage
    private var service: LightWalletService
    private var done = false
    private var cancelable: CancellableCall?
    private var startHeight: BlockHeight?
    private var targetHeight: BlockHeight?
    private weak var progressDelegate: BlockStreamProgressDelegate?
    required init(service: LightWalletService,
                  storage: CompactBlockStorage,
                  startHeight: BlockHeight? = nil,
                  targetHeight: BlockHeight? = nil,
                  progressDelegate: BlockStreamProgressDelegate? = nil) {
        
        self.storage = storage
        self.service = service
        self.startHeight = startHeight
        self.targetHeight = targetHeight
        self.progressDelegate = progressDelegate
        super.init()
        self.name = "Download Stream Operation"
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        do {
            
            if self.targetHeight == nil {
                self.targetHeight = try service.latestBlockHeight()
            }
            guard let latestHeight = self.targetHeight else {
                throw LightWalletServiceError.generalError(message: "missing target height on block stream operation")
            }
            let latestDownloaded = try storage.latestHeight()
            let startHeight = max(self.startHeight ?? BlockHeight.empty(), latestDownloaded)
            guard startHeight > ZcashSDK.SAPLING_ACTIVATION_HEIGHT else {
                throw CompactBlockStreamDownloadOperationError.startHeightMissing
            }
            
            self.cancelable = self.service.blockStream(startHeight: startHeight, endHeight: latestHeight) { [weak self] result in
                switch result {
                
                case .success(let r):
                    switch r {
                    case .ok:
                        self?.done = true
                        return
                    case .error(let e):
                        self?.error = e
                        self?.fail()
                    }
                case .failure(let e):
                    self?.error = e
                    self?.fail()
                }
               
            } handler: {[weak self] block in
                guard let self = self else { return }
                do {
                    try self.storage.insert(block)
                } catch {
                    self.error = error
                    self.fail()
                }
            } progress: { progress in
                self.progressDelegate?.progressUpdated(progress)
            }
            
            while !done && !isCancelled {
                sleep(1)
            }
        } catch {
            self.error = error
            self.fail()
        }
    }
}
