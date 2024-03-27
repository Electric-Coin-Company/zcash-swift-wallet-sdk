//
//  CheckpointSourceFactory.swift
//
//
//  Created by Francisco Gindre on 2023-10-30.
//

import Foundation

enum CheckpointSourceFactory {
    static func fromBundle(for network: NetworkType) -> CheckpointSource {
        BundleCheckpointSource(network: network)
    }
}
