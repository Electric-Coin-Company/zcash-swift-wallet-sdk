//
//  XCAsyncTestCase.swift
//  
//
//  credits: https://betterprogramming.pub/async-setup-and-teardown-in-xctestcase-dc7a2cdb9fb
//
///
/// A subclass of ``XCTestCase`` that supports async setup and teardown.
///
import Foundation
import XCTest
class XCAsyncTestCase: XCTestCase {

    func asyncSetUpWithError() async throws {
        fatalError("Must override")
    }

    func asyncTearDownWithError() async throws {
        fatalError("Must override")
    }

    override func setUpWithError() throws {
        wait {
            try await self.asyncSetUpWithError()
        }
    }

    override func tearDownWithError() throws {
        wait {
            try await self.asyncTearDownWithError()
        }
    }

    func wait(asyncBlock: @escaping (() async throws -> Void)) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.init {
            try await asyncBlock()
            semaphore.signal()
        }
        semaphore.wait()
    }
}
