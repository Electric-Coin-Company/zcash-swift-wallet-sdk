//
//  PagedTransactionRepositoryTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 12/6/19.
//

import XCTest
@testable import ZcashLightClientKit

// swiftlint:disable implicitly_unwrapped_optional
class PagedTransactionRepositoryTests: XCTestCase {
    var pagedTransactionRepository: PaginatedTransactionRepository!
    var transactionRepository: TransactionRepository!
    
    override func setUp() {
        super.setUp()
        transactionRepository = MockTransactionRepository(
            unminedCount: 5,
            receivedCount: 150,
            sentCount: 100,
            network: ZcashNetworkBuilder.network(for: .testnet)
        )
        pagedTransactionRepository = PagedTransactionDAO(repository: transactionRepository)
    }

    func testBrowsePages() {
        let pageSize = pagedTransactionRepository.pageSize
        let pageCount = pagedTransactionRepository.pageCount
        let totalItems = pagedTransactionRepository.itemCount

        for index in 0 ..< pageCount / pageSize {
            guard let page = try? pagedTransactionRepository.page(index) else {
                XCTFail("page failed to get page \(index)")
                return
            }
            if index < pageCount {
                XCTAssert(page.count == pageSize)
            } else {
                // last page has to have the remainding items
                XCTAssertEqual(page.count, totalItems - (pageSize * pageCount))
            }
        }
    }
}
