//
//  NotesDao.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/18/19.
//

import Foundation
import SQLite

struct ReceivedNote: ReceivedNoteEntity {
    var id: Int
    var spent: Int?
    var diverifier: Data
    var rcm: Data
    var nf: Data
    var isChange: Bool
    var transactionId: Int
    var outputIndex: Int
    var account: Int
    var address: String
    var value: Int
    var memo: Data?
}

class ReceivedNotesSQLDAO: ReceivedNoteRepository {
    var dbProvider: ConnectionProvider
    
    let table = Table("received_notes")
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func count() throws -> Int {
        try dbProvider.connection().scalar(table.count)
    }
}

struct SentNote: SentNoteEntity {
    var id: Int
    var transactionId: Int
    var outputIndex: Int
    var account: Int
    var address: String
    var value: Int
    var memo: Data?
}

class SentNotesSQLDAO: SentNotesRepository {
    var dbProvider: ConnectionProvider
    let table = Table("sent_notes")
    
    init(dbProvider: ConnectionProvider) {
        self.dbProvider = dbProvider
    }
    
    func count() throws -> Int {
        try dbProvider.connection().scalar(table.count)
    }
}
