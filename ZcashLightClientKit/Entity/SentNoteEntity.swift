//
//  Sent.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

protocol SentNoteEntity {
    var id: Int { get set }
    var transactionId: Int { get set }
    var outputIndex: Int { get set }
    var account: Int { get set }
    var address: String { get set }
    var value: Int { get set }
    var memo: Data? { get set }
}
    
extension SentNoteEntity {
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.id == rhs.id,
            lhs.transactionId == rhs.transactionId,
            lhs.outputIndex == rhs.outputIndex,
            lhs.account == rhs.account,
            lhs.address == rhs.address,
            lhs.value == rhs.value,
            lhs.memo == rhs.memo else { return false }
        return true
    }
            
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(transactionId)
        hasher.combine(outputIndex)
        hasher.combine(account)
        hasher.combine(address)
        hasher.combine(value)
        if let memo = memo {
            hasher.combine(memo)
        } else {
            hasher.combine(Int(0))
        }
    }
}
