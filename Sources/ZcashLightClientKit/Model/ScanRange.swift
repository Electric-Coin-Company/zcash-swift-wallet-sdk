//
//  ScanRange.swift
//
//
//  Created by Jack Grigg on 17/07/2023.
//

import Foundation

struct ScanRange {
    enum Priority: UInt8 {
        case unknown = 0
        case scanned = 10
        case historic = 20
        case openAdjacent = 30
        case foundNote = 40
        case chainTip = 50
        case verify = 60
        
        init(_ value: UInt8) {
            self = Priority(rawValue: value) ?? .unknown
        }
    }
    
    let range: Range<BlockHeight>
    let priority: Priority
}
