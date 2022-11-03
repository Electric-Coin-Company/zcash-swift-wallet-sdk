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

    func readBlocks(from stream: BlocksDownloadStream, at range: CompactBlockRange) async throws -> [ZcashCompactBlock] {
        var buffer: [ZcashCompactBlock] = []
        for _ in stride(from: range.lowerBound, to: range.upperBound + 1, by: 1) {
            try Task.checkCancellation()
            if let block = try await stream.nextBlock() {
                buffer.append(block)
            } else {
                break
            }
        }

        return buffer
    }

    func storeCompactBlocks(buffer: [ZcashCompactBlock]?) async throws {
        guard let buffer else { return }
        try await storage.write(blocks: buffer)
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

extension CompactBlockProcessor {
    enum CompactBlockBatchDownloadError: Error {
        case startHeightMissing
        case batchDownloadFailed(range: CompactBlockRange, error: Error?)
    }

    func compactBlockBatchDownload(
        range: CompactBlockRange,
        batchSize: Int = 100,
        maxRetries: Int = 5
    ) async throws {
        try Task.checkCancellation()
        
        var startHeight = range.lowerBound
        let targetHeight = range.upperBound
        
        do {
            let localDownloadedHeight = try await self.storage.latestHeightAsync()
            
            if localDownloadedHeight != BlockHeight.empty() && localDownloadedHeight > startHeight {
                LoggerProxy.warn("provided startHeight (\(startHeight)) differs from local latest downloaded height (\(localDownloadedHeight))")
                startHeight = localDownloadedHeight + 1
            }
            
            var currentHeight = startHeight

            while !Task.isCancelled && currentHeight <= targetHeight {
                var retries = 0
                var success = true
                var localError: Error?
                
                let range = CompactBlockRange(uncheckedBounds: (lower: currentHeight, upper: min(currentHeight + batchSize, targetHeight)))
                
                repeat {
                    do {
                        let stream: AsyncThrowingStream<ZcashCompactBlock, Error> = service.blockRange(range)

                        var blocks: [ZcashCompactBlock] = []
                        for try await compactBlock in stream {
                            blocks.append(compactBlock)
                        }
                        try storage.insert(blocks)
                        success = true
                    } catch {
                        success = false
                        localError = error
                        retries += 1
                    }
                } while !Task.isCancelled && !success && retries < maxRetries
                
                if retries >= maxRetries {
                    throw CompactBlockBatchDownloadError.batchDownloadFailed(range: range, error: localError)
                }
                                
                currentHeight = range.upperBound + 1
            }
        } catch {
            throw error
        }
    }
}
