//
//  NotesRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/18/19.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

class NotesRepositoryTests: XCTestCase {
    var sentNotesRepository: SentNotesRepository!
    var receivedNotesRepository: ReceivedNoteRepository!

    override func setUp() async throws {
        try await super.setUp()
        sentNotesRepository = try! await TestDbBuilder.sentNotesRepository()
        receivedNotesRepository = try! await TestDbBuilder.receivedNotesRepository()
    }
    
    override func tearDown() {
        super.tearDown()
        sentNotesRepository = nil
        receivedNotesRepository = nil
    }
    
    func testSentCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try sentNotesRepository.count() }())
        XCTAssertEqual(count, 13)
    }
    
    func testReceivedCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try receivedNotesRepository.count() }())
        XCTAssertEqual(count, 22)
    }
}
