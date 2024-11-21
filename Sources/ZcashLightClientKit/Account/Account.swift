//
//  Account.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 19.11.2024.
//

public struct Account: Equatable, Codable, Hashable {
    public let id: Int32
    
    public init(_ id: Int32) {
        self.id = id
    }
}
