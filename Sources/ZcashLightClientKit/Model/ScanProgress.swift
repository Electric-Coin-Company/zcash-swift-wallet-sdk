//
//  ScanProgress.swift
//  
//
//  Created by Jack Grigg on 06/09/2023.
//

import Foundation

struct ScanProgress: Equatable {
    let numerator: UInt64
    let denominator: UInt64
    
    func progress() throws -> Float {
        guard denominator != 0 else {
            // this shouldn't happen but if it does, we need to get notified by clients and work on a fix
            throw ZcashError.rustScanProgressOutOfRange("\(numerator)/\(denominator)")
        }

        let value = Float(numerator) / Float(denominator)
        
        // this shouldn't happen but if it does, we need to get notified by clients and work on a fix
        if value > 1.0 {
            throw ZcashError.rustScanProgressOutOfRange("\(value)")
        }

        return value
    }
}
