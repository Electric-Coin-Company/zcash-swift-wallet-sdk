//
//  ReceivedNotesEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

protocol ReceivedNoteEntity {
    var id: Int { get set }
    var transactionId: Int { get set }
    var outputIndex: Int { get set }
    var account: Int { get set }
    var value: Int { get set }
    var memo: Data? { get set }
    var spent: Int? { get set }
    var diversifier: Data { get set }
    var rcm: Data { get set }
    var nf: Data { get set }
    var isChange: Bool { get set }
}
