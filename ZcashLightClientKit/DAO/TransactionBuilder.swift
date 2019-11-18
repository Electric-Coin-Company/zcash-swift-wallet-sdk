//
//  TransactionBuilder.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/18/19.
//

import Foundation
import SQLite
struct TransactionBuilder {
    enum ConfirmedColumns: Int {
           case id
           case minedHeight
           case transactionIndex
           case rawTransactionId
           case expiryHeight
           case raw
           case toAddress
           case value
           case memo
           case noteId
           case blockTimeInSeconds
    }
    
    enum ReceivedColumns: Int {
        case id
        case minedHeight
        case transactionIndex
        case rawTransactionId
        case value
        case memo
        case noteId
        case blockTimeInSeconds
    }
    
    static func createConfirmedTransaction(from bindings: [Binding?]) -> ConfirmedTransaction? {
        guard let id = bindings[ConfirmedColumns.id.rawValue] as? Int64,
            let minedHeight = bindings[ConfirmedColumns.minedHeight.rawValue] as? Int64,
            let noteId = bindings[ConfirmedColumns.noteId.rawValue] as? Int64,
            let blockTimeInSeconds = bindings[ConfirmedColumns.blockTimeInSeconds.rawValue] as? Int64,
            let transactionIndex = bindings[ConfirmedColumns.transactionIndex.rawValue] as? Int64,
            let value = bindings[ConfirmedColumns.value.rawValue] as? Int64
            else { return nil }
        
        // Optional values
        
        var toAddress: String?
        if let to =  bindings[ConfirmedColumns.toAddress.rawValue] as? String {
            toAddress = to
        }
        
        var expiryHeight: BlockHeight?
        if let expiry = bindings[ConfirmedColumns.expiryHeight.rawValue] as? Int64{
            expiryHeight = BlockHeight(expiry)
        }
        
        var raw: Data?
        if let rawBlob = bindings[ConfirmedColumns.raw.rawValue] as? Blob {
            raw = Data(blob: rawBlob)
        }
        
        var memo: Data?
        if let memoBlob =  bindings[ConfirmedColumns.memo.rawValue] as? Blob {
            memo = Data(blob: memoBlob)
        }
        
        var transactionId: Data?
        if let txIdBlob = bindings[ConfirmedColumns.rawTransactionId.rawValue] as? Blob {
            transactionId = Data(blob: txIdBlob)
        }
        
        return ConfirmedTransaction(toAddress: toAddress,
             expiryHeight: expiryHeight,
             minedHeight: Int(minedHeight),
             noteId: Int(noteId),
             blockTimeInSeconds: TimeInterval(integerLiteral: blockTimeInSeconds),
             transactionIndex: Int(transactionIndex),
             raw: raw,
             id: UInt(id),
             value: Int(value),
             memo: memo,
             rawTransactionId: transactionId)
    }
    
    static func createReceivedTransaction(from bindings: [Binding?]) -> ConfirmedTransaction? {
        guard let id = bindings[ReceivedColumns.id.rawValue] as? Int64,
            let minedHeight = bindings[ReceivedColumns.minedHeight.rawValue] as? Int64,
            let noteId = bindings[ReceivedColumns.noteId.rawValue] as? Int64,
            let blockTimeInSeconds = bindings[ReceivedColumns.blockTimeInSeconds.rawValue] as? Int64,
            let transactionIndex = bindings[ReceivedColumns.transactionIndex.rawValue] as? Int64,
            let value = bindings[ReceivedColumns.value.rawValue] as? Int64
            else { return nil }
        
        // Optional values
        
        var memo: Data?
        if let memoBlob =  bindings[ReceivedColumns.memo.rawValue] as? Blob {
            memo = Data(blob: memoBlob)
        }
        
        var transactionId: Data?
        if let txIdBlob = bindings[ReceivedColumns.rawTransactionId.rawValue] as? Blob {
            transactionId = Data(blob: txIdBlob)
        }
        
        return ConfirmedTransaction(toAddress: nil,
             expiryHeight: nil,
             minedHeight: Int(minedHeight),
             noteId: Int(noteId),
             blockTimeInSeconds: TimeInterval(integerLiteral: blockTimeInSeconds),
             transactionIndex: Int(transactionIndex),
             raw: nil,
             id: UInt(id),
             value: Int(value),
             memo: memo,
             rawTransactionId: transactionId)
    }
}
