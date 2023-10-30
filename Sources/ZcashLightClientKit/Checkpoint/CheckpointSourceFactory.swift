//
//  CheckpointSourceFactory.swift
//
//
//  Created by Francisco Gindre on 10/30/23.
//

import Foundation

struct CheckpointSourceFactory {
    static func fromBundle(for network: NetworkType) -> CheckpointSource {
        BundleCheckpointSource(network: network)
    }
}
