//
//  PagedTransactionRepository.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/6/19.
//

import Foundation

public protocol PaginatedTransactionRepository {
    /**
    The page size of this repository
    */
    var pageSize: Int { get }
    
    /**
    How many pages are in total
    */
    var pageCount: Int { get }
    
    /**
    How many items are to be displayed in total
    */
    var itemCount: Int { get }

    /**
    Returns the page number if exists. Blocking
    */
    func page(_ number: Int) throws -> [TransactionEntity]?
    
    /**
    Returns the page number if exists. Non-blocking
    */
    func page(_ number: Int, result: @escaping (Result<[TransactionEntity]?, Error>) -> Void)
}
