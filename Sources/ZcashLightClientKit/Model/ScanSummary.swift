//
//  ScanSummary.swift
//
//
//  Created by Jack Grigg on 26/01/2024.
//

import Foundation

struct ScanSummary: Equatable {
    let scannedRange: Range<BlockHeight>
    let spentSaplingNoteCount: UInt64
    let receivedSaplingNoteCount: UInt64
}
