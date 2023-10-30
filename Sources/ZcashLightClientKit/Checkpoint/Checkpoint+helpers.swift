//
//  WalletBirthday+Constants.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 7/28/21.
//

import Foundation

extension Checkpoint {
    static func birthday(with height: BlockHeight, network: ZcashNetwork) -> Checkpoint {
        let checkpointDirectoryURL = BundleCheckpointURLProvider.default.url(network.networkType)

        switch network.networkType {
        case .mainnet:
            return birthday(with: height, checkpointDirectory: checkpointDirectoryURL) ?? .mainnetMin
        case .testnet:
            return birthday(with: height, checkpointDirectory: checkpointDirectoryURL) ?? .testnetMin
        }
    }
}

extension Checkpoint {
    static func birthday(with height: BlockHeight, checkpointDirectory: URL) -> Checkpoint? {
        return bestCheckpointHeight(for: height, checkpointDirectory: checkpointDirectory)
            .flatMap { checkpoint(height: $0, directory: checkpointDirectory) }
    }

    private static func bestCheckpointHeight(for height: BlockHeight, checkpointDirectory: URL) -> Int? {
        guard let checkPointURLs = try? FileManager.default.contentsOfDirectory(
            at: checkpointDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return nil
        }

        return checkPointURLs
            .map { $0.deletingPathExtension() }
            .map(\.lastPathComponent)
            .compactMap(Int.init)
            .filter { $0 <= height }
            .sorted()
            .last
    }

    private static func checkpoint(height: BlockHeight, directory checkpointDirectory: URL) -> Checkpoint? {
        let url = checkpointDirectory
            .appendingPathComponent(String(height))
            .appendingPathExtension("json")

        return try? checkpoint(at: url)
    }

    /// - Throws:
    ///     - `checkpointCantLoadFromDisk` if can't load JSON with checkpoint from disk.
    private static func checkpoint(at url: URL) throws -> Checkpoint {
        do {
            let data = try Data(contentsOf: url)
            let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
            return checkpoint
        } catch {
            throw ZcashError.checkpointCantLoadFromDisk(error)
        }
    }
}
