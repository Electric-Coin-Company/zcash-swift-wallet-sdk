//
//  CompactBlockDownload.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

extension CompactBlockProcessor {

    class BlocksDownloadStream {
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

    func downloadAndScanBlocks(at range: CompactBlockRange, totalProgressRange: CompactBlockRange) async throws {
        let downloadStream = try await compactBlocksDownloadStream(
            startHeight: range.lowerBound,
            targetHeight: range.upperBound
        )

        // Divide `range` by `batchSize` and compute how many time do we need to run to download and scan all the blocks.
        // +1 must be done here becase `range` is closed range. So even if upperBound and lowerBound are same there is one block to sync.
        let blocksCountToSync = (range.upperBound - range.lowerBound) + 1
        var loopsCount = blocksCountToSync / batchSize
        if blocksCountToSync % batchSize != 0 {
            loopsCount += 1
        }

        for i in 0..<loopsCount {
            let processingRange = computeSingleLoopDownloadRange(fullRange: range, loopCounter: i, batchSize: batchSize)

            LoggerProxy.debug("Sync loop #\(i+1) range: \(processingRange.lowerBound)...\(processingRange.upperBound)")

            try await downloadAndStoreBlocks(using: downloadStream, at: processingRange, maxBlockBufferSize: config.downloadBufferSize)
            try await compactBlockValidation()
            try await compactBlockBatchScanning(range: processingRange)
            try await removeCacheDB()

            let progress = BlockProgress(
                startHeight: totalProgressRange.lowerBound,
                targetHeight: totalProgressRange.upperBound,
                progressHeight: processingRange.upperBound
            )
            notifyProgress(.syncing(progress))
        }
    }

    /*
     Here range for one batch is computed. For example if we want to sync blocks 0...1000 with batchSize 100 we want to generage blocks like
     this:
     0...99
     100...199
     200...299
     300...399
     ...
     900...999
     1000...1000
     */
    func computeSingleLoopDownloadRange(fullRange: CompactBlockRange, loopCounter: Int, batchSize: BlockHeight) -> CompactBlockRange {
        let lowerBound = fullRange.lowerBound + (loopCounter * batchSize)
        let upperBound = min(fullRange.lowerBound + ((loopCounter+1) * batchSize) - 1, fullRange.upperBound)
        return lowerBound...upperBound
    }

    func compactBlocksDownloadStream(
        startHeight: BlockHeight? = nil,
        targetHeight: BlockHeight? = nil
    ) async throws -> BlocksDownloadStream {
        try Task.checkCancellation()

        var targetHeightInternal: BlockHeight? = targetHeight
        if targetHeight == nil {
            targetHeightInternal = try await service.latestBlockHeightAsync()
        }
        guard let latestHeight = targetHeightInternal else {
            throw LightWalletServiceError.generalError(message: "missing target height on compactBlockStreamDownload")
        }
        try Task.checkCancellation()
        let latestDownloaded = try await storage.latestHeightAsync()
        let startHeight = max(startHeight ?? BlockHeight.empty(), latestDownloaded)

        let stream = service.blockStream(
            startHeight: startHeight,
            endHeight: latestHeight
        )

        return BlocksDownloadStream(stream: stream)
    }

    func downloadAndStoreBlocks(using stream: BlocksDownloadStream, at range: CompactBlockRange, maxBlockBufferSize: Int) async throws {
        var buffer: [ZcashCompactBlock] = []
        LoggerProxy.debug("Downloading blocks in range: \(range.lowerBound)...\(range.upperBound)")
        for _ in stride(from: range.lowerBound, to: range.upperBound + 1, by: 1) {
            try Task.checkCancellation()
            guard let block = try await stream.nextBlock() else { break }

            buffer.append(block)
            if buffer.count >= maxBlockBufferSize {
                try await storage.write(blocks: buffer)
                await blocksBufferWritten(buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        try await storage.write(blocks: buffer)
        await blocksBufferWritten(buffer)
    }

    private func removeCacheDB() async throws {
        storage.closeDBConnection()
        try FileManager.default.removeItem(at: config.cacheDb)
        try storage.createTable()
        LoggerProxy.info("Cache removed")
    }

    private func blocksBufferWritten(_ buffer: [ZcashCompactBlock]) async {
        guard let lastBlock = buffer.last else { return }
        await internalSyncProgress.set(lastBlock.height, .latestDownloadedBlockHeight)
    }
}

extension CompactBlockProcessor {
    func compactBlockDownload(
        downloader: CompactBlockDownloading,
        range: CompactBlockRange
    ) async throws {
        try Task.checkCancellation()
        
        do {
            try await downloader.downloadBlockRange(range)
        } catch {
            throw error
        }
    }
}
