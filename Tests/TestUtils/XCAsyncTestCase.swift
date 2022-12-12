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

extension XCTestCase {
    static func wait(asyncBlock: @escaping (() async throws -> Void)) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.init {
            try await asyncBlock()
            semaphore.signal()
        }
        semaphore.wait()
    }

    func wait(asyncBlock: @escaping (() async throws -> Void)) {
        XCTestCase.wait(asyncBlock: asyncBlock)
    }
}
