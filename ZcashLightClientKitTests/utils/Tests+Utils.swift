//
//  Tests+Utils.swift
//  ZcashLightClientKitTests
//
//  Created by Francisco Gindre on 18/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import SwiftGRPC

import XCTest
class ChannelProvider {
    func channel() -> SwiftGRPC.Channel {
        Channel(address: Constants.address, secure: false)
    }
}


struct MockDbInit {
    @discardableResult static func emptyFile(at path: String) -> Bool {
        
        
        FileManager.default.createFile(atPath: path, contents: Data("".utf8), attributes: nil)
        
        
    }
    
    static func destroy(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

}

extension XCTestExpectation {
    func suscribe(to notification: Notification.Name, object: Any?) {
        NotificationCenter.default.addObserver(self, selector: #selector(fulfill), name: notification, object: object)
    }
    
    func unsuscribe(from notification: Notification.Name) {
        NotificationCenter.default.removeObserver(self, name: notification, object: nil)
    }
    
    func unsuscribeFromNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
