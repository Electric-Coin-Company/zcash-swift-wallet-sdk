//
//  CompactBlockDownload.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

extension CompactBlockProcessor {
    func compactBlockStreamDownload(
        blockBufferSize: Int,
        startHeight: BlockHeight? = nil,
        targetHeight: BlockHeight? = nil
    ) async throws {
        try Task.checkCancellation()
        
        state = .downloading
        
        var buffer: [ZcashCompactBlock] = []
        var targetHeightInternal: BlockHeight?
        
        do {
            targetHeightInternal = targetHeight
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
            
            for try await zcashCompactBlock in stream {
                try Task.checkCancellation()
                buffer.append(zcashCompactBlock)
                if buffer.count >= blockBufferSize {
                    try await storage.write(blocks: buffer)
                    buffer.removeAll(keepingCapacity: true)
                }
                
                let progress = BlockProgress(
                    startHeight: startHeight,
                    targetHeight: latestHeight,
                    progressHeight: zcashCompactBlock.height
                )
                notifyProgress(.download(progress))
            }
            try await storage.write(blocks: buffer)
            buffer.removeAll(keepingCapacity: true)
        } catch {
            guard let err = error as? LightWalletServiceError, case .userCancelled = err else {
                throw error
            }
        }
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
            notifyProgress(
                .download(
                    BlockProgress(
                        startHeight: currentHeight,
                        targetHeight: targetHeight,
                        progressHeight: currentHeight
                    )
                )
            )
            
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
                
                notifyProgress(
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
            throw error
        }
    }
}
