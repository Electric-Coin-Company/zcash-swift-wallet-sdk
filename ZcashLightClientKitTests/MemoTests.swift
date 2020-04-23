//
//  MemoTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/23/20.
//

import XCTest

class MemoTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    /**
      Non-utf8 memos are properly ignored
     */
    func testNonUnicodeMemos() throws {
        
    }
    
    /**
     Memo length is correct, padding characters are ignored
     */
    func testMemoLength() throws {
        
    }
    /**
     Verify support for common unicode characters
     */
    func testUnicodeCharacters() throws {
        
    }

    /**
     Blank memos are ignored
     */
    func testBlankMemos() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
