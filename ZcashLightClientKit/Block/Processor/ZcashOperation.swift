//
//  ZcashOperation.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 10/27/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

typealias ZcashOperationCompletionBlock = (_ finished: Bool, _ cancelled: Bool) -> Void
typealias ZcashOperationStartedBlock = () -> Void
typealias ZcashOperationErrorBlock = (_ error: Error) -> Void

enum ZcashOperationError: Error {
    case unknown
}

class ZcashOperation: Operation {
    var error: Error?
    var startedHandler: ZcashOperationStartedBlock?
    var errorHandler: ZcashOperationErrorBlock?
    var completionHandler: ZcashOperationCompletionBlock?
    var handlerDispatchQueue: DispatchQueue = DispatchQueue.main
    
    override init() {
        super.init()
        
        completionBlock = { [weak self] in
            guard let self = self, let handler = self.completionHandler else { return }
            
            handler(self.isFinished, self.isCancelled)
        }
    }
    
    convenience init(completionDispatchQueue: DispatchQueue = DispatchQueue.main) {
        self.init()
        self.handlerDispatchQueue = completionDispatchQueue
    }
    
    override func start() {
        LoggerProxy.debug("\(self) started")
        startedHandler?()
        super.start()
    }
    
    func shouldCancel() -> Bool {
        self.error != nil || isCancelled || dependencyCancelled()
    }
    
    func dependencyCancelled() -> Bool {
        self.dependencies.first { $0.isCancelled } != nil
    }
    
    func fail(error: Error? = nil) {
        defer {
            self.cancel()
        }
        LoggerProxy.debug("\(self) failed")
        
        guard let errorHandler = self.errorHandler else {
            return
        }
        
        self.handlerDispatchQueue.async { [weak self] in
            let e = error ?? (self?.error ?? ZcashOperationError.unknown)
            errorHandler(e)
        }
        
    }
}
