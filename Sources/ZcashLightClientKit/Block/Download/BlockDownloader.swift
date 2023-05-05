//
//  CompactBlockDownload.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

private class BlockDownloaderStream {
    let stream: AsyncThrowingStream<ZcashCompactBlock, Error>
    var iterator: AsyncThrowingStream<ZcashCompactBlock, Error>.Iterator

    init(stream: AsyncThrowingStream<ZcashCompactBlock, Error>) {
        self.stream = stream
        self.iterator = stream.makeAsyncIterator()
    }

    func nextBlock() async throws -> ZcashCompactBlock? {
        return try await iterator.next()
    }
}

/// Described object which can download blocks.
protocol BlockDownloader {
    /// Set max height to which blocks will be downloaded. If this is higher than upper bound of the whole range then upper bound of the whole range
    /// is used as limit.
    func setDownloadLimit(_ limit: BlockHeight) async

    /// Set the range for the whole sync process. This method creates stream that is used to download blocks.
    /// This method must be called before `startDownload()` is called. And it can't be called while download is in progress otherwise bad things
    /// happen.
    func setSyncRange(_ range: CompactBlockRange) async throws

    /// Start downloading blocks.
    ///
    /// This methods creates new detached Task which is used to do the actual downloading.
    ///
    /// It's possible to call this methods anytime. If any download is already in progress nothing happens.
    /// If the download limit is changed while download is in progress then blocks within new limit are downloaded automatically.
    /// If the downlading finishes and then limit is changed you must call this method to start downloading.
    ///
    /// - Parameters:
    ///   - maxBlockBufferSize: Number of blocks that is held in memory before blocks are written to disk.
    ///   - syncRange: Whole range in which blocks should be downloaded. This should be sync range.
    func startDownload(maxBlockBufferSize: Int, syncRange: CompactBlockRange) async

    /// Stop download. This method cancels Task used for downloading. And then it is waiting until internal `isDownloading` flag is set to `false`
    func stopDownload() async

    /// Waits until blocks from `range` are downloaded. This method does just the waiting. If `startDownload(maxBlockBufferSize:syncRange:)` isn't
    /// called before then nothing is downloaded.
    /// - Parameter range: Wait until blocks from `range` are downloaded.
    func waitUntilRequestedBlocksAreDownloaded(in range: CompactBlockRange) async throws
}

actor BlockDownloaderImpl {
    let service: LightWalletService
    let downloaderService: BlockDownloaderService
    let storage: CompactBlockRepository
    let internalSyncProgress: InternalSyncProgress
    let metrics: SDKMetrics
    let logger: Logger

    private var downloadStream: BlockDownloaderStream?

    private var downloadToHeight: BlockHeight = 0
    private var isDownloading = false
    private var task: Task<Void, Error>?
    private var lastError: Error?

    init(
        service: LightWalletService,
        downloaderService: BlockDownloaderService,
        storage: CompactBlockRepository,
        internalSyncProgress: InternalSyncProgress,
        metrics: SDKMetrics,
        logger: Logger
    ) {
        self.service = service
        self.downloaderService = downloaderService
        self.storage = storage
        self.internalSyncProgress = internalSyncProgress
        self.metrics = metrics
        self.logger = logger
    }

    private func doDownload(maxBlockBufferSize: Int, syncRange: CompactBlockRange) async {
        lastError = nil
        do {
            guard let downloadStream = self.downloadStream else {
                logger.error("Dont have downloadStream. Trying to download blocks before sync range is not set.")
                throw ZcashError.blockDownloadSyncRangeNotSet
            }

            let latestDownloadedBlockHeight = await internalSyncProgress.load(.latestDownloadedBlockHeight)

            let downloadFrom = max(syncRange.lowerBound, latestDownloadedBlockHeight + 1)
            let downloadTo = min(downloadToHeight, syncRange.upperBound)

            if downloadFrom > downloadTo {
                logger.debug("""
                Download from \(downloadFrom) is higher or same as dowload to \(downloadTo). All blocks are probably downloaded. Exiting.
                """)
                isDownloading = false
                task = nil
                return
            }

            let range = downloadFrom...downloadTo

            logger.debug("""
            Starting downloading blocks.
            syncRange:                   \(syncRange.lowerBound)...\(syncRange.upperBound)
            downloadToHeight:            \(downloadToHeight)
            latestDownloadedBlockHeight: \(latestDownloadedBlockHeight)
            range:                       \(range.lowerBound)...\(range.upperBound)
            """)

            try await downloadAndStoreBlocks(
                using: downloadStream,
                at: range,
                maxBlockBufferSize: maxBlockBufferSize,
                totalProgressRange: syncRange
            )

            task = nil
            if downloadToHeight > range.upperBound {
                logger.debug("""
                Finished downloading with range: \(range.lowerBound)...\(range.upperBound). Going to start new download.
                range upper bound:      \(range.upperBound)
                new downloadToHeight:   \(downloadToHeight)
                """)
                await startDownload(maxBlockBufferSize: maxBlockBufferSize, syncRange: syncRange)
                logger.debug("finishing after start download")
            } else {
                logger.debug("Finished downloading with range: \(range.lowerBound)...\(range.upperBound)")
                isDownloading = false
            }
        } catch {
            lastError = error
            if Task.isCancelled {
                logger.debug("Blocks downloading canceled.")
            } else {
                logger.error("Blocks downloading failed: \(error)")
            }
            isDownloading = false
            task = nil
        }
    }

    private func compactBlocksDownloadStream(startHeight: BlockHeight, targetHeight: BlockHeight) async throws -> BlockDownloaderStream {
        try Task.checkCancellation()
        let stream = service.blockStream(startHeight: startHeight, endHeight: targetHeight)
        return BlockDownloaderStream(stream: stream)
    }

    private func downloadAndStoreBlocks(
        using stream: BlockDownloaderStream,
        at range: CompactBlockRange,
        maxBlockBufferSize: Int,
        totalProgressRange: CompactBlockRange
    ) async throws {
        var buffer: [ZcashCompactBlock] = []
        logger.debug("Downloading blocks in range: \(range.lowerBound)...\(range.upperBound)")

        var startTime = Date()
        var counter = 0
        var lastDownloadedBlockHeight = -1

        let pushMetrics: (BlockHeight, Date, Date) -> Void = { [metrics] lastDownloadedBlockHeight, startTime, finishTime in
            metrics.pushProgressReport(
                progress: BlockProgress(
                    startHeight: totalProgressRange.lowerBound,
                    targetHeight: totalProgressRange.upperBound,
                    progressHeight: Int(lastDownloadedBlockHeight)
                ),
                start: startTime,
                end: finishTime,
                batchSize: maxBlockBufferSize,
                operation: .downloadBlocks
            )
        }

        for _ in stride(from: range.lowerBound, to: range.upperBound + 1, by: 1) {
            try Task.checkCancellation()
            guard let block = try await stream.nextBlock() else { break }

            counter += 1
            lastDownloadedBlockHeight = block.height

            buffer.append(block)
            if buffer.count >= maxBlockBufferSize {
                let finishTime = Date()
                try await storage.write(blocks: buffer)
                await blocksBufferWritten(buffer)
                buffer.removeAll(keepingCapacity: true)

                pushMetrics(block.height, startTime, finishTime)

                counter = 0
                startTime = finishTime
            }
        }

        if counter > 0 {
            pushMetrics(lastDownloadedBlockHeight, startTime, Date())
        }

        try await storage.write(blocks: buffer)
        await blocksBufferWritten(buffer)
    }

    private func blocksBufferWritten(_ buffer: [ZcashCompactBlock]) async {
        guard let lastBlock = buffer.last else { return }
        await internalSyncProgress.set(lastBlock.height, .latestDownloadedBlockHeight)
    }
}

extension BlockDownloaderImpl: BlockDownloader {
    func setDownloadLimit(_ limit: BlockHeight) async {
        downloadToHeight = limit
    }

    func setSyncRange(_ range: CompactBlockRange) async throws {
        downloadStream = try await compactBlocksDownloadStream(startHeight: range.lowerBound, targetHeight: range.upperBound)
    }

    func startDownload(maxBlockBufferSize: Int, syncRange: CompactBlockRange) async {
        guard task == nil else {
            logger.debug("Download already in progress.")
            return
        }
        isDownloading = true
        task = Task.detached() { [weak self] in
            // Solve when self is nil, task should be niled.
            await self?.doDownload(maxBlockBufferSize: maxBlockBufferSize, syncRange: syncRange)
        }
    }

    func stopDownload() async {
        task?.cancel()
        task = nil
        while isDownloading {
            do {
                try await Task.sleep(milliseconds: 10)
            } catch {
                break
            }
        }
    }

    func waitUntilRequestedBlocksAreDownloaded(in range: CompactBlockRange) async throws {
        logger.debug("Waiting until requested blocks are downloaded at \(range)")
        var latestDownloadedBlock = await internalSyncProgress.load(.latestDownloadedBlockHeight)
        while latestDownloadedBlock < range.upperBound {
            if let error = lastError {
                throw error
            }
            try await Task.sleep(milliseconds: 10)
            latestDownloadedBlock = await internalSyncProgress.load(.latestDownloadedBlockHeight)
        }
        logger.debug("Waiting done. Blocks are downloaded at \(range)")
    }
}
