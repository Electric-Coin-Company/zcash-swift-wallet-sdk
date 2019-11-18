//
//  NotesRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/18/19.
//

import Foundation

protocol ReceivedNoteRepository {
    func count() throws -> Int
}

protocol SentNotesRepository {
    func count() throws -> Int
}
