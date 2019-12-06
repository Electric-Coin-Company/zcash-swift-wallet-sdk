//
//  LightWalletService.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftGRPC
import SwiftProtobuf
public enum LightWalletServiceError: Error {
    case generalError
    case failed(statusCode: StatusCode)
    case invalidBlock
    case sentFailed(sendResponse: LightWalletServiceResponse)
    case genericError(error: Error)
}

extension LightWalletServiceError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .generalError:
            switch rhs {
            case .generalError:
                return true
            default:
                return false
            }
        case .failed(let statusCode):
            switch rhs {
            case .failed(let anotherStatus):
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
        case .sentFailed(let sendResponse):
            switch rhs {
            case .sentFailed(let response):
                return response.errorCode == sendResponse.errorCode
            default:
                return false
            }
        case .genericError:
            return false
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
    func blockRange(_ range: Range<BlockHeight>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void )
    
    /**
             Return the given range of blocks.
         
             - Parameter range: the inclusive range to fetch.
             For instance if 1..5 is given, then every block in that will be fetched, including 1 and 5.
            blocking
     
       */
    func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock]
    
    /**
     Submits a raw transaction over lightwalletd. Non-Blocking
     */
    func submit(spendTransaction: Data, result: @escaping(Result<LightWalletServiceResponse,LightWalletServiceError>) -> Void)
    
    /**
    Submits a raw transaction over lightwalletd. Blocking
    */
    
    func submit(spendTransaction: Data) throws -> LightWalletServiceResponse
    
}
