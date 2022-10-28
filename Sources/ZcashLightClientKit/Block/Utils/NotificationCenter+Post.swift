//
//  NotificationCenter+Post.swift
//  
//
//  Created by Lukáš Korba on 12.10.2022.
//

import Foundation

extension NotificationCenter {
    func mainThreadPost(
        name aName: NSNotification.Name,
        object anObject: Any?,
        userInfo aUserInfo: [AnyHashable : Any]? = nil
    ) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: aName,
                object: anObject,
                userInfo: aUserInfo
            )
        }
    }
    
    func mainThreadPostNotification(_ notification: Notification) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(notification)
        }
    }
}
