//
//  UnspentTransactionOutputEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/20.
//

import Foundation

public protocol UnspentTransactionOutputEntity {
    // TODO: [#714] Remove address field?, https://github.com/zcash/ZcashLightClientKit/issues/714
    var address: String { get set }
    var txid: Data { get set }
    var index: Int { get set }
    var script: Data { get set }
    var valueZat: Int { get set }
    var height: Int { get set }
}
