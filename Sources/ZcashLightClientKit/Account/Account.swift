//
//  Account.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2024-11-19.
//

/// A [ZIP 32](https://zips.z.cash/zip-0032) account index.
public struct Zip32Account: Equatable, Codable, Hashable {
    public let index: Int32
    
    public init(_ index: Int32) {
        guard index >= 0 else {
            fatalError("Account index must be >= 0. Input value is \(index).")
        }
        
        self.index = index
    }
}

public struct AccountId: Equatable, Codable, Hashable {
    public let index: Int
    
    public init(_ index: Int) {
        guard index >= 0 else {
            fatalError("Account index must be >= 0. Input value is \(index).")
        }
        
        self.index = index
    }
}
