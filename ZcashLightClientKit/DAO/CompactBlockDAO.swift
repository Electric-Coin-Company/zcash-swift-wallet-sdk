//
//   CompactBlockDAO.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

protocol CompactBlockDAO {
    func createTable() throws
    
    func insert(_ block: ZcashCompactBlock) throws
    
    func insert(_ blocks: [ZcashCompactBlock]) throws
    
    /**
    Query the latest block height, returns -1 if no block is stored
    */
    func latestBlockHeight() throws -> BlockHeight
    
    func rewind(to height: BlockHeight) throws
}
