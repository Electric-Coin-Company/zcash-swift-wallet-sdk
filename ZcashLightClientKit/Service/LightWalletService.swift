//
//  LightWalletService.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import SwiftProtobuf

/**
 Wrapper for errors received from a Lightwalletd endpoint
 */
public enum LightWalletServiceError: Error {
    case generalError(message: String)
    case failed(statusCode: Int, message: String)
    case invalidBlock
    case sentFailed(error: Error)
    case genericError(error: Error)
    case timeOut
    case criticalError
    case userCancelled
    case unknown
}

extension LightWalletServiceError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .generalError(let m):
            switch rhs {
            case .generalError(let msg):
                return m == msg
            default:
                return false
            }
        case .failed(let statusCode, _):
            switch rhs {
            case .failed(let anotherStatus, _):
                return statusCode == anotherStatus
            default:
                return false
            }
            
        case .invalidBlock:
            switch rhs {
            case .invalidBlock:
                return true
            default:
                return false
            }
        case .sentFailed:
            switch rhs {
            case .sentFailed:
                return true
            default:
                return false
            }
        case .genericError:
            return false
        
        case .timeOut:
            switch rhs {
            case .timeOut:
                return true
            default:
                return false
            }
        case .criticalError:
            switch rhs  {
            case .criticalError:
                return true
            default:
                return false
            }
        case .userCancelled:
            switch rhs  {
            case .userCancelled:
                return true
            default:
                return false
            }
        case .unknown:
            switch rhs  {
            case .unknown:
                return true
            default:
                return false
            }
        }
    }
}

public protocol LightWalletServiceResponse {
    var errorCode: Int32 { get }
    var errorMessage: String { get }
    var unknownFields: SwiftProtobuf.UnknownStorage { get }
}

extension SendResponse: LightWalletServiceResponse {}

public protocol LightWalletService {
    /**
        Return the latest block height known to the service.
     
        - Parameter result: a result containing the height or an Error
     */
    func latestBlockHeight(result: @escaping (Result<BlockHeight,LightWalletServiceError>) -> Void)
    
    /**
       Return the latest block height known to the service.
    
       - Parameter result: a result containing the height or an Error
    */
    
    func latestBlockHeight() throws -> BlockHeight
    /**
          Return the given range of blocks.
      
          - Parameter range: the inclusive range to fetch.
          For instance if 1..5 is given, then every block in that will be fetched, including 1 and 5.
        Non blocking
    */
    func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void )
    
    /**
             Return the given range of blocks.
         
             - Parameter range: the inclusive range to fetch.
            
     For instance if 1..5 is given, then every block in that will be fetched, including 1 and 5.
            blocking
     
       */
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock]
    
    /**
     Submits a raw transaction over lightwalletd. Non-Blocking
     - Parameter spendTransaction: data representing the transaction to be sent
     - Parameter result: escaping closure that takes a result containing either LightWalletServiceResponse or LightWalletServiceError
     */
    func submit(spendTransaction: Data, result: @escaping(Result<LightWalletServiceResponse,LightWalletServiceError>) -> Void)
    
    /**
    Submits a raw transaction over lightwalletd. Blocking
     - Parameter spendTransaction: data representing the transaction to be sent
     - Throws: LightWalletServiceError
     - Returns: LightWalletServiceResponse
    */
    
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse
    
    /**
    Gets a transaction by id
     - Parameter txId: data representing the transaction ID
     - Throws: LightWalletServiceError
     - Returns: LightWalletServiceResponse
     */
    
    func fetchTransaction(txId: Data) throws -> TransactionEntity
    
    /**
    Gets a transaction by id
     - Parameter txId: data representing the transaction ID
     - Parameter result: handler for the result
     - Throws: LightWalletServiceError
     - Returns: LightWalletServiceResponse
     */
    func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity,LightWalletServiceError>) -> Void)
    
    func fetchUTXOs(for tAddress: String, result: @escaping(Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void)
}
