//
//  CompactBlockFsStorage.swift
//  
//
//  Created by Francisco Gindre on 12/15/22.
//

import Foundation

class FSCompactBlockRepository {
    let fsBlockDbRoot: URL
    let blockDescriptor: ZcashCompactBlockDescriptor
    let contentProvider: SortedDirectoryListing
    let fileWriter: FSBlockFileWriter
    let metadataStore: FSMetadataStore

    private let fileManager = FileManager()
    private let storageBatchSize = 10

    var blocksDirectory: URL {
        fsBlockDbRoot.appendingPathComponent("blocks", isDirectory: true)
    }

    /// Initializes an instance of the Filesystem based compact block repository
    /// - Parameter fsBlockDbRoot: The `URL` pointing to where the blocks should be writen
    /// write access must be **guaranteed**.
    /// - Parameter blockDescriptor: A `ZcashCompactBlockDescriptor` that is used to turn a
    /// `ZcashCompactBlock` into the filename that will hold it on cache
    /// - parameter contentProvider: `SortedDirectoryListing` implementation. This injects the
    /// behaviour of traversing a Directory in an ordered fashion which is not guaranteed by `Foundation`'s `FileManager`
    init(
        fsBlockDbRoot: URL,
        metadataStore: FSMetadataStore,
        blockDescriptor: ZcashCompactBlockDescriptor,
        contentProvider: SortedDirectoryListing,
        fileWriter: FSBlockFileWriter = .atomic
    ) {
        self.fsBlockDbRoot = fsBlockDbRoot
        self.metadataStore = metadataStore
        self.blockDescriptor = blockDescriptor
        self.contentProvider = contentProvider
        self.fileWriter = fileWriter
    }
}

extension FSCompactBlockRepository: CompactBlockRepository {
    func create() throws {
        if !fileManager.fileExists(atPath: blocksDirectory.path) {
            try fileManager.createDirectory(at: blocksDirectory, withIntermediateDirectories: true)
        }

        guard try self.metadataStore.initFsBlockDbRoot(self.fsBlockDbRoot) else {
            throw CompactBlockRepositoryError.failedToInitializeCache
        }
    }

    func latestHeight() -> BlockHeight {
        metadataStore.latestHeight()
    }

    func latestHeightAsync() async -> BlockHeight {
        await metadataStore.latestHeightAsync()
    }

    func write(blocks: [ZcashCompactBlock]) async throws {
        do {
            var savedBlocks: [ZcashCompactBlock] = []

            for block in blocks {
                // check if file exists
                let blockURL = self.urlForBlock(block)

                if self.blockExistsInCache(block) {
                    // remove if needed
                    try self.fileManager.removeItem(at: blockURL)
                }

                // store atomically
                do {
                    try self.fileWriter.writeToURL(block.data, blockURL)
                } catch {
                    LoggerProxy.error("Failed to write block: \(block.height) to path: \(blockURL.path) with error: \(error)")
                    throw CompactBlockRepositoryError.failedToWriteBlock(block)
                }

                savedBlocks.append(block)

                if (savedBlocks.count % storageBatchSize) == 0 {
                    try await self.metadataStore.saveBlocksMeta(savedBlocks)
                    savedBlocks.removeAll(keepingCapacity: true)
                }
            }

            // if there are any remaining blocks on the cache store them
            try await self.metadataStore.saveBlocksMeta(savedBlocks)
        } catch {
            LoggerProxy.error("failed to Block save to cache error: \(error.localizedDescription)")
            throw error
        }
    }

    func rewind(to height: BlockHeight) throws {
        try metadataStore.rewindToHeight(height)
        // Reverse the cached contents to browse from higher to lower heights
        let sortedCachedContents = try contentProvider.listContents(of: blocksDirectory)

        // it that bears no elements then there's nothing to do.
        guard let deleteList = try Self.filterBlockFiles(
            from: sortedCachedContents,
            toRewind: height,
            with: self.blockDescriptor
        ),
            !deleteList.isEmpty
        else { return }

        for item in deleteList {
            try self.fileManager.removeItem(at: item)
        }
    }

    func rewindAsync(to height: BlockHeight) async throws {
        try await Task {
            try rewind(to: height)
        }.value
    }

    func clear() async throws {
        try await Task {
            if self.fileManager.fileExists(atPath: self.fsBlockDbRoot.path) {
                try self.fileManager.removeItem(at: self.fsBlockDbRoot)
            }
            try create()
        }.value
    }
}

extension FSCompactBlockRepository {
    static let filenameComparison: (String, String) -> Int? = { lhs, rhs in
        guard
            let leftHeightStr = lhs.split(separator: "-").first,
            let leftHeight = BlockHeight(leftHeightStr),
            let rightHeightStr = rhs.split(separator: "-").first,
            let rightHeight = BlockHeight(rightHeightStr)
        else { return nil }

        return leftHeight - rightHeight
    }

    static let filenameDescription: (ZcashCompactBlock) -> String = { block in
        [
            "\(block.height)",
            block.meta.hash.toHexStringTxId(),
            "compactblock"
        ]
            .joined(separator: "-")
    }

    static let filenameToHeight: (String) -> BlockHeight? = { block in
        block.split(separator: "-")
            .first
            .flatMap { BlockHeight(String($0)) }
    }
}

extension FSCompactBlockRepository {
    /// Filters block files from a sorted list of filenames from the FsCache directory
    /// with the goal of rewinding up to height `toHeight` and parsing the filenames
    /// with the given `blockDescriptor`
    /// - note: it is assumed that the `sortedList` is ascending.
    /// - Parameter sortedList: ascending list of block filenames
    /// - Parameter toHeight:
    static func filterBlockFiles(
        from sortedList: [URL],
        toRewind toHeight: BlockHeight,
        with blockDescriptor: ZcashCompactBlockDescriptor
    ) throws -> [URL]? {
        // Reverse the cached contents to browse from higher to lower heights
        let sortedCachedContents = sortedList.reversed()

        // pick the blocks that are higher than the rewind height
        // then return their URLs
        let deleteList = try sortedCachedContents.filter({ url in
            guard let filename = try url.resourceValues(forKeys: [.nameKey]).name else {
                throw CompactBlockRepositoryError.malformedCacheEntry("failed to get url \(url) from cache")
            }

            return try filename.filterGreaterThan(toHeight, with: blockDescriptor)
        })

        guard !deleteList.isEmpty else { return nil }

        return deleteList
    }

    func urlForBlock(_ block: ZcashCompactBlock) -> URL {
        self.blocksDirectory.appendingPathComponent(
            self.blockDescriptor.describe(block)
        )
    }

    func blockExistsInCache(_ block: ZcashCompactBlock) -> Bool {
        self.fileManager.fileExists(
            atPath: urlForBlock(block).path
        )
    }
}
// MARK: Associated and Helper types

struct FSBlockFileWriter {
    var writeToURL: (Data, URL) throws -> Void
}

extension FSBlockFileWriter {
    static let atomic = FSBlockFileWriter(writeToURL: { data, url in
        try data.write(to: url, options: .atomic)
    })
}

struct FSMetadataStore {
    var saveBlocksMeta: ([ZcashCompactBlock]) async throws -> Void
    var rewindToHeight: (BlockHeight) throws -> Void
    var initFsBlockDbRoot: (URL) throws -> Bool
    var latestHeightAsync: () async -> BlockHeight
    var latestHeight: () -> BlockHeight
}

extension FSMetadataStore {
    static func live(fsBlockDbRoot: URL, rustBackend: ZcashRustBackendWelding.Type) -> FSMetadataStore {
        FSMetadataStore { blocks in
            try await FSMetadataStore.saveBlocksMeta(
                blocks,
                fsBlockDbRoot: fsBlockDbRoot,
                rustBackend: rustBackend
            )
        } rewindToHeight: { height in
            guard rustBackend.rewindCacheToHeight(fsBlockDbRoot: fsBlockDbRoot, height: Int32(height)) else {
                throw CompactBlockRepositoryError.failedToRewind(height)
            }
        } initFsBlockDbRoot: { dbRootURL in
            try rustBackend.initBlockMetadataDb(fsBlockDbRoot: dbRootURL)
        } latestHeightAsync: {
            await Task { rustBackend.latestCachedBlockHeight(fsBlockDbRoot: fsBlockDbRoot) }.value
        } latestHeight: {
            rustBackend.latestCachedBlockHeight(fsBlockDbRoot: fsBlockDbRoot)
        }
    }
}

extension FSMetadataStore {
    /// saves blocks to the FsBlockDb metadata database.
    /// - Parameter blocks: Array of `ZcashCompactBlock` to save
    /// - Throws `CompactBlockRepositoryError.failedToWriteMetadata` if the
    /// operation fails. the underlying error is logged through `LoggerProxy`
    /// - Note: This shouldn't be called in parallel by many threads or workers. Won't do anything if `blocks` is empty
    static func saveBlocksMeta(_ blocks: [ZcashCompactBlock], fsBlockDbRoot: URL, rustBackend: ZcashRustBackendWelding.Type) async throws {
        guard !blocks.isEmpty else { return }

        do {
            guard try rustBackend.writeBlocksMetadata(fsBlockDbRoot: fsBlockDbRoot, blocks: blocks) else {
                throw CompactBlockRepositoryError.failedToWriteMetadata
            }
        } catch {
            LoggerProxy.error("Failed to write metadata with error: \(error)")
            throw CompactBlockRepositoryError.failedToWriteMetadata
        }
    }
}

struct ZcashCompactBlockDescriptor {
    var height: (String) -> BlockHeight?
    var describe: (ZcashCompactBlock) -> String
    var compare: (String, String) -> Int?
}

extension ZcashCompactBlockDescriptor {
    /// describes the block following this convention: `HEIGHT-BLOCKHASHHEX-compactblock`
    static let live = ZcashCompactBlockDescriptor(
        height: FSCompactBlockRepository.filenameToHeight,
        describe: FSCompactBlockRepository.filenameDescription,
        compare: FSCompactBlockRepository.filenameComparison
    )
}

enum DirectoryListingProviders {
    /// returns an ascending list of files from a given directory.
    static let `defaultSorted` = SortedDirectoryContentProvider(
        fileManager: FileManager.default,
        sorting: URL.areInIncreasingOrderByFilename
    )

    /// the default sorting of FileManager
    static let naive = FileManager.default
}

class SortedDirectoryContentProvider: SortedDirectoryListing {
    let fileManager: FileManager
    let sorting: (URL, URL) throws -> Bool
    let recursive: Bool

    /// inits the `SortedDirectoryContentProvider`
    /// - Parameter fileManager: an instance of `FileManager`
    /// - Parameter sorting: A predicate that returns `true` if its
    ///   first argument should be ordered before its second argument;
    ///   otherwise, `false`.
    /// - Parameter recursive: make this list subdirectories. Default
    init(fileManager: FileManager, sorting: @escaping (URL, URL) throws -> Bool, recursive: Bool = false) {
        self.fileManager = fileManager
        self.sorting = sorting
        self.recursive = recursive
    }

    /// lists the contents of the given directory on `url` using the
    /// sorting provided by `sorting` property of this provider.
    /// - Parameter url: url to list the contents from. It must be a directory or the call will fail.
    /// - Returns an array with the contained files or an empty one if the directory is empty
    /// - Throws rethrows any errors from the underlying `FileManager`
    func listContents(of url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
            options: recursive ? [] : .skipsSubdirectoryDescendants
        )
        .sorted(by: sorting)
    }
}

protocol SortedDirectoryListing {
    func listContents(of url: URL) throws -> [URL]
}

// MARK: Extensions
extension URL {
    /// asumes that URLs are from the same directory for efficiency reasons
    static let areInIncreasingOrderByFilename: (URL, URL) throws -> Bool = { lhs, rhs in
        guard
            let lhsName = try lhs.resourceValues(forKeys: [.nameKey, .isDirectoryKey]).name,
            let rhsName = try rhs.resourceValues(forKeys: [.nameKey, .isDirectoryKey]).name else {
            throw URLError(URLError.badURL)
        }

        guard let strcmp = FSCompactBlockRepository.filenameComparison(lhsName, rhsName) else { throw URLError(URLError.badURL) }

        return strcmp < 0
    }
}

extension FileManager: SortedDirectoryListing {
    func listContents(of url: URL) throws -> [URL] {
        try contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
            options: .skipsSubdirectoryDescendants
        )
    }
}

extension String {
    /// a sorting filter to be used on URL or path arrays from `FileManager`.
    /// - Parameter height: the height of the block we want to filter from
    /// - Parameter descriptor: The block descriptor that corresponds to the filename
    /// convention of the FsBlockDb
    /// - Returns if the height from this filename is greater that the one received by parameter
    /// - Throws `CompactBlockRepositoryError.malformedCacheEntry` if this String
    /// can't be parsed by the given `ZcashCompactBlockDescriptor`
    func filterGreaterThan(_ height: BlockHeight, with descriptor: ZcashCompactBlockDescriptor) throws -> Bool {
        guard let blockHeight = descriptor.height(self) else {
            throw CompactBlockRepositoryError.malformedCacheEntry("couldn't retrieve filename from file \(self)")
        }

        return blockHeight > height
    }
}
