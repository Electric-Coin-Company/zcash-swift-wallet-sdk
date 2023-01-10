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

    func downloadAndStoreBlocks(
        using stream: BlocksDownloadStream,
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

    func removeCacheDB() async throws {
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
