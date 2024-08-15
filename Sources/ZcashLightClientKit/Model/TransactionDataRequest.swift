//
//  TransactionDataRequest.swift
//
//
//  Created by Lukáš Korba on 08-15-2024.
//

import Foundation

struct SpendsFromAddress: Equatable {
    let address: String
    let blockRangeStart: UInt32
    let blockRangeEnd: Int64
}

enum TransactionDataRequest: Equatable {
    case getStatus([UInt8])
    case enhancement([UInt8])
    case spendsFromAddress(SpendsFromAddress)
}

enum TransactionStatus: Equatable {
    case txidNotRecognized
    case notInMainChain
    case mined(BlockHeight)
}
