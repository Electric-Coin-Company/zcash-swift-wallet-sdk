//
//  NotesRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/18/19.
//

import XCTest
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional
class NotesRepositoryTests: XCTestCase {
    var sentNotesRepository: SentNotesRepository!
    var receivedNotesRepository: ReceivedNoteRepository!

    override func setUp() {
        super.setUp()
        sentNotesRepository = TestDbBuilder.sentNotesRepository()
        receivedNotesRepository = TestDbBuilder.receivedNotesRepository()
    }
    
    override func tearDown() {
        super.tearDown()
        sentNotesRepository = nil
        receivedNotesRepository = nil
    }
    
    func testSentCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try sentNotesRepository.count() }())
        XCTAssertEqual(count, 0)
    }
    
    func testReceivedCount() {
        var count: Int?
        XCTAssertNoThrow(try { count = try receivedNotesRepository.count() }())
        XCTAssertEqual(count, 27)
    }
}
