//
//  NotificationSender.swift
//  
//
//  Created by Michal Fousek on 21.11.2022.
//

import Foundation

class NotificationSender {
    static let `default` = NotificationSender()
    private let queue = DispatchQueue(label: "NotificationsSender")

    func post(name aName: Notification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable : Any]? = nil) {
        let notification = Notification(name: aName, object: anObject, userInfo: aUserInfo)
        post(notification: notification)
    }

    func post(notification: Notification) {
        queue.async {
            NotificationCenter.default.post(notification)
        }
    }
}
