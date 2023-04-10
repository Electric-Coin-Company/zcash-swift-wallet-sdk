//
//  ReceivedNotesEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

protocol ReceivedNoteEntity {
    var id: Int { get }
    var transactionId: Int { get }
    var outputIndex: Int { get }
    var account: Int { get }
    var value: Int { get }
    var memo: Data? { get }
    var spent: Int? { get }
    var diversifier: Data { get }
    var rcm: Data { get }
    var nf: Data { get }
    var isChange: Bool { get }
}
