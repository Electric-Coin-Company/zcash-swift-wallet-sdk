//
//  LightWalletService.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftGRPC

public enum LightWalletServiceError: Error {
    case generalError
    case failed(statusCode: StatusCode)
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
            
        }
    }
    
}

public protocol LightWalletSyncService {
    
    /// Return the latest block height known to the service.
    func latestBlockHeight() throws -> BlockHeight
    
}


public protocol LightWalletService {
    /**
        Return the latest block height known to the service.
     
        - Parameter result: a result containing the height or an Error
     */
    func latestBlockHeight(result: @escaping (Result<BlockHeight,LightWalletServiceError>) -> ())
    
    /**
          Return the given range of blocks.
      
          - Parameter range: the inclusive range to fetch.
          For instance if 1..5 is given, then every block in that will be fetched, including 1 and 5.
    */
    func blockRange(_ range: Range<BlockHeight>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void )
    
}
