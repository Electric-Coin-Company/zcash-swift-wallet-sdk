//
//  AppDelegate.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 06/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
import NotificationBubbles

var loggerProxy = SampleLogger(logLevel: .debug)

@UIApplicationMain
// swiftlint:disable force_cast force_try force_unwrapping
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var wallet: Initializer?
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
            let unifiedViewingKeys = try! DerivationTool(networkType: kZcashNetwork.networkType)
                .deriveUnifiedViewingKeysFromSeed(DemoAppConfig.seed, numberOfAccounts: 1)

            let wallet = Initializer(
                cacheDbURL: try! cacheDbURLHelper(),
                dataDbURL: try! dataDbURLHelper(),
                pendingDbURL: try! pendingDbURLHelper(),
                endpoint: DemoAppConfig.endpoint,
                network: kZcashNetwork,
                spendParamsURL: try! spendParamsURLHelper(),
                outputParamsURL: try! outputParamsURLHelper(),
                viewingKeys: unifiedViewingKeys,
                walletBirthday: DemoAppConfig.birthdayHeight,
                loggerProxy: loggerProxy
            )
            
            try! wallet.initialize()
            var storage = SampleStorage.shared
            storage!.seed = Data(DemoAppConfig.seed)
            storage!.privateKey = try! DerivationTool(networkType: kZcashNetwork.networkType)
                .deriveSpendingKeys(seed: DemoAppConfig.seed, numberOfAccounts: 1)[0]
            self.wallet = wallet
            return wallet
        }
    }
    
    func subscribeToMinedTxNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(txMinedNotification(_:)),
            name: Notification.Name.synchronizerMinedTransaction,
            object: nil
        )
    }
    
    @objc func txMinedNotification(_ notification: Notification) {
        guard let transaction = notification.userInfo?[SDKSynchronizer.NotificationKeys.minedTransaction] as? PendingTransactionEntity else {
            loggerProxy.error("no tx information on notification")
            return
        }

        NotificationBubble.display(
            in: window!.rootViewController!.view,
            options: NotificationBubble.sucessOptions(
                animation: NotificationBubble.Animation.fade(duration: 1)
            ),
            attributedText: NSAttributedString(string: "Transaction \(String(describing: transaction.id))mined!"),
            handleTap: {}
        )
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        _ = self.sharedWallet
        subscribeToMinedTxNotifications()
        
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
            try FileManager.default.removeItem(at: try cacheDbURLHelper())
        } catch {
            loggerProxy.error("error clearing cache DB: \(error)")
        }
        
        do {
            try FileManager.default.removeItem(at: try dataDbURLHelper())
        } catch {
            loggerProxy.error("error clearing data db: \(error)")
        }
        
        do {
            try FileManager.default.removeItem(at: try pendingDbURLHelper())
        } catch {
            loggerProxy.error("error clearing data db: \(error)")
        }
        
        var storage = SampleStorage.shared
        storage!.seed = nil
        storage!.privateKey = nil
    }
}

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

func documentsDirectoryHelper() throws -> URL {
    try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
}

func cacheDbURLHelper() throws -> URL {
    try documentsDirectoryHelper()
        .appendingPathComponent(
            kZcashNetwork.constants.defaultDbNamePrefix + ZcashSDK.defaultCacheDbName,
            isDirectory: false
        )
}

func dataDbURLHelper() throws -> URL {
    try documentsDirectoryHelper()
        .appendingPathComponent(
            kZcashNetwork.constants.defaultDbNamePrefix + ZcashSDK.defaultDataDbName,
            isDirectory: false
        )
}

func pendingDbURLHelper() throws -> URL {
    try documentsDirectoryHelper()
        .appendingPathComponent(kZcashNetwork.constants.defaultDbNamePrefix + ZcashSDK.defaultPendingDbName)
}

func spendParamsURLHelper() throws -> URL {
    try documentsDirectoryHelper().appendingPathComponent("sapling-spend.params")
}

func outputParamsURLHelper() throws -> URL {
    try documentsDirectoryHelper().appendingPathComponent("sapling-output.params")
}

public extension NotificationBubble {
    static func sucessOptions(animation: NotificationBubble.Animation) -> [NotificationBubble.Style] {
        return [
            NotificationBubble.Style.animation(animation),
            NotificationBubble.Style.margins(UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0)),
            NotificationBubble.Style.cornerRadius(8),
            NotificationBubble.Style.duration(timeInterval: 10),
            NotificationBubble.Style.backgroundColor(UIColor.green)
        ]
    }
}
