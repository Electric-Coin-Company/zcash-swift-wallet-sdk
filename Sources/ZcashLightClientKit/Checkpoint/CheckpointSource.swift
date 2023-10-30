//
//  CheckpointSource.swift
//
//
//  Created by Francisco Gindre on 10/30/23.
//

import Foundation

/// A protocol that abstracts the requirements around obtaining wallet checkpoints
/// (also known as TreeStates).
protocol CheckpointSource {
    /// `NetworkType` of this Checkpoint source
    var network: NetworkType { get }

    /// The `Checkpoint` that represents the block in which Sapling was activated
    var saplingActivation: Checkpoint { get }

    /// Obtain the latest `Checkpoint` in terms of block height known by
    /// this `CheckpointSource`. It is possible that the returned checkpoint
    /// is not the latest checkpoint that exists in the blockchain.
    /// - Returns a `Checkpoint` with the highest height known by this source
    func latestKnownCheckpoint() -> Checkpoint

    /// Obtain a `Checkpoint` in terms of a "wallet birthday". Wallet birthday
    /// is estimated to be the latest height of the Zcash blockchain at the moment when the wallet was
    /// created.
    /// - Parameter height: Estimated or effective height known for the wallet birthday
    /// - Returns: a `Checkpoint` that will allow the wallet to manage funds from the given `height`
    /// onwards.
    /// - Note: When the user knows the exact height of the first received funds for a wallet,
    /// the effective birthday of that wallet is `transaction.height - 1`.
    func birthday(for height: BlockHeight) -> Checkpoint
}
