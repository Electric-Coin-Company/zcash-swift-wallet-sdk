//
//  CheckpointSourceFactory.swift
//
//
//  Created by Francisco Gindre on 10/30/23.
//

import Foundation

struct CheckpointSourceFactory {
    static func fromBundle(for network: NetworkType) -> CheckpointSource {
        Placeholder()
    }
}

// TODO: Remove this

struct Placeholder: CheckpointSource {
    var network: NetworkType { .mainnet }

    var saplingActivation: Checkpoint {
        Checkpoint(
            height: 1,
            hash: "deadbeef",
            time: 1,
            saplingTree: """
            000000
            """,
            orchardTree: """
            000000
            """
        )
    }

    func latestKnownCheckpoint() -> ZcashLightClientKit.Checkpoint {
        Checkpoint(
            height: 1,
            hash: "deadbeef",
            time: 1,
            saplingTree: """
            000000
            """,
            orchardTree: """
            000000
            """
        )
    }

    func birthday(for height: BlockHeight) -> Checkpoint {
        Checkpoint(
            height: 1,
            hash: "deadbeef",
            time: 1,
            saplingTree: """
            000000
            """,
            orchardTree: """
            000000
            """
        )
    }
}

