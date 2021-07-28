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
        self.startedHandler?()
        do {
            try downloader.downloadBlockRange(range)
        } catch {
            self.error = error
            self.fail()
        }
    }
}

protocol CompactBlockProgressDelegate: AnyObject {
    func progressUpdated(_ progress: CompactBlockProgress)
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
    private weak var progressDelegate: CompactBlockProgressDelegate?
    required init(service: LightWalletService,
                  storage: CompactBlockStorage,
                  startHeight: BlockHeight? = nil,
                  targetHeight: BlockHeight? = nil,
                  progressDelegate: CompactBlockProgressDelegate? = nil) {
        
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
        self.startedHandler?()
        do {
            
            if self.targetHeight == nil {
                self.targetHeight = try service.latestBlockHeight()
            }
            guard let latestHeight = self.targetHeight else {
                throw LightWalletServiceError.generalError(message: "missing target height on block stream operation")
            }
            let latestDownloaded = try storage.latestHeight()
            let startHeight = max(self.startHeight ?? BlockHeight.empty(), latestDownloaded)
            
            self.cancelable = self.service.blockStream(startHeight: startHeight, endHeight: latestHeight) { [weak self] result in
                switch result {
                
                case .success(let r):
                    switch r {
                    case .ok:
                        self?.done = true
                        return
                    case .error(let e):
                        self?.fail(error: e)
                    }
                case .failure(let e):
                    if case .userCancelled = e {
                        self?.done = true
                    } else {
                        self?.fail(error: e)
                    }
                }
               
            } handler: {[weak self] block in
                guard let self = self else { return }
                do {
                    try self.storage.insert(block)
                } catch {
                    self.fail(error: error)
                }
            } progress: { progress in
                self.progressDelegate?.progressUpdated(.download(progress))
            }
            
            while !done && !isCancelled {
                sleep(1)
            }
        } catch {
            self.fail(error: error)
        }
    }
    override func fail(error: Error? = nil) {
        self.cancelable?.cancel()
        super.fail(error: error)
    }
    
    override func cancel() {
        self.cancelable?.cancel()
        super.cancel()
    }
}

class CompactBlockBatchDownloadOperation: ZcashOperation {
    enum CompactBlockBatchDownloadOperationError: Error {
        case startHeightMissing
        case batchDownloadFailed(range: CompactBlockRange, error: Error?)
    }
    override var isConcurrent: Bool { false }
    
    override var isAsynchronous: Bool { false }
    
    private var batch: Int
    private var maxRetries: Int
    private var storage: CompactBlockStorage
    private var service: LightWalletService
    private var cancelable: CancellableCall?
    private var startHeight: BlockHeight
    private var targetHeight: BlockHeight
    private weak var progressDelegate: CompactBlockProgressDelegate?
    required init(service: LightWalletService,
                  storage: CompactBlockStorage,
                  startHeight: BlockHeight,
                  targetHeight: BlockHeight,
                  batchSize: Int = 100,
                  maxRetries: Int = 5,
                  progressDelegate: CompactBlockProgressDelegate? = nil) {
        
        self.storage = storage
        self.service = service
        self.startHeight = startHeight
        self.targetHeight = targetHeight
        self.progressDelegate = progressDelegate
        self.batch = batchSize
        self.maxRetries = maxRetries
        super.init()
        self.name = "Download Batch Operation"
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        self.startedHandler?()
        do {
           
            let localDownloadedHeight = try self.storage.latestHeight()
            
            if localDownloadedHeight != BlockHeight.empty() && localDownloadedHeight > startHeight {
                LoggerProxy.warn("provided startHeight (\(startHeight)) differs from local latest downloaded height (\(localDownloadedHeight))")
                startHeight = localDownloadedHeight + 1
            }
            
            var currentHeight = startHeight
            self.progressDelegate?.progressUpdated(.download(BlockProgress(startHeight: currentHeight, targetHeight: targetHeight, progressHeight: currentHeight)))
            
            while !isCancelled && currentHeight <= targetHeight {
                var retries = 0
                var success = true
                var localError: Error? = nil
            
                let range = nextRange(currentHeight: currentHeight, targetHeight: targetHeight)
                
                repeat {
                    do {
                        let blocks = try service.blockRange(range)
                        try storage.insert(blocks)
                        success = true
                       
                    } catch {
                        success = false
                        localError = error
                        retries = retries + 1
                    }
                } while !isCancelled && !success && retries < maxRetries
                if retries >= maxRetries {
                    throw CompactBlockBatchDownloadOperationError.batchDownloadFailed(range: range, error: localError)
                }
                
                self.progressDelegate?.progressUpdated(.download(BlockProgress(startHeight: startHeight, targetHeight: targetHeight, progressHeight: range.upperBound)))
                currentHeight = range.upperBound + 1
            }
        } catch {
            self.fail(error: error)
        }
    }
    
    func nextRange(currentHeight: BlockHeight, targetHeight: BlockHeight) -> CompactBlockRange {
        CompactBlockRange(uncheckedBounds: (lower: currentHeight, upper: min(currentHeight + batch, targetHeight)))
    }
    override func fail(error: Error? = nil) {
        self.cancelable?.cancel()
        super.fail(error: error)
    }
    
    override func cancel() {
        self.cancelable?.cancel()
        super.cancel()
    }
}
