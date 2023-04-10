//
//  UnspentTransactionOutputEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/20.
//

import Foundation

public protocol UnspentTransactionOutputEntity {
    // TODO: [#714] Remove address field?, https://github.com/zcash/ZcashLightClientKit/issues/714
    var address: String { get }
    var txid: Data { get }
    var index: Int { get }
    var script: Data { get }
    var valueZat: Int { get }
    var height: Int { get }
}
