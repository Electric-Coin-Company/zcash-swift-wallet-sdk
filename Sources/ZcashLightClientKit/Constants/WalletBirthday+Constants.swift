//
//  WalletBirthday+Constants.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 7/28/21.
//

import Foundation

public extension WalletBirthday {
  static func birthday(with height: BlockHeight, network: ZcashNetwork) -> WalletBirthday {
    switch network.networkType {
    case .mainnet:
      return birthday(with: height, checkpointDirectory: Self.mainnetCheckpointDirectory) ?? .mainnetMin
    case .testnet:
      return birthday(with: height, checkpointDirectory: Self.testnetCheckpointDirectory) ?? .testnetMin
    }
  }
}

extension WalletBirthday {
  static func birthday(with height: BlockHeight, checkpointDirectory: URL) -> WalletBirthday? {
    return bestCheckpointHeight(for: height, checkpointDirectory: checkpointDirectory)
      .flatMap { checkpoint(height: $0, directory: checkpointDirectory) }
  }

  private static func bestCheckpointHeight(for height: BlockHeight, checkpointDirectory: URL) -> Int? {
    guard let checkPointsInFolder = try? FileManager.default.contentsOfDirectory(atPath: checkpointDirectory.absoluteString) else {
      return nil
    }

    return checkPointsInFolder
      .compactMap(Int.init)
      .filter { $0 <= height }
      .sorted()
      .last
  }

  private static func checkpoint(height: BlockHeight, directory checkpointDirectory: URL) -> WalletBirthday? {
    let url = checkpointDirectory
      .appendingPathComponent(String(height))
      .appendingPathExtension("json")

    return try? checkpoint(at: url)
  }

  private static func checkpoint(at url: URL) throws -> WalletBirthday {
    let data = try Data(contentsOf: url)
    let checkpoint = try JSONDecoder().decode(WalletBirthday.self, from: data)
    return checkpoint
  }
}
