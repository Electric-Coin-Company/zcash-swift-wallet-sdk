//
//  NotesRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 11/18/19.
//

import XCTest
@testable import TestUtils
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional
class NotesRepositoryTests: XCTestCase {
    var sentNotesRepository: SentNotesRepository!
    var receivedNotesRepository: ReceivedNoteRepository!

    override func setUp() {
        super.setUp()
        sentNotesRepository = try! TestDbBuilder.sentNotesRepository()
        receivedNotesRepository = try! TestDbBuilder.receivedNotesRepository()
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
