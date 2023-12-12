//
//  BundleCheckpointSource.swift
//
//
//  Created by Francisco Gindre on 2023-10-30.
//

import Foundation

struct BundleCheckpointSource: CheckpointSource {
    var network: NetworkType
    
    var saplingActivation: Checkpoint
    
    init(network: NetworkType) {
        self.network = network
        self.saplingActivation = switch network {
        case .mainnet:
            Checkpoint.mainnetMin
        case .testnet:
            Checkpoint.testnetMin
        }
    }

    func latestKnownCheckpoint() -> Checkpoint {
        Checkpoint.birthday(
            with: .max,
            checkpointDirectory: BundleCheckpointURLProvider.default.url(self.network)
        ) ?? saplingActivation
    }
    
    func birthday(for height: BlockHeight) -> Checkpoint {
        Checkpoint.birthday(
            with: height,
            checkpointDirectory: BundleCheckpointURLProvider.default.url(self.network)
        ) ?? saplingActivation
    }
}
