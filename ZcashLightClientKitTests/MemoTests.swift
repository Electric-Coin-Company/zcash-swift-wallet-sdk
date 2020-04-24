//
//  MemoTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 4/23/20.
//

import XCTest
@testable import ZcashLightClientKit
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
        XCTAssertNil(Self.randomMemoData()!.asZcashTransactionMemo())
    }
    
    /**
     Memo length is correct, padding characters are ignored
     */
    func testMemoLength() throws {
        XCTAssertEqual(validMemoData.count, 512)
        XCTAssertEqual(validMemoData.asZcashTransactionMemo()!.count, Self.validMemoDataExpectedString.count)
    }
    /**
     Verify support for common unicode characters
     */
    func testUnicodeCharacters() throws {
        
        let memo = validMemoData.asZcashTransactionMemo()
        XCTAssertNotNil(memo)
        XCTAssertEqual(memo!, Self.validMemoDataExpectedString)
        
    }
    
    /**
     Blank memos are ignored
     */
    func testBlankMemos() throws {
        // This is an example of a functional test case.
        XCTAssertNil(emptyMemoData.asZcashTransactionMemo())
    }
    
    /**
     *******
     * mocked memos
     * ******
     */
    
    /**
     Real text:  "Here's gift from the Zec Fairy @ ECC!"
     */
    static let validMemoDataExpectedString = "Here's gift from the Zec Fairy @ ECC!"
    
    static let validMemoDataBase64 = "SGVyZSdzIGdpZnQgZnJvbSB0aGUgWmVjIEZhaXJ5IEAgRUNDIQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    
    let validMemoData = Data(base64Encoded: validMemoDataBase64)!
    
    let emptyMemoData = Data([UInt8](repeating: 0, count: 512))
    
    let totallyRandomDataMemo = randomMemoData()!
    
    
    
    static func randomMemoData() -> Data? {
        let length: Int = 512
        var keyData = Data(count: length)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }
        if result == errSecSuccess {
            return keyData
        } else {
            print("Problem generating random bytes")
            return nil
        }
    }
}

