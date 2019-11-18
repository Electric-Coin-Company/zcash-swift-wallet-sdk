//
//  ReceivedNotesEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/14/19.
//

import Foundation

protocol ReceivedNoteEntity: SentNoteEntity {
    var spent: Int? { get set }
    var diverifier: Data { get set }
    var rcm: Data { get set }
    var nf: Data { get set }
    var isChange: Bool { get set }
}
