//
//  CompactBlockDownloadOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/16/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

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
        guard !shouldCancel() else {
            cancel()
            return
        }
        do {
            try downloader.downloadBlockRange(range)
        } catch {
            self.error = error
            self.fail()
        }
    }
}
