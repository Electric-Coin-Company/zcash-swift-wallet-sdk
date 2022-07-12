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

    private static func checkpoint(at url: URL) throws -> Checkpoint {
        let data = try Data(contentsOf: url)
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        return checkpoint
    }
}

struct BundleCheckpointURLProvider {
    var url: (NetworkType) -> URL
}


extension BundleCheckpointURLProvider {

    /// Attempts to resolve the platform by checking `#if os(macOS)` build corresponds to a MacOS target
    /// `#else` branch of that condition will assume iOS is the target platform
    static var `default` = BundleCheckpointURLProvider { networkType in
        #if os(macOS)
        Self.macOS.url(networkType)
        #else
        Self.iOS.url(networkType)
        #endif
    }

    static var iOS = BundleCheckpointURLProvider(url: { networkType in
        switch networkType {
        case .mainnet:
            return Checkpoint.mainnetCheckpointDirectory
        case .testnet:
            return Checkpoint.testnetCheckpointDirectory
        }
    })

    /// This variant attempts to retrieve the saplingActivation checkpoint for the given network type
    /// using `Bundle.module.url(forResource:withExtension:subdirectory:localization)`
    /// if not found it will return `WalletBirthday.mainnetCheckpointDirectory` or
    /// `WalletBirthday.testnetCheckpointDirectory`. This responds to tests
    /// failing on MacOS target because the checkpoint resources would fail.
    static var macOS = BundleCheckpointURLProvider(url: { networkType in
        switch networkType {
        case .mainnet:
            return Bundle.module.url(
                forResource: "419200",
                withExtension: "json",
                subdirectory: "checkpoints/mainnet/",
                localization: nil
            )?
            .deletingLastPathComponent() ?? Checkpoint.mainnetCheckpointDirectory
        case .testnet:
           return Bundle.module.url(
                forResource: "280000",
                withExtension: "json",
                subdirectory: "checkpoints/testnet/",
                localization: nil
            )?
            .deletingLastPathComponent() ?? Checkpoint.testnetCheckpointDirectory
        }
    })
}
