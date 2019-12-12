//
//  AppDelegate.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 06/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var wallet: Initializer?
    var addresses: [String]?
    private var synchronizer: SDKSynchronizer?
    
    var sharedSynchronizer: SDKSynchronizer {
        if let sync = synchronizer {
            return sync
        } else {
            let sync = try! SDKSynchronizer(initializer: sharedWallet) // this must break if fails
            self.synchronizer = sync
            return sync
        }
    }
    
    var sharedWallet: Initializer {
        if let wallet = wallet {
            return wallet
        } else {
            let wallet = Initializer(cacheDbURL:try! __cacheDbURL() , dataDbURL: try! __dataDbURL(), pendingDbURL: try! __pendingDbURL(), endpoint: DemoAppConfig.endpoint, spendParamsURL: try! __spendParamsURL(), outputParamsURL: try! __outputParamsURL())
            self.addresses = try! wallet.initialize(seedProvider: DemoAppConfig(), walletBirthdayHeight: BlockHeight(DemoAppConfig.birthdayHeight)) // Init or DIE
            self.wallet = wallet
            return wallet
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        _ = self.sharedWallet
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
}
/**
 The functions below are convenience functions for THIS SAMPLE APP.
 */


extension AppDelegate {
    
    static var shared: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }
    
    func clearDatabases() {
        do {
            try FileManager.default.removeItem(at: try __cacheDbURL())
        } catch {
            print("error clearing cache DB: \(error)")
        }
        
        do {
            try FileManager.default.removeItem(at: try __dataDbURL())
        } catch {
            print("error clearing data db: \(error)")
        }
        
        do {
            try FileManager.default.removeItem(at: try __pendingDbURL())
        } catch {
            print("error clearing data db: \(error)")
        }
    }
}

extension DemoAppConfig: SeedProvider {}

extension Initializer {
    static var shared: Initializer {
        AppDelegate.shared.sharedWallet // AppDelegate or DIE.
    }
}

extension Synchronizer {
    static var shared: Synchronizer {
        AppDelegate.shared.sharedSynchronizer
    }
}

func __documentsDirectory() throws -> URL {
    try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
}

func __cacheDbURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("cache.db", isDirectory: false)
}

func __dataDbURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("data.db", isDirectory: false)
}

func __pendingDbURL() throws -> URL {
    try __documentsDirectory().appendingPathComponent("pending.db")
}

func __spendParamsURL() throws -> URL {
    Bundle.main.url(forResource: "sapling-spend", withExtension: ".params")!
}

func __outputParamsURL() throws -> URL {
    Bundle.main.url(forResource: "sapling-output", withExtension: ".params")!
}
