//
//  BundleCheckpointURLProvider.swift
//  
//
//  Created by Francisco Gindre on 10/30/23.
//

import Foundation

struct BundleCheckpointURLProvider {
    var url: (NetworkType) -> URL
}

extension BundleCheckpointURLProvider {
    /// Attempts to resolve the platform by checking `#if os(macOS)` build corresponds to a MacOS target
    /// `#else` branch of that condition will assume iOS is the target platform
    static let `default` = BundleCheckpointURLProvider { networkType in
        #if os(macOS)
        Self.macOS.url(networkType)
        #else
        Self.iOS.url(networkType)
        #endif
    }

    static let iOS = BundleCheckpointURLProvider(url: { networkType in
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
    static let macOS = BundleCheckpointURLProvider(url: { networkType in
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
