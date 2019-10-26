//
//  CompactBlockDownloadOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

typealias ZcashOperationCompletionBlock = (_ finished: Bool, _ cancelled: Bool, _ error: Error?) -> Void
typealias ZcashOperationStartedBlock = () -> Void
enum ZcashOperationError: Error {
    case unknown
}

class ZcashOperation: Operation {
    var error: Error?
    var startedHandler: ZcashOperationStartedBlock?
    var completionHandler: ZcashOperationCompletionBlock?
    var completionDispatchQueue: DispatchQueue = DispatchQueue.main
    
    override init() {
        super.init()
        
        completionBlock = { [weak self] in
            guard let self = self, let handler = self.completionHandler else { return }
            
            self.completionDispatchQueue.async {
                handler(self.isFinished, self.isCancelled, self.error)
            }
        }
    }
    
    convenience init(completionDispatchQueue: DispatchQueue = DispatchQueue.main) {
        self.init()
        self.completionDispatchQueue = completionDispatchQueue
    }
    
    override func start() {
        startedHandler?()
        super.start()
    }
}

class CompactBlockDownloadOperation: ZcashOperation {
    
    override var isConcurrent: Bool { false }
       
    override var isAsynchronous: Bool { false }
    
    private var downloader: CompactBlockDownloading
    
    private var range: CompactBlockRange
    
    required init(downloader: CompactBlockDownloading, range: CompactBlockRange) {
        self.range = range
        self.downloader = downloader
        super.init()
        self.name = "Download Operation: \(range)"
    }
    
    override func main() {
        do {
            try downloader.downloadBlockRange(range)
        } catch {
            self.error = error
            self.cancel()
        }
    }
}
