//
//  AppDelegate.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase
import Alamofire
import SwiftyBeaver
let log = SwiftyBeaver.self
import MultipeerConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    // Override point for customization after application launch.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let console = ConsoleDestination()
        let file = FileDestination()  // log to default swiftybeaver.log file
        console.format = "$DHH:mm:ss$d $L $M"
        console.levelString.info = "\u{1F49C} (INFO)"
        console.levelString.error = "\u{2764} (ERROR)"
        log.addDestination(console)
        log.addDestination(file)
        
        SKCacheManager.cache.diskStorage.config.expiration = .never
        SKCacheManager.cache.diskStorage.config.sizeLimit = 1000 * 1024 * 1024 // 1GB
        SKCacheManager.cache.memoryStorage.config.countLimit = 150
        
        FirebaseApp.configure()
        
        if SettingsManager.firstAppStartup() {
            _ = NeoLibrary.getHomeDirectoryURL()
            UserDefaults.settings.set(false, forKey: SettingsKeys.AutomaticAnnotation.rawValue)
            UserDefaults.settings.set(true, forKey: SettingsKeys.TextRecognitionCloud.rawValue)
            UserDefaults.settings.set(true, forKey: SettingsKeys.TextRecognitionCloudOption.rawValue)
            UserDefaults.annotators.set(true, forKey: Annotator.TAGME.rawValue)
            UserDefaults.annotators.set(true, forKey: Annotator.BioPortal.rawValue)
            UserDefaults.annotators.set(true, forKey: Annotator.CHEBI.rawValue)
        }
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
        if importURL != nil {
            Notifications.announce(importedNoteURL: importURL)
            importURL = nil
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    var importURL: URL?
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        log.info("Attempting to import file from outside.")
        importURL = url
        return true
    }

}

