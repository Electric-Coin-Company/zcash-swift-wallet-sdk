//
//  WalletBirthday+mainnet.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 7/28/21.
//
// swiftlint:disable function_body_length line_length cyclomatic_complexity
import Foundation

extension WalletBirthday {
  static let mainnetMin = WalletBirthday(
    height: 419_200,
    hash: "00000000025a57200d898ac7f21e26bf29028bbe96ec46e05b2c17cc9db9e4f3",
    time: 1540779337,
    tree: "000000"
  )

  static let mainnetCheckpointDirectory = Bundle.module.bundleURL.appendingPathComponent("saplingtree-checkpoints/mainnet/")

}
