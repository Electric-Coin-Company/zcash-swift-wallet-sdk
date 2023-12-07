//
//  DBActor.swift
//
//
//  Created by Michal Fousek on 07.12.2023.
//

import Foundation

/// Global actor used to protect access to the Data DB.
@globalActor
enum DBActor {
    actor Actor { }
    typealias ActorType = Actor
    static let shared = Actor()
    static var sharedUnownedExecutor: UnownedSerialExecutor { shared.unownedExecutor }
}
