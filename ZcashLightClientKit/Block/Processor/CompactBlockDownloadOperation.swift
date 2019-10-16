//
//  CompactBlockDownloadOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

typealias ZcashOperationCompletionBlock = (_ finished: Bool, _ cancelled: Bool, _ error: Error?) -> Void

class ZcashOperation: Operation {
    var error: Error?
    var completionHandler: ZcashOperationCompletionBlock?
    var completionDispatchQueue: DispatchQueue = DispatchQueue.main
    
    override init() {
        super.init()
        
        completionBlock = { [weak self] in
            guard let self = self else { return }
            self.completionHandler?(self.isFinished, self.isCancelled, self.error)
            
        }
    }
    
    convenience init(completionDispatchQueue: DispatchQueue = DispatchQueue.main) {
        self.init()
        self.completionDispatchQueue = completionDispatchQueue
    }
}

class CompactBlockDownloadOperation: ZcashOperation {
    
    override var isConcurrent: Bool { false }
       
    override var isAsynchronous: Bool { false }
    
    private var downloader: CompactBlockDownloading?
    
    private var range: CompactBlockRange?
    
    required init(downloader: CompactBlockDownloading, range: CompactBlockRange) {
        super.init()
        self.name = "Download Operation: \(range)"
        self.range = range
        self.downloader = downloader

    }
    
    override func main() {
        
        guard let range = range, let downloader = downloader else { return }
        
        do {
            try downloader.downloadBlockRange(range)
        } catch {
            self.error = error
            self.cancel()
        }
    }
}
