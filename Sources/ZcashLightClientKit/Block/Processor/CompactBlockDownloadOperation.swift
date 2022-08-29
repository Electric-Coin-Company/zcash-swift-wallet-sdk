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
    private var cancelableTask: Task<Void, Error>?
    private var startHeight: BlockHeight?
    private var targetHeight: BlockHeight?
    private var blockBufferSize: Int
    private var buffer: [ZcashCompactBlock] = []

    private weak var progressDelegate: CompactBlockProgressDelegate?

    /// Creates an Compact Block Stream Download Operation Operation
    ///  - Parameters:
    ///    - service: instance that conforms to `LightWalletService`
    ///    - storage: instance that conforms to `CompactBlockStorage`
    ///    - blockBufferSize: the number of blocks that the stream downloader will store in memory
    ///    before writing them to disk. Making this number smaller makes the downloader easier on RAM
    ///    memory while being less efficient on disk writes. Making it bigger takes up more RAM memory
    ///    but is less straining on Disk Writes. Too little or too big buffer will make this less efficient.
    ///    - startHeight: the height this downloader will start downloading from. If `nil`,
    ///    it will start from the latest height found on the local cacheDb
    ///    - targetHeight: the upper bound for this stream download. If `nil`, the
    ///    streamer will call `service.latestBlockHeight()`
    ///    - progressDelegate: Optional delegate to report ongoing progress conforming to
    ///    `CompactBlockProgressDelegate`
    ///
    required init(
        service: LightWalletService,
        storage: CompactBlockStorage,
        blockBufferSize: Int,
        startHeight: BlockHeight? = nil,
        targetHeight: BlockHeight? = nil,
        progressDelegate: CompactBlockProgressDelegate? = nil
    ) {
        self.storage = storage
        self.service = service
        self.startHeight = startHeight
        self.targetHeight = targetHeight
        self.progressDelegate = progressDelegate
        self.blockBufferSize = blockBufferSize
        super.init()
        self.name = "Download Stream Operation"
    }
    
    override func main() {
        guard !shouldCancel() else {
            cancel()
            return
        }
        self.startedHandler?()
        
        cancelableTask = Task {
            do {
                if self.targetHeight == nil {
                    self.targetHeight = try await service.latestBlockHeightAsync()
                }
                guard let latestHeight = self.targetHeight else {
                    throw LightWalletServiceError.generalError(message: "missing target height on block stream operation")
                }
                let latestDownloaded = try await storage.latestHeightAsync()
                let startHeight = max(self.startHeight ?? BlockHeight.empty(), latestDownloaded)
                
                let stream = service.blockStream(
                    startHeight: startHeight,
                    endHeight: latestHeight
                )
                
                for try await zcashCompactBlock in stream {
                    try self.cache(zcashCompactBlock, flushCache: false)
                    let progress = BlockProgress(
                        startHeight: startHeight,
                        targetHeight: latestHeight,
                        progressHeight: zcashCompactBlock.height
                    )
                    self.progressDelegate?.progressUpdated(.download(progress))
                }
                try self.flush()
                self.done = true
            } catch {
                if let err = error as? LightWalletServiceError, case .userCancelled = err {
                    self.done = true
                } else {
                    self.fail(error: error)
                }
            }
        }
        
        while !done && !isCancelled {
            sleep(1)
        }
    }

    override func fail(error: Error? = nil) {
        self.cancelableTask?.cancel()
        super.fail(error: error)
    }
    
    override func cancel() {
        self.cancelableTask?.cancel()
        super.cancel()
    }

    func cache(_ block: ZcashCompactBlock, flushCache: Bool) throws {
        self.buffer.append(block)

        if flushCache || buffer.count >= blockBufferSize {
            try flush()
        }
    }

    func flush() throws {
        try self.storage.write(blocks: self.buffer)
        self.buffer.removeAll(keepingCapacity: true)
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

    required init(
        service: LightWalletService,
        storage: CompactBlockStorage,
        startHeight: BlockHeight,
        targetHeight: BlockHeight,
        batchSize: Int = 100,
        maxRetries: Int = 5,
        progressDelegate: CompactBlockProgressDelegate? = nil
    ) {
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
            self.progressDelegate?.progressUpdated(
                .download(
                    BlockProgress(
                        startHeight: currentHeight,
                        targetHeight: targetHeight,
                        progressHeight: currentHeight
                    )
                )
            )
            
            while !isCancelled && currentHeight <= targetHeight {
                var retries = 0
                var success = true
                var localError: Error?
            
                let range = nextRange(currentHeight: currentHeight, targetHeight: targetHeight)
                
                repeat {
                    do {
                        let blocks = try service.blockRange(range)
                        try storage.insert(blocks)
                        success = true
                    } catch {
                        success = false
                        localError = error
                        retries += 1
                    }
                } while !isCancelled && !success && retries < maxRetries

                if retries >= maxRetries {
                    throw CompactBlockBatchDownloadOperationError.batchDownloadFailed(range: range, error: localError)
                }
                
                self.progressDelegate?.progressUpdated(
                    .download(
                        BlockProgress(
                            startHeight: startHeight,
                            targetHeight: targetHeight,
                            progressHeight: range.upperBound
                        )
                    )
                )

                currentHeight = range.upperBound + 1
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

    func nextRange(currentHeight: BlockHeight, targetHeight: BlockHeight) -> CompactBlockRange {
        CompactBlockRange(uncheckedBounds: (lower: currentHeight, upper: min(currentHeight + batch, targetHeight)))
    }
}
