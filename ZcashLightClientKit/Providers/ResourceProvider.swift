//
//  ResourceProvider.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 19/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

public enum ResourceProviderError: Error {
    case unavailableResource
}
public protocol ResourceProvider {
    
    var dataDbPath: String { get }
    var cacheDbPath: String { get }
    
}

public struct DefaultResourceProvider: ResourceProvider {
     
     public var dataDbPath: String {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return url.appendingPathComponent(DEFAULT_DATA_DB_NAME).path
        } catch {
            return "file://\(DEFAULT_DATA_DB_NAME)"
        }
        
    }
    
    public var cacheDbPath: String {
        do {
            let path = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return path.appendingPathComponent(DEFAULT_CACHES_DB_NAME).path
        } catch {
            return "file://\(DEFAULT_CACHES_DB_NAME)"
        }
    }
    
}
