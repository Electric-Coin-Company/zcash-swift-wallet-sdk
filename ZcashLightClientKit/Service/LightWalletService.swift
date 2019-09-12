//
//  LightWalletService.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation


public enum LightWalletServiceError: Error {
    case generalError
}

public protocol LightWalletSyncService {
    
    /// Return the latest block height known to the service.
    func latestBlockHeight() throws -> UInt64
    
}


public protocol LightWalletService {
    /**
        Return the latest block height known to the service.
     
        - Parameter result: a result containing the height or an Error
     */
    func latestBlockHeight(result: @escaping (Result<UInt64,LightWalletServiceError>) -> ())
    
    /**
          Return the given range of blocks.
      
          - Parameter range: the inclusive range to fetch.
          For instance if 1..5 is given, then every block in that will be fetched, including 1 and 5.
    */
    func blockRange(_ range: Range<UInt64>, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void )
    
}
