//
//  Storage.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/13/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation


protocol Storage {
    
    func createDatabase(at path: String) throws
    
    func closeDatabase()
    
    var compactBlockDao: CompactBlockDAO { get }
}

enum StorageError: Error {
    case couldNotCreate
    case openFailed
    case closeFailed
    case operationFailed
}


