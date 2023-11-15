//
//  CheckpointSourceFactory.swift
//
//
//  Created by Francisco Gindre on 2023-10-30.
//

import Foundation

struct CheckpointSourceFactory {
    static func fromBundle(for network: NetworkType) -> CheckpointSource {
        BundleCheckpointSource(network: network)
    }
}
