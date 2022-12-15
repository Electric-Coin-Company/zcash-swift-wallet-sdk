//
//  CompactBlockDownload.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class BlockDownloaderStream {
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
    /// Create stream that can be used to download blocks for specific range.
    func compactBlocksDownloadStream(startHeight: BlockHeight, targetHeight: BlockHeight) async throws -> BlockDownloaderStream

    /// Read (download) blocks from stream and store those in storage.
    /// - Parameters:
    ///   - stream: Stream used to read blocks.
    ///   - range: Range used to compute how many blocks to download.
    ///   - maxBlockBufferSize: Max amount of blocks that can be held in memory.
    ///   - totalProgressRange: Range that contains height for the whole sync process. This is used to compute progress.
    func downloadAndStoreBlocks(
        using stream: BlockDownloaderStream,
        at range: CompactBlockRange,
        maxBlockBufferSize: Int,
        totalProgressRange: CompactBlockRange
    ) async throws
}

class BlockDownloaderImpl {
    let service: LightWalletService
    let downloaderService: BlockDownloaderService
    let storage: CompactBlockRepository
    let internalSyncProgress: InternalSyncProgress

    init(
        service: LightWalletService,
        downloaderService: BlockDownloaderService,
        storage: CompactBlockRepository,
        internalSyncProgress: InternalSyncProgress
    ) {
        self.service = service
        self.downloaderService = downloaderService
        self.storage = storage
        self.internalSyncProgress = internalSyncProgress
    }
}

extension BlockDownloaderImpl: BlockDownloader {
    func compactBlocksDownloadStream(startHeight: BlockHeight, targetHeight: BlockHeight) async throws -> BlockDownloaderStream {
        try Task.checkCancellation()
        let stream = service.blockStream(startHeight: startHeight, endHeight: targetHeight)
        return BlockDownloaderStream(stream: stream)
    }

    func downloadAndStoreBlocks(
        using stream: BlockDownloaderStream,
        at range: CompactBlockRange,
        maxBlockBufferSize: Int,
        totalProgressRange: CompactBlockRange
    ) async throws {
        var buffer: [ZcashCompactBlock] = []
        LoggerProxy.debug("Downloading blocks in range: \(range.lowerBound)...\(range.upperBound)")

        var startTime = Date()
        var counter = 0
        var lastDownloadedBlockHeight = -1

        let pushMetrics: (BlockHeight, Date, Date) -> Void = { lastDownloadedBlockHeight, startTime, finishTime in
            SDKMetrics.shared.pushProgressReport(
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
