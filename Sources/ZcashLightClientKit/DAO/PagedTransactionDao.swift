//
//  File.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/9/19.
//

import Foundation

class PagedTransactionDAO: PaginatedTransactionRepository {
    var pageSize: Int
    var transactionRepository: TransactionRepository
    var kind: TransactionKind
    
    var pageCount: Int {
        guard pageSize > 0 else {
            return 0
        }
        return itemCount / pageSize
    }
    
    var itemCount: Int {
        guard let count = try? transactionRepository.countAll() else {
            return 0
        }
        return count
    }
    
    init(repository: TransactionRepository, pageSize: Int = 30, kind: TransactionKind = .all) {
        self.transactionRepository = repository
        self.pageSize = pageSize
        self.kind = kind
    }
    
    func getAll(offset: Int, limit: Int, kind: TransactionKind) throws -> [ConfirmedTransactionEntity]? {
        switch kind {
        case .all:
            return try transactionRepository.findAll(offset: offset, limit: limit)
        case .received:
            return try transactionRepository.findAll(offset: offset, limit: limit)
        case .sent:
            return try transactionRepository.findAllSentTransactions(offset: offset, limit: limit)
        }
    }
    
    func page(_ number: Int) throws -> [TransactionEntity]? {
        let offset = number * pageSize
        guard offset < itemCount else { return nil }
        return try getAll(offset: offset, limit: pageSize, kind: kind)?.map({ $0.transactionEntity })
    }
    
    func page(_ number: Int, result: @escaping (Result<[TransactionEntity]?, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                result(.success(try self.page(number)))
            } catch {
                result(.failure(error))
            }
        }
    }
}
